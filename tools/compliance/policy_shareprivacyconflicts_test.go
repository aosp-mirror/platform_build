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

// byConflict orders conflicts by target then share then privacy
type byConflict []SourceSharePrivacyConflict

// Len returns the count of elements in the slice.
func (l byConflict) Len() int { return len(l) }

// Swap rearranged 2 elements so that each occupies the other's former
// position.
func (l byConflict) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographically less than
// the `j`th element.
func (l byConflict) Less(i, j int) bool {
	if l[i].SourceNode.Name() == l[j].SourceNode.Name() {
		if l[i].ShareCondition.Name() == l[j].ShareCondition.Name() {
			return l[i].PrivacyCondition.Name() < l[j].PrivacyCondition.Name()
		}
		return l[i].ShareCondition.Name() < l[j].ShareCondition.Name()
	}
	return l[i].SourceNode.Name() < l[j].SourceNode.Name()
}

func TestConflictingSharedPrivateSource(t *testing.T) {
	tests := []struct {
		name              string
		roots             []string
		edges             []annotated
		expectedConflicts []confl
	}{
		{
			name:  "firstparty",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedConflicts: []confl{},
		},
		{
			name:  "notice",
			roots: []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedConflicts: []confl{},
		},
		{
			name:  "lgpl",
			roots: []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedConflicts: []confl{},
		},
		{
			name:  "proprietaryonrestricted",
			roots: []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedConflicts: []confl{
				{"proprietary.meta_lic", "gplLib.meta_lic:restricted", "proprietary.meta_lic:proprietary"},
			},
		},
		{
			name:  "restrictedonproprietary",
			roots: []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedConflicts: []confl{
				{"proprietary.meta_lic", "gplBin.meta_lic:restricted", "proprietary.meta_lic:proprietary"},
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
			expectedConflicts := toConflictList(lg, tt.expectedConflicts)
			actualConflicts := ConflictingSharedPrivateSource(lg)
			sort.Sort(byConflict(expectedConflicts))
			sort.Sort(byConflict(actualConflicts))
			if len(expectedConflicts) != len(actualConflicts) {
				t.Errorf("unexpected number of share/privacy conflicts: got %v with %d conflicts, want %v with %d conflicts",
					actualConflicts, len(actualConflicts), expectedConflicts, len(expectedConflicts))
			} else {
				for i := 0; i < len(actualConflicts); i++ {
					if !actualConflicts[i].IsEqualTo(expectedConflicts[i]) {
						t.Errorf("unexpected share/privacy conflict at element %d: got %q, want %q",
							i, actualConflicts[i].Error(), expectedConflicts[i].Error())
					}
				}
			}

		})
	}
}
