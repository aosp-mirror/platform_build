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

type context struct {
	graphViz        bool
	labelConditions bool
	stripPrefix     []string
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

Outputs space-separated Target Dependency Annotations tuples for each
edge in the license graph. When -dot flag given, outputs the nodes and
edges in graphViz directed graph format.

In plain text mode, multiple values within a field are colon-separated.
e.g. multiple annotations appear as annotation1:annotation2:annotation3
or when -label_conditions is requested, Target and Dependency become
target:condition1:condition2 etc.

Options:
`, filepath.Base(os.Args[0]))
		flags.PrintDefaults()
	}

	graphViz := flags.Bool("dot", false, "Whether to output graphviz (i.e. dot) format.")
	labelConditions := flags.Bool("label_conditions", false, "Whether to label target nodes with conditions.")
	outputFile := flags.String("o", "-", "Where to write the output. (default stdout)")
	stripPrefix := newMultiString(flags, "strip_prefix", "Prefix to remove from paths. i.e. path to root (multiple allowed)")

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

	ctx := &context{*graphViz, *labelConditions, *stripPrefix}

	err := dumpGraph(ctx, ofile, os.Stderr, compliance.FS, flags.Args()...)
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

// dumpGraph implements the dumpgraph utility.
func dumpGraph(ctx *context, stdout, stderr io.Writer, rootFS fs.FS, files ...string) error {
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

	// Sort the edges of the graph.
	edges := licenseGraph.Edges()
	sort.Sort(edges)

	// nodes maps license metadata file names to graphViz node names when ctx.graphViz is true.
	var nodes map[string]string
	n := 0

	// targetOut calculates the string to output for `target` separating conditions as needed using `sep`.
	targetOut := func(target *compliance.TargetNode, sep string) string {
		tOut := ctx.strip(target.Name())
		if ctx.labelConditions {
			conditions := target.LicenseConditions().Names()
			sort.Strings(conditions)
			if len(conditions) > 0 {
				tOut += sep + strings.Join(conditions, sep)
			}
		}
		return tOut
	}

	// makeNode maps `target` to a graphViz node name.
	makeNode := func(target *compliance.TargetNode) {
		tName := target.Name()
		if _, ok := nodes[tName]; !ok {
			nodeName := fmt.Sprintf("n%d", n)
			nodes[tName] = nodeName
			fmt.Fprintf(stdout, "\t%s [label=\"%s\"];\n", nodeName, targetOut(target, "\\n"))
			n++
		}
	}

	// If graphviz output, map targets to node names, and start the directed graph.
	if ctx.graphViz {
		nodes = make(map[string]string)
		targets := licenseGraph.Targets()
		sort.Sort(targets)

		fmt.Fprintf(stdout, "strict digraph {\n\trankdir=RL;\n")
		for _, target := range targets {
			makeNode(target)
		}
	}

	// Print the sorted edges to stdout ...
	for _, e := range edges {
		// sort the annotations for repeatability/stability
		annotations := e.Annotations().AsList()
		sort.Strings(annotations)

		tName := e.Target().Name()
		dName := e.Dependency().Name()

		if ctx.graphViz {
			// ... one edge per line labelled with \\n-separated annotations.
			tNode := nodes[tName]
			dNode := nodes[dName]
			fmt.Fprintf(stdout, "\t%s -> %s [label=\"%s\"];\n", dNode, tNode, strings.Join(annotations, "\\n"))
		} else {
			// ... one edge per line with annotations in a colon-separated tuple.
			fmt.Fprintf(stdout, "%s %s %s\n", targetOut(e.Target(), ":"), targetOut(e.Dependency(), ":"), strings.Join(annotations, ":"))
		}
	}

	// If graphViz output, rank the root nodes together, and complete the directed graph.
	if ctx.graphViz {
		fmt.Fprintf(stdout, "\t{rank=same;")
		for _, f := range files {
			fName := f
			if !strings.HasSuffix(fName, ".meta_lic") {
				fName += ".meta_lic"
			}
			if fNode, ok := nodes[fName]; ok {
				fmt.Fprintf(stdout, " %s", fNode)
			}
		}
		fmt.Fprintf(stdout, "}\n}\n")
	}
	return nil
}
