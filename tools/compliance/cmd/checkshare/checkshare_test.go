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

type outcome struct {
	target           string
	privacyCondition string
	shareCondition   string
}

func (o *outcome) String() string {
	return fmt.Sprintf("%s %s and must share from %s", o.target, o.privacyCondition, o.shareCondition)
}

type outcomeList []*outcome

func (ol outcomeList) String() string {
	result := ""
	for _, o := range ol {
		result = result + o.String() + "\n"
	}
	return result
}

func Test(t *testing.T) {
	tests := []struct {
		condition        string
		name             string
		outDir           string
		roots            []string
		expectedStdout   string
		expectedOutcomes outcomeList
	}{
		{
			condition:      "firstparty",
			name:           "apex",
			roots:          []string{"highest.apex.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "firstparty",
			name:           "container",
			roots:          []string{"container.zip.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "firstparty",
			name:           "application",
			roots:          []string{"application.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "firstparty",
			name:           "binary",
			roots:          []string{"bin/bin2.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "firstparty",
			name:           "library",
			roots:          []string{"lib/libd.so.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "notice",
			name:           "apex",
			roots:          []string{"highest.apex.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "notice",
			name:           "container",
			roots:          []string{"container.zip.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "notice",
			name:           "application",
			roots:          []string{"application.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "notice",
			name:           "binary",
			roots:          []string{"bin/bin2.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "notice",
			name:           "library",
			roots:          []string{"lib/libd.so.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "reciprocal",
			name:           "apex",
			roots:          []string{"highest.apex.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "reciprocal",
			name:           "container",
			roots:          []string{"container.zip.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "reciprocal",
			name:           "application",
			roots:          []string{"application.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "reciprocal",
			name:           "binary",
			roots:          []string{"bin/bin2.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "reciprocal",
			name:           "library",
			roots:          []string{"lib/libd.so.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "restricted",
			name:           "apex",
			roots:          []string{"highest.apex.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "restricted",
			name:           "container",
			roots:          []string{"container.zip.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "restricted",
			name:           "application",
			roots:          []string{"application.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "restricted",
			name:           "binary",
			roots:          []string{"bin/bin2.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "restricted",
			name:           "library",
			roots:          []string{"lib/libd.so.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "proprietary",
			name:           "apex",
			roots:          []string{"highest.apex.meta_lic"},
			expectedStdout: "FAIL",
			expectedOutcomes: outcomeList{
				&outcome{
					target:           "testdata/proprietary/bin/bin2.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
			},
		},
		{
			condition:      "proprietary",
			name:           "container",
			roots:          []string{"container.zip.meta_lic"},
			expectedStdout: "FAIL",
			expectedOutcomes: outcomeList{
				&outcome{
					target:           "testdata/proprietary/bin/bin2.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
			},
		},
		{
			condition:      "proprietary",
			name:           "application",
			roots:          []string{"application.meta_lic"},
			expectedStdout: "FAIL",
			expectedOutcomes: outcomeList{
				&outcome{
					target:           "testdata/proprietary/lib/liba.so.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
			},
		},
		{
			condition:      "proprietary",
			name:           "binary",
			roots:          []string{"bin/bin2.meta_lic", "lib/libb.so.meta_lic"},
			expectedStdout: "FAIL",
			expectedOutcomes: outcomeList{
				&outcome{
					target:           "testdata/proprietary/bin/bin2.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
			},
		},
		{
			condition:      "proprietary",
			name:           "library",
			roots:          []string{"lib/libd.so.meta_lic"},
			expectedStdout: "PASS",
		},
		{
			condition:      "regressconcur",
			name:           "container",
			roots:          []string{"container.zip.meta_lic"},
			expectedStdout: "FAIL",
			expectedOutcomes: outcomeList{
				&outcome{
					target:           "testdata/regressconcur/bin/bin1.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin2.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin3.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin4.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin5.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin6.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin7.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin8.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
				&outcome{
					target:           "testdata/regressconcur/bin/bin9.meta_lic",
					privacyCondition: "proprietary",
					shareCondition:   "restricted",
				},
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
			err := checkShare(stdout, stderr, compliance.GetFS(tt.outDir), rootFiles...)
			if err != nil && err != failConflicts {
				t.Fatalf("checkshare: error = %v, stderr = %v", err, stderr)
				return
			}
			var actualStdout string
			for _, s := range strings.Split(stdout.String(), "\n") {
				ts := strings.TrimLeft(s, " \t")
				if len(ts) < 1 {
					continue
				}
				if len(actualStdout) > 0 {
					t.Errorf("checkshare: unexpected multiple output lines %q, want %q", actualStdout+"\n"+ts, tt.expectedStdout)
				}
				actualStdout = ts
			}
			if actualStdout != tt.expectedStdout {
				t.Errorf("checkshare: unexpected stdout %q, want %q", actualStdout, tt.expectedStdout)
			}
			errList := strings.Split(stderr.String(), "\n")
			actualOutcomes := make(outcomeList, 0, len(errList))
			for _, cstring := range errList {
				ts := strings.TrimLeft(cstring, " \t")
				if len(ts) < 1 {
					continue
				}
				cFields := strings.Split(ts, " ")
				actualOutcomes = append(actualOutcomes, &outcome{
					target:           cFields[0],
					privacyCondition: cFields[1],
					shareCondition:   cFields[6],
				})
			}
			if len(actualOutcomes) != len(tt.expectedOutcomes) {
				t.Errorf("checkshare: unexpected got %d outcomes %s, want %d outcomes %s",
					len(actualOutcomes), actualOutcomes, len(tt.expectedOutcomes), tt.expectedOutcomes)
				return
			}
			for i := range actualOutcomes {
				if actualOutcomes[i].String() != tt.expectedOutcomes[i].String() {
					t.Errorf("checkshare: unexpected outcome #%d, got %q, want %q",
						i+1, actualOutcomes[i], tt.expectedOutcomes[i])
				}
			}
		})
	}
}
