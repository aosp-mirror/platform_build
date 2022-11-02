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
	"encoding/xml"
	"fmt"
	"os"
	"reflect"
	"regexp"
	"strings"
	"testing"

	"android/soong/tools/compliance"
)

var (
	installTarget = regexp.MustCompile(`^<file-name contentId="[^"]{32}" lib="([^"]*)">([^<]+)</file-name>`)
	licenseText = regexp.MustCompile(`^<file-content contentId="[^"]{32}"><![[]CDATA[[]([^]]*)[]][]]></file-content>`)
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
				target{"highest.apex", "Android"},
				target{"highest.apex/bin/bin1", "Android"},
				target{"highest.apex/bin/bin2", "Android"},
				target{"highest.apex/lib/liba.so", "Android"},
				target{"highest.apex/lib/libb.so", "Android"},
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
				target{"container.zip", "Android"},
				target{"container.zip/bin1", "Android"},
				target{"container.zip/bin2", "Android"},
				target{"container.zip/liba.so", "Android"},
				target{"container.zip/libb.so", "Android"},
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
				target{"application", "Android"},
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
				target{"bin/bin1", "Android"},
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
				target{"lib/libd.so", "Android"},
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
				target{"highest.apex", "Android"},
				target{"highest.apex/bin/bin1", "Android"},
				target{"highest.apex/bin/bin1", "Device"},
				target{"highest.apex/bin/bin1", "External"},
				target{"highest.apex/bin/bin2", "Android"},
				target{"highest.apex/lib/liba.so", "Device"},
				target{"highest.apex/lib/libb.so", "Android"},
				firstParty{},
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
				target{"container.zip", "Android"},
				target{"container.zip/bin1", "Android"},
				target{"container.zip/bin1", "Device"},
				target{"container.zip/bin1", "External"},
				target{"container.zip/bin2", "Android"},
				target{"container.zip/liba.so", "Device"},
				target{"container.zip/libb.so", "Android"},
				firstParty{},
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
				target{"application", "Android"},
				target{"application", "Device"},
				firstParty{},
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
				target{"bin/bin1", "Android"},
				target{"bin/bin1", "Device"},
				target{"bin/bin1", "External"},
				firstParty{},
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
				target{"lib/libd.so", "External"},
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
				target{"highest.apex", "Android"},
				target{"highest.apex/bin/bin1", "Android"},
				target{"highest.apex/bin/bin1", "Device"},
				target{"highest.apex/bin/bin1", "External"},
				target{"highest.apex/bin/bin2", "Android"},
				target{"highest.apex/lib/liba.so", "Device"},
				target{"highest.apex/lib/libb.so", "Android"},
				firstParty{},
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
				target{"container.zip", "Android"},
				target{"container.zip/bin1", "Android"},
				target{"container.zip/bin1", "Device"},
				target{"container.zip/bin1", "External"},
				target{"container.zip/bin2", "Android"},
				target{"container.zip/liba.so", "Device"},
				target{"container.zip/libb.so", "Android"},
				firstParty{},
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
				target{"application", "Android"},
				target{"application", "Device"},
				firstParty{},
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
				target{"bin/bin1", "Android"},
				target{"bin/bin1", "Device"},
				target{"bin/bin1", "External"},
				firstParty{},
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
				target{"lib/libd.so", "External"},
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
				target{"highest.apex", "Android"},
				target{"highest.apex/bin/bin1", "Android"},
				target{"highest.apex/bin/bin1", "Device"},
				target{"highest.apex/bin/bin1", "External"},
				target{"highest.apex/bin/bin2", "Android"},
				target{"highest.apex/bin/bin2", "Android"},
				target{"highest.apex/lib/liba.so", "Device"},
				target{"highest.apex/lib/libb.so", "Android"},
				firstParty{},
				restricted{},
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
				target{"container.zip", "Android"},
				target{"container.zip/bin1", "Android"},
				target{"container.zip/bin1", "Device"},
				target{"container.zip/bin1", "External"},
				target{"container.zip/bin2", "Android"},
				target{"container.zip/bin2", "Android"},
				target{"container.zip/liba.so", "Device"},
				target{"container.zip/libb.so", "Android"},
				firstParty{},
				restricted{},
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
				target{"application", "Android"},
				target{"application", "Device"},
				firstParty{},
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
				target{"bin/bin1", "Android"},
				target{"bin/bin1", "Device"},
				target{"bin/bin1", "External"},
				firstParty{},
				restricted{},
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
				target{"lib/libd.so", "External"},
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
				target{"highest.apex", "Android"},
				target{"highest.apex/bin/bin1", "Android"},
				target{"highest.apex/bin/bin1", "Device"},
				target{"highest.apex/bin/bin1", "External"},
				target{"highest.apex/bin/bin2", "Android"},
				target{"highest.apex/bin/bin2", "Android"},
				target{"highest.apex/lib/liba.so", "Device"},
				target{"highest.apex/lib/libb.so", "Android"},
				restricted{},
				firstParty{},
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
				target{"container.zip", "Android"},
				target{"container.zip/bin1", "Android"},
				target{"container.zip/bin1", "Device"},
				target{"container.zip/bin1", "External"},
				target{"container.zip/bin2", "Android"},
				target{"container.zip/bin2", "Android"},
				target{"container.zip/liba.so", "Device"},
				target{"container.zip/libb.so", "Android"},
				restricted{},
				firstParty{},
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
				target{"application", "Android"},
				target{"application", "Device"},
				firstParty{},
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
				target{"bin/bin1", "Android"},
				target{"bin/bin1", "Device"},
				target{"bin/bin1", "External"},
				firstParty{},
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
				target{"lib/libd.so", "External"},
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

			ctx := context{stdout, stderr, compliance.GetFS(tt.outDir), "", []string{tt.stripPrefix}, "", &deps}

			err := xmlNotice(&ctx, rootFiles...)
			if err != nil {
				t.Fatalf("xmlnotice: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("xmlnotice: gotStderr = %v, want none", stderr)
			}

			t.Logf("got stdout: %s", stdout.String())

			t.Logf("want stdout: %s", matcherList(tt.expectedOut).String())

			out := bufio.NewScanner(stdout)
			lineno := 0
			inBody := false
			outOfBody := true
			for out.Scan() {
				line := out.Text()
				if strings.TrimLeft(line, " ") == "" {
					continue
				}
				if lineno == 0 && !inBody && `<?xml version="1.0" encoding="utf-8"?>` == line {
					continue
				}
				if !inBody {
					if "<licenses>" == line {
						inBody = true
						outOfBody = false
					}
					continue
				} else if "</licenses>" == line {
					outOfBody = true
					continue
				}

				if len(tt.expectedOut) <= lineno {
					t.Errorf("xmlnotice: unexpected output at line %d: got %q, want nothing (wanted %d lines)", lineno+1, line, len(tt.expectedOut))
				} else if !tt.expectedOut[lineno].isMatch(line) {
					t.Errorf("xmlnotice: unexpected output at line %d: got %q, want %q", lineno+1, line, tt.expectedOut[lineno].String())
				}
				lineno++
			}
			if !inBody {
				t.Errorf("xmlnotice: missing <licenses> tag: got no <licenses> tag, want <licenses> tag on 2nd line")
			}
			if !outOfBody {
				t.Errorf("xmlnotice: missing </licenses> tag: got no </licenses> tag, want </licenses> tag on last line")
			}
			for ; lineno < len(tt.expectedOut); lineno++ {
				t.Errorf("xmlnotice: missing output line %d: ended early, want %q", lineno+1, tt.expectedOut[lineno].String())
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

func escape(s string) string {
	b := &bytes.Buffer{}
	xml.EscapeText(b, []byte(s))
	return b.String()
}

type matcher interface {
	isMatch(line string) bool
	String() string
}

type target struct {
	name string
	lib string
}

func (m target) isMatch(line string) bool {
	groups := installTarget.FindStringSubmatch(line)
	if len(groups) != 3 {
		return false
	}
	return groups[1] == escape(m.lib) && strings.HasPrefix(groups[2], "out/") && strings.HasSuffix(groups[2], "/"+escape(m.name))
}

func (m target) String() string {
	return `<file-name contentId="hash" lib="` + escape(m.lib) + `">` + escape(m.name) + `</file-name>`
}

func matchesText(line, text string) bool {
	groups := licenseText.FindStringSubmatch(line)
	if len(groups) != 2 {
		return false
	}
	return groups[1] == escape(text + "\n")
}

func expectedText(text string) string {
	return `<file-content contentId="hash"><![CDATA[` + escape(text + "\n") + `]]></file-content>`
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
	fmt.Fprintln(&sb, `<?xml version="1.0" encoding="utf-8"?>`)
	fmt.Fprintln(&sb, `<licenses>`)
	for _, m := range l {
		s := m.String()
		fmt.Fprintln(&sb, s)
		if _, ok := m.(target); !ok {
			fmt.Fprintln(&sb)
		}
	}
	fmt.Fprintln(&sb, `/<licenses>`)
	return sb.String()
}
