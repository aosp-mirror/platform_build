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

package compliance

import (
	"bytes"
	"sort"
	"testing"
)

func TestShippedNodes(t *testing.T) {
	tests := []struct {
		name          string
		roots         []string
		edges         []annotated
		expectedNodes []string
	}{
		{
			name:      "singleton",
			roots:     []string{"apacheLib.meta_lic"},
			edges: []annotated{},
			expectedNodes: []string{"apacheLib.meta_lic"},
		},
		{
			name:      "simplebinary",
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedNodes: []string{"apacheBin.meta_lic", "apacheLib.meta_lic"},
		},
		{
			name:      "simpledynamic",
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedNodes: []string{"apacheBin.meta_lic"},
		},
		{
			name:      "container",
			roots:     []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedNodes: []string{
				"apacheContainer.meta_lic",
				"apacheLib.meta_lic",
				"gplLib.meta_lic",
			},
		},
		{
			name:      "binary",
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedNodes: []string{
				"apacheBin.meta_lic",
				"apacheLib.meta_lic",
				"gplLib.meta_lic",
			},
		},
		{
			name:      "binarydynamic",
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedNodes: []string{
				"apacheBin.meta_lic",
				"apacheLib.meta_lic",
			},
		},
		{
			name:      "containerdeep",
			roots:     []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheLib.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedNodes: []string{
				"apacheContainer.meta_lic",
				"apacheBin.meta_lic",
				"apacheLib.meta_lic",
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			stderr := &bytes.Buffer{}
			lg, err := toGraph(stderr, tt.roots, tt.edges)
			if err != nil {
				t.Errorf("unexpected test data error: got %w, want no error", err)
				return
			}
			expectedNodes := append([]string{}, tt.expectedNodes...)
			actualNodes := ShippedNodes(lg).Names()
			sort.Strings(expectedNodes)
			sort.Strings(actualNodes)
                        if len(expectedNodes) != len(actualNodes) {
				t.Errorf("unexpected number of shipped nodes: got %v with %d nodes, want %v with %d nodes",
					actualNodes, len(actualNodes), expectedNodes, len(expectedNodes))
				return
			}
			for i := 0; i < len(actualNodes); i++ {
				if expectedNodes[i] != actualNodes[i] {
					t.Errorf("unexpected node at index %d: got %q in %v, want %q in %v",
						i, actualNodes[i], actualNodes, expectedNodes[i], expectedNodes)
				}
			}
		})
	}
}
