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

package main

import (
	"flag"
	"fmt"
	"os"
	"rbcrun"
	"regexp"
	"strings"

	"go.starlark.net/starlark"
)

var (
	allowExternalEntrypoint = flag.Bool("allow_external_entrypoint", false, "allow the entrypoint starlark file to be outside of the source tree")
	modeFlag  = flag.String("mode", "", "the general behavior of rbcrun. Can be \"rbc\" or \"make\". Required.")
	rootdir  = flag.String("d", ".", "the value of // for load paths")
	perfFile = flag.String("perf", "", "save performance data")
	identifierRe = regexp.MustCompile("[a-zA-Z_][a-zA-Z0-9_]*")
)

func getEntrypointStarlarkFile() string {
	filename := ""

	for _, arg := range flag.Args() {
		if filename == "" {
			filename = arg
		} else {
			quit("only one file can be executed\n")
		}
	}
	if filename == "" {
		flag.Usage()
		os.Exit(1)
	}
	return filename
}

func getMode() rbcrun.ExecutionMode {
	switch *modeFlag {
	case "rbc":
		return rbcrun.ExecutionModeRbc
	case "make":
		return rbcrun.ExecutionModeScl
	case "":
		quit("-mode flag is required.")
	default:
		quit("Unknown -mode value %q, expected 1 of \"rbc\", \"make\"", *modeFlag)
	}
	return rbcrun.ExecutionModeScl
}

var makeStringReplacer = strings.NewReplacer("#", "\\#", "$", "$$")

func cleanStringForMake(s string) (string, error) {
	if strings.ContainsAny(s, "\\\n") {
		// \\ in make is literally \\, not a single \, so we can't allow them.
		// \<newline> in make will produce a space, not a newline.
		return "", fmt.Errorf("starlark strings exported to make cannot contain backslashes or newlines")
	}
	return makeStringReplacer.Replace(s), nil
}

func getValueInMakeFormat(value starlark.Value, allowLists bool) (string, error) {
	switch v := value.(type) {
	case starlark.String:
		if cleanedValue, err := cleanStringForMake(v.GoString()); err == nil {
			return cleanedValue, nil
		} else {
			return "", err
		}
	case starlark.Int:
		return v.String(), nil
	case *starlark.List:
		if !allowLists {
			return "", fmt.Errorf("nested lists are not allowed to be exported from starlark to make, flatten the list in starlark first")
		}
		result := ""
		for i := 0; i < v.Len(); i++ {
			value, err := getValueInMakeFormat(v.Index(i), false)
			if err != nil {
				return "", err
			}
			if i > 0 {
				result += " "
			}
			result += value
		}
		return result, nil
	default:
		return "", fmt.Errorf("only starlark strings, ints, and lists of strings/ints can be exported to make. Please convert all other types in starlark first. Found type: %s", value.Type())
	}
}

func printVarsInMakeFormat(globals starlark.StringDict) error {
	// We could just directly export top level variables by name instead of going through
	// a variables_to_export_to_make dictionary, but that wouldn't allow for exporting a
	// runtime-defined number of variables to make. This can be important because dictionaries
	// in make are often represented by a unique variable for every key in the dictionary.
	variablesValue, ok := globals["variables_to_export_to_make"]
	if !ok {
		return fmt.Errorf("expected top-level starlark file to have a \"variables_to_export_to_make\" variable")
	}
	variables, ok := variablesValue.(*starlark.Dict)
	if !ok {
		return fmt.Errorf("expected variables_to_export_to_make to be a dict, got %s", variablesValue.Type())
	}

	for _, varTuple := range variables.Items() {
		varNameStarlark, ok := varTuple.Index(0).(starlark.String)
		if !ok {
			return fmt.Errorf("all keys in variables_to_export_to_make must be strings, but got %q", varTuple.Index(0).Type())
		}
		varName := varNameStarlark.GoString()
		if !identifierRe.MatchString(varName) {
			return fmt.Errorf("all variables at the top level starlark file must be valid c identifiers, but got %q", varName)
		}
		if varName == "LOADED_STARLARK_FILES" {
			return fmt.Errorf("the name LOADED_STARLARK_FILES is reserved for use by the starlark interpreter")
		}
		valueMake, err := getValueInMakeFormat(varTuple.Index(1), true)
		if err != nil {
			return err
		}
		// The :=$= is special Kati syntax that means "set and make readonly"
		fmt.Printf("%s :=$= %s\n", varName, valueMake)
	}
	return nil
}

func main() {
	flag.Parse()
	filename := getEntrypointStarlarkFile()
	mode := getMode()

	if os.Chdir(*rootdir) != nil {
		quit("could not chdir to %s\n", *rootdir)
	}
	if *perfFile != "" {
		pprof, err := os.Create(*perfFile)
		if err != nil {
			quit("%s: err", *perfFile)
		}
		defer pprof.Close()
		if err := starlark.StartProfile(pprof); err != nil {
			quit("%s\n", err)
		}
	}
	variables, loadedStarlarkFiles, err := rbcrun.Run(filename, nil, mode, *allowExternalEntrypoint)
	rc := 0
	if *perfFile != "" {
		if err2 := starlark.StopProfile(); err2 != nil {
			fmt.Fprintln(os.Stderr, err2)
			rc = 1
		}
	}
	if err != nil {
		if evalErr, ok := err.(*starlark.EvalError); ok {
			quit("%s\n", evalErr.Backtrace())
		} else {
			quit("%s\n", err)
		}
	}
	if mode == rbcrun.ExecutionModeScl {
		if err := printVarsInMakeFormat(variables); err != nil {
			quit("%s\n", err)
		}
		fmt.Printf("LOADED_STARLARK_FILES := %s\n", strings.Join(loadedStarlarkFiles, " "))
	}
	os.Exit(rc)
}

func quit(format string, s ...interface{}) {
	fmt.Fprintf(os.Stderr, format, s...)
	os.Exit(2)
}
