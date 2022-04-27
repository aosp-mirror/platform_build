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
	"strings"

	"android/soong/tools/compliance"
)

func init() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `Usage: %s file.meta_lic {file.meta_lic...}

Outputs a csv file with 1 project per line in the first field followed
by target:condition pairs describing why the project must be shared.

Each target is the path to a generated license metadata file for a
Soong module or Make target, and the license condition is either
restricted (e.g. GPL) or reciprocal (e.g. MPL).
`, filepath.Base(os.Args[0]))
	}
}

var (
	failNoneRequested = fmt.Errorf("\nNo license metadata files requested")
	failNoLicenses    = fmt.Errorf("No licenses found")
)

func main() {
	flag.Parse()

	// Must specify at least one root target.
	if flag.NArg() == 0 {
		flag.Usage()
		os.Exit(2)
	}

	err := listShare(os.Stdout, os.Stderr, compliance.FS, flag.Args()...)
	if err != nil {
		if err == failNoneRequested {
			flag.Usage()
		}
		fmt.Fprintf(os.Stderr, "%s\n", err.Error())
		os.Exit(1)
	}
	os.Exit(0)
}

// listShare implements the listshare utility.
func listShare(stdout, stderr io.Writer, rootFS fs.FS, files ...string) error {
	// Must be at least one root file.
	if len(files) < 1 {
		return failNoneRequested
	}

	// Read the license graph from the license metadata files (*.meta_lic).
	licenseGraph, err := compliance.ReadLicenseGraph(rootFS, stderr, files)
	if err != nil {
		return fmt.Errorf("Unable to read license metadata file(s) %q: %v\n", files, err)
	}
	if licenseGraph == nil {
		return failNoLicenses
	}

	// shareSource contains all source-sharing resolutions.
	shareSource := compliance.ResolveSourceSharing(licenseGraph)

	// Group the resolutions by project.
	presolution := make(map[string]compliance.LicenseConditionSet)
	for _, target := range shareSource.AttachesTo() {
		rl := shareSource.Resolutions(target)
		sort.Sort(rl)
		for _, r := range rl {
			for _, p := range r.ActsOn().Projects() {
				if _, ok := presolution[p]; !ok {
					presolution[p] = r.Resolves()
					continue
				}
				presolution[p] = presolution[p].Union(r.Resolves())
			}
		}
	}

	// Sort the projects for repeatability/stability.
	projects := make([]string, 0, len(presolution))
	for p := range presolution {
		projects = append(projects, p)
	}
	sort.Strings(projects)

	// Output the sorted projects and the source-sharing license conditions that each project resolves.
	for _, p := range projects {
		if presolution[p].IsEmpty() {
			fmt.Fprintf(stdout, "%s\n", p)
		} else {
			fmt.Fprintf(stdout, "%s,%s\n", p, strings.Join(presolution[p].Names(), ","))
		}
	}

	return nil
}
