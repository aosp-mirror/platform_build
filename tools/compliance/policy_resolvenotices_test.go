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
	"testing"
)

func TestResolveNotices(t *testing.T) {
	tests := []struct {
		name                string
		roots               []string
		edges               []annotated
		expectedResolutions []res
	}{
		{
			name:  "firstparty",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartydynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:  "firstpartydynamicshipped",
			roots: []string{"apacheBin.meta_lic", "apacheLib.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:  "restricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice|restricted"},
			},
		},
		{
			name:  "restrictedtool",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplBin.meta_lic", []string{"toolchain"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
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
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice|restricted"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice|restricted"},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheContainer.meta_lic", "mitBin.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "mitLib.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "mplLib.meta_lic", "reciprocal|restricted"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "mplLib.meta_lic", "reciprocal|restricted"},
				{"mitBin.meta_lic", "mitBin.meta_lic", "notice"},
				{"mitBin.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "restrictedwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice|restricted"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "restricted"},
			},
		},
		{
			name:  "restricteddynamicshipped",
			roots: []string{"apacheBin.meta_lic", "mitLib.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice|restricted"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "restricted"},
				{"mitLib.meta_lic", "mitLib.meta_lic", "notice|restricted"},
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
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice|restricted"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice|restricted"},
				{"apacheContainer.meta_lic", "mitBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice|restricted"},
				{"mitBin.meta_lic", "mitBin.meta_lic", "notice"},
			},
		},
		{
			name:  "restricteddynamicwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice|restricted"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:  "restricteddynamicwideshipped",
			roots: []string{"apacheContainer.meta_lic", "gplLib.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice|restricted"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "weakrestricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice|restricted_if_statically_linked"},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice|restricted_if_statically_linked"},
			},
		},
		{
			name:  "weakrestrictedtool",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplBin.meta_lic", []string{"toolchain"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "weakrestrictedtoolshipped",
			roots: []string{"apacheBin.meta_lic", "lgplBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplBin.meta_lic", []string{"toolchain"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "restricted_if_statically_linked"},
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
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice|restricted_if_statically_linked"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice|restricted_if_statically_linked"},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
				{"apacheContainer.meta_lic", "mitLib.meta_lic", "notice|restricted_if_statically_linked"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice|restricted_if_statically_linked"},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice|restricted_if_statically_linked"},
			},
		},
		{
			name:  "weakrestrictedwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice|restricted_if_statically_linked"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
			},
		},
		{
			name:  "weakrestricteddynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "weakrestricteddynamicshipped",
			roots: []string{"apacheBin.meta_lic", "lgplLib.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
				{"lgplLib.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
			},
		},
		{
			name:  "weakrestricteddynamicdeep",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:  "weakrestricteddynamicdeepshipped",
			roots: []string{"apacheContainer.meta_lic", "lgplLib.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
			},
		},
		{
			name:  "weakrestricteddynamicwide",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:  "weakrestricteddynamicwideshipped",
			roots: []string{"apacheContainer.meta_lic", "lgplLib.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"lgplLib.meta_lic", "lgplLib.meta_lic", "restricted_if_statically_linked"},
			},
		},
		{
			name:  "classpath",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "classpathdependent",
			roots: []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
				{"dependentModule.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"dependentModule.meta_lic", "dependentModule.meta_lic", "notice"},
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
				{"dependentModule.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "classpathdynamic",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "classpathdynamicshipped",
			roots: []string{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
				{"apacheBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "mitLib.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:  "classpathdependentdynamic",
			roots: []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
				{"dependentModule.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"dependentModule.meta_lic", "dependentModule.meta_lic", "notice"},
				{"dependentModule.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:  "classpathdependentdynamicshipped",
			roots: []string{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
				{"dependentModule.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"dependentModule.meta_lic", "dependentModule.meta_lic", "notice"},
				{"dependentModule.meta_lic", "mitLib.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
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
			expectedRs := toResolutionSet(lg, tt.expectedResolutions)
			actualRs := ResolveNotices(lg)
			checkSame(actualRs, expectedRs, t)
		})
	}
}
