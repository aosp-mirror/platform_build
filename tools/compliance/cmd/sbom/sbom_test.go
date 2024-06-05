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
	"encoding/json"
	"fmt"
	"os"
	"reflect"
	"strings"
	"testing"
	"time"

	"android/soong/tools/compliance"

	"github.com/spdx/tools-golang/builder/builder2v2"
	"github.com/spdx/tools-golang/spdx/common"
	spdx "github.com/spdx/tools-golang/spdx/v2_2"
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
		expectedOut  *spdx.Document
		expectedDeps []string
	}{
		{
			condition: "firstparty",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-firstparty-highest.apex",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/firstparty/highest.apex.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-firstparty-highest.apex.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-highest.apex.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-highest.apex.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/firstparty/bin/bin1.meta_lic",
				"testdata/firstparty/bin/bin2.meta_lic",
				"testdata/firstparty/highest.apex.meta_lic",
				"testdata/firstparty/lib/liba.so.meta_lic",
				"testdata/firstparty/lib/libb.so.meta_lic",
				"testdata/firstparty/lib/libc.a.meta_lic",
				"testdata/firstparty/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "firstparty",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-firstparty-application",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/firstparty/application.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-firstparty-application.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-application.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-bin-bin3.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-bin-bin3.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-application.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-bin-bin3.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-application.meta_lic"),
						Relationship: "BUILD_TOOL_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-application.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-application.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/firstparty/application.meta_lic",
				"testdata/firstparty/bin/bin3.meta_lic",
				"testdata/firstparty/lib/liba.so.meta_lic",
				"testdata/firstparty/lib/libb.so.meta_lic",
			},
		},
		{
			condition: "firstparty",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-firstparty-container.zip",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/firstparty/container.zip.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-firstparty-container.zip.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-container.zip.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-container.zip.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/firstparty/bin/bin1.meta_lic",
				"testdata/firstparty/bin/bin2.meta_lic",
				"testdata/firstparty/container.zip.meta_lic",
				"testdata/firstparty/lib/liba.so.meta_lic",
				"testdata/firstparty/lib/libb.so.meta_lic",
				"testdata/firstparty/lib/libc.a.meta_lic",
				"testdata/firstparty/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "firstparty",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-firstparty-bin-bin1",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/firstparty/bin/bin1.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-firstparty-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-firstparty-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-firstparty-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/firstparty/bin/bin1.meta_lic",
				"testdata/firstparty/lib/liba.so.meta_lic",
				"testdata/firstparty/lib/libc.a.meta_lic",
			},
		},
		{
			condition: "firstparty",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-firstparty-lib-libd.so",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/firstparty/lib/libd.so.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-firstparty-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-firstparty-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-firstparty-lib-libd.so.meta_lic"),
						Relationship: "DESCRIBES",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/firstparty/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "notice",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-notice-highest.apex",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/notice/highest.apex.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-notice-highest.apex.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-highest.apex.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-notice-highest.apex.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/notice/bin/bin1.meta_lic",
				"testdata/notice/bin/bin2.meta_lic",
				"testdata/notice/highest.apex.meta_lic",
				"testdata/notice/lib/liba.so.meta_lic",
				"testdata/notice/lib/libb.so.meta_lic",
				"testdata/notice/lib/libc.a.meta_lic",
				"testdata/notice/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "notice",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-notice-container.zip",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/notice/container.zip.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-notice-container.zip.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-container.zip.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-notice-container.zip.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/notice/bin/bin1.meta_lic",
				"testdata/notice/bin/bin2.meta_lic",
				"testdata/notice/container.zip.meta_lic",
				"testdata/notice/lib/liba.so.meta_lic",
				"testdata/notice/lib/libb.so.meta_lic",
				"testdata/notice/lib/libc.a.meta_lic",
				"testdata/notice/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "notice",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-notice-application",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/notice/application.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-notice-application.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-application.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-bin-bin3.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-bin-bin3.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-notice-application.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-bin-bin3.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-application.meta_lic"),
						Relationship: "BUILD_TOOL_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-application.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-application.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/notice/application.meta_lic",
				"testdata/notice/bin/bin3.meta_lic",
				"testdata/notice/lib/liba.so.meta_lic",
				"testdata/notice/lib/libb.so.meta_lic",
			},
		},
		{
			condition: "notice",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-notice-bin-bin1",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/notice/bin/bin1.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-notice-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-notice-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-notice-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/notice/bin/bin1.meta_lic",
				"testdata/notice/lib/liba.so.meta_lic",
				"testdata/notice/lib/libc.a.meta_lic",
			},
		},
		{
			condition: "notice",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-notice-lib-libd.so",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/notice/lib/libd.so.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-notice-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-notice-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-notice-lib-libd.so.meta_lic"),
						Relationship: "DESCRIBES",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/notice/NOTICE_LICENSE",
				"testdata/notice/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "reciprocal",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-reciprocal-highest.apex",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/reciprocal/highest.apex.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-reciprocal-highest.apex.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-highest.apex.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-highest.apex.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
						ExtractedText:     "$$$Reciprocal License$$$\n",
						LicenseName:       "testdata-reciprocal-RECIPROCAL_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/reciprocal/bin/bin1.meta_lic",
				"testdata/reciprocal/bin/bin2.meta_lic",
				"testdata/reciprocal/highest.apex.meta_lic",
				"testdata/reciprocal/lib/liba.so.meta_lic",
				"testdata/reciprocal/lib/libb.so.meta_lic",
				"testdata/reciprocal/lib/libc.a.meta_lic",
				"testdata/reciprocal/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "reciprocal",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-reciprocal-application",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/reciprocal/application.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-reciprocal-application.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-application.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-bin-bin3.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-bin-bin3.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-application.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin3.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-application.meta_lic"),
						Relationship: "BUILD_TOOL_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-application.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-application.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
						ExtractedText:     "$$$Reciprocal License$$$\n",
						LicenseName:       "testdata-reciprocal-RECIPROCAL_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/reciprocal/application.meta_lic",
				"testdata/reciprocal/bin/bin3.meta_lic",
				"testdata/reciprocal/lib/liba.so.meta_lic",
				"testdata/reciprocal/lib/libb.so.meta_lic",
			},
		},
		{
			condition: "reciprocal",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-reciprocal-bin-bin1",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/reciprocal/bin/bin1.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-reciprocal-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						PackageName:             "testdata-reciprocal-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin1.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-reciprocal-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
						ExtractedText:     "$$$Reciprocal License$$$\n",
						LicenseName:       "testdata-reciprocal-RECIPROCAL_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/reciprocal/bin/bin1.meta_lic",
				"testdata/reciprocal/lib/liba.so.meta_lic",
				"testdata/reciprocal/lib/libc.a.meta_lic",
			},
		},
		{
			condition: "reciprocal",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-reciprocal-lib-libd.so",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/reciprocal/lib/libd.so.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-reciprocal-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-reciprocal-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-reciprocal-lib-libd.so.meta_lic"),
						Relationship: "DESCRIBES",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "restricted",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-restricted-highest.apex",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/restricted/highest.apex.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-restricted-highest.apex.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-highest.apex.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-highest.apex.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
						ExtractedText:     "$$$Reciprocal License$$$\n",
						LicenseName:       "testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
						ExtractedText:     "###Restricted License###\n",
						LicenseName:       "testdata-restricted-RESTRICTED_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
				"testdata/restricted/bin/bin1.meta_lic",
				"testdata/restricted/bin/bin2.meta_lic",
				"testdata/restricted/highest.apex.meta_lic",
				"testdata/restricted/lib/liba.so.meta_lic",
				"testdata/restricted/lib/libb.so.meta_lic",
				"testdata/restricted/lib/libc.a.meta_lic",
				"testdata/restricted/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "restricted",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-restricted-container.zip",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/restricted/container.zip.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-restricted-container.zip.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-container.zip.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-container.zip.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
						ExtractedText:     "$$$Reciprocal License$$$\n",
						LicenseName:       "testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
						ExtractedText:     "###Restricted License###\n",
						LicenseName:       "testdata-restricted-RESTRICTED_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
				"testdata/restricted/bin/bin1.meta_lic",
				"testdata/restricted/bin/bin2.meta_lic",
				"testdata/restricted/container.zip.meta_lic",
				"testdata/restricted/lib/liba.so.meta_lic",
				"testdata/restricted/lib/libb.so.meta_lic",
				"testdata/restricted/lib/libc.a.meta_lic",
				"testdata/restricted/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "restricted",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-restricted-bin-bin1",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/restricted/bin/bin1.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-restricted-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-restricted-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-restricted-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-reciprocal-RECIPROCAL_LICENSE",
						ExtractedText:     "$$$Reciprocal License$$$\n",
						LicenseName:       "testdata-reciprocal-RECIPROCAL_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
						ExtractedText:     "###Restricted License###\n",
						LicenseName:       "testdata-restricted-RESTRICTED_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
				"testdata/restricted/bin/bin1.meta_lic",
				"testdata/restricted/lib/liba.so.meta_lic",
				"testdata/restricted/lib/libc.a.meta_lic",
			},
		},
		{
			condition: "restricted",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-restricted-lib-libd.so",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/restricted/lib/libd.so.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-restricted-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-restricted-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-restricted-lib-libd.so.meta_lic"),
						Relationship: "DESCRIBES",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/notice/NOTICE_LICENSE",
				"testdata/restricted/lib/libd.so.meta_lic",
			},
		},
		{
			condition: "proprietary",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-proprietary-highest.apex",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/proprietary/highest.apex.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-proprietary-highest.apex.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-highest.apex.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-highest.apex.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-highest.apex.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
						ExtractedText:     "@@@Proprietary License@@@\n",
						LicenseName:       "testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
						ExtractedText:     "###Restricted License###\n",
						LicenseName:       "testdata-restricted-RESTRICTED_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/proprietary/bin/bin1.meta_lic",
				"testdata/proprietary/bin/bin2.meta_lic",
				"testdata/proprietary/highest.apex.meta_lic",
				"testdata/proprietary/lib/liba.so.meta_lic",
				"testdata/proprietary/lib/libb.so.meta_lic",
				"testdata/proprietary/lib/libc.a.meta_lic",
				"testdata/proprietary/lib/libd.so.meta_lic",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "proprietary",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-proprietary-container.zip",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/proprietary/container.zip.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-proprietary-container.zip.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-container.zip.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-bin-bin2.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-bin-bin2.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-container.zip.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin2.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-container.zip.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-libb.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-lib-libd.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin2.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
						ExtractedText:     "@@@Proprietary License@@@\n",
						LicenseName:       "testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
						ExtractedText:     "###Restricted License###\n",
						LicenseName:       "testdata-restricted-RESTRICTED_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/notice/NOTICE_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/proprietary/bin/bin1.meta_lic",
				"testdata/proprietary/bin/bin2.meta_lic",
				"testdata/proprietary/container.zip.meta_lic",
				"testdata/proprietary/lib/liba.so.meta_lic",
				"testdata/proprietary/lib/libb.so.meta_lic",
				"testdata/proprietary/lib/libc.a.meta_lic",
				"testdata/proprietary/lib/libd.so.meta_lic",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "proprietary",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-proprietary-application",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/proprietary/application.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-proprietary-application.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-application.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-bin-bin3.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-bin-bin3.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libb.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libb.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-application.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-bin-bin3.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-application.meta_lic"),
						Relationship: "BUILD_TOOL_OF",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-application.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-lib-libb.so.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-application.meta_lic"),
						Relationship: "RUNTIME_DEPENDENCY_OF",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
						ExtractedText:     "@@@Proprietary License@@@\n",
						LicenseName:       "testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-restricted-RESTRICTED_LICENSE",
						ExtractedText:     "###Restricted License###\n",
						LicenseName:       "testdata-restricted-RESTRICTED_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/proprietary/application.meta_lic",
				"testdata/proprietary/bin/bin3.meta_lic",
				"testdata/proprietary/lib/liba.so.meta_lic",
				"testdata/proprietary/lib/libb.so.meta_lic",
				"testdata/restricted/RESTRICTED_LICENSE",
			},
		},
		{
			condition: "proprietary",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-proprietary-bin-bin1",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/proprietary/bin/bin1.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-proprietary-bin-bin1.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-bin-bin1.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-liba.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-liba.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
					{
						PackageName:             "testdata-proprietary-lib-libc.a.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libc.a.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						Relationship: "DESCRIBES",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-liba.so.meta_lic"),
						Relationship: "CONTAINS",
					},
					{
						RefA:         common.MakeDocElementID("", "testdata-proprietary-bin-bin1.meta_lic"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-libc.a.meta_lic"),
						Relationship: "CONTAINS",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-firstparty-FIRST_PARTY_LICENSE",
						ExtractedText:     "&&&First Party License&&&\n",
						LicenseName:       "testdata-firstparty-FIRST_PARTY_LICENSE",
					},
					{
						LicenseIdentifier: "LicenseRef-testdata-proprietary-PROPRIETARY_LICENSE",
						ExtractedText:     "@@@Proprietary License@@@\n",
						LicenseName:       "testdata-proprietary-PROPRIETARY_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/proprietary/bin/bin1.meta_lic",
				"testdata/proprietary/lib/liba.so.meta_lic",
				"testdata/proprietary/lib/libc.a.meta_lic",
			},
		},
		{
			condition: "proprietary",
			name:      "library",
			roots:     []string{"lib/libd.so.meta_lic"},
			expectedOut: &spdx.Document{
				SPDXVersion:       "SPDX-2.2",
				DataLicense:       "CC0-1.0",
				SPDXIdentifier:    "DOCUMENT",
				DocumentName:      "testdata-proprietary-lib-libd.so",
				DocumentNamespace: generateSPDXNamespace("", "1970-01-01T00:00:00Z", "testdata/proprietary/lib/libd.so.meta_lic"),
				CreationInfo:      getCreationInfo(t),
				Packages: []*spdx.Package{
					{
						PackageName:             "testdata-proprietary-lib-libd.so.meta_lic",
						PackageVersion:          "NOASSERTION",
						PackageDownloadLocation: "NOASSERTION",
						PackageSPDXIdentifier:   common.ElementID("testdata-proprietary-lib-libd.so.meta_lic"),
						PackageLicenseConcluded: "LicenseRef-testdata-notice-NOTICE_LICENSE",
					},
				},
				Relationships: []*spdx.Relationship{
					{
						RefA:         common.MakeDocElementID("", "DOCUMENT"),
						RefB:         common.MakeDocElementID("", "testdata-proprietary-lib-libd.so.meta_lic"),
						Relationship: "DESCRIBES",
					},
				},
				OtherLicenses: []*spdx.OtherLicense{
					{
						LicenseIdentifier: "LicenseRef-testdata-notice-NOTICE_LICENSE",
						ExtractedText:     "%%%Notice License%%%\n",
						LicenseName:       "testdata-notice-NOTICE_LICENSE",
					},
				},
			},
			expectedDeps: []string{
				"testdata/notice/NOTICE_LICENSE",
				"testdata/proprietary/lib/libd.so.meta_lic",
			},
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

			ctx := context{stdout, stderr, compliance.GetFS(tt.outDir), "", []string{tt.stripPrefix}, fakeTime, ""}

			spdxDoc, deps, err := sbomGenerator(&ctx, rootFiles...)
			if err != nil {
				t.Fatalf("sbom: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("sbom: gotStderr = %v, want none", stderr)
			}

			if err := validate(spdxDoc); err != nil {
				t.Fatalf("sbom: document fails to validate: %v", err)
			}

			gotData, err := json.Marshal(spdxDoc)
			if err != nil {
				t.Fatalf("sbom: failed to marshal spdx doc: %v", err)
				return
			}

			t.Logf("Got SPDX Doc: %s", string(gotData))

			expectedData, err := json.Marshal(tt.expectedOut)
			if err != nil {
				t.Fatalf("sbom: failed to marshal spdx doc: %v", err)
				return
			}

			t.Logf("Want SPDX Doc: %s", string(expectedData))

			// compare the spdx Docs
			compareSpdxDocs(t, spdxDoc, tt.expectedOut)

			// compare deps
			t.Logf("got deps: %q", deps)

			t.Logf("want deps: %q", tt.expectedDeps)

			if g, w := deps, tt.expectedDeps; !reflect.DeepEqual(g, w) {
				t.Errorf("unexpected deps, wanted:\n%s\ngot:\n%s\n",
					strings.Join(w, "\n"), strings.Join(g, "\n"))
			}
		})
	}
}

