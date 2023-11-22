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
	"strings"
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
func testSetup(t *testing.T) *starlark.Thread {
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
	if err := os.Chdir(dataDir()); err != nil {
		t.Fatal(err)
	}
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
	thread.SetLocal(executionModeKey, ExecutionModeRbc)
	thread.SetLocal(shellKey, "/bin/sh")
	if _, err := starlark.ExecFile(thread, filename, nil, rbcBuiltins); err != nil {
		if err, ok := err.(*starlark.EvalError); ok {
			t.Fatal(err.Backtrace())
		}
		t.Fatal(err)
	}
}

func TestFileOps(t *testing.T) {
	// TODO(asmundak): convert this to use exerciseStarlarkTestFile
	thread := testSetup(t)
	if _, err := starlark.ExecFile(thread, "file_ops.star", nil, rbcBuiltins); err != nil {
		if err, ok := err.(*starlark.EvalError); ok {
			t.Fatal(err.Backtrace())
		}
		t.Fatal(err)
	}
}

func TestLoad(t *testing.T) {
	// TODO(asmundak): convert this to use exerciseStarlarkTestFile
	thread := testSetup(t)
	thread.Load = func(thread *starlark.Thread, module string) (starlark.StringDict, error) {
		if module == "assert.star" {
			return starlarktest.LoadAssertModule()
		} else {
			return loader(thread, module)
		}
	}
	dir := dataDir()
	if err := os.Chdir(filepath.Dir(dir)); err != nil {
		t.Fatal(err)
	}
	thread.SetLocal(allowExternalEntrypointKey, false)
	thread.SetLocal(callingFileKey, "testdata/load.star")
	thread.SetLocal(executionModeKey, ExecutionModeRbc)
	if _, err := starlark.ExecFile(thread, "testdata/load.star", nil, rbcBuiltins); err != nil {
		if err, ok := err.(*starlark.EvalError); ok {
			t.Fatal(err.Backtrace())
		}
		t.Fatal(err)
	}
}

func TestBzlLoadsScl(t *testing.T) {
	moduleCache = make(map[string]*modentry)
	dir := dataDir()
	if err := os.Chdir(filepath.Dir(dir)); err != nil {
		t.Fatal(err)
	}
	vars, _, err := Run("testdata/bzl_loads_scl.bzl", nil, ExecutionModeRbc, false)
	if err != nil {
		t.Fatal(err)
	}
	if val, ok := vars["foo"]; !ok {
		t.Fatalf("Failed to load foo variable")
	} else if val.(starlark.String) != "bar" {
		t.Fatalf("Expected \"bar\", got %q", val)
	}
}

func TestNonEntrypointBzlLoadsScl(t *testing.T) {
	moduleCache = make(map[string]*modentry)
	dir := dataDir()
	if err := os.Chdir(filepath.Dir(dir)); err != nil {
		t.Fatal(err)
	}
	vars, _, err := Run("testdata/bzl_loads_scl_2.bzl", nil, ExecutionModeRbc, false)
	if err != nil {
		t.Fatal(err)
	}
	if val, ok := vars["foo"]; !ok {
		t.Fatalf("Failed to load foo variable")
	} else if val.(starlark.String) != "bar" {
		t.Fatalf("Expected \"bar\", got %q", val)
	}
}

func TestSclLoadsBzl(t *testing.T) {
	moduleCache = make(map[string]*modentry)
	dir := dataDir()
	if err := os.Chdir(filepath.Dir(dir)); err != nil {
		t.Fatal(err)
	}
	_, _, err := Run("testdata/scl_incorrectly_loads_bzl.scl", nil, ExecutionModeScl, false)
	if err == nil {
		t.Fatal("Expected failure")
	}
	if !strings.Contains(err.Error(), ".scl files can only load other .scl files") {
		t.Fatalf("Expected error to contain \".scl files can only load other .scl files\": %q", err.Error())
	}
}

func TestCantLoadSymlink(t *testing.T) {
	moduleCache = make(map[string]*modentry)
	dir := dataDir()
	if err := os.Chdir(filepath.Dir(dir)); err != nil {
		t.Fatal(err)
	}
	_, _, err := Run("testdata/test_scl_symlink.scl", nil, ExecutionModeScl, false)
	if err == nil {
		t.Fatal("Expected failure")
	}
	if !strings.Contains(err.Error(), "symlinks to starlark files are not allowed") {
		t.Fatalf("Expected error to contain \"symlinks to starlark files are not allowed\": %q", err.Error())
	}
}

func TestShell(t *testing.T) {
	exerciseStarlarkTestFile(t, "testdata/shell.star")
}
