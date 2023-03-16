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
	"go.starlark.net/starlark"
	"os"
	"rbcrun"
	"strings"
)

var (
	execprog = flag.String("c", "", "execute program `prog`")
	rootdir  = flag.String("d", ".", "the value of // for load paths")
	file     = flag.String("f", "", "file to execute")
	perfFile = flag.String("perf", "", "save performance data")
)

func main() {
	flag.Parse()
	filename := *file
	var src interface{}
	var env []string

	rc := 0
	for _, arg := range flag.Args() {
		if strings.Contains(arg, "=") {
			env = append(env, arg)
		} else if filename == "" {
			filename = arg
		} else {
			quit("only one file can be executed\n")
		}
	}
	if *execprog != "" {
		if filename != "" {
			quit("either -c or file name should be present\n")
		}
		filename = "<cmdline>"
		src = *execprog
	}
	if filename == "" {
		if len(env) > 0 {
			fmt.Fprintln(os.Stderr,
				"no file to run -- if your file's name contains '=', use -f to specify it")
		}
		flag.Usage()
		os.Exit(1)
	}
	if stat, err := os.Stat(*rootdir); os.IsNotExist(err) || !stat.IsDir() {
		quit("%s is not a directory\n", *rootdir)
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
	rbcrun.LoadPathRoot = *rootdir
	err := rbcrun.Run(filename, src, env)
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
	os.Exit(rc)
}

func quit(format string, s ...interface{}) {
	fmt.Fprintf(os.Stderr, format, s...)
	os.Exit(2)
}
