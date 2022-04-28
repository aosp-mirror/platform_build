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
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"go.starlark.net/resolve"
	"go.starlark.net/starlark"
	"go.starlark.net/starlarktest"
)

// In order to use "assert.star" from go/starlark.net/starlarktest in the tests,
// provide:
//  * load function that handles "assert.star"
//  * starlarktest.DataFile function that finds its location

func init() {
	starlarktestSetup()
}

func starlarktestSetup() {
	resolve.AllowLambda = true
	starlarktest.DataFile = func(pkgdir, filename string) string {
		// The caller expects this function to return the path to the
		// data file. The implementation assumes that the source file
		// containing the caller and the data file are in the same
		// directory. It's ugly. Not sure what's the better way.
		// TODO(asmundak): handle Bazel case
		_, starlarktestSrcFile, _, _ := runtime.Caller(1)
		if filepath.Base(starlarktestSrcFile) != "starlarktest.go" {
			panic(fmt.Errorf("this function should be called from starlarktest.go, got %s",
				starlarktestSrcFile))
		}
		return filepath.Join(filepath.Dir(starlarktestSrcFile), filename)
	}
}

// Common setup for the tests: create thread, change to the test directory
func testSetup(t *testing.T, env []string) *starlark.Thread {
	setup(env)
	thread := &starlark.Thread{
		Load: func(thread *starlark.Thread, module string) (starlark.StringDict, error) {
			if module == "assert.star" {
				return starlarktest.LoadAssertModule()
			}
			return nil, fmt.Errorf("load not implemented")
		}}
	starlarktest.SetReporter(thread, t)
	if err := os.Chdir(dataDir()); err != nil {
		t.Fatal(err)
	}
	return thread
}

func dataDir() string {
	_, thisSrcFile, _, _ := runtime.Caller(0)
	return filepath.Join(filepath.Dir(thisSrcFile), "testdata")

}

func exerciseStarlarkTestFile(t *testing.T, starFile string) {
	// In order to use "assert.star" from go/starlark.net/starlarktest in the tests, provide:
	//  * load function that handles "assert.star"
	//  * starlarktest.DataFile function that finds its location
	setup(nil)
	thread := &starlark.Thread{
		Load: func(thread *starlark.Thread, module string) (starlark.StringDict, error) {
			if module == "assert.star" {
				return starlarktest.LoadAssertModule()
			}
			return nil, fmt.Errorf("load not implemented")
		}}
	starlarktest.SetReporter(thread, t)
	_, thisSrcFile, _, _ := runtime.Caller(0)
	filename := filepath.Join(filepath.Dir(thisSrcFile), starFile)
	if _, err := starlark.ExecFile(thread, filename, nil, builtins); err != nil {
		if err, ok := err.(*starlark.EvalError); ok {
			t.Fatal(err.Backtrace())
		}
		t.Fatal(err)
	}
}

func TestCliAndEnv(t *testing.T) {
	// TODO(asmundak): convert this to use exerciseStarlarkTestFile
	if err := os.Setenv("TEST_ENVIRONMENT_FOO", "test_environment_foo"); err != nil {
		t.Fatal(err)
	}
	thread := testSetup(t, []string{"CLI_FOO=foo"})
	if _, err := starlark.ExecFile(thread, "cli_and_env.star", nil, builtins); err != nil {
		if err, ok := err.(*starlark.EvalError); ok {
			t.Fatal(err.Backtrace())
		}
		t.Fatal(err)
	}
}

func TestFileOps(t *testing.T) {
	// TODO(asmundak): convert this to use exerciseStarlarkTestFile
	if err := os.Setenv("TEST_DATA_DIR", dataDir()); err != nil {
		t.Fatal(err)
	}
	thread := testSetup(t, nil)
	if _, err := starlark.ExecFile(thread, "file_ops.star", nil, builtins); err != nil {
		if err, ok := err.(*starlark.EvalError); ok {
			t.Fatal(err.Backtrace())
		}
		t.Fatal(err)
	}
}

func TestLoad(t *testing.T) {
	// TODO(asmundak): convert this to use exerciseStarlarkTestFile
	thread := testSetup(t, nil)
	thread.Load = func(thread *starlark.Thread, module string) (starlark.StringDict, error) {
		if module == "assert.star" {
			return starlarktest.LoadAssertModule()
		} else {
			return loader(thread, module)
		}
	}
	dir := dataDir()
	thread.SetLocal(callerDirKey, dir)
	LoadPathRoot = filepath.Dir(dir)
	if _, err := starlark.ExecFile(thread, "load.star", nil, builtins); err != nil {
		if err, ok := err.(*starlark.EvalError); ok {
			t.Fatal(err.Backtrace())
		}
		t.Fatal(err)
	}
}

func TestShell(t *testing.T) {
	if err := os.Setenv("TEST_DATA_DIR", dataDir()); err != nil {
		t.Fatal(err)
	}
	exerciseStarlarkTestFile(t, "testdata/shell.star")
}