func TestGenerateSPDXNamespace(t *testing.T) {

	buildID1 := "example-1"
	buildID2 := "example-2"
	files1 := "file1"
	timestamp1 := "2022-05-01"
	timestamp2 := "2022-05-02"
	files2 := "file2"

	// Test case 1: different timestamps, same files
	nsh1 := generateSPDXNamespace("", timestamp1, files1)
	nsh2 := generateSPDXNamespace("", timestamp2, files1)

	if nsh1 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", "", timestamp1, files1)
	}

	if nsh2 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", "", timestamp2, files1)
	}

	if nsh1 == nsh2 {
		t.Errorf("generateSPDXNamespace(%s, %s, %s) and generateSPDXNamespace(%s, %s, %s): expected different namespace hashes, but got the same", "", timestamp1, files1, "", timestamp2, files1)
	}

	// Test case 2: different build ids, same timestamps and files
	nsh1 = generateSPDXNamespace(buildID1, timestamp1, files1)
	nsh2 = generateSPDXNamespace(buildID2, timestamp1, files1)

	if nsh1 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", buildID1, timestamp1, files1)
	}

	if nsh2 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", buildID2, timestamp1, files1)
	}

	if nsh1 == nsh2 {
		t.Errorf("generateSPDXNamespace(%s, %s, %s) and generateSPDXNamespace(%s, %s, %s): expected different namespace hashes, but got the same", buildID1, timestamp1, files1, buildID2, timestamp1, files1)
	}

	// Test case 3: same build ids and files, different timestamps
	nsh1 = generateSPDXNamespace(buildID1, timestamp1, files1)
	nsh2 = generateSPDXNamespace(buildID1, timestamp2, files1)

	if nsh1 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", buildID1, timestamp1, files1)
	}

	if nsh2 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", buildID1, timestamp2, files1)
	}

	if nsh1 != nsh2 {
		t.Errorf("generateSPDXNamespace(%s, %s, %s) and generateSPDXNamespace(%s, %s, %s): expected same namespace hashes, but got different: %s and %s", buildID1, timestamp1, files1, buildID2, timestamp1, files1, nsh1, nsh2)
	}

	// Test case 4: same build ids and timestamps, different files
	nsh1 = generateSPDXNamespace(buildID1, timestamp1, files1)
	nsh2 = generateSPDXNamespace(buildID1, timestamp1, files2)

	if nsh1 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", buildID1, timestamp1, files1)
	}

	if nsh2 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", buildID1, timestamp1, files2)
	}

	if nsh1 == nsh2 {
		t.Errorf("generateSPDXNamespace(%s, %s, %s) and generateSPDXNamespace(%s, %s, %s): expected different namespace hashes, but got the same", buildID1, timestamp1, files1, buildID1, timestamp1, files2)
	}

	// Test case 5: empty build ids, same timestamps and different files
	nsh1 = generateSPDXNamespace("", timestamp1, files1)
	nsh2 = generateSPDXNamespace("", timestamp1, files2)

	if nsh1 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", "", timestamp1, files1)
	}

	if nsh2 == "" {
		t.Errorf("generateSPDXNamespace(%s, %s, %s): expected non-empty string, but got empty string", "", timestamp1, files2)
	}

	if nsh1 == nsh2 {
		t.Errorf("generateSPDXNamespace(%s, %s, %s) and generateSPDXNamespace(%s, %s, %s): expected different namespace hashes, but got the same", "", timestamp1, files1, "", timestamp1, files2)
	}
}

