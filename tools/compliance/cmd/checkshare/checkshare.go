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
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"

	"android/soong/tools/compliance"
)

func init() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: %s file.meta_lic {file.meta_lic...}

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
	}
}

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
	flag.Parse()

	// Must specify at least one root target.
	if flag.NArg() == 0 {
		flag.Usage()
		os.Exit(2)
	}

	err := checkShare(os.Stdout, os.Stderr, compliance.FS, flag.Args()...)
	if err != nil {
		if err != failConflicts {
			if err == failNoneRequested {
				flag.Usage()
			}
			fmt.Fprintf(os.Stderr, "%s\n", err.Error())
		}
		os.Exit(1)
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
		return fmt.Errorf("Unable to read license metadata file(s) %q: %w\n", files, err)
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
