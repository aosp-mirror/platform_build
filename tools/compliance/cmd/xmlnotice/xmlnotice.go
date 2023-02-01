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
	"compress/gzip"
	"encoding/xml"
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

	"github.com/google/blueprint/deptools"
)

var (
	failNoneRequested = fmt.Errorf("\nNo license metadata files requested")
	failNoLicenses    = fmt.Errorf("No licenses found")
)

type context struct {
	stdout      io.Writer
	stderr      io.Writer
	rootFS      fs.FS
	product     string
	stripPrefix []string
	title       string
	deps        *[]string
}

func (ctx context) strip(installPath string) string {
	for _, prefix := range ctx.stripPrefix {
		if strings.HasPrefix(installPath, prefix) {
			p := strings.TrimPrefix(installPath, prefix)
			if 0 == len(p) {
				p = ctx.product
			}
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

Outputs an xml NOTICE.xml or gzipped NOTICE.xml.gz file if the -o filename ends
with ".gz".

Options:
`, filepath.Base(os.Args[0]))
		flags.PrintDefaults()
	}

	outputFile := flags.String("o", "-", "Where to write the NOTICE xml or xml.gz file. (default stdout)")
	depsFile := flags.String("d", "", "Where to write the deps file")
	product := flags.String("product", "", "The name of the product for which the notice is generated.")
	stripPrefix := newMultiString(flags, "strip_prefix", "Prefix to remove from paths. i.e. path to root (multiple allowed)")
	title := flags.String("title", "", "The title of the notice file.")

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
	var closer io.Closer
	ofile = os.Stdout
	var obuf *bytes.Buffer
	if *outputFile != "-" {
		obuf = &bytes.Buffer{}
		ofile = obuf
	}
	if strings.HasSuffix(*outputFile, ".gz") {
		ofile, _ = gzip.NewWriterLevel(obuf, gzip.BestCompression)
		closer = ofile.(io.Closer)
	}

	var deps []string

	ctx := &context{ofile, os.Stderr, compliance.FS, *product, *stripPrefix, *title, &deps}

	err := xmlNotice(ctx, flags.Args()...)
	if err != nil {
		if err == failNoneRequested {
			flags.Usage()
		}
		fmt.Fprintf(os.Stderr, "%s\n", err.Error())
		os.Exit(1)
	}
	if closer != nil {
		closer.Close()
	}

	if *outputFile != "-" {
		err := os.WriteFile(*outputFile, obuf.Bytes(), 0666)
		if err != nil {
			fmt.Fprintf(os.Stderr, "could not write output to %q: %s\n", *outputFile, err)
			os.Exit(1)
		}
	}
	if *depsFile != "" {
		err := deptools.WriteDepFile(*depsFile, *outputFile, deps)
		if err != nil {
			fmt.Fprintf(os.Stderr, "could not write deps to %q: %s\n", *depsFile, err)
			os.Exit(1)
		}
	}
	os.Exit(0)
}

// xmlNotice implements the xmlnotice utility.
func xmlNotice(ctx *context, files ...string) error {
	// Must be at least one root file.
	if len(files) < 1 {
		return failNoneRequested
	}

	// Read the license graph from the license metadata files (*.meta_lic).
	licenseGraph, err := compliance.ReadLicenseGraph(ctx.rootFS, ctx.stderr, files)
	if err != nil {
		return fmt.Errorf("Unable to read license metadata file(s) %q: %v\n", files, err)
	}
	if licenseGraph == nil {
		return failNoLicenses
	}

	// rs contains all notice resolutions.
	rs := compliance.ResolveNotices(licenseGraph)

	ni, err := compliance.IndexLicenseTexts(ctx.rootFS, licenseGraph, rs)
	if err != nil {
		return fmt.Errorf("Unable to read license text file(s) for %q: %v\n", files, err)
	}

	fmt.Fprintln(ctx.stdout, "<?xml version=\"1.0\" encoding=\"utf-8\"?>")
	fmt.Fprintln(ctx.stdout, "<licenses>")

	for installPath := range ni.InstallPaths() {
		p := ctx.strip(installPath)
		for _, h := range ni.InstallHashes(installPath) {
			for _, lib := range ni.InstallHashLibs(installPath, h) {
				fmt.Fprintf(ctx.stdout, "<file-name contentId=\"%s\" lib=\"", h.String())
				xml.EscapeText(ctx.stdout, []byte(lib))
				fmt.Fprintf(ctx.stdout, "\">")
				xml.EscapeText(ctx.stdout, []byte(p))
				fmt.Fprintln(ctx.stdout, "</file-name>")
			}
		}
	}
	for h := range ni.Hashes() {
		fmt.Fprintf(ctx.stdout, "<file-content contentId=\"%s\"><![CDATA[", h)
		xml.EscapeText(ctx.stdout, ni.HashText(h))
		fmt.Fprintf(ctx.stdout, "]]></file-content>\n\n")
	}
	fmt.Fprintln(ctx.stdout, "</licenses>")

	*ctx.deps = ni.InputFiles()
	sort.Strings(*ctx.deps)

	return nil
}
