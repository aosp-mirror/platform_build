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

func Test(t *testing.T) {
	tests := []struct {
		condition   string
		name        string
		outDir      string
		roots       []string
		stripPrefix string
		expectedOut []string
	}{
		{
			condition:   "firstparty",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			stripPrefix: "out/target/product/fictional",
			expectedOut: []string{
				"/system/apex/highest.apex",
				"/system/apex/highest.apex/bin/bin1",
				"/system/apex/highest.apex/bin/bin2",
				"/system/apex/highest.apex/lib/liba.so",
				"/system/apex/highest.apex/lib/libb.so",
			},
		},
		{
			condition:   "firstparty",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			stripPrefix: "out/target/product/fictional/data/",
			expectedOut: []string{
				"container.zip",
				"container.zip/bin1",
				"container.zip/bin2",
				"container.zip/liba.so",
				"container.zip/libb.so",
			},
		},
		{
			condition:   "firstparty",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			stripPrefix: "out/target/product/fictional/bin/",
			expectedOut: []string{"application"},
		},
		{
			condition:   "firstparty",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"bin/bin1"},
		},
		{
			condition:   "firstparty",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"lib/libd.so"},
		},
		{
			condition: "notice",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []string{
				"out/target/product/fictional/system/apex/highest.apex",
				"out/target/product/fictional/system/apex/highest.apex/bin/bin1",
				"out/target/product/fictional/system/apex/highest.apex/bin/bin2",
				"out/target/product/fictional/system/apex/highest.apex/lib/liba.so",
				"out/target/product/fictional/system/apex/highest.apex/lib/libb.so",
			},
		},
		{
			condition: "notice",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []string{
				"out/target/product/fictional/data/container.zip",
				"out/target/product/fictional/data/container.zip/bin1",
				"out/target/product/fictional/data/container.zip/bin2",
				"out/target/product/fictional/data/container.zip/liba.so",
				"out/target/product/fictional/data/container.zip/libb.so",
			},
		},
		{
			condition:   "notice",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{"out/target/product/fictional/bin/application"},
		},
		{
			condition:   "notice",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{"out/target/product/fictional/system/bin/bin1"},
		},
		{
			condition:   "notice",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{"out/target/product/fictional/system/lib/libd.so"},
		},
		{
			condition:   "reciprocal",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/apex/",
			expectedOut: []string{
				"highest.apex",
				"highest.apex/bin/bin1",
				"highest.apex/bin/bin2",
				"highest.apex/lib/liba.so",
				"highest.apex/lib/libb.so",
			},
		},
		{
			condition:   "reciprocal",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			stripPrefix: "out/target/product/fictional/data/",
			expectedOut: []string{
				"container.zip",
				"container.zip/bin1",
				"container.zip/bin2",
				"container.zip/liba.so",
				"container.zip/libb.so",
			},
		},
		{
			condition:   "reciprocal",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			stripPrefix: "out/target/product/fictional/bin/",
			expectedOut: []string{"application"},
		},
		{
			condition:   "reciprocal",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"bin/bin1"},
		},
		{
			condition:   "reciprocal",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"lib/libd.so"},
		},
		{
			condition:   "restricted",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/apex/",
			expectedOut: []string{
				"highest.apex",
				"highest.apex/bin/bin1",
				"highest.apex/bin/bin2",
				"highest.apex/lib/liba.so",
				"highest.apex/lib/libb.so",
			},
		},
		{
			condition:   "restricted",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			stripPrefix: "out/target/product/fictional/data/",
			expectedOut: []string{
				"container.zip",
				"container.zip/bin1",
				"container.zip/bin2",
				"container.zip/liba.so",
				"container.zip/libb.so",
			},
		},
		{
			condition:   "restricted",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			stripPrefix: "out/target/product/fictional/bin/",
			expectedOut: []string{"application"},
		},
		{
			condition:   "restricted",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"bin/bin1"},
		},
		{
			condition:   "restricted",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"lib/libd.so"},
		},
		{
			condition:   "proprietary",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/apex/",
			expectedOut: []string{
				"highest.apex",
				"highest.apex/bin/bin1",
				"highest.apex/bin/bin2",
				"highest.apex/lib/liba.so",
				"highest.apex/lib/libb.so",
			},
		},
		{
			condition:   "proprietary",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			stripPrefix: "out/target/product/fictional/data/",
			expectedOut: []string{
				"container.zip",
				"container.zip/bin1",
				"container.zip/bin2",
				"container.zip/liba.so",
				"container.zip/libb.so",
			},
		},
		{
			condition:   "proprietary",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			stripPrefix: "out/target/product/fictional/bin/",
			expectedOut: []string{"application"},
		},
		{
			condition:   "proprietary",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"bin/bin1"},
		},
		{
			condition:   "proprietary",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			stripPrefix: "out/target/product/fictional/system/",
			expectedOut: []string{"lib/libd.so"},
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

			ctx := context{stdout, stderr, compliance.GetFS(tt.outDir), []string{tt.stripPrefix}}

			err := billOfMaterials(&ctx, rootFiles...)
			if err != nil {
				t.Fatalf("bom: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("bom: gotStderr = %v, want none", stderr)
			}

			t.Logf("got stdout: %s", stdout.String())

			t.Logf("want stdout: %s", strings.Join(tt.expectedOut, "\n"))

			out := bufio.NewScanner(stdout)
			lineno := 0
			for out.Scan() {
				line := out.Text()
				if strings.TrimLeft(line, " ") == "" {
					continue
				}
				if len(tt.expectedOut) <= lineno {
					t.Errorf("bom: unexpected output at line %d: got %q, want nothing (wanted %d lines)", lineno+1, line, len(tt.expectedOut))
				} else if tt.expectedOut[lineno] != line {
					t.Errorf("bom: unexpected output at line %d: got %q, want %q", lineno+1, line, tt.expectedOut[lineno])
				}
				lineno++
			}
			for ; lineno < len(tt.expectedOut); lineno++ {
				t.Errorf("bom: missing output line %d: ended early, want %q", lineno+1, tt.expectedOut[lineno])
			}
		})
	}
}
