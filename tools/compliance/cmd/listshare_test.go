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
	"strings"
	"testing"
)

func Test(t *testing.T) {
	type projectShare struct {
		project    string
		conditions []string
	}
	tests := []struct {
		condition   string
		name        string
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
					conditions: []string{"lib/liba.so.meta_lic:reciprocal"},
				},
				{
					project: "static/library",
					conditions: []string{
						"lib/libc.a.meta_lic:reciprocal",
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
					conditions: []string{"lib/liba.so.meta_lic:reciprocal"},
				},
				{
					project: "static/library",
					conditions: []string{
						"lib/libc.a.meta_lic:reciprocal",
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
					conditions: []string{"lib/liba.so.meta_lic:reciprocal"},
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
						"lib/liba.so.meta_lic:reciprocal",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"lib/libc.a.meta_lic:reciprocal",
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
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project:    "device/library",
					conditions: []string{"lib/liba.so.meta_lic:restricted"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project: "highest/apex",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
						"lib/libb.so.meta_lic:restricted",
					},
				},
				{
					project: "static/binary",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
						"lib/libc.a.meta_lic:reciprocal",
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
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project: "container/zip",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
						"lib/libb.so.meta_lic:restricted",
					},
				},
				{
					project:    "device/library",
					conditions: []string{"lib/liba.so.meta_lic:restricted"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project: "static/binary",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
						"lib/libc.a.meta_lic:reciprocal",
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
						"lib/liba.so.meta_lic:restricted",
						"lib/libb.so.meta_lic:restricted",
					},
				},
				{
					project: "distributable/application",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
						"lib/libb.so.meta_lic:restricted",
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
						"lib/liba.so.meta_lic:restricted",
					},
				},
				{
					project: "static/binary",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
					},
				},
				{
					project: "static/library",
					conditions: []string{
						"lib/liba.so.meta_lic:restricted",
						"lib/libc.a.meta_lic:reciprocal",
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
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project:    "highest/apex",
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
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
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project:    "container/zip",
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project:    "dynamic/binary",
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
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
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
				},
				{
					project:    "distributable/application",
					conditions: []string{"lib/libb.so.meta_lic:restricted"},
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
	}
	for _, tt := range tests {
		t.Run(tt.condition+" "+tt.name, func(t *testing.T) {
			expectedOut := &bytes.Buffer{}
			for _, p := range tt.expectedOut {
				expectedOut.WriteString(p.project)
				for _, lc := range p.conditions {
					expectedOut.WriteString(",")
					expectedOut.WriteString("testdata/")
					expectedOut.WriteString(tt.condition)
					expectedOut.WriteString("/")
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
			err := listShare(stdout, stderr, rootFiles...)
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