func getCreationInfo(t *testing.T) *spdx.CreationInfo {
	ci, err := builder2v2.BuildCreationInfoSection2_2("Organization", "Google LLC", nil)
	if err != nil {
		t.Errorf("Unable to get creation info: %v", err)
		return nil
	}
	return ci
}

// validate returns an error if the Document is found to be invalid
func validate(doc *spdx.Document) error {
	if doc.SPDXVersion == "" {
		return fmt.Errorf("SPDXVersion: got nothing, want spdx version")
	}
	if doc.DataLicense == "" {
		return fmt.Errorf("DataLicense: got nothing, want Data License")
	}
	if doc.SPDXIdentifier == "" {
		return fmt.Errorf("SPDXIdentifier: got nothing, want SPDX Identifier")
	}
	if doc.DocumentName == "" {
		return fmt.Errorf("DocumentName: got nothing, want Document Name")
	}
	if c := fmt.Sprintf("%v", doc.CreationInfo.Creators[1].Creator); c != "Google LLC" {
		return fmt.Errorf("Creator: got %v, want  'Google LLC'", c)
	}
	_, err := time.Parse(time.RFC3339, doc.CreationInfo.Created)
	if err != nil {
		return fmt.Errorf("Invalid time spec: %q: got error %q, want no error", doc.CreationInfo.Created, err)
	}

	for _, license := range doc.OtherLicenses {
		if license.ExtractedText == "" {
			return fmt.Errorf("License file: %q: got nothing, want license text", license.LicenseName)
		}
	}
	return nil
}

