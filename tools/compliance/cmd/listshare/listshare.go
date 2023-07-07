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
	failNoneRequested = fmt.Errorf("\nNo license metadata files requested")
	failNoLicenses    = fmt.Errorf("No licenses found")
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
		fmt.Fprintf(os.Stderr, `Usage: %s {-o outfile} file.meta_lic {file.meta_lic...}

Outputs a csv file with 1 project per line in the first field followed
by target:condition pairs describing why the project must be shared.

Each target is the path to a generated license metadata file for a
Soong module or Make target, and the license condition is either
restricted (e.g. GPL) or reciprocal (e.g. MPL).
`, filepath.Base(os.Args[0]))
	}

	outputFile := flags.String("o", "-", "Where to write the list of projects to share. (default stdout)")

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

	err := listShare(ofile, os.Stderr, compliance.FS, flags.Args()...)
	if err != nil {
		if err == failNoneRequested {
			flags.Usage()
		}
		fmt.Fprintf(os.Stderr, "%s\n", err.Error())
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

// listShare implements the listshare utility.
func listShare(stdout, stderr io.Writer, rootFS fs.FS, files ...string) error {
	// Must be at least one root file.
	if len(files) < 1 {
		return failNoneRequested
	}

	// Read the license graph from the license metadata files (*.meta_lic).
	licenseGraph, err := compliance.ReadLicenseGraph(rootFS, stderr, files)
	if err != nil {
		return fmt.Errorf("Unable to read license metadata file(s) %q from %q: %v\n", files, os.Getenv("PWD"), err)
	}
	if licenseGraph == nil {
		return failNoLicenses
	}

	// shareSource contains all source-sharing resolutions.
	shareSource := compliance.ResolveSourceSharing(licenseGraph)

	// Group the resolutions by project.
	presolution := make(map[string]compliance.LicenseConditionSet)
	for _, target := range shareSource.AttachesTo() {
		if shareSource.IsPureAggregate(target) && !target.LicenseConditions().MatchesAnySet(compliance.ImpliesShared) {
			continue
		}
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
