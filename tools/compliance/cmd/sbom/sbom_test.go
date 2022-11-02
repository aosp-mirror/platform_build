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
	"bufio"
	"bytes"
	"fmt"
	"os"
	"reflect"
	"regexp"
	"strings"
	"testing"
	"time"

	"android/soong/tools/compliance"
)

var (
	spdxVersionTag              = regexp.MustCompile(`^\s*SPDXVersion: SPDX-2.2\s*$`)
	spdxDataLicenseTag          = regexp.MustCompile(`^\s*DataLicense: CC-1.0\s*$`)
	spdxDocumentNameTag         = regexp.MustCompile(`^\s*DocumentName:\s*Android*\s*$`)
	spdxIDTag                   = regexp.MustCompile(`^\s*SPDXID:\s*SPDXRef-DOCUMENT-(.*)\s*$`)
	spdxDocumentNameSpaceTag    = regexp.MustCompile(`^\s*DocumentNamespace:\s*Android\s*$`)
	spdxCreatorOrganizationTag  = regexp.MustCompile(`^\s*Creator:\s*Organization:\s*Google LLC\s*$`)
	spdxCreatedTimeTag          = regexp.MustCompile(`^\s*Created: 1970-01-01T00:00:00Z\s*$`)
	spdxPackageTag              = regexp.MustCompile(`^\s*#####\s*Package:\s*(.*)\s*$`)
	spdxPackageNameTag          = regexp.MustCompile(`^\s*PackageName:\s*(.*)\s*$`)
	spdxPkgIDTag                = regexp.MustCompile(`^\s*SPDXID:\s*SPDXRef-Package-(.*)\s*$`)
	spdxPkgDownloadLocationTag  = regexp.MustCompile(`^\s*PackageDownloadLocation:\s*NOASSERTION\s*$`)
	spdxPkgLicenseDeclaredTag   = regexp.MustCompile(`^\s*PackageLicenseConcluded:\s*LicenseRef-(.*)\s*$`)
	spdxRelationshipTag         = regexp.MustCompile(`^\s*Relationship:\s*SPDXRef-(.*)\s*(DESCRIBES|CONTAINS|BUILD_TOOL_OF|RUNTIME_DEPENDENCY_OF)\s*SPDXRef-Package-(.*)\s*$`)
	spdxLicenseTag              = regexp.MustCompile(`^\s*##### Non-standard license:\s*$`)
	spdxLicenseIDTag            = regexp.MustCompile(`^\s*LicenseID: LicenseRef-(.*)\s*$`)
	spdxExtractedTextTag        = regexp.MustCompile(`^\s*ExtractedText:\s*<text>(.*)\s*$`)
	spdxExtractedClosingTextTag = regexp.MustCompile(`^\s*</text>\s*$`)
)

func TestMain(m *testing.M) {
	// Change into the parent directory before running the tests
	// so they can find the testdata directory.
	if err := os.Chdir(".."); err != nil {
		fmt.Printf("failed to change to testdata directory: %s\n", err)
		os.Exit(1)
	}
	os.Exit(m.Run())
}

