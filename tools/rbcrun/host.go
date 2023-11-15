// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package rbcrun

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"go.starlark.net/starlark"
	"go.starlark.net/starlarkstruct"
)

type ExecutionMode int
const (
	ExecutionModeRbc ExecutionMode = iota
	ExecutionModeScl ExecutionMode = iota
)

const allowExternalEntrypointKey = "allowExternalEntrypoint"
const callingFileKey = "callingFile"
const executionModeKey = "executionMode"
const shellKey = "shell"

type modentry struct {
	globals starlark.StringDict
	err     error
}

var moduleCache = make(map[string]*modentry)

var rbcBuiltins starlark.StringDict = starlark.StringDict{
	"struct":   starlark.NewBuiltin("struct", starlarkstruct.Make),
	// To convert find-copy-subdir and product-copy-files-by pattern
	"rblf_find_files": starlark.NewBuiltin("rblf_find_files", find),
	// To convert makefile's $(shell cmd)
	"rblf_shell": starlark.NewBuiltin("rblf_shell", shell),
	// Output to stderr
	"rblf_log": starlark.NewBuiltin("rblf_log", log),
	// To convert makefile's $(wildcard foo*)
	"rblf_wildcard": starlark.NewBuiltin("rblf_wildcard", wildcard),
}

var sclBuiltins starlark.StringDict = starlark.StringDict{
	"struct":   starlark.NewBuiltin("struct", starlarkstruct.Make),
}

func isSymlink(filepath string) (bool, error) {
	if info, err := os.Lstat(filepath); err == nil {
		return info.Mode() & os.ModeSymlink != 0, nil
	} else {
		return false, err
	}
}

// Takes a module name (the first argument to the load() function) and returns the path
// it's trying to load, stripping out leading //, and handling leading :s.
func cleanModuleName(moduleName string, callerDir string, allowExternalPaths bool) (string, error) {
	if strings.Count(moduleName, ":") > 1 {
		return "", fmt.Errorf("at most 1 colon must be present in starlark path: %s", moduleName)
	}

	// We don't have full support for external repositories, but at least support skylib's dicts.
	if moduleName == "@bazel_skylib//lib:dicts.bzl" {
		return "external/bazel-skylib/lib/dicts.bzl", nil
	}

	localLoad := false
	if strings.HasPrefix(moduleName, "@//") {
		moduleName = moduleName[3:]
	} else if strings.HasPrefix(moduleName, "//") {
		moduleName = moduleName[2:]
	} else if strings.HasPrefix(moduleName, ":") {
		moduleName = moduleName[1:]
		localLoad = true
	} else if !allowExternalPaths {
		return "", fmt.Errorf("load path must start with // or :")
	}

	if ix := strings.LastIndex(moduleName, ":"); ix >= 0 {
		moduleName = moduleName[:ix] + string(os.PathSeparator) + moduleName[ix+1:]
	}

	if filepath.Clean(moduleName) != moduleName {
		return "", fmt.Errorf("load path must be clean, found: %s, expected: %s", moduleName, filepath.Clean(moduleName))
	}
	if !allowExternalPaths {
		if strings.HasPrefix(moduleName, "../") {
			return "", fmt.Errorf("load path must not start with ../: %s", moduleName)
		}
		if strings.HasPrefix(moduleName, "/") {
			return "", fmt.Errorf("load path starts with /, use // for a absolute path: %s", moduleName)
		}
	}

	if localLoad {
		return filepath.Join(callerDir, moduleName), nil
	}

	return moduleName, nil
}