// compareSpdxDocs deep-compares two spdx docs by going through the info section, packages, relationships and licenses
func compareSpdxDocs(t *testing.T, actual, expected *spdx.Document) {

	if actual == nil || expected == nil {
		t.Errorf("SBOM: SPDX Doc is nil! Got %v: Expected %v", actual, expected)
	}

	if actual.DocumentName != expected.DocumentName {
		t.Errorf("sbom: unexpected SPDX Document Name got %q, want %q", actual.DocumentName, expected.DocumentName)
	}

	if actual.SPDXVersion != expected.SPDXVersion {
		t.Errorf("sbom: unexpected SPDX Version got %s, want %s", actual.SPDXVersion, expected.SPDXVersion)
	}

	if actual.DataLicense != expected.DataLicense {
		t.Errorf("sbom: unexpected SPDX DataLicense got %s, want %s", actual.DataLicense, expected.DataLicense)
	}

	if actual.SPDXIdentifier != expected.SPDXIdentifier {
		t.Errorf("sbom: unexpected SPDX Identified got %s, want %s", actual.SPDXIdentifier, expected.SPDXIdentifier)
	}

	if actual.DocumentNamespace != expected.DocumentNamespace {
		t.Errorf("sbom: unexpected SPDX Document Namespace got %s, want %s", actual.DocumentNamespace, expected.DocumentNamespace)
	}

	// compare creation info
	compareSpdxCreationInfo(t, actual.CreationInfo, expected.CreationInfo)

	// compare packages
	if len(actual.Packages) != len(expected.Packages) {
		t.Errorf("SBOM: Number of Packages is different! Got %d: Expected %d", len(actual.Packages), len(expected.Packages))
	}

	for i, pkg := range actual.Packages {
		if !compareSpdxPackages(t, i, pkg, expected.Packages[i]) {
			break
		}
	}

	// compare licenses
	if len(actual.OtherLicenses) != len(expected.OtherLicenses) {
		t.Errorf("SBOM: Number of Licenses in actual is different! Got %d: Expected %d", len(actual.OtherLicenses), len(expected.OtherLicenses))
	}
	for i, license := range actual.OtherLicenses {
		if !compareLicenses(t, i, license, expected.OtherLicenses[i]) {
			break
		}
	}

	//compare Relationships
	if len(actual.Relationships) != len(expected.Relationships) {
		t.Errorf("SBOM: Number of Licenses in actual is different! Got %d: Expected %d", len(actual.Relationships), len(expected.Relationships))
	}
	for i, rl := range actual.Relationships {
		if !compareRelationShips(t, i, rl, expected.Relationships[i]) {
			break
		}
	}
}

