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
	"regexp"
	"strings"

	"go.starlark.net/starlark"
	"go.starlark.net/starlarkstruct"
)

const callerDirKey = "callerDir"

var LoadPathRoot = "."
var shellPath string

type modentry struct {
	globals starlark.StringDict
	err     error
}

var moduleCache = make(map[string]*modentry)

var builtins starlark.StringDict

func moduleName2AbsPath(moduleName string, callerDir string) (string, error) {
	path := moduleName
	if ix := strings.LastIndex(path, ":"); ix >= 0 {
		path = path[0:ix] + string(os.PathSeparator) + path[ix+1:]
	}
	if strings.HasPrefix(path, "//") {
		return filepath.Abs(filepath.Join(LoadPathRoot, path[2:]))
	} else if strings.HasPrefix(moduleName, ":") {
		return filepath.Abs(filepath.Join(callerDir, path[1:]))
	} else {
		return filepath.Abs(path)
	}
}

// loader implements load statement. The format of the loaded module URI is
//  [//path]:base[|symbol]
// The file path is $ROOT/path/base if path is present, <caller_dir>/base otherwise.
// The presence of `|symbol` indicates that the loader should return a single 'symbol'
// bound to None if file is missing.
func loader(thread *starlark.Thread, module string) (starlark.StringDict, error) {
	pipePos := strings.LastIndex(module, "|")
	mustLoad := pipePos < 0
	var defaultSymbol string
	if !mustLoad {
		defaultSymbol = module[pipePos+1:]
		module = module[:pipePos]
	}
	modulePath, err := moduleName2AbsPath(module, thread.Local(callerDirKey).(string))
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
			childThread := &starlark.Thread{Name: "exec " + module, Load: thread.Load}
			// Cheating for the sake of testing:
			// propagate starlarktest's Reporter key, otherwise testing
			// the load function may cause panic in starlarktest code.
			const testReporterKey = "Reporter"
			if v := thread.Local(testReporterKey); v != nil {
				childThread.SetLocal(testReporterKey, v)
			}

			childThread.SetLocal(callerDirKey, filepath.Dir(modulePath))
			globals, err := starlark.ExecFile(childThread, modulePath, nil, builtins)
			e = &modentry{globals, err}
		} else {
			e = &modentry{starlark.StringDict{defaultSymbol: starlark.None}, nil}
		}

		// Update the cache.
		moduleCache[modulePath] = e
	}
	return e.globals, e.err
}

// fileExists returns True if file with given name exists.
func fileExists(_ *starlark.Thread, b *starlark.Builtin, args starlark.Tuple,
	kwargs []starlark.Tuple) (starlark.Value, error) {
	var path string
	if err := starlark.UnpackPositionalArgs(b.Name(), args, kwargs, 1, &path); err != nil {
		return starlark.None, err
	}
	if _, err := os.Stat(path); err != nil {
		return starlark.False, nil
	}
	return starlark.True, nil
}

// regexMatch(pattern, s) returns True if s matches pattern (a regex)
func regexMatch(_ *starlark.Thread, b *starlark.Builtin, args starlark.Tuple,
	kwargs []starlark.Tuple) (starlark.Value, error) {
	var pattern, s string
	if err := starlark.UnpackPositionalArgs(b.Name(), args, kwargs, 2, &pattern, &s); err != nil {
		return starlark.None, err
	}
	match, err := regexp.MatchString(pattern, s)
	if err != nil {
		return starlark.None, err
	}
	if match {
		return starlark.True, nil
	}
	return starlark.False, nil
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
func shell(_ *starlark.Thread, b *starlark.Builtin, args starlark.Tuple,
	kwargs []starlark.Tuple) (starlark.Value, error) {
	var command string
	if err := starlark.UnpackPositionalArgs(b.Name(), args, kwargs, 1, &command); err != nil {
		return starlark.None, err
	}
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

// propsetFromEnv constructs a propset from the array of KEY=value strings
func structFromEnv(env []string) *starlarkstruct.Struct {
	sd := make(map[string]starlark.Value, len(env))
	for _, x := range env {
		kv := strings.SplitN(x, "=", 2)
		sd[kv[0]] = starlark.String(kv[1])
	}
	return starlarkstruct.FromStringDict(starlarkstruct.Default, sd)
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

func setup(env []string) {
	// Create the symbols that aid makefile conversion. See README.md
	builtins = starlark.StringDict{
		"struct":   starlark.NewBuiltin("struct", starlarkstruct.Make),
		"rblf_cli": structFromEnv(env),
		"rblf_env": structFromEnv(os.Environ()),
		// To convert makefile's $(wildcard foo)
		"rblf_file_exists": starlark.NewBuiltin("rblf_file_exists", fileExists),
		// To convert find-copy-subdir and product-copy-files-by pattern
		"rblf_find_files": starlark.NewBuiltin("rblf_find_files", find),
		// To convert makefile's $(filter ...)/$(filter-out)
		"rblf_regex": starlark.NewBuiltin("rblf_regex", regexMatch),
		// To convert makefile's $(shell cmd)
		"rblf_shell": starlark.NewBuiltin("rblf_shell", shell),
		// Output to stderr
		"rblf_log": starlark.NewBuiltin("rblf_log", log),
		// To convert makefile's $(wildcard foo*)
		"rblf_wildcard": starlark.NewBuiltin("rblf_wildcard", wildcard),
	}

	// NOTE(asmundak): OS-specific. Behave similar to Linux `system` call,
	// which always uses /bin/sh to run the command
	shellPath = "/bin/sh"
	if _, err := os.Stat(shellPath); err != nil {
		shellPath = ""
	}
}

// Parses, resolves, and executes a Starlark file.
// filename and src parameters are as for starlark.ExecFile:
// * filename is the name of the file to execute,
//   and the name that appears in error messages;
// * src is an optional source of bytes to use instead of filename
//   (it can be a string, or a byte array, or an io.Reader instance)
// * commandVars is an array of "VAR=value" items. They are accessible from
//   the starlark script as members of the `rblf_cli` propset.
func Run(filename string, src interface{}, commandVars []string) error {
	setup(commandVars)

	mainThread := &starlark.Thread{
		Name:  "main",
		Print: func(_ *starlark.Thread, msg string) { fmt.Println(msg) },
		Load:  loader,
	}
	absPath, err := filepath.Abs(filename)
	if err == nil {
		mainThread.SetLocal(callerDirKey, filepath.Dir(absPath))
		_, err = starlark.ExecFile(mainThread, absPath, src, builtins)
	}
	return err
}
