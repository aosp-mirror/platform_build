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

func TestResolveBottomUpConditions(t *testing.T) {
	tests := []struct {
		name            string
		roots           []string
		edges           []annotated
		expectedActions []tcond
	}{
		{
			name:  "firstparty",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartytool",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"toolchain"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartydeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartywide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartydynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartydynamicdeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartydynamicwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "restricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice|restricted"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restrictedtool",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"toolchain"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice|restricted"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restrictedwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice|restricted"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddynamicdeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice|restricted"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddynamicwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "weakrestricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestrictedtool",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"toolchain"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestricteddeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"apacheBin.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestrictedwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestricteddynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestricteddynamicdeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestricteddynamicwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "classpath",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:  "classpathdependent",
			roots: []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"dependentModule.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:  "classpathdynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:  "classpathdependentdynamic",
			roots: []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"dependentModule.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
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

			logGraph(lg, t)

			ResolveBottomUpConditions(lg)
			actual := asActionList(lg)
			sort.Sort(actual)
			t.Logf("actual: %s", actual.String())

			expected := toActionList(lg, tt.expectedActions)
			sort.Sort(expected)
			t.Logf("expected: %s", expected.String())

			if len(actual) != len(expected) {
				t.Errorf("unexpected number of actions: got %d, want %d", len(actual), len(expected))
				return
			}
			for i := 0; i < len(actual); i++ {
				if actual[i] != expected[i] {
					t.Errorf("unexpected action at index %d: got %s, want %s", i, actual[i].String(), expected[i].String())
				}
			}
		})
	}
}

func TestResolveTopDownConditions(t *testing.T) {
	tests := []struct {
		name            string
		roots           []string
		edges           []annotated
		expectedActions []tcond
	}{
		{
			name:  "firstparty",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartydynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "restricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice|restricted"},
				{"mitLib.meta_lic", "notice|restricted"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restrictedtool",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplBin.meta_lic", []string{"toolchain"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"mitLib.meta_lic", "notice"},
				{"gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "mitBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mplLib.meta_lic", []string{"static"}},
				{"mitBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice|restricted"},
				{"mitBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "restricted"},
				{"mplLib.meta_lic", "reciprocal|restricted"},
				{"mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "restrictedwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice|restricted"},
				{"gplLib.meta_lic", "restricted"},
				{"mitLib.meta_lic", "notice|restricted"},
			},
		},
		{
			name:  "restricteddynamicdeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "mitBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mplLib.meta_lic", []string{"dynamic"}},
				{"mitBin.meta_lic", "mitLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice|restricted"},
				{"mitBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "restricted"},
				{"mplLib.meta_lic", "reciprocal|restricted"},
				{"mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "restricteddynamicwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "weakrestricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
				{"mitLib.meta_lic", "notice|restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestrictedtool",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplBin.meta_lic", []string{"toolchain"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"lgplBin.meta_lic", "restricted_allows_dynamic_linking"},
				{"mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "weakrestricteddeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"apacheBin.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
				{"mitLib.meta_lic", "notice|restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestrictedwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice|restricted_allows_dynamic_linking"},
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestricteddynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
				{"mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "weakrestricteddynamicdeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "weakrestricteddynamicwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []tcond{
				{"apacheContainer.meta_lic", "notice"},
				{"apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "restricted_allows_dynamic_linking"},
			},
		},
		{
			name:  "classpath",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
				{"mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "classpathdependent",
			roots: []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
				{"dependentModule.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"dependentModule.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
				{"mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "classpathdynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"apacheBin.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
				{"mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "classpathdependentdynamic",
			roots: []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
				{"dependentModule.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []tcond{
				{"dependentModule.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "permissive"},
				{"mitLib.meta_lic", "notice"},
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

			logGraph(lg, t)

			ResolveTopDownConditions(lg)
			actual := asActionList(lg)
			sort.Sort(actual)
			t.Logf("actual: %s", actual.String())

			expected := toActionList(lg, tt.expectedActions)
			sort.Sort(expected)
			t.Logf("expected: %s", expected.String())

			if len(actual) != len(expected) {
				t.Errorf("unexpected number of actions: got %d, want %d", len(actual), len(expected))
				return
			}
			for i := 0; i < len(actual); i++ {
				if actual[i] != expected[i] {
					t.Errorf("unexpected action at index %d: got %s, want %s", i, actual[i].String(), expected[i].String())
				}
			}
		})
	}
}