func Test(t *testing.T) {
	tests := []struct {
		condition    string
		name         string
		outDir       string
		roots        []string
		stripPrefix  string
		expectedOut  []matcher
		expectedDeps []string
	}{
		{
			condition: "firstparty",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/firstparty/highest.apex.meta_lic"},
				packageName{"testdata/firstparty/highest.apex.meta_lic"},
				spdxPkgID{"testdata/firstparty/highest.apex.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata-firstparty-highest.apex.meta_lic", "DESCRIBES"},
				packageTag{"testdata/firstparty/bin/bin1.meta_lic"},
				packageName{"testdata/firstparty/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/firstparty/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/highest.apex.meta_lic ", "testdata/firstparty/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/bin/bin2.meta_lic"},
				packageName{"testdata/firstparty/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/firstparty/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/highest.apex.meta_lic ", "testdata-firstparty-bin-bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/liba.so.meta_lic"},
				packageName{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/highest.apex.meta_lic ", "testdata/firstparty/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/libb.so.meta_lic"},
				packageName{"testdata/firstparty/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/highest.apex.meta_lic ", "testdata/firstparty/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/firstparty/bin/bin1.meta_lic ", "testdata/firstparty/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/libc.a.meta_lic"},
				packageName{"testdata/firstparty/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata-firstparty-bin-bin1.meta_lic ", "testdata/firstparty/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/firstparty/lib/libb.so.meta_lic ", "testdata/firstparty/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/firstparty/lib/libd.so.meta_lic"},
				packageName{"testdata/firstparty/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/lib/libd.so.meta_lic ", "testdata/firstparty/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/firstparty/FIRST_PARTY_LICENSE"},
		},
		{
			condition: "firstparty",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/firstparty/application.meta_lic"},
				packageName{"testdata/firstparty/application.meta_lic"},
				spdxPkgID{"testdata/firstparty/application.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/firstparty/application.meta_lic", "DESCRIBES"},
				packageTag{"testdata/firstparty/bin/bin3.meta_lic"},
				packageName{"testdata/firstparty/bin/bin3.meta_lic"},
				spdxPkgID{"testdata/firstparty/bin/bin3.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/bin/bin3.meta_lic ", "testdata-firstparty-application.meta_lic", "BUILD_TOOL_OF"},
				packageTag{"testdata/firstparty/lib/liba.so.meta_lic"},
				packageName{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/application.meta_lic ", "testdata/firstparty/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/libb.so.meta_lic"},
				packageName{"testdata/firstparty/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/lib/libb.so.meta_lic ", "testdata-firstparty-application.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/firstparty/FIRST_PARTY_LICENSE"},
		},
		{
			condition: "firstparty",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/firstparty/container.zip.meta_lic"},
				packageName{"testdata/firstparty/container.zip.meta_lic"},
				spdxPkgID{"testdata/firstparty/container.zip.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/firstparty/container.zip.meta_lic", "DESCRIBES"},
				packageTag{"testdata/firstparty/bin/bin1.meta_lic"},
				packageName{"testdata/firstparty/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/firstparty/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/container.zip.meta_lic ", "testdata/firstparty/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/bin/bin2.meta_lic"},
				packageName{"testdata/firstparty/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/firstparty/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/container.zip.meta_lic ", "testdata/firstparty/bin/bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/liba.so.meta_lic"},
				packageName{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/container.zip.meta_lic ", "testdata/firstparty/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/libb.so.meta_lic"},
				packageName{"testdata/firstparty/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/container.zip.meta_lic ", "testdata/firstparty/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/firstparty/bin/bin1.meta_lic ", "testdata/firstparty/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/libc.a.meta_lic"},
				packageName{"testdata/firstparty/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/bin/bin1.meta_lic ", "testdata/firstparty/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/firstparty/lib/libb.so.meta_lic ", "testdata/firstparty/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/firstparty/lib/libd.so.meta_lic"},
				packageName{"testdata/firstparty/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/lib/libd.so.meta_lic ", "testdata/firstparty/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/firstparty/FIRST_PARTY_LICENSE"},
		},
		{
			condition: "firstparty",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/firstparty/bin/bin1.meta_lic"},
				packageName{"testdata/firstparty/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/firstparty/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/firstparty/bin/bin1.meta_lic", "DESCRIBES"},
				packageTag{"testdata/firstparty/lib/liba.so.meta_lic"},
				packageName{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/bin/bin1.meta_lic ", "testdata/firstparty/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/firstparty/lib/libc.a.meta_lic"},
				packageName{"testdata/firstparty/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/firstparty/bin/bin1.meta_lic ", "testdata/firstparty/lib/libc.a.meta_lic", "CONTAINS"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/firstparty/FIRST_PARTY_LICENSE"},
		},
		{
			condition: "firstparty",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/firstparty/lib/libd.so.meta_lic"},
				packageName{"testdata/firstparty/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/firstparty/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/firstparty/lib/libd.so.meta_lic", "DESCRIBES"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/firstparty/FIRST_PARTY_LICENSE"},
		},
		{
			condition: "notice",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/notice/highest.apex.meta_lic"},
				packageName{"testdata/notice/highest.apex.meta_lic"},
				spdxPkgID{"testdata/notice/highest.apex.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/notice/highest.apex.meta_lic", "DESCRIBES"},
				packageTag{"testdata/notice/bin/bin1.meta_lic"},
				packageName{"testdata/notice/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/notice/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/notice/highest.apex.meta_lic ", "testdata/notice/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/bin/bin2.meta_lic"},
				packageName{"testdata/notice/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/notice/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/notice/highest.apex.meta_lic ", "testdata/notice/bin/bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/liba.so.meta_lic"},
				packageName{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/highest.apex.meta_lic ", "testdata/notice/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/libb.so.meta_lic"},
				packageName{"testdata/notice/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/notice/highest.apex.meta_lic ", "testdata/notice/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/notice/bin/bin1.meta_lic ", "testdata/notice/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/libc.a.meta_lic"},
				packageName{"testdata/notice/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/bin/bin1.meta_lic ", "testdata/notice/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/notice/lib/libb.so.meta_lic ", "testdata/notice/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/notice/lib/libd.so.meta_lic"},
				packageName{"testdata/notice/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/lib/libd.so.meta_lic ", "testdata/notice/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
			},
		},
		{
			condition: "notice",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/notice/container.zip.meta_lic"},
				packageName{"testdata/notice/container.zip.meta_lic"},
				spdxPkgID{"testdata/notice/container.zip.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/notice/container.zip.meta_lic", "DESCRIBES"},
				packageTag{"testdata/notice/bin/bin1.meta_lic"},
				packageName{"testdata/notice/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/notice/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/notice/container.zip.meta_lic ", "testdata/notice/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/bin/bin2.meta_lic"},
				packageName{"testdata/notice/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/notice/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/notice/container.zip.meta_lic ", "testdata/notice/bin/bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/liba.so.meta_lic"},
				packageName{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/container.zip.meta_lic ", "testdata/notice/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/libb.so.meta_lic"},
				packageName{"testdata/notice/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/notice/container.zip.meta_lic ", "testdata/notice/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/notice/bin/bin1.meta_lic ", "testdata/notice/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/libc.a.meta_lic"},
				packageName{"testdata/notice/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/bin/bin1.meta_lic ", "testdata/notice/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/notice/lib/libb.so.meta_lic ", "testdata/notice/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/notice/lib/libd.so.meta_lic"},
				packageName{"testdata/notice/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/lib/libd.so.meta_lic ", "testdata/notice/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
			},
		},
		{
			condition: "notice",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/notice/application.meta_lic"},
				packageName{"testdata/notice/application.meta_lic"},
				spdxPkgID{"testdata/notice/application.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata-notice-application.meta_lic", "DESCRIBES"},
				packageTag{"testdata/notice/bin/bin3.meta_lic"},
				packageName{"testdata/notice/bin/bin3.meta_lic"},
				spdxPkgID{"testdata/notice/bin/bin3.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata-notice-bin-bin3.meta_lic ", "testdata/notice/application.meta_lic", "BUILD_TOOL_OF"},
				packageTag{"testdata/notice/lib/liba.so.meta_lic"},
				packageName{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/application.meta_lic ", "testdata-notice-lib-liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/libb.so.meta_lic"},
				packageName{"testdata/notice/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata-notice-lib-libb.so.meta_lic ", "testdata/notice/application.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
			},
		},
		{
			condition: "notice",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/notice/bin/bin1.meta_lic"},
				packageName{"testdata/notice/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/notice/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/notice/bin/bin1.meta_lic", "DESCRIBES"},
				packageTag{"testdata/notice/lib/liba.so.meta_lic"},
				packageName{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/bin/bin1.meta_lic ", "testdata/notice/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/notice/lib/libc.a.meta_lic"},
				packageName{"testdata/notice/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/notice/bin/bin1.meta_lic ", "testdata/notice/lib/libc.a.meta_lic", "CONTAINS"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
			},
		},
		{
			condition: "notice",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/notice/lib/libd.so.meta_lic"},
				packageName{"testdata/notice/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/notice/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/notice/lib/libd.so.meta_lic", "DESCRIBES"},
				spdxLicense{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/notice/NOTICE_LICENSE"},
		},
		{
			condition: "reciprocal",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/reciprocal/highest.apex.meta_lic"},
				packageName{"testdata/reciprocal/highest.apex.meta_lic"},
				spdxPkgID{"testdata/reciprocal/highest.apex.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/reciprocal/highest.apex.meta_lic", "DESCRIBES"},
				packageTag{"testdata/reciprocal/bin/bin1.meta_lic"},
				packageName{"testdata/reciprocal/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/reciprocal/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/highest.apex.meta_lic ", "testdata-reciprocal-bin-bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/bin/bin2.meta_lic"},
				packageName{"testdata/reciprocal/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/reciprocal/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/highest.apex.meta_lic ", "testdata-reciprocal-bin-bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/liba.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/highest.apex.meta_lic ", "testdata/reciprocal/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/libb.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/highest.apex.meta_lic ", "testdata/reciprocal/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/reciprocal/bin/bin1.meta_lic ", "testdata/reciprocal/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/libc.a.meta_lic"},
				packageName{"testdata/reciprocal/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/bin/bin1.meta_lic ", "testdata/reciprocal/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/reciprocal/lib/libb.so.meta_lic ", "testdata/reciprocal/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/reciprocal/lib/libd.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/lib/libd.so.meta_lic ", "testdata/reciprocal/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxExtractedText{"$$$Reciprocal License$$$"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
			},
		},
		{
			condition: "reciprocal",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/reciprocal/container.zip.meta_lic"},
				packageName{"testdata/reciprocal/container.zip.meta_lic"},
				spdxPkgID{"testdata/reciprocal/container.zip.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/reciprocal/container.zip.meta_lic", "DESCRIBES"},
				packageTag{"testdata/reciprocal/bin/bin1.meta_lic"},
				packageName{"testdata/reciprocal/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/reciprocal/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/container.zip.meta_lic ", "testdata-reciprocal-bin-bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/bin/bin2.meta_lic"},
				packageName{"testdata/reciprocal/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/reciprocal/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/container.zip.meta_lic ", "testdata-reciprocal-bin-bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/liba.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/container.zip.meta_lic ", "testdata/reciprocal/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/libb.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/container.zip.meta_lic ", "testdata/reciprocal/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/reciprocal/bin/bin1.meta_lic ", "testdata/reciprocal/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/libc.a.meta_lic"},
				packageName{"testdata/reciprocal/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/bin/bin1.meta_lic ", "testdata/reciprocal/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/reciprocal/lib/libb.so.meta_lic ", "testdata/reciprocal/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/reciprocal/lib/libd.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/lib/libd.so.meta_lic ", "testdata/reciprocal/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxExtractedText{"$$$Reciprocal License$$$"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
			},
		},
		{
			condition: "reciprocal",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/reciprocal/application.meta_lic"},
				packageName{"testdata/reciprocal/application.meta_lic"},
				spdxPkgID{"testdata/reciprocal/application.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/reciprocal/application.meta_lic", "DESCRIBES"},
				packageTag{"testdata/reciprocal/bin/bin3.meta_lic"},
				packageName{"testdata/reciprocal/bin/bin3.meta_lic"},
				spdxPkgID{"testdata/reciprocal/bin/bin3.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata-reciprocal-bin-bin3.meta_lic ", "testdata/reciprocal/application.meta_lic", "BUILD_TOOL_OF"},
				packageTag{"testdata/reciprocal/lib/liba.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/application.meta_lic ", "testdata/reciprocal/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/libb.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/lib/libb.so.meta_lic ", "testdata/reciprocal/application.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxExtractedText{"$$$Reciprocal License$$$"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
			},
		},
		{
			condition: "reciprocal",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/reciprocal/bin/bin1.meta_lic"},
				packageName{"testdata/reciprocal/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/reciprocal/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/reciprocal/bin/bin1.meta_lic", "DESCRIBES"},
				packageTag{"testdata/reciprocal/lib/liba.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/bin/bin1.meta_lic ", "testdata/reciprocal/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/reciprocal/lib/libc.a.meta_lic"},
				packageName{"testdata/reciprocal/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/reciprocal/bin/bin1.meta_lic ", "testdata/reciprocal/lib/libc.a.meta_lic", "CONTAINS"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxExtractedText{"$$$Reciprocal License$$$"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
			},
		},
		{
			condition: "reciprocal",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/reciprocal/lib/libd.so.meta_lic"},
				packageName{"testdata/reciprocal/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/reciprocal/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/reciprocal/lib/libd.so.meta_lic", "DESCRIBES"},
				spdxLicense{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/notice/NOTICE_LICENSE",
			},
		},
		{
			condition:   "restricted",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/apex/",
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/restricted/highest.apex.meta_lic"},
				packageName{"testdata/restricted/highest.apex.meta_lic"},
				spdxPkgID{"testdata/restricted/highest.apex.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/restricted/highest.apex.meta_lic", "DESCRIBES"},
				packageTag{"testdata/restricted/bin/bin1.meta_lic"},
				packageName{"testdata/restricted/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/restricted/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/highest.apex.meta_lic ", "testdata/restricted/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/bin/bin2.meta_lic"},
				packageName{"testdata/restricted/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/restricted/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/highest.apex.meta_lic ", "testdata/restricted/bin/bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/lib/liba.so.meta_lic"},
				packageName{"testdata/restricted/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/highest.apex.meta_lic ", "testdata/restricted/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/lib/libb.so.meta_lic"},
				packageName{"testdata/restricted/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/highest.apex.meta_lic ", "testdata/restricted/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/restricted/bin/bin1.meta_lic ", "testdata/restricted/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/lib/libc.a.meta_lic"},
				packageName{"testdata/restricted/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/bin/bin1.meta_lic ", "testdata/restricted/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/restricted/lib/libb.so.meta_lic ", "testdata/restricted/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/restricted/lib/libd.so.meta_lic"},
				packageName{"testdata/restricted/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/lib/libd.so.meta_lic ", "testdata/restricted/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxExtractedText{"$$$Reciprocal License$$$"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxExtractedText{"###Restricted License###"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition:   "restricted",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/apex/",
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/restricted/container.zip.meta_lic"},
				packageName{"testdata/restricted/container.zip.meta_lic"},
				spdxPkgID{"testdata/restricted/container.zip.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/restricted/container.zip.meta_lic", "DESCRIBES"},
				packageTag{"testdata/restricted/bin/bin1.meta_lic"},
				packageName{"testdata/restricted/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/restricted/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/container.zip.meta_lic ", "testdata/restricted/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/bin/bin2.meta_lic"},
				packageName{"testdata/restricted/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/restricted/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/container.zip.meta_lic ", "testdata/restricted/bin/bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/lib/liba.so.meta_lic"},
				packageName{"testdata/restricted/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/container.zip.meta_lic ", "testdata/restricted/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/lib/libb.so.meta_lic"},
				packageName{"testdata/restricted/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/container.zip.meta_lic ", "testdata/restricted/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/restricted/bin/bin1.meta_lic ", "testdata/restricted/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/lib/libc.a.meta_lic"},
				packageName{"testdata/restricted/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/bin/bin1.meta_lic ", "testdata/restricted/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/restricted/lib/libb.so.meta_lic ", "testdata/restricted/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/restricted/lib/libd.so.meta_lic"},
				packageName{"testdata/restricted/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/lib/libd.so.meta_lic ", "testdata/restricted/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxExtractedText{"$$$Reciprocal License$$$"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxExtractedText{"###Restricted License###"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "restricted",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/restricted/bin/bin1.meta_lic"},
				packageName{"testdata/restricted/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/restricted/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/restricted/bin/bin1.meta_lic", "DESCRIBES"},
				packageTag{"testdata/restricted/lib/liba.so.meta_lic"},
				packageName{"testdata/restricted/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/bin/bin1.meta_lic ", "testdata/restricted/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/restricted/lib/libc.a.meta_lic"},
				packageName{"testdata/restricted/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxRelationship{"Package-testdata/restricted/bin/bin1.meta_lic ", "testdata/restricted/lib/libc.a.meta_lic", "CONTAINS"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-reciprocal-RECIPROCAL_LICENSE"},
				spdxExtractedText{"$$$Reciprocal License$$$"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxExtractedText{"###Restricted License###"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "restricted",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/restricted/lib/libd.so.meta_lic"},
				packageName{"testdata/restricted/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/restricted/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/restricted/lib/libd.so.meta_lic", "DESCRIBES"},
				spdxLicense{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/notice/NOTICE_LICENSE"},
		},
		{
			condition: "proprietary",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/proprietary/highest.apex.meta_lic"},
				packageName{"testdata/proprietary/highest.apex.meta_lic"},
				spdxPkgID{"testdata/proprietary/highest.apex.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/proprietary/highest.apex.meta_lic", "DESCRIBES"},
				packageTag{"testdata/proprietary/bin/bin1.meta_lic"},
				packageName{"testdata/proprietary/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/proprietary/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/highest.apex.meta_lic ", "testdata/proprietary/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/bin/bin2.meta_lic"},
				packageName{"testdata/proprietary/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/proprietary/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/highest.apex.meta_lic ", "testdata/proprietary/bin/bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/liba.so.meta_lic"},
				packageName{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/highest.apex.meta_lic ", "testdata/proprietary/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/libb.so.meta_lic"},
				packageName{"testdata/proprietary/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/highest.apex.meta_lic ", "testdata/proprietary/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/proprietary/bin/bin1.meta_lic ", "testdata/proprietary/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/libc.a.meta_lic"},
				packageName{"testdata/proprietary/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/bin/bin1.meta_lic ", "testdata/proprietary/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata-proprietary-lib-libb.so.meta_lic ", "testdata/proprietary/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/proprietary/lib/libd.so.meta_lic"},
				packageName{"testdata/proprietary/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata-proprietary-lib-libd.so.meta_lic ", "testdata/proprietary/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxExtractedText{"@@@Proprietary License@@@"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxExtractedText{"###Restricted License###"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "proprietary",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/proprietary/container.zip.meta_lic"},
				packageName{"testdata/proprietary/container.zip.meta_lic"},
				spdxPkgID{"testdata/proprietary/container.zip.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/proprietary/container.zip.meta_lic", "DESCRIBES"},
				packageTag{"testdata/proprietary/bin/bin1.meta_lic"},
				packageName{"testdata/proprietary/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/proprietary/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/container.zip.meta_lic ", "testdata/proprietary/bin/bin1.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/bin/bin2.meta_lic"},
				packageName{"testdata/proprietary/bin/bin2.meta_lic"},
				spdxPkgID{"testdata/proprietary/bin/bin2.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/container.zip.meta_lic ", "testdata/proprietary/bin/bin2.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/liba.so.meta_lic"},
				packageName{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/container.zip.meta_lic ", "testdata/proprietary/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/libb.so.meta_lic"},
				packageName{"testdata/proprietary/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/container.zip.meta_lic ", "testdata/proprietary/lib/libb.so.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata/proprietary/bin/bin1.meta_lic ", "testdata/proprietary/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/libc.a.meta_lic"},
				packageName{"testdata/proprietary/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/bin/bin1.meta_lic ", "testdata/proprietary/lib/libc.a.meta_lic", "CONTAINS"},
				spdxRelationship{"Package-testdata-proprietary-lib-libb.so.meta_lic ", "testdata/proprietary/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				packageTag{"testdata/proprietary/lib/libd.so.meta_lic"},
				packageName{"testdata/proprietary/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"Package-testdata-proprietary-lib-libd.so.meta_lic ", "testdata/proprietary/bin/bin2.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxExtractedText{"@@@Proprietary License@@@"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxExtractedText{"###Restricted License###"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "proprietary",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/proprietary/application.meta_lic"},
				packageName{"testdata/proprietary/application.meta_lic"},
				spdxPkgID{"testdata/proprietary/application.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/proprietary/application.meta_lic", "DESCRIBES"},
				packageTag{"testdata/proprietary/bin/bin3.meta_lic"},
				packageName{"testdata/proprietary/bin/bin3.meta_lic"},
				spdxPkgID{"testdata/proprietary/bin/bin3.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/bin/bin3.meta_lic ", "testdata/proprietary/application.meta_lic", "BUILD_TOOL_OF"},
				packageTag{"testdata/proprietary/lib/liba.so.meta_lic"},
				packageName{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/application.meta_lic ", "testdata/proprietary/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/libb.so.meta_lic"},
				packageName{"testdata/proprietary/lib/libb.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libb.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/lib/libb.so.meta_lic ", "testdata/proprietary/application.meta_lic", "RUNTIME_DEPENDENCY_OF"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxExtractedText{"@@@Proprietary License@@@"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-restricted-RESTRICTED_LICENSE"},
				spdxExtractedText{"###Restricted License###"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "proprietary",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/proprietary/bin/bin1.meta_lic"},
				packageName{"testdata/proprietary/bin/bin1.meta_lic"},
				spdxPkgID{"testdata/proprietary/bin/bin1.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/proprietary/bin/bin1.meta_lic", "DESCRIBES"},
				packageTag{"testdata/proprietary/lib/liba.so.meta_lic"},
				packageName{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/liba.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/bin/bin1.meta_lic ", "testdata/proprietary/lib/liba.so.meta_lic", "CONTAINS"},
				packageTag{"testdata/proprietary/lib/libc.a.meta_lic"},
				packageName{"testdata/proprietary/lib/libc.a.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libc.a.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxRelationship{"Package-testdata/proprietary/bin/bin1.meta_lic ", "testdata/proprietary/lib/libc.a.meta_lic", "CONTAINS"},
				spdxLicense{},
				spdxLicenseID{"testdata-firstparty-FIRST_PARTY_LICENSE"},
				spdxExtractedText{"&&&First Party License&&&"},
				spdxExtractedClosingText{},
				spdxLicenseID{"testdata-proprietary-PROPRIETARY_LICENSE"},
				spdxExtractedText{"@@@Proprietary License@@@"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
			},
		},
		{
			condition: "proprietary",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: []matcher{
				spdxVersion{},
				spdxDataLicense{},
				spdxDocumentName{"Android"},
				spdxID{"Android"},
				spdxDocumentNameSpace{},
				spdxCreatorOrganization{},
				spdxCreatedTime{},
				packageTag{"testdata/proprietary/lib/libd.so.meta_lic"},
				packageName{"testdata/proprietary/lib/libd.so.meta_lic"},
				spdxPkgID{"testdata/proprietary/lib/libd.so.meta_lic"},
				spdxPkgDownloadLocation{"NOASSERTION"},
				spdxPkgLicenseDeclared{"testdata-notice-NOTICE_LICENSE"},
				spdxRelationship{"DOCUMENT-Android ", "testdata/proprietary/lib/libd.so.meta_lic", "DESCRIBES"},
				spdxLicense{},
				spdxLicenseID{"testdata-notice-NOTICE_LICENSE"},
				spdxExtractedText{"%%%Notice License%%%"},
				spdxExtractedClosingText{},
			},
			expectedDeps: []string{"testdata/notice/NOTICE_LICENSE"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.condition+" "+tt.name, func(t *testing.T) {
			stdout := &bytes.Buffer{}
			stderr := &bytes.Buffer{}

			rootFiles := make([]string, 0, len(tt.roots))
			for _, r := range tt.roots {
				rootFiles = append(rootFiles, "testdata/"+tt.condition+"/"+r)
			}

			ctx := context{stdout, stderr, compliance.GetFS(tt.outDir), "Android", []string{tt.stripPrefix}, fakeTime}

			deps, err := sbomGenerator(&ctx, rootFiles...)
			if err != nil {
				t.Fatalf("sbom: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("sbom: gotStderr = %v, want none", stderr)
			}

			t.Logf("got stdout: %s", stdout.String())

			t.Logf("want stdout: %s", matcherList(tt.expectedOut).String())

			out := bufio.NewScanner(stdout)
			lineno := 0
			for out.Scan() {
				line := out.Text()
				if strings.TrimLeft(line, " ") == "" {
					continue
				}
				if len(tt.expectedOut) <= lineno {
					t.Errorf("sbom: unexpected output at line %d: got %q, want nothing (wanted %d lines)", lineno+1, line, len(tt.expectedOut))
				} else if !tt.expectedOut[lineno].isMatch(line) {
					t.Errorf("sbom: unexpected output at line %d: got %q, want %q", lineno+1, line, tt.expectedOut[lineno])
				}
				lineno++
			}
			for ; lineno < len(tt.expectedOut); lineno++ {
				t.Errorf("bom: missing output line %d: ended early, want %q", lineno+1, tt.expectedOut[lineno])
			}

			t.Logf("got deps: %q", deps)

			t.Logf("want deps: %q", tt.expectedDeps)

			if g, w := deps, tt.expectedDeps; !reflect.DeepEqual(g, w) {
				t.Errorf("unexpected deps, wanted:\n%s\ngot:\n%s\n",
					strings.Join(w, "\n"), strings.Join(g, "\n"))
			}
		})
	}
}

type matcher interface {
	isMatch(line string) bool
	String() string
}

type packageTag struct {
	name string
}

func (m packageTag) isMatch(line string) bool {
	groups := spdxPackageTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == m.name
}

func (m packageTag) String() string {
	return "##### Package: " + m.name
}

type packageName struct {
	name string
}

func (m packageName) isMatch(line string) bool {
	groups := spdxPackageNameTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == replaceSlashes(m.name)
}

func (m packageName) String() string {
	return "PackageName: " + replaceSlashes(m.name)
}

type spdxID struct {
	name string
}

func (m spdxID) isMatch(line string) bool {
	groups := spdxIDTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == replaceSlashes(m.name)
}

func (m spdxID) String() string {
	return "SPDXID: SPDXRef-DOCUMENT-" + replaceSlashes(m.name)
}

type spdxPkgID struct {
	name string
}

func (m spdxPkgID) isMatch(line string) bool {
	groups := spdxPkgIDTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == replaceSlashes(m.name)
}

func (m spdxPkgID) String() string {
	return "SPDXID: SPDXRef-Package-" + replaceSlashes(m.name)
}

type spdxVersion struct{}

func (m spdxVersion) isMatch(line string) bool {
	return spdxVersionTag.MatchString(line)
}

func (m spdxVersion) String() string {
	return "SPDXVersion: SPDX-2.2"
}

type spdxDataLicense struct{}

func (m spdxDataLicense) isMatch(line string) bool {
	return spdxDataLicenseTag.MatchString(line)
}

func (m spdxDataLicense) String() string {
	return "DataLicense: CC-1.0"
}

type spdxDocumentName struct {
	name string
}

func (m spdxDocumentName) isMatch(line string) bool {
	return spdxDocumentNameTag.MatchString(line)
}

func (m spdxDocumentName) String() string {
	return "DocumentName: " + m.name
}

type spdxDocumentNameSpace struct {
	name string
}

func (m spdxDocumentNameSpace) isMatch(line string) bool {
	return spdxDocumentNameSpaceTag.MatchString(line)
}

func (m spdxDocumentNameSpace) String() string {
	return "DocumentNameSpace: Android"
}

type spdxCreatorOrganization struct{}

func (m spdxCreatorOrganization) isMatch(line string) bool {
	return spdxCreatorOrganizationTag.MatchString(line)
}

func (m spdxCreatorOrganization) String() string {
	return "Creator: Organization: Google LLC"
}

func fakeTime() time.Time {
	return time.UnixMicro(0).UTC()
}

type spdxCreatedTime struct{}

func (m spdxCreatedTime) isMatch(line string) bool {
	return spdxCreatedTimeTag.MatchString(line)
}

func (m spdxCreatedTime) String() string {
	return "Created: 1970-01-01T00:00:00Z"
}

type spdxPkgDownloadLocation struct {
	name string
}

func (m spdxPkgDownloadLocation) isMatch(line string) bool {
	return spdxPkgDownloadLocationTag.MatchString(line)
}

func (m spdxPkgDownloadLocation) String() string {
	return "PackageDownloadLocation: " + m.name
}

type spdxPkgLicenseDeclared struct {
	name string
}

func (m spdxPkgLicenseDeclared) isMatch(line string) bool {
	groups := spdxPkgLicenseDeclaredTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == replaceSlashes(m.name)
}

func (m spdxPkgLicenseDeclared) String() string {
	return "PackageLicenseConcluded: LicenseRef-" + m.name
}

type spdxRelationship struct {
	pkg1     string
	pkg2     string
	relation string
}

func (m spdxRelationship) isMatch(line string) bool {
	groups := spdxRelationshipTag.FindStringSubmatch(line)
	if len(groups) != 4 {
		return false
	}
	return groups[1] == replaceSlashes(m.pkg1) && groups[2] == m.relation && groups[3] == replaceSlashes(m.pkg2)
}

func (m spdxRelationship) String() string {
	return "Relationship: SPDXRef-" + replaceSlashes(m.pkg1) + " " + m.relation + " SPDXRef-Package-" + replaceSlashes(m.pkg2)
}

type spdxLicense struct{}

func (m spdxLicense) isMatch(line string) bool {
	return spdxLicenseTag.MatchString(line)
}

func (m spdxLicense) String() string {
	return "##### Non-standard license:"
}

type spdxLicenseID struct {
	name string
}

func (m spdxLicenseID) isMatch(line string) bool {
	groups := spdxLicenseIDTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == replaceSlashes(m.name)
}

func (m spdxLicenseID) String() string {
	return "LicenseID: LicenseRef-" + m.name
}

type spdxExtractedText struct {
	name string
}

func (m spdxExtractedText) isMatch(line string) bool {
	groups := spdxExtractedTextTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == replaceSlashes(m.name)
}

func (m spdxExtractedText) String() string {
	return "ExtractedText: <text>" + m.name
}

type spdxExtractedClosingText struct{}

func (m spdxExtractedClosingText) isMatch(line string) bool {
	return spdxExtractedClosingTextTag.MatchString(line)
}

func (m spdxExtractedClosingText) String() string {
	return "</text>"
}

type matcherList []matcher

func (l matcherList) String() string {
	var sb strings.Builder
	for _, m := range l {
		s := m.String()
		fmt.Fprintf(&sb, "%s\n", s)
	}
	return sb.String()
}
