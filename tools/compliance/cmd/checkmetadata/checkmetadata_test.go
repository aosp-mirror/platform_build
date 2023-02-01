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
		name           string
		projects       []string
		expectedStdout string
	}{
		{
			name:           "1p",
			projects:       []string{"firstparty"},
			expectedStdout: "PASS -- parsed 1 project metadata files for 1 projects",
		},
		{
			name:           "notice",
			projects:       []string{"notice"},
			expectedStdout: "PASS -- parsed 1 project metadata files for 1 projects",
		},
		{
			name:           "1p+notice",
			projects:       []string{"firstparty", "notice"},
			expectedStdout: "PASS -- parsed 2 project metadata files for 2 projects",
		},
		{
			name:           "reciprocal",
			projects:       []string{"reciprocal"},
			expectedStdout: "PASS -- parsed 1 project metadata files for 1 projects",
		},
		{
			name:           "1p+notice+reciprocal",
			projects:       []string{"firstparty", "notice", "reciprocal"},
			expectedStdout: "PASS -- parsed 3 project metadata files for 3 projects",
		},
		{
			name:           "restricted",
			projects:       []string{"restricted"},
			expectedStdout: "PASS -- parsed 1 project metadata files for 1 projects",
		},
		{
			name:           "1p+notice+reciprocal+restricted",
			projects:       []string{
				"firstparty",
				"notice",
				"reciprocal",
				"restricted",
			},
			expectedStdout: "PASS -- parsed 4 project metadata files for 4 projects",
		},
		{
			name:           "proprietary",
			projects:       []string{"proprietary"},
			expectedStdout: "PASS -- parsed 1 project metadata files for 1 projects",
		},
		{
			name:           "1p+notice+reciprocal+restricted+proprietary",
			projects:       []string{
				"firstparty",
				"notice",
				"reciprocal",
				"restricted",
				"proprietary",
			},
			expectedStdout: "PASS -- parsed 5 project metadata files for 5 projects",
		},
		{
			name:           "missing1",
			projects:       []string{"regressgpl1"},
			expectedStdout: "PASS -- parsed 0 project metadata files for 1 projects",
		},
		{
			name:           "1p+notice+reciprocal+restricted+proprietary+missing1",
			projects:       []string{
				"firstparty",
				"notice",
				"reciprocal",
				"restricted",
				"proprietary",
				"regressgpl1",
			},
			expectedStdout: "PASS -- parsed 5 project metadata files for 6 projects",
		},
		{
			name:           "missing2",
			projects:       []string{"regressgpl2"},
			expectedStdout: "PASS -- parsed 0 project metadata files for 1 projects",
		},
		{
			name:           "1p+notice+reciprocal+restricted+proprietary+missing1+missing2",
			projects:       []string{
				"firstparty",
				"notice",
				"reciprocal",
				"restricted",
				"proprietary",
				"regressgpl1",
				"regressgpl2",
			},
			expectedStdout: "PASS -- parsed 5 project metadata files for 7 projects",
		},
		{
			name:           "missing2+1p+notice+reciprocal+restricted+proprietary+missing1",
			projects:       []string{
				"regressgpl2",
				"firstparty",
				"notice",
				"reciprocal",
				"restricted",
				"proprietary",
				"regressgpl1",
			},
			expectedStdout: "PASS -- parsed 5 project metadata files for 7 projects",
		},
		{
			name:           "missing2+1p+notice+missing1+reciprocal+restricted+proprietary",
			projects:       []string{
				"regressgpl2",
				"firstparty",
				"notice",
				"regressgpl1",
				"reciprocal",
				"restricted",
				"proprietary",
			},
			expectedStdout: "PASS -- parsed 5 project metadata files for 7 projects",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			stdout := &bytes.Buffer{}
			stderr := &bytes.Buffer{}

			projects := make([]string, 0, len(tt.projects))
			for _, project := range tt.projects {
				projects = append(projects, "testdata/"+project)
			}
			err := checkProjectMetadata(stdout, stderr, compliance.GetFS(""), projects...)
			if err != nil {
				t.Fatalf("checkmetadata: error = %v, stderr = %v", err, stderr)
				return
			}
			var actualStdout string
			for _, s := range strings.Split(stdout.String(), "\n") {
				ts := strings.TrimLeft(s, " \t")
				if len(ts) < 1 {
					continue
				}
				if len(actualStdout) > 0 {
					t.Errorf("checkmetadata: unexpected multiple output lines %q, want %q", actualStdout+"\n"+ts, tt.expectedStdout)
				}
				actualStdout = ts
			}
			if actualStdout != tt.expectedStdout {
				t.Errorf("checkmetadata: unexpected stdout %q, want %q", actualStdout, tt.expectedStdout)
			}
		})
	}
}
