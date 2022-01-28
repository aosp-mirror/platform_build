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
	"strings"
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
			name:          "singleton",
			roots:         []string{"apacheLib.meta_lic"},
			edges:         []annotated{},
			expectedNodes: []string{"apacheLib.meta_lic"},
		},
		{
			name:  "simplebinary",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedNodes: []string{"apacheBin.meta_lic", "apacheLib.meta_lic"},
		},
		{
			name:  "simpledynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedNodes: []string{"apacheBin.meta_lic"},
		},
		{
			name:  "container",
			roots: []string{"apacheContainer.meta_lic"},
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
			name:  "binary",
			roots: []string{"apacheBin.meta_lic"},
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
			name:  "binarydynamic",
			roots: []string{"apacheBin.meta_lic"},
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
			name:  "containerdeep",
			roots: []string{"apacheContainer.meta_lic"},
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
				t.Errorf("unexpected test data error: got %s, want no error", err)
				return
			}
			t.Logf("graph:")
			for _, edge := range lg.Edges() {
				t.Logf("  %s", edge.String())
			}
			expectedNodes := append([]string{}, tt.expectedNodes...)
			nodeset := ShippedNodes(lg)
			t.Logf("shipped node set: %s", nodeset.String())

			actualNodes := nodeset.Names()
			t.Logf("shipped nodes: [%s]", strings.Join(actualNodes, ", "))

			sort.Strings(expectedNodes)
			sort.Strings(actualNodes)

			t.Logf("sorted nodes: [%s]", strings.Join(actualNodes, ", "))
			t.Logf("expected nodes: [%s]", strings.Join(expectedNodes, ", "))
			if len(expectedNodes) != len(actualNodes) {
				t.Errorf("unexpected number of shipped nodes: %d nodes, want %d nodes",
					len(actualNodes), len(expectedNodes))
				return
			}
			for i := 0; i < len(actualNodes); i++ {
				if expectedNodes[i] != actualNodes[i] {
					t.Errorf("unexpected node at index %d: got %q, want %q",
						i, actualNodes[i], expectedNodes[i])
				}
			}
		})
	}
}