func compareSpdxCreationInfo(t *testing.T, actual, expected *spdx.CreationInfo) {
	if actual == nil || expected == nil {
		t.Errorf("SBOM: Creation info is nil! Got %q: Expected %q", actual, expected)
	}

	if actual.LicenseListVersion != expected.LicenseListVersion {
		t.Errorf("SBOM: Creation info license version Error! Got %s: Expected %s", actual.LicenseListVersion, expected.LicenseListVersion)
	}

	if len(actual.Creators) != len(expected.Creators) {
		t.Errorf("SBOM: Creation info creators Error! Got %d: Expected %d", len(actual.Creators), len(expected.Creators))
	}

	for i, info := range actual.Creators {
		if info != expected.Creators[i] {
			t.Errorf("SBOM: Creation info creators Error! Got %q: Expected %q", info, expected.Creators[i])
		}
	}
}

func compareSpdxPackages(t *testing.T, i int, actual, expected *spdx.Package) bool {
	if actual == nil || expected == nil {
		t.Errorf("SBOM: Packages are nil at index %d! Got %v: Expected %v", i, actual, expected)
		return false
	}
	if actual.PackageName != expected.PackageName {
		t.Errorf("SBOM: Package name Error at index %d! Got %s: Expected %s", i, actual.PackageName, expected.PackageName)
		return false
	}

	if actual.PackageVersion != expected.PackageVersion {
		t.Errorf("SBOM: Package version Error at index %d! Got %s: Expected %s", i, actual.PackageVersion, expected.PackageVersion)
		return false
	}

	if actual.PackageSPDXIdentifier != expected.PackageSPDXIdentifier {
		t.Errorf("SBOM: Package identifier Error at index %d! Got %s: Expected %s", i, actual.PackageSPDXIdentifier, expected.PackageSPDXIdentifier)
		return false
	}

	if actual.PackageDownloadLocation != expected.PackageDownloadLocation {
		t.Errorf("SBOM: Package download location Error at index %d! Got %s: Expected %s", i, actual.PackageDownloadLocation, expected.PackageDownloadLocation)
		return false
	}

	if actual.PackageLicenseConcluded != expected.PackageLicenseConcluded {
		t.Errorf("SBOM: Package license concluded Error at index %d! Got %s: Expected %s", i, actual.PackageLicenseConcluded, expected.PackageLicenseConcluded)
		return false
	}
	return true
}

