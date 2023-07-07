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
	"bufio"
	"bytes"
	"fmt"
	"html"
	"os"
	"reflect"
	"regexp"
	"strings"
	"testing"

	"android/soong/tools/compliance"
)

var (
	horizontalRule = regexp.MustCompile(`^\s*<hr>\s*$`)
	bodyTag        = regexp.MustCompile(`^\s*<body>\s*$`)
	boilerPlate    = regexp.MustCompile(`^\s*(?:<ul class="file-list">|<ul>|</.*)\s*$`)
	tocTag         = regexp.MustCompile(`^\s*<ul class="toc">\s*$`)
	libraryName    = regexp.MustCompile(`^\s*<strong>(.*)</strong>\s\s*used\s\s*by\s*:\s*$`)
	licenseText    = regexp.MustCompile(`^\s*<a id="[^"]{32}"/><pre class="license-text">(.*)$`)
	titleTag       = regexp.MustCompile(`^\s*<title>(.*)</title>\s*$`)
	h1Tag          = regexp.MustCompile(`^\s*<h1>(.*)</h1>\s*$`)
	usedByTarget   = regexp.MustCompile(`^\s*<li>(?:<a href="#id[0-9]+">)?((?:out/(?:[^/<]*/)+)[^/<]*)(?:</a>)?\s*$`)
	installTarget  = regexp.MustCompile(`^\s*<li id="id[0-9]+"><strong>(.*)</strong>\s*$`)
	libReference   = regexp.MustCompile(`^\s*<li><a href="#[^"]{32}">(.*)</a>\s*$`)
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
		includeTOC   bool
		stripPrefix  string
		title        string
		expectedOut  []matcher
		expectedDeps []string
	}{
		{
			condition: "firstparty",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/liba.so"},
				usedBy{"highest.apex/lib/libb.so"},
				firstParty{},
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
			condition:  "firstparty",
			name:       "apex+toc",
			roots:      []string{"highest.apex.meta_lic"},
			includeTOC: true,
			expectedOut: []matcher{
				toc{},
				target{"highest.apex"},
				uses{"Android"},
				target{"highest.apex/bin/bin1"},
				uses{"Android"},
				target{"highest.apex/bin/bin2"},
				uses{"Android"},
				target{"highest.apex/lib/liba.so"},
				uses{"Android"},
				target{"highest.apex/lib/libb.so"},
				uses{"Android"},
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/liba.so"},
				usedBy{"highest.apex/lib/libb.so"},
				firstParty{},
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
			name:      "apex-with-title",
			roots:     []string{"highest.apex.meta_lic"},
			title:     "Emperor",
			expectedOut: []matcher{
				pageTitle{"Emperor"},
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/liba.so"},
				usedBy{"highest.apex/lib/libb.so"},
				firstParty{},
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
			condition:  "firstparty",
			name:       "apex-with-title+toc",
			roots:      []string{"highest.apex.meta_lic"},
			includeTOC: true,
			title:      "Emperor",
			expectedOut: []matcher{
				pageTitle{"Emperor"},
				toc{},
				target{"highest.apex"},
				uses{"Android"},
				target{"highest.apex/bin/bin1"},
				uses{"Android"},
				target{"highest.apex/bin/bin2"},
				uses{"Android"},
				target{"highest.apex/lib/liba.so"},
				uses{"Android"},
				target{"highest.apex/lib/libb.so"},
				uses{"Android"},
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/liba.so"},
				usedBy{"highest.apex/lib/libb.so"},
				firstParty{},
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
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"container.zip"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/bin2"},
				usedBy{"container.zip/liba.so"},
				usedBy{"container.zip/libb.so"},
				firstParty{},
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
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"application"},
				firstParty{},
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
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"bin/bin1"},
				firstParty{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"lib/libd.so"},
				firstParty{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/libb.so"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/lib/liba.so"},
				library{"External"},
				usedBy{"highest.apex/bin/bin1"},
				notice{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"container.zip"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/bin2"},
				usedBy{"container.zip/libb.so"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/liba.so"},
				library{"External"},
				usedBy{"container.zip/bin1"},
				notice{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"application"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"application"},
				notice{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"bin/bin1"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"bin/bin1"},
				library{"External"},
				usedBy{"bin/bin1"},
				notice{},
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
			expectedOut: []matcher{
				hr{},
				library{"External"},
				usedBy{"lib/libd.so"},
				notice{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/libb.so"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/lib/liba.so"},
				library{"External"},
				usedBy{"highest.apex/bin/bin1"},
				reciprocal{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
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
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"container.zip"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/bin2"},
				usedBy{"container.zip/libb.so"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/liba.so"},
				library{"External"},
				usedBy{"container.zip/bin1"},
				reciprocal{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/reciprocal/RECIPROCAL_LICENSE",
				"testdata/reciprocal/bin/bin1.meta_lic",
				"testdata/reciprocal/bin/bin2.meta_lic",
				"testdata/reciprocal/container.zip.meta_lic",
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"application"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"application"},
				reciprocal{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"bin/bin1"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"bin/bin1"},
				library{"External"},
				usedBy{"bin/bin1"},
				reciprocal{},
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
			expectedOut: []matcher{
				hr{},
				library{"External"},
				usedBy{"lib/libd.so"},
				notice{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/bin/bin2"},
				firstParty{},
				hr{},
				library{"Android"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/libb.so"},
				library{"Device"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/lib/liba.so"},
				restricted{},
				hr{},
				library{"External"},
				usedBy{"highest.apex/bin/bin1"},
				reciprocal{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"container.zip"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/bin2"},
				firstParty{},
				hr{},
				library{"Android"},
				usedBy{"container.zip/bin2"},
				usedBy{"container.zip/libb.so"},
				library{"Device"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/liba.so"},
				restricted{},
				hr{},
				library{"External"},
				usedBy{"container.zip/bin1"},
				reciprocal{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
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
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"application"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"application"},
				restricted{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/restricted/RESTRICTED_LICENSE",
				"testdata/restricted/application.meta_lic",
				"testdata/restricted/bin/bin3.meta_lic",
				"testdata/restricted/lib/liba.so.meta_lic",
				"testdata/restricted/lib/libb.so.meta_lic",
			},
		},
		{
			condition: "restricted",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"bin/bin1"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"bin/bin1"},
				restricted{},
				hr{},
				library{"External"},
				usedBy{"bin/bin1"},
				reciprocal{},
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
			expectedOut: []matcher{
				hr{},
				library{"External"},
				usedBy{"lib/libd.so"},
				notice{},
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"highest.apex/bin/bin2"},
				usedBy{"highest.apex/lib/libb.so"},
				restricted{},
				hr{},
				library{"Android"},
				usedBy{"highest.apex"},
				usedBy{"highest.apex/bin/bin1"},
				firstParty{},
				hr{},
				library{"Android"},
				usedBy{"highest.apex/bin/bin2"},
				library{"Device"},
				usedBy{"highest.apex/bin/bin1"},
				usedBy{"highest.apex/lib/liba.so"},
				library{"External"},
				usedBy{"highest.apex/bin/bin1"},
				proprietary{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"container.zip/bin2"},
				usedBy{"container.zip/libb.so"},
				restricted{},
				hr{},
				library{"Android"},
				usedBy{"container.zip"},
				usedBy{"container.zip/bin1"},
				firstParty{},
				hr{},
				library{"Android"},
				usedBy{"container.zip/bin2"},
				library{"Device"},
				usedBy{"container.zip/bin1"},
				usedBy{"container.zip/liba.so"},
				library{"External"},
				usedBy{"container.zip/bin1"},
				proprietary{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
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
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"application"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"application"},
				proprietary{},
			},
			expectedDeps: []string{
				"testdata/firstparty/FIRST_PARTY_LICENSE",
				"testdata/proprietary/PROPRIETARY_LICENSE",
				"testdata/proprietary/application.meta_lic",
				"testdata/proprietary/bin/bin3.meta_lic",
				"testdata/proprietary/lib/liba.so.meta_lic",
				"testdata/proprietary/lib/libb.so.meta_lic",
			},
		},
		{
			condition: "proprietary",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []matcher{
				hr{},
				library{"Android"},
				usedBy{"bin/bin1"},
				firstParty{},
				hr{},
				library{"Device"},
				usedBy{"bin/bin1"},
				library{"External"},
				usedBy{"bin/bin1"},
				proprietary{},
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
			expectedOut: []matcher{
				hr{},
				library{"External"},
				usedBy{"lib/libd.so"},
				notice{},
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

			var deps []string

			ctx := context{stdout, stderr, compliance.GetFS(tt.outDir), tt.includeTOC, "", []string{tt.stripPrefix}, tt.title, &deps}

			err := htmlNotice(&ctx, rootFiles...)
			if err != nil {
				t.Fatalf("htmlnotice: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("htmlnotice: gotStderr = %v, want none", stderr)
			}

			t.Logf("got stdout: %s", stdout.String())

			t.Logf("want stdout: %s", matcherList(tt.expectedOut).String())

			out := bufio.NewScanner(stdout)
			lineno := 0
			inBody := false
			hasTitle := false
			ttle, expectTitle := tt.expectedOut[0].(pageTitle)
			for out.Scan() {
				line := out.Text()
				if strings.TrimLeft(line, " ") == "" {
					continue
				}
				if !inBody {
					if expectTitle {
						if tl := checkTitle(line); len(tl) > 0 {
							if tl != ttle.t {
								t.Errorf("htmlnotice: unexpected title: got %q, want %q", tl, ttle.t)
							}
							hasTitle = true
						}
					}
					if bodyTag.MatchString(line) {
						inBody = true
						if expectTitle && !hasTitle {
							t.Errorf("htmlnotice: missing title: got no <title> tag, want <title>%s</title>", ttle.t)
						}
					}
					continue
				}
				if boilerPlate.MatchString(line) {
					continue
				}
				if len(tt.expectedOut) <= lineno {
					t.Errorf("htmlnotice: unexpected output at line %d: got %q, want nothing (wanted %d lines)", lineno+1, line, len(tt.expectedOut))
				} else if !tt.expectedOut[lineno].isMatch(line) {
					t.Errorf("htmlnotice: unexpected output at line %d: got %q, want %q", lineno+1, line, tt.expectedOut[lineno].String())
				}
				lineno++
			}
			if !inBody {
				t.Errorf("htmlnotice: missing body: got no <body> tag, want <body> tag followed by %s", matcherList(tt.expectedOut).String())
				return
			}
			for ; lineno < len(tt.expectedOut); lineno++ {
				t.Errorf("htmlnotice: missing output line %d: ended early, want %q", lineno+1, tt.expectedOut[lineno].String())
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

func checkTitle(line string) string {
	groups := titleTag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return ""
	}
	return groups[1]
}

type matcher interface {
	isMatch(line string) bool
	String() string
}

type pageTitle struct {
	t string
}

func (m pageTitle) isMatch(line string) bool {
	groups := h1Tag.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == html.EscapeString(m.t)
}

func (m pageTitle) String() string {
	return "  <h1>" + html.EscapeString(m.t) + "</h1>"
}

type toc struct{}

func (m toc) isMatch(line string) bool {
	return tocTag.MatchString(line)
}

func (m toc) String() string {
	return `  <ul class="toc">`
}

type target struct {
	name string
}

func (m target) isMatch(line string) bool {
	groups := installTarget.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return strings.HasPrefix(groups[1], "out/") && strings.HasSuffix(groups[1], "/"+html.EscapeString(m.name))
}

func (m target) String() string {
	return `  <li id="id#"><strong>` + html.EscapeString(m.name) + `</strong>`
}

type uses struct {
	name string
}

func (m uses) isMatch(line string) bool {
	groups := libReference.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == html.EscapeString(m.name)
}

func (m uses) String() string {
	return `  <li><a href="#hash">` + html.EscapeString(m.name) + `</a>`
}

type hr struct{}

func (m hr) isMatch(line string) bool {
	return horizontalRule.MatchString(line)
}

func (m hr) String() string {
	return "  <hr>"
}

type library struct {
	name string
}

func (m library) isMatch(line string) bool {
	groups := libraryName.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == html.EscapeString(m.name)
}

func (m library) String() string {
	return "  <strong>" + html.EscapeString(m.name) + "</strong> used by:"
}

type usedBy struct {
	name string
}

func (m usedBy) isMatch(line string) bool {
	groups := usedByTarget.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return strings.HasPrefix(groups[1], "out/") && strings.HasSuffix(groups[1], "/"+html.EscapeString(m.name))
}

func (m usedBy) String() string {
	return "  <li>out/.../" + html.EscapeString(m.name)
}

func matchesText(line, text string) bool {
	groups := licenseText.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == html.EscapeString(text)
}

func expectedText(text string) string {
	return `  <a href="#hash"/><pre class="license-text">` + html.EscapeString(text)
}

type firstParty struct{}

func (m firstParty) isMatch(line string) bool {
	return matchesText(line, "&&&First Party License&&&")
}

func (m firstParty) String() string {
	return expectedText("&&&First Party License&&&")
}

type notice struct{}

func (m notice) isMatch(line string) bool {
	return matchesText(line, "%%%Notice License%%%")
}

func (m notice) String() string {
	return expectedText("%%%Notice License%%%")
}

type reciprocal struct{}

func (m reciprocal) isMatch(line string) bool {
	return matchesText(line, "$$$Reciprocal License$$$")
}

func (m reciprocal) String() string {
	return expectedText("$$$Reciprocal License$$$")
}

type restricted struct{}

func (m restricted) isMatch(line string) bool {
	return matchesText(line, "###Restricted License###")
}

func (m restricted) String() string {
	return expectedText("###Restricted License###")
}

type proprietary struct{}

func (m proprietary) isMatch(line string) bool {
	return matchesText(line, "@@@Proprietary License@@@")
}

func (m proprietary) String() string {
	return expectedText("@@@Proprietary License@@@")
}

type matcherList []matcher

func (l matcherList) String() string {
	var sb strings.Builder
	for _, m := range l {
		s := m.String()
		if s[:3] == s[len(s)-3:] {
			fmt.Fprintln(&sb)
		}
		fmt.Fprintf(&sb, "%s\n", s)
		if s[:3] == s[len(s)-3:] {
			fmt.Fprintln(&sb)
		}
	}
	return sb.String()
}
