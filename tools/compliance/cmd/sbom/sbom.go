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
	"crypto/sha1"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"android/soong/response"
	"android/soong/tools/compliance"
	"android/soong/tools/compliance/projectmetadata"

	"github.com/google/blueprint/deptools"

	"github.com/spdx/tools-golang/builder/builder2v2"
	spdx_json "github.com/spdx/tools-golang/json"
	"github.com/spdx/tools-golang/spdx/common"
	spdx "github.com/spdx/tools-golang/spdx/v2_2"
	"github.com/spdx/tools-golang/spdxlib"
)

var (
	failNoneRequested = fmt.Errorf("\nNo license metadata files requested")
	failNoLicenses    = fmt.Errorf("No licenses found")
)

const NOASSERTION = "NOASSERTION"

type context struct {
	stdout       io.Writer
	stderr       io.Writer
	rootFS       fs.FS
	product      string
	stripPrefix  []string
	creationTime creationTimeGetter
	buildid      string
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

Outputs an SBOM.spdx.

Options:
`, filepath.Base(os.Args[0]))
		flags.PrintDefaults()
	}

	outputFile := flags.String("o", "-", "Where to write the SBOM spdx file. (default stdout)")
	depsFile := flags.String("d", "", "Where to write the deps file")
	product := flags.String("product", "", "The name of the product for which the notice is generated.")
	stripPrefix := newMultiString(flags, "strip_prefix", "Prefix to remove from paths. i.e. path to root (multiple allowed)")
	buildid := flags.String("build_id", "", "Uniquely identifies the build. (default timestamp)")

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

	ctx := &context{ofile, os.Stderr, compliance.FS, *product, *stripPrefix, actualTime, *buildid}

	spdxDoc, deps, err := sbomGenerator(ctx, flags.Args()...)

	if err != nil {
		if err == failNoneRequested {
			flags.Usage()
		}
		fmt.Fprintf(os.Stderr, "%s\n", err.Error())
		os.Exit(1)
	}

	// writing the spdx Doc created
	if err := spdx_json.Save2_2(spdxDoc, ofile); err != nil {
		fmt.Fprintf(os.Stderr, "failed to write document to %v: %v", *outputFile, err)
		os.Exit(1)
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

type creationTimeGetter func() string

// actualTime returns current time in UTC
func actualTime() string {
	t := time.Now().UTC()
	return t.UTC().Format("2006-01-02T15:04:05Z")
}

// replaceSlashes replaces "/" by "-" for the library path to be used for packages & files SPDXID
func replaceSlashes(x string) string {
	return strings.ReplaceAll(x, "/", "-")
}

// stripDocName removes the outdir prefix and meta_lic suffix from a target Name
func stripDocName(name string) string {
	// remove outdir prefix
	if strings.HasPrefix(name, "out/") {
		name = name[4:]
	}

	// remove suffix
	if strings.HasSuffix(name, ".meta_lic") {
		name = name[:len(name)-9]
	} else if strings.HasSuffix(name, "/meta_lic") {
		name = name[:len(name)-9] + "/"
	}

	return name
}

// getPackageName returns a package name of a target Node
func getPackageName(_ *context, tn *compliance.TargetNode) string {
	return replaceSlashes(tn.Name())
}

// getDocumentName returns a package name of a target Node
func getDocumentName(ctx *context, tn *compliance.TargetNode, pm *projectmetadata.ProjectMetadata) string {
	if len(ctx.product) > 0 {
		return replaceSlashes(ctx.product)
	}
	if len(tn.ModuleName()) > 0 {
		if pm != nil {
			return replaceSlashes(pm.Name() + ":" + tn.ModuleName())
		}
		return replaceSlashes(tn.ModuleName())
	}

	return stripDocName(replaceSlashes(tn.Name()))
}

// getDownloadUrl returns the download URL if available (GIT, SVN, etc..),
// or NOASSERTION if not available, none determined or ambiguous
func getDownloadUrl(_ *context, pm *projectmetadata.ProjectMetadata) string {
	if pm == nil {
		return NOASSERTION
	}

	urlsByTypeName := pm.UrlsByTypeName()
	if urlsByTypeName == nil {
		return NOASSERTION
	}

	url := urlsByTypeName.DownloadUrl()
	if url == "" {
		return NOASSERTION
	}
	return url
}

// getProjectMetadata returns the optimal project metadata for the target node
func getProjectMetadata(_ *context, pmix *projectmetadata.Index,
	tn *compliance.TargetNode) (*projectmetadata.ProjectMetadata, error) {
	pms, err := pmix.MetadataForProjects(tn.Projects()...)
	if err != nil {
		return nil, fmt.Errorf("Unable to read projects for %q: %w\n", tn.Name(), err)
	}
	if len(pms) == 0 {
		return nil, nil
	}

	// Getting the project metadata that contains most of the info needed for sbomGenerator
	score := -1
	index := -1
	for i := 0; i < len(pms); i++ {
		tempScore := 0
		if pms[i].Name() != "" {
			tempScore += 1
		}
		if pms[i].Version() != "" {
			tempScore += 1
		}
		if pms[i].UrlsByTypeName().DownloadUrl() != "" {
			tempScore += 1
		}

		if tempScore == score {
			if pms[i].Project() < pms[index].Project() {
				index = i
			}
		} else if tempScore > score {
			score = tempScore
			index = i
		}
	}
	return pms[index], nil
}

// inputFiles returns the complete list of files read
func inputFiles(lg *compliance.LicenseGraph, pmix *projectmetadata.Index, licenseTexts []string) []string {
	projectMeta := pmix.AllMetadataFiles()
	targets := lg.TargetNames()
	files := make([]string, 0, len(licenseTexts)+len(targets)+len(projectMeta))
	files = append(files, licenseTexts...)
	files = append(files, targets...)
	files = append(files, projectMeta...)
	return files
}

// generateSPDXNamespace generates a unique SPDX Document Namespace using a SHA1 checksum
func generateSPDXNamespace(buildid string, created string, files ...string) string {

	seed := strings.Join(files, "")

	if buildid == "" {
		seed += created
	} else {
		seed += buildid
	}

	// Compute a SHA1 checksum of the seed.
	hash := sha1.Sum([]byte(seed))
	uuid := hex.EncodeToString(hash[:])

	namespace := fmt.Sprintf("SPDXRef-DOCUMENT-%s", uuid)

	return namespace
}

// sbomGenerator implements the spdx bom utility

// SBOM is part of the new government regulation issued to improve national cyber security
// and enhance software supply chain and transparency, see https://www.cisa.gov/sbom

// sbomGenerator uses the SPDX standard, see the SPDX specification (https://spdx.github.io/spdx-spec/)
// sbomGenerator is also following the internal google SBOM styleguide (http://goto.google.com/spdx-style-guide)
func sbomGenerator(ctx *context, files ...string) (*spdx.Document, []string, error) {
	// Must be at least one root file.
	if len(files) < 1 {
		return nil, nil, failNoneRequested
	}

	pmix := projectmetadata.NewIndex(ctx.rootFS)

	lg, err := compliance.ReadLicenseGraph(ctx.rootFS, ctx.stderr, files)

	if err != nil {
		return nil, nil, fmt.Errorf("Unable to read license text file(s) for %q: %v\n", files, err)
	}

	// creating the packages section
	pkgs := []*spdx.Package{}

	// creating the relationship section
	relationships := []*spdx.Relationship{}

	// creating the license section
	otherLicenses := []*spdx.OtherLicense{}

	// spdx document name
	var docName string

	// main package name
	var mainPkgName string

	// implementing the licenses references for the packages
	licenses := make(map[string]string)
	concludedLicenses := func(licenseTexts []string) string {
		licenseRefs := make([]string, 0, len(licenseTexts))
		for _, licenseText := range licenseTexts {
			license := strings.SplitN(licenseText, ":", 2)[0]
			if _, ok := licenses[license]; !ok {
				licenseRef := "LicenseRef-" + replaceSlashes(license)
				licenses[license] = licenseRef
			}

			licenseRefs = append(licenseRefs, licenses[license])
		}
		if len(licenseRefs) > 1 {
			return "(" + strings.Join(licenseRefs, " AND ") + ")"
		} else if len(licenseRefs) == 1 {
			return licenseRefs[0]
		}
		return "NONE"
	}

	isMainPackage := true
	visitedNodes := make(map[*compliance.TargetNode]struct{})

	// performing a Breadth-first top down walk of licensegraph and building package information
	compliance.WalkTopDownBreadthFirst(nil, lg,
		func(lg *compliance.LicenseGraph, tn *compliance.TargetNode, path compliance.TargetEdgePath) bool {
			if err != nil {
				return false
			}
			var pm *projectmetadata.ProjectMetadata
			pm, err = getProjectMetadata(ctx, pmix, tn)
			if err != nil {
				return false
			}

			if isMainPackage {
				docName = getDocumentName(ctx, tn, pm)
				mainPkgName = replaceSlashes(getPackageName(ctx, tn))
				isMainPackage = false
			}

			if len(path) == 0 {
				// Add the describe relationship for the main package
				rln := &spdx.Relationship{
					RefA:         common.MakeDocElementID("" /* this document */, "DOCUMENT"),
					RefB:         common.MakeDocElementID("", mainPkgName),
					Relationship: "DESCRIBES",
				}
				relationships = append(relationships, rln)

			} else {
				// Check parent and identify annotation
				parent := path[len(path)-1]
				targetEdge := parent.Edge()
				if targetEdge.IsRuntimeDependency() {
					// Adding the dynamic link annotation RUNTIME_DEPENDENCY_OF relationship
					rln := &spdx.Relationship{
						RefA:         common.MakeDocElementID("", replaceSlashes(getPackageName(ctx, tn))),
						RefB:         common.MakeDocElementID("", replaceSlashes(getPackageName(ctx, targetEdge.Target()))),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					}
					relationships = append(relationships, rln)

				} else if targetEdge.IsDerivation() {
					// Adding the  derivation annotation as a CONTAINS relationship
					rln := &spdx.Relationship{
						RefA:         common.MakeDocElementID("", replaceSlashes(getPackageName(ctx, targetEdge.Target()))),
						RefB:         common.MakeDocElementID("", replaceSlashes(getPackageName(ctx, tn))),
						Relationship: "CONTAINS",
					}
					relationships = append(relationships, rln)

				} else if targetEdge.IsBuildTool() {
					// Adding the toolchain annotation as a BUILD_TOOL_OF relationship
					rln := &spdx.Relationship{
						RefA:         common.MakeDocElementID("", replaceSlashes(getPackageName(ctx, tn))),
						RefB:         common.MakeDocElementID("", replaceSlashes(getPackageName(ctx, targetEdge.Target()))),
						Relationship: "BUILD_TOOL_OF",
					}
					relationships = append(relationships, rln)

				} else {
					panic(fmt.Errorf("Unknown dependency type: %v", targetEdge.Annotations()))
				}
			}

			if _, alreadyVisited := visitedNodes[tn]; alreadyVisited {
				return false
			}
			visitedNodes[tn] = struct{}{}
			pkgName := getPackageName(ctx, tn)

			// Making an spdx package and adding it to pkgs
			pkg := &spdx.Package{
				PackageName:             replaceSlashes(pkgName),
				PackageDownloadLocation: getDownloadUrl(ctx, pm),
				PackageSPDXIdentifier:   common.ElementID(replaceSlashes(pkgName)),
				PackageLicenseConcluded: concludedLicenses(tn.LicenseTexts()),
			}

			if pm != nil && pm.Version() != "" {
				pkg.PackageVersion = pm.Version()
			} else {
				pkg.PackageVersion = NOASSERTION
			}

			pkgs = append(pkgs, pkg)

			return true
		})

	// Adding Non-standard licenses

	licenseTexts := make([]string, 0, len(licenses))

	for licenseText := range licenses {
		licenseTexts = append(licenseTexts, licenseText)
	}

	sort.Strings(licenseTexts)

	for _, licenseText := range licenseTexts {
		// open the file
		f, err := ctx.rootFS.Open(filepath.Clean(licenseText))
		if err != nil {
			return nil, nil, fmt.Errorf("error opening license text file %q: %w", licenseText, err)
		}

		// read the file
		text, err := io.ReadAll(f)
		if err != nil {
			return nil, nil, fmt.Errorf("error reading license text file %q: %w", licenseText, err)
		}
		// Making an spdx License and adding it to otherLicenses
		otherLicenses = append(otherLicenses, &spdx.OtherLicense{
			LicenseName:       strings.Replace(licenses[licenseText], "LicenseRef-", "", -1),
			LicenseIdentifier: string(licenses[licenseText]),
			ExtractedText:     string(text),
		})
	}

	deps := inputFiles(lg, pmix, licenseTexts)
	sort.Strings(deps)

	// Making the SPDX doc
	ci, err := builder2v2.BuildCreationInfoSection2_2("Organization", "Google LLC", nil)
	if err != nil {
		return nil, nil, fmt.Errorf("Unable to build creation info section for SPDX doc: %v\n", err)
	}

	ci.Created = ctx.creationTime()

	doc := &spdx.Document{
		SPDXVersion:       "SPDX-2.2",
		DataLicense:       "CC0-1.0",
		SPDXIdentifier:    "DOCUMENT",
		DocumentName:      docName,
		DocumentNamespace: generateSPDXNamespace(ctx.buildid, ci.Created, files...),
		CreationInfo:      ci,
		Packages:          pkgs,
		Relationships:     relationships,
		OtherLicenses:     otherLicenses,
	}

	if err := spdxlib.ValidateDocument2_2(doc); err != nil {
		return nil, nil, fmt.Errorf("Unable to validate the SPDX doc: %v\n", err)
	}

	return doc, deps, nil
}