func compareRelationShips(t *testing.T, i int, actual, expected *spdx.Relationship) bool {
	if actual == nil || expected == nil {
		t.Errorf("SBOM: Relationships is nil at index %d! Got %v: Expected %v", i, actual, expected)
		return false
	}

	if actual.RefA != expected.RefA {
		t.Errorf("SBOM: Relationship RefA Error at index %d! Got %s: Expected %s", i, actual.RefA, expected.RefA)
		return false
	}

	if actual.RefB != expected.RefB {
		t.Errorf("SBOM: Relationship RefB Error at index %d! Got %s: Expected %s", i, actual.RefB, expected.RefB)
		return false
	}

	if actual.Relationship != expected.Relationship {
		t.Errorf("SBOM: Relationship type Error at index %d! Got %s: Expected %s", i, actual.Relationship, expected.Relationship)
		return false
	}
	return true
}

func compareLicenses(t *testing.T, i int, actual, expected *spdx.OtherLicense) bool {
	if actual == nil || expected == nil {
		t.Errorf("SBOM: Licenses is nil at index %d! Got %v: Expected %v", i, actual, expected)
		return false
	}

	if actual.LicenseName != expected.LicenseName {
		t.Errorf("SBOM: License Name Error at index %d! Got %s: Expected %s", i, actual.LicenseName, expected.LicenseName)
		return false
	}

	if actual.LicenseIdentifier != expected.LicenseIdentifier {
		t.Errorf("SBOM: License Identifier Error at index %d! Got %s: Expected %s", i, actual.LicenseIdentifier, expected.LicenseIdentifier)
		return false
	}

	if actual.ExtractedText != expected.ExtractedText {
		t.Errorf("SBOM: License Extracted Text Error at index %d! Got: %q want: %q", i, actual.ExtractedText, expected.ExtractedText)
		return false
	}
	return true
}

func fakeTime() string {
	t := time.UnixMicro(0)
	return t.UTC().Format("2006-01-02T15:04:05Z")
}