// loader implements load statement. The format of the loaded module URI is
//  [//path]:base[|symbol]
// The file path is $ROOT/path/base if path is present, <caller_dir>/base otherwise.
// The presence of `|symbol` indicates that the loader should return a single 'symbol'
// bound to None if file is missing.
func loader(thread *starlark.Thread, module string) (starlark.StringDict, error) {
	mode := thread.Local(executionModeKey).(ExecutionMode)
	allowExternalEntrypoint := thread.Local(allowExternalEntrypointKey).(bool)
	var defaultSymbol string
	mustLoad := true
	if mode == ExecutionModeRbc {
		pipePos := strings.LastIndex(module, "|")
		if pipePos >= 0 {
			mustLoad = false
			defaultSymbol = module[pipePos+1:]
			module = module[:pipePos]
		}
	}
	callingFile := thread.Local(callingFileKey).(string)
	modulePath, err := cleanModuleName(module, filepath.Dir(callingFile), allowExternalEntrypoint)
	if err != nil {
		return nil, err
	}
	e, ok := moduleCache[modulePath]
	if e == nil {
		if ok {
			return nil, fmt.Errorf("cycle in load graph")
		}

		// Add a placeholder to indicate "load in progress".
		moduleCache[modulePath] = nil

		// Decide if we should load.
		if !mustLoad {
			if _, err := os.Stat(modulePath); err == nil {
				mustLoad = true
			}
		}

		// Load or return default
		if mustLoad {
			if strings.HasSuffix(callingFile, ".scl") && !strings.HasSuffix(modulePath, ".scl") {
				return nil, fmt.Errorf(".scl files can only load other .scl files: %q loads %q", callingFile, modulePath)
			}
			// Switch into scl mode from here on
			if strings.HasSuffix(modulePath, ".scl") {
				mode = ExecutionModeScl
			}

			if sym, err := isSymlink(modulePath); sym && err == nil {
				return nil, fmt.Errorf("symlinks to starlark files are not allowed. Instead, load the target file and re-export its symbols: %s", modulePath)
			} else if err != nil {
				return nil, err
			}

			childThread := &starlark.Thread{Name: "exec " + module, Load: thread.Load}
			// Cheating for the sake of testing:
			// propagate starlarktest's Reporter key, otherwise testing
			// the load function may cause panic in starlarktest code.
			const testReporterKey = "Reporter"
			if v := thread.Local(testReporterKey); v != nil {
				childThread.SetLocal(testReporterKey, v)
			}

			// Only the entrypoint starlark file allows external loads.
			childThread.SetLocal(allowExternalEntrypointKey, false)
			childThread.SetLocal(callingFileKey, modulePath)
			childThread.SetLocal(executionModeKey, mode)
			childThread.SetLocal(shellKey, thread.Local(shellKey))
			if mode == ExecutionModeRbc {
				globals, err := starlark.ExecFile(childThread, modulePath, nil, rbcBuiltins)
				e = &modentry{globals, err}
			} else if mode == ExecutionModeScl {
				globals, err := starlark.ExecFile(childThread, modulePath, nil, sclBuiltins)
				e = &modentry{globals, err}
			} else {
				return nil, fmt.Errorf("unknown executionMode %d", mode)
			}
		} else {
			e = &modentry{starlark.StringDict{defaultSymbol: starlark.None}, nil}
		}

		// Update the cache.
		moduleCache[modulePath] = e
	}
	return e.globals, e.err
}

// wildcard(pattern, top=None) expands shell's glob pattern. If 'top' is present,
// the 'top/pattern' is globbed and then 'top/' prefix is removed.
func wildcard(_ *starlark.Thread, b *starlark.Builtin, args starlark.Tuple,
	kwargs []starlark.Tuple) (starlark.Value, error) {
	var pattern string
	var top string

	if err := starlark.UnpackPositionalArgs(b.Name(), args, kwargs, 1, &pattern, &top); err != nil {
		return starlark.None, err
	}

	var files []string
	var err error
	if top == "" {
		if files, err = filepath.Glob(pattern); err != nil {
			return starlark.None, err
		}
	} else {
		prefix := top + string(filepath.Separator)
		if files, err = filepath.Glob(prefix + pattern); err != nil {
			return starlark.None, err
		}
		for i := range files {
			files[i] = strings.TrimPrefix(files[i], prefix)
		}
	}
	// Kati uses glob(3) with no flags, which means it's sorted
	// because GLOB_NOSORT is not passed. Go's glob is not
	// guaranteed to sort the results.
	sort.Strings(files)
	return makeStringList(files), nil
}

// find(top, pattern, only_files = 0) returns all the paths under 'top'
// whose basename matches 'pattern' (which is a shell's glob pattern).
// If 'only_files' is non-zero, only the paths to the regular files are
// returned. The returned paths are relative to 'top'.
func find(_ *starlark.Thread, b *starlark.Builtin, args starlark.Tuple,
	kwargs []starlark.Tuple) (starlark.Value, error) {
	var top, pattern string
	var onlyFiles int
	if err := starlark.UnpackArgs(b.Name(), args, kwargs,
		"top", &top, "pattern", &pattern, "only_files?", &onlyFiles); err != nil {
		return starlark.None, err
	}
	top = filepath.Clean(top)
	pattern = filepath.Clean(pattern)
	// Go's filepath.Walk is slow, consider using OS's find
	var res []string
	err := filepath.WalkDir(top, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if d != nil && d.IsDir() {
				return fs.SkipDir
			} else {
				return nil
			}
		}
		relPath := strings.TrimPrefix(path, top)
		if len(relPath) > 0 && relPath[0] == os.PathSeparator {
			relPath = relPath[1:]
		}
		// Do not return top-level dir
		if len(relPath) == 0 {
			return nil
		}
		if matched, err := filepath.Match(pattern, d.Name()); err == nil && matched && (onlyFiles == 0 || d.Type().IsRegular()) {
			res = append(res, relPath)
		}
		return nil
	})
	return makeStringList(res), err
}

