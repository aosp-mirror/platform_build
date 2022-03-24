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
		expectedOut []string
	}{
		{
			condition:   "firstparty",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{"Android"},
		},
		{
			condition:   "firstparty",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{"Android"},
		},
		{
			condition:   "firstparty",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{"Android"},
		},
		{
			condition:   "firstparty",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{"Android"},
		},
		{
			condition:   "firstparty",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{"Android"},
		},
		{
			condition:   "notice",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "notice",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "notice",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{"Android", "Device"},
		},
		{
			condition:   "notice",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "notice",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{"External"},
		},
		{
			condition:   "reciprocal",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "reciprocal",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "reciprocal",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{"Android", "Device"},
		},
		{
			condition:   "reciprocal",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "reciprocal",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{"External"},
		},
		{
			condition:   "restricted",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "restricted",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "restricted",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{"Android", "Device"},
		},
		{
			condition:   "restricted",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "restricted",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{"External"},
		},
		{
			condition:   "proprietary",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "proprietary",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "proprietary",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []string{"Android", "Device"},
		},
		{
			condition:   "proprietary",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []string{"Android", "Device", "External"},
		},
		{
			condition:   "proprietary",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []string{"External"},
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

			ctx := context{stdout, stderr, compliance.GetFS(tt.outDir)}

			err := shippedLibs(&ctx, rootFiles...)
			if err != nil {
				t.Fatalf("shippedLibs: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("shippedLibs: gotStderr = %v, want none", stderr)
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
					t.Errorf("shippedLibs: unexpected output at line %d: got %q, want nothing (wanted %d lines)", lineno+1, line, len(tt.expectedOut))
				} else if tt.expectedOut[lineno] != line {
					t.Errorf("shippedLibs: unexpected output at line %d: got %q, want %q", lineno+1, line, tt.expectedOut[lineno])
				}
				lineno++
			}
			for ; lineno < len(tt.expectedOut); lineno++ {
				t.Errorf("shippedLibs: missing output line %d: ended early, want %q", lineno+1, tt.expectedOut[lineno])
			}
		})
	}
}
