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
	"bytes"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"android/soong/response"
	"android/soong/tools/compliance"
)

var (
	failConflicts     = fmt.Errorf("conflicts")
	failNoneRequested = fmt.Errorf("\nNo metadata files requested")
	failNoLicenses    = fmt.Errorf("No licenses")
)

// byError orders conflicts by error string
type byError []compliance.SourceSharePrivacyConflict

func (l byError) Len() int           { return len(l) }
func (l byError) Swap(i, j int)      { l[i], l[j] = l[j], l[i] }
func (l byError) Less(i, j int) bool { return l[i].Error() < l[j].Error() }

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
		fmt.Fprintf(os.Stderr, `Usage: %s {-o outfile} file.meta_lic {file.meta_lic...}

Reports on stderr any targets where policy says that the source both
must and must not be shared. The error report indicates the target, the
license condition that has a source privacy policy, and the license
condition that has a source sharing policy.

Any given target may appear multiple times with different combinations
of conflicting license conditions.

If all the source code that policy says must be shared may be shared,
outputs "PASS" to stdout and exits with status 0.

If policy says any source must both be shared and not be shared,
outputs "FAIL" to stdout and exits with status 1.
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

	err := checkShare(ofile, os.Stderr, compliance.FS, flags.Args()...)
	if err != nil {
		if err != failConflicts {
			if err == failNoneRequested {
				flags.Usage()
			}
			fmt.Fprintf(os.Stderr, "%s\n", err.Error())
		}
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

// checkShare implements the checkshare utility.
func checkShare(stdout, stderr io.Writer, rootFS fs.FS, files ...string) error {

	if len(files) < 1 {
		return failNoneRequested
	}

	// Read the license graph from the license metadata files (*.meta_lic).
	licenseGraph, err := compliance.ReadLicenseGraph(rootFS, stderr, files)
	if err != nil {
		return fmt.Errorf("Unable to read license metadata file(s) %q from %q: %w\n", files, os.Getenv("PWD"), err)
	}
	if licenseGraph == nil {
		return failNoLicenses
	}

	// Apply policy to find conflicts and report them to stderr lexicographically ordered.
	conflicts := compliance.ConflictingSharedPrivateSource(licenseGraph)
	sort.Sort(byError(conflicts))
	for _, conflict := range conflicts {
		fmt.Fprintln(stderr, conflict.Error())
	}

	// Indicate pass or fail on stdout.
	if len(conflicts) > 0 {
		fmt.Fprintln(stdout, "FAIL")
		return failConflicts
	}
	fmt.Fprintln(stdout, "PASS")
	return nil
}