// shell(command) runs OS shell with given command and returns back
// its output the same way as Make's $(shell ) function. The end-of-lines
// ("\n" or "\r\n") are replaced with " " in the result, and the trailing
// end-of-line is removed.
func shell(thread *starlark.Thread, b *starlark.Builtin, args starlark.Tuple,
	kwargs []starlark.Tuple) (starlark.Value, error) {
	var command string
	if err := starlark.UnpackPositionalArgs(b.Name(), args, kwargs, 1, &command); err != nil {
		return starlark.None, err
	}
	shellPath := thread.Local(shellKey).(string)
	if shellPath == "" {
		return starlark.None,
			fmt.Errorf("cannot run shell, /bin/sh is missing (running on Windows?)")
	}
	cmd := exec.Command(shellPath, "-c", command)
	// We ignore command's status
	bytes, _ := cmd.Output()
	output := string(bytes)
	if strings.HasSuffix(output, "\n") {
		output = strings.TrimSuffix(output, "\n")
	} else {
		output = strings.TrimSuffix(output, "\r\n")
	}

	return starlark.String(
		strings.ReplaceAll(
			strings.ReplaceAll(output, "\r\n", " "),
			"\n", " ")), nil
}

func makeStringList(items []string) *starlark.List {
	elems := make([]starlark.Value, len(items))
	for i, item := range items {
		elems[i] = starlark.String(item)
	}
	return starlark.NewList(elems)
}

func log(thread *starlark.Thread, fn *starlark.Builtin, args starlark.Tuple, kwargs []starlark.Tuple) (starlark.Value, error) {
	sep := " "
	if err := starlark.UnpackArgs("print", nil, kwargs, "sep?", &sep); err != nil {
		return nil, err
	}
	for i, v := range args {
		if i > 0 {
			fmt.Fprint(os.Stderr, sep)
		}
		if s, ok := starlark.AsString(v); ok {
			fmt.Fprint(os.Stderr, s)
		} else if b, ok := v.(starlark.Bytes); ok {
			fmt.Fprint(os.Stderr, string(b))
		} else {
			fmt.Fprintf(os.Stderr, "%s", v)
		}
	}

	fmt.Fprintln(os.Stderr)
	return starlark.None, nil
}

// Parses, resolves, and executes a Starlark file.
// filename and src parameters are as for starlark.ExecFile:
// * filename is the name of the file to execute,
//   and the name that appears in error messages;
// * src is an optional source of bytes to use instead of filename
//   (it can be a string, or a byte array, or an io.Reader instance)
// Returns the top-level starlark variables, the list of starlark files loaded, and an error
func Run(filename string, src interface{}, mode ExecutionMode, allowExternalEntrypoint bool) (starlark.StringDict, []string, error) {
	// NOTE(asmundak): OS-specific. Behave similar to Linux `system` call,
	// which always uses /bin/sh to run the command
	shellPath := "/bin/sh"
	if _, err := os.Stat(shellPath); err != nil {
		shellPath = ""
	}

	mainThread := &starlark.Thread{
		Name:  "main",
		Print: func(_ *starlark.Thread, msg string) {
			if mode == ExecutionModeRbc {
				// In rbc mode, rblf_log is used to print to stderr
				fmt.Println(msg)
			} else if mode == ExecutionModeScl {
				fmt.Fprintln(os.Stderr, msg)
			}
		},
		Load:  loader,
	}
	filename, err := filepath.Abs(filename)
	if err != nil {
		return nil, nil, err
	}
	if wd, err := os.Getwd(); err == nil {
		filename, err = filepath.Rel(wd, filename)
		if err != nil {
			return nil, nil, err
		}
		if !allowExternalEntrypoint && strings.HasPrefix(filename, "../") {
			return nil, nil, fmt.Errorf("path could not be made relative to workspace root: %s", filename)
		}
	} else {
		return nil, nil, err
	}

	if sym, err := isSymlink(filename); sym && err == nil {
		return nil, nil, fmt.Errorf("symlinks to starlark files are not allowed. Instead, load the target file and re-export its symbols: %s", filename)
	} else if err != nil {
		return nil, nil, err
	}

	if mode == ExecutionModeScl && !strings.HasSuffix(filename, ".scl") {
		return nil, nil, fmt.Errorf("filename must end in .scl: %s", filename)
	}

	// Add top-level file to cache for cycle detection purposes
	moduleCache[filename] = nil

	var results starlark.StringDict
	mainThread.SetLocal(allowExternalEntrypointKey, allowExternalEntrypoint)
	mainThread.SetLocal(callingFileKey, filename)
	mainThread.SetLocal(executionModeKey, mode)
	mainThread.SetLocal(shellKey, shellPath)
	if mode == ExecutionModeRbc {
		results, err = starlark.ExecFile(mainThread, filename, src, rbcBuiltins)
	} else if mode == ExecutionModeScl {
		results, err = starlark.ExecFile(mainThread, filename, src, sclBuiltins)
	} else {
		return results, nil, fmt.Errorf("unknown executionMode %d", mode)
	}
	loadedStarlarkFiles := make([]string, 0, len(moduleCache))
	for file := range moduleCache {
		loadedStarlarkFiles = append(loadedStarlarkFiles, file)
	}
	sort.Strings(loadedStarlarkFiles)

	return results, loadedStarlarkFiles, err
}
