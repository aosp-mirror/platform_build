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
	"os"
	"reflect"
	"regexp"
	"strings"
	"testing"

	"android/soong/tools/compliance"
)

var (
	horizontalRule = regexp.MustCompile("^===[=]*===$")
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

			ctx := context{stdout, stderr, compliance.GetFS(tt.outDir), "", []string{tt.stripPrefix}, "", &deps}

			err := textNotice(&ctx, rootFiles...)
			if err != nil {
				t.Fatalf("textnotice: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("textnotice: gotStderr = %v, want none", stderr)
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
					t.Errorf("unexpected output at line %d: got %q, want nothing (wanted %d lines)", lineno+1, line, len(tt.expectedOut))
				} else if !tt.expectedOut[lineno].isMatch(line) {
					t.Errorf("unexpected output at line %d: got %q, want %q", lineno+1, line, tt.expectedOut[lineno].String())
				}
				lineno++
			}
			for ; lineno < len(tt.expectedOut); lineno++ {
				t.Errorf("textnotice: missing output line %d: ended early, want %q", lineno+1, tt.expectedOut[lineno].String())
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

type hr struct{}

func (m hr) isMatch(line string) bool {
	return horizontalRule.MatchString(line)
}

func (m hr) String() string {
	return " ================================================== "
}

type library struct {
	name string
}

func (m library) isMatch(line string) bool {
	return strings.HasPrefix(line, m.name+" ")
}

func (m library) String() string {
	return m.name + " used by:"
}

type usedBy struct {
	name string
}

func (m usedBy) isMatch(line string) bool {
	return len(line) > 0 && line[0] == ' ' && strings.HasPrefix(strings.TrimLeft(line, " "), "out/") && strings.HasSuffix(line, "/"+m.name)
}

func (m usedBy) String() string {
	return "  out/.../" + m.name
}

type firstParty struct{}

func (m firstParty) isMatch(line string) bool {
	return strings.HasPrefix(strings.TrimLeft(line, " "), "&&&First Party License&&&")
}

func (m firstParty) String() string {
	return "&&&First Party License&&&"
}

type notice struct{}

func (m notice) isMatch(line string) bool {
	return strings.HasPrefix(strings.TrimLeft(line, " "), "%%%Notice License%%%")
}

func (m notice) String() string {
	return "%%%Notice License%%%"
}

type reciprocal struct{}

func (m reciprocal) isMatch(line string) bool {
	return strings.HasPrefix(strings.TrimLeft(line, " "), "$$$Reciprocal License$$$")
}

func (m reciprocal) String() string {
	return "$$$Reciprocal License$$$"
}

type restricted struct{}

func (m restricted) isMatch(line string) bool {
	return strings.HasPrefix(strings.TrimLeft(line, " "), "###Restricted License###")
}

func (m restricted) String() string {
	return "###Restricted License###"
}

type proprietary struct{}

func (m proprietary) isMatch(line string) bool {
	return strings.HasPrefix(strings.TrimLeft(line, " "), "@@@Proprietary License@@@")
}

func (m proprietary) String() string {
	return "@@@Proprietary License@@@"
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
