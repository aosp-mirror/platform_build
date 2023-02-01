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
	"fmt"
	"os"
	"strings"
	"testing"

	"android/soong/tools/compliance"
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

func Test_plaintext(t *testing.T) {
	tests := []struct {
		condition   string
		name        string
		outDir      string
		roots       []string
		ctx         context
		expectedOut []string
	}{
		{
			condition:   "firstparty",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "firstparty",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				sources:     []string{"testdata/firstparty/bin/bin1.meta_lic"},
				stripPrefix: []string{"testdata/firstparty/"},
			},
			expectedOut: []string{},
		},
		{
			condition:   "firstparty",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "firstparty",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "firstparty",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "firstparty",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "notice",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "notice",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				sources:     []string{"testdata/notice/bin/bin1.meta_lic"},
				stripPrefix: []string{"testdata/notice/"},
			},
			expectedOut: []string{},
		},
		{
			condition:   "notice",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "notice",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "notice",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "notice",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "reciprocal",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "reciprocal",
			name:      "apex_trimmed",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				sources:     []string{"testdata/reciprocal/bin/bin1.meta_lic"},
				stripPrefix: []string{"testdata/reciprocal/"},
			},
			expectedOut: []string{},
		},
		{
			condition:   "reciprocal",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "reciprocal",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "reciprocal",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "reciprocal",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition: "restricted",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_bin1",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				sources:     []string{"testdata/restricted/bin/bin1.meta_lic"},
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []string{"lib/liba.so.meta_lic restricted_if_statically_linked"},
		},
		{
			condition: "restricted",
			name:      "apex_trimmed_bin2",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				sources:     []string{"testdata/restricted/bin/bin2.meta_lic"},
				stripPrefix: []string{"testdata/restricted/"},
			},
			expectedOut: []string{"lib/libb.so.meta_lic restricted"},
		},
		{
			condition: "restricted",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked",
				"testdata/restricted/lib/libb.so.meta_lic restricted",
			},
		},
		{
			condition:   "restricted",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{"testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked"},
		},
		{
			condition:   "restricted",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{"testdata/restricted/lib/liba.so.meta_lic restricted_if_statically_linked"},
		},
		{
			condition:   "restricted",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "proprietary",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{"testdata/proprietary/lib/libb.so.meta_lic restricted"},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_bin1",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				sources:     []string{"testdata/proprietary/bin/bin1.meta_lic"},
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []string{},
		},
		{
			condition: "proprietary",
			name:      "apex_trimmed_bin2",
			roots:     []string{"highest.apex.meta_lic"},
			ctx: context{
				sources:     []string{"testdata/proprietary/bin/bin2.meta_lic"},
				stripPrefix: []string{"testdata/proprietary/"},
			},
			expectedOut: []string{"lib/libb.so.meta_lic restricted"},
		},
		{
			condition:   "proprietary",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{"testdata/proprietary/lib/libb.so.meta_lic restricted"},
		},
		{
			condition:   "proprietary",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "proprietary",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{},
		},
		{
			condition:   "proprietary",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{},
		},
	}
	for _, tt := range tests {
		t.Run(tt.condition+" "+tt.name, func(t *testing.T) {
			expectedOut := &bytes.Buffer{}
			for _, eo := range tt.expectedOut {
				expectedOut.WriteString(eo)
				expectedOut.WriteString("\n")
			}
			fmt.Fprintf(expectedOut, "restricted conditions trace to %d targets\n", len(tt.expectedOut))
			if 0 == len(tt.expectedOut) {
				fmt.Fprintln(expectedOut, "  (check for typos in project names or metadata files)")
			}

			stdout := &bytes.Buffer{}
			stderr := &bytes.Buffer{}

			rootFiles := make([]string, 0, len(tt.roots))
			for _, r := range tt.roots {
				rootFiles = append(rootFiles, "testdata/"+tt.condition+"/"+r)
			}
			if len(tt.ctx.sources) < 1 {
				tt.ctx.sources = rootFiles
			}
			_, err := traceRestricted(&tt.ctx, stdout, stderr, compliance.GetFS(tt.outDir), rootFiles...)
			t.Logf("rtrace: stderr = %v", stderr)
			t.Logf("rtrace: stdout = %v", stdout)
			if err != nil {
				t.Fatalf("rtrace: error = %v", err)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("rtrace: gotStderr = %v, want none", stderr)
			}
			out := stdout.String()
			expected := expectedOut.String()
			if out != expected {
				outList := strings.Split(out, "\n")
				expectedList := strings.Split(expected, "\n")
				startLine := 0
				for startLine < len(outList) && startLine < len(expectedList) && outList[startLine] == expectedList[startLine] {
					startLine++
				}
				t.Errorf("rtrace: gotStdout = %v, want %v, somewhere near line %d Stdout = %v, want %v",
					out, expected, startLine+1, outList[startLine], expectedList[startLine])
			}
		})
	}
}
