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

func Test(t *testing.T) {
	type projectShare struct {
		project    string
		conditions []string
	}
	tests := []struct {
		condition   string
		name        string
		outDir      string
		roots       []string
		expectedOut []projectShare
	}{
		{
			condition:   "firstparty",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "firstparty",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "firstparty",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "firstparty",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "firstparty",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "notice",
			name:        "apex",
			roots:       []string{"highest.apex.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "notice",
			name:        "container",
			roots:       []string{"container.zip.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "notice",
			name:        "application",
			roots:       []string{"application.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "notice",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "notice",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition: "reciprocal",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "device/library",
					conditions: []string{"reciprocal"},
				},
				{
					project: "static/library",
					conditions: []string{
						"reciprocal",
					},
				},
			},
		},
		{
			condition: "reciprocal",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "device/library",
					conditions: []string{"reciprocal"},
				},
				{
					project: "static/library",
					conditions: []string{
						"reciprocal",
					},
				},
			},
		},
		{
			condition: "reciprocal",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "device/library",
					conditions: []string{"reciprocal"},
				},
			},
		},
		{
			condition: "reciprocal",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []projectShare{
				{
					project: "device/library",
					conditions: []string{
						"reciprocal",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"reciprocal",
					},
				},
			},
		},
		{
			condition:   "reciprocal",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition: "restricted",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "base/library",
					conditions: []string{"restricted"},
				},
				{
					project:    "device/library",
					conditions: []string{"restricted_allows_dynamic_linking"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"restricted"},
				},
				{
					project: "static/binary",
					conditions: []string{
						"restricted_allows_dynamic_linking",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"reciprocal",
						"restricted_allows_dynamic_linking",
					},
				},
			},
		},
		{
			condition: "restricted",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "base/library",
					conditions: []string{"restricted"},
				},
				{
					project:    "device/library",
					conditions: []string{"restricted_allows_dynamic_linking"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"restricted"},
				},
				{
					project: "static/binary",
					conditions: []string{
						"restricted_allows_dynamic_linking",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"reciprocal",
						"restricted_allows_dynamic_linking",
					},
				},
			},
		},
		{
			condition: "restricted",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []projectShare{
				{
					project: "device/library",
					conditions: []string{
						"restricted",
						"restricted_allows_dynamic_linking",
					},
				},
				{
					project: "distributable/application",
					conditions: []string{
						"restricted",
						"restricted_allows_dynamic_linking",
					},
				},
			},
		},
		{
			condition: "restricted",
			name:      "binary",
			roots:     []string{"bin/bin1.meta_lic"},
			expectedOut: []projectShare{
				{
					project: "device/library",
					conditions: []string{
						"restricted_allows_dynamic_linking",
					},
				},
				{
					project: "static/binary",
					conditions: []string{
						"restricted_allows_dynamic_linking",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"reciprocal",
						"restricted_allows_dynamic_linking",
					},
				},
			},
		},
		{
			condition:   "restricted",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition: "proprietary",
			name:      "apex",
			roots:     []string{"highest.apex.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "base/library",
					conditions: []string{"restricted"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"restricted"},
				},
			},
		},
		{
			condition: "proprietary",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "base/library",
					conditions: []string{"restricted"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"restricted"},
				},
			},
		},
		{
			condition: "proprietary",
			name:      "application",
			roots:     []string{"application.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "device/library",
					conditions: []string{"restricted"},
				},
				{
					project:    "distributable/application",
					conditions: []string{"restricted"},
				},
			},
		},
		{
			condition:   "proprietary",
			name:        "binary",
			roots:       []string{"bin/bin1.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition:   "proprietary",
			name:        "library",
			roots:       []string{"lib/libd.so.meta_lic"},
			expectedOut: []projectShare{},
		},
		{
			condition: "regressgpl1",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "bin/threelibraries",
					conditions: []string{"restricted"},
				},
			},
		},
		{
			condition: "regressgpl1",
			name:      "containerplus",
			roots:     []string{"container.zip.meta_lic", "lib/libapache.so.meta_lic", "lib/libc++.so.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "bin/threelibraries",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/apache",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/c++",
					conditions: []string{"restricted"},
				},
			},
		},
		{
			condition: "regressgpl2",
			name:      "container",
			roots:     []string{"container.zip.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "bin/threelibraries",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/apache",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/c++",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/gpl",
					conditions: []string{"restricted"},
				},
			},
		},
		{
			condition: "regressgpl2",
			name:      "containerplus",
			roots:     []string{"container.zip.meta_lic", "lib/libapache.so.meta_lic", "lib/libc++.so.meta_lic"},
			expectedOut: []projectShare{
				{
					project:    "bin/threelibraries",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/apache",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/c++",
					conditions: []string{"restricted"},
				},
				{
					project:    "lib/gpl",
					conditions: []string{"restricted"},
				},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.condition+" "+tt.name, func(t *testing.T) {
			expectedOut := &bytes.Buffer{}
			for _, p := range tt.expectedOut {
				expectedOut.WriteString(p.project)
				for _, lc := range p.conditions {
					expectedOut.WriteString(",")
					expectedOut.WriteString(lc)
				}
				expectedOut.WriteString("\n")
			}

			stdout := &bytes.Buffer{}
			stderr := &bytes.Buffer{}

			rootFiles := make([]string, 0, len(tt.roots))
			for _, r := range tt.roots {
				rootFiles = append(rootFiles, "testdata/"+tt.condition+"/"+r)
			}
			err := listShare(stdout, stderr, compliance.GetFS(tt.outDir), rootFiles...)
			if err != nil {
				t.Fatalf("listshare: error = %v, stderr = %v", err, stderr)
				return
			}
			if stderr.Len() > 0 {
				t.Errorf("listshare: gotStderr = %v, want none", stderr)
			}
			out := stdout.String()
			expected := expectedOut.String()
			if out != expected {
				outList := strings.Split(out, "\n")
				expectedList := strings.Split(expected, "\n")
				startLine := 0
				for len(outList) > startLine && len(expectedList) > startLine && outList[startLine] == expectedList[startLine] {
					startLine++
				}
				t.Errorf("listshare: gotStdout = %v, want %v, somewhere near line %d Stdout = %v, want %v",
					out, expected, startLine+1, outList[startLine], expectedList[startLine])
			}
		})
	}
}
