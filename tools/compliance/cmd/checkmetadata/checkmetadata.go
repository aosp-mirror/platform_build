// Copyright 2022 Google LLC
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
	"bytes"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"android/soong/response"
	"android/soong/tools/compliance"
	"android/soong/tools/compliance/projectmetadata"
)

var (
	failNoneRequested = fmt.Errorf("\nNo projects requested")
)

func main() {
	var expandedArgs []string
	for _, arg := range os.Args[1:] {
		if strings.HasPrefix(arg, "@") {
			f, err := os.Open(strings.TrimPrefix(arg, "@"))
			if err != nil {
				fmt.Fprintln(os.Stderr, err.Error())
				os.Exit(1)
			}

			respArgs, err := response.ReadRspFile(f)
			f.Close()
			if err != nil {
				fmt.Fprintln(os.Stderr, err.Error())
				os.Exit(1)
			}
			expandedArgs = append(expandedArgs, respArgs...)
		} else {
			expandedArgs = append(expandedArgs, arg)
		}
	}

	flags := flag.NewFlagSet("flags", flag.ExitOnError)

	flags.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: %s {-o outfile} projectdir {projectdir...}

Tries to open the METADATA.android or METADATA file in each projectdir
reporting any errors on stderr.

Reports "FAIL" to stdout if any errors found and exits with status 1.

Otherwise, reports "PASS" and the number of project metadata files
found exiting with status 0.
`, filepath.Base(os.Args[0]))
		flags.PrintDefaults()
	}

	outputFile := flags.String("o", "-", "Where to write the output. (default stdout)")

	flags.Parse(expandedArgs)

	// Must specify at least one root target.
	if flags.NArg() == 0 {
		flags.Usage()
		os.Exit(2)
	}

	if len(*outputFile) == 0 {
		flags.Usage()
		fmt.Fprintf(os.Stderr, "must specify file for -o; use - for stdout\n")
		os.Exit(2)
	} else {
		dir, err := filepath.Abs(filepath.Dir(*outputFile))
		if err != nil {
			fmt.Fprintf(os.Stderr, "cannot determine path to %q: %s\n", *outputFile, err)
			os.Exit(1)
		}
		fi, err := os.Stat(dir)
		if err != nil {
			fmt.Fprintf(os.Stderr, "cannot read directory %q of %q: %s\n", dir, *outputFile, err)
			os.Exit(1)
		}
		if !fi.IsDir() {
			fmt.Fprintf(os.Stderr, "parent %q of %q is not a directory\n", dir, *outputFile)
			os.Exit(1)
		}
	}

	var ofile io.Writer
	ofile = os.Stdout
	var obuf *bytes.Buffer
	if *outputFile != "-" {
		obuf = &bytes.Buffer{}
		ofile = obuf
	}

	err := checkProjectMetadata(ofile, os.Stderr, compliance.FS, flags.Args()...)
	if err != nil {
		if err == failNoneRequested {
			flags.Usage()
		}
		fmt.Fprintf(os.Stderr, "%s\n", err.Error())
		fmt.Fprintln(ofile, "FAIL")
		os.Exit(1)
	}
	if *outputFile != "-" {
		err := os.WriteFile(*outputFile, obuf.Bytes(), 0666)
		if err != nil {
			fmt.Fprintf(os.Stderr, "could not write output to %q from %q: %s\n", *outputFile, os.Getenv("PWD"), err)
			os.Exit(1)
		}
	}
	os.Exit(0)
}

// checkProjectMetadata implements the checkmetadata utility.
func checkProjectMetadata(stdout, stderr io.Writer, rootFS fs.FS, projects ...string) error {

	if len(projects) < 1 {
		return failNoneRequested
	}

	// Read the project metadata files from `projects`
	ix := projectmetadata.NewIndex(rootFS)
	pms, err := ix.MetadataForProjects(projects...)
	if err != nil {
		return fmt.Errorf("Unable to read project metadata file(s) %q from %q: %w\n", projects, os.Getenv("PWD"), err)
	}

	fmt.Fprintf(stdout, "PASS -- parsed %d project metadata files for %d projects\n", len(pms), len(projects))
	return nil
}
