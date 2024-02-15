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
	failNoSources     = fmt.Errorf("\nNo projects or metadata files to trace back from")
	failNoLicenses    = fmt.Errorf("No licenses found")
)

type context struct {
	sources     []string
	stripPrefix []string
}

func (ctx context) strip(installPath string) string {
	for _, prefix := range ctx.stripPrefix {
		if strings.HasPrefix(installPath, prefix) {
			p := strings.TrimPrefix(installPath, prefix)
			if 0 == len(p) {
				continue
			}
			return p
		}
	}
	return installPath
}

// newMultiString creates a flag that allows multiple values in an array.
func newMultiString(flags *flag.FlagSet, name, usage string) *multiString {
	var f multiString
	flags.Var(&f, name, usage)
	return &f
}

// multiString implements the flag `Value` interface for multiple strings.
type multiString []string

func (ms *multiString) String() string     { return strings.Join(*ms, ", ") }
func (ms *multiString) Set(s string) error { *ms = append(*ms, s); return nil }

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
		fmt.Fprintf(os.Stderr, `Usage: %s {options} file.meta_lic {file.meta_lic...}

Calculates the source-sharing requirements in reverse starting at the
-rtrace projects or metadata files that inherited source-sharing and
working back to the targets where the source-sharing requirmements
originate.

Outputs a space-separated pair where the first field is an originating
target with one or more restricted conditions and where the second
field is a colon-separated list of the restricted conditions.

Outputs a count of the originating targets, and if the count is zero,
outputs a warning to check the -rtrace projects and/or filenames.

Options:
`, filepath.Base(os.Args[0]))
		flags.PrintDefaults()
	}

	outputFile := flags.String("o", "-", "Where to write the output. (default stdout)")
	sources := newMultiString(flags, "rtrace", "Projects or metadata files to trace back from. (required; multiple allowed)")
	stripPrefix := newMultiString(flags, "strip_prefix", "Prefix to remove from paths. i.e. path to root (multiple allowed)")

	flags.Parse(expandedArgs)

	// Must specify at least one root target.
	if flags.NArg() == 0 {
		flags.Usage()
		os.Exit(2)
	}

	if len(*sources) == 0 {
		flags.Usage()
		fmt.Fprintf(os.Stderr, "\nMust specify at least 1 --rtrace source.\n")
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

	ctx := &context{
		sources:     *sources,
		stripPrefix: *stripPrefix,
	}
	_, err := traceRestricted(ctx, ofile, os.Stderr, compliance.FS, flags.Args()...)
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

// traceRestricted implements the rtrace utility.
func traceRestricted(ctx *context, stdout, stderr io.Writer, rootFS fs.FS, files ...string) (*compliance.LicenseGraph, error) {
	if len(files) < 1 {
		return nil, failNoneRequested
	}

	if len(ctx.sources) < 1 {
		return nil, failNoSources
	}

	// Read the license graph from the license metadata files (*.meta_lic).
	licenseGraph, err := compliance.ReadLicenseGraph(rootFS, stderr, files)
	if err != nil {
		return nil, fmt.Errorf("Unable to read license metadata file(s) %q: %v\n", files, err)
	}
	if licenseGraph == nil {
		return nil, failNoLicenses
	}

	sourceMap := make(map[string]struct{})
	for _, source := range ctx.sources {
		sourceMap[source] = struct{}{}
	}

	compliance.TraceTopDownConditions(licenseGraph, func(tn *compliance.TargetNode) compliance.LicenseConditionSet {
		if _, isPresent := sourceMap[tn.Name()]; isPresent {
			return compliance.ImpliesRestricted
		}
		for _, project := range tn.Projects() {
			if _, isPresent := sourceMap[project]; isPresent {
				return compliance.ImpliesRestricted
			}
		}
		return compliance.NewLicenseConditionSet()
	})

	// targetOut calculates the string to output for `target` adding `sep`-separated conditions as needed.
	targetOut := func(target *compliance.TargetNode, sep string) string {
		tOut := ctx.strip(target.Name())
		return tOut
	}

	// outputResolution prints a resolution in the requested format to `stdout`, where one can read
	// a resolution as `tname` resolves conditions named in `cnames`.
	// `tname` is the name of the target the resolution traces back to.
	// `cnames` is the list of conditions to resolve.
	outputResolution := func(tname string, cnames []string) {
		// ... one edge per line with names in a colon-separated tuple.
		fmt.Fprintf(stdout, "%s %s\n", tname, strings.Join(cnames, ":"))
	}

	// Sort the resolutions by targetname for repeatability/stability.
	actions := compliance.WalkResolutionsForCondition(licenseGraph, compliance.ImpliesShared).AllActions()
	targets := make(compliance.TargetNodeList, 0, len(actions))
	for tn := range actions {
		if tn.LicenseConditions().MatchesAnySet(compliance.ImpliesRestricted) {
			targets = append(targets, tn)
		}
	}
	sort.Sort(targets)

	// Output the sorted targets.
	for _, target := range targets {
		var tname string
		tname = targetOut(target, ":")

		// cnames accumulates the list of condition names originating at a single origin that apply to `target`.
		cnames := target.LicenseConditions().Names()

		// Output 1 line for each attachesTo+actsOn combination.
		outputResolution(tname, cnames)
	}
	fmt.Fprintf(stdout, "restricted conditions trace to %d targets\n", len(targets))
	if 0 == len(targets) {
		fmt.Fprintln(stdout, "  (check for typos in project names or metadata files)")
	}
	return licenseGraph, nil
}
