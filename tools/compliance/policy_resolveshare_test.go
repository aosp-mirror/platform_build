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

func TestResolveSourceSharing(t *testing.T) {
	tests := []struct {
		name                string
		roots               []string
		edges               []annotated
		expectedResolutions []res
	}{
		{
			name:  "independentmodulerestricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "independentmodulerestrictedshipped",
			roots: []string{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "independentmodulestaticrestricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "dependentmodulerestricted",
			roots: []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "dependentmodulerestrictedshipclasspath",
			roots: []string{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "lgplonfprestricted",
			roots: []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "lgplBin.meta_lic", "restricted_if_statically_linked"},
				{"lgplBin.meta_lic", "apacheLib.meta_lic", "lgplBin.meta_lic", "restricted_if_statically_linked"},
			},
		},
		{
			name:  "lgplonfpdynamicrestricted",
			roots: []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "lgplBin.meta_lic", "restricted_if_statically_linked"},
			},
		},
		{
			name:  "lgplonfpdynamicrestrictedshiplib",
			roots: []string{"lgplBin.meta_lic", "apacheLib.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "lgplBin.meta_lic", "restricted_if_statically_linked"},
			},
		},
		{
			name:  "gplonfprestricted",
			roots: []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"gplBin.meta_lic", "apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:  "gplcontainerrestricted",
			roots: []string{"gplContainer.meta_lic"},
			edges: []annotated{
				{"gplContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplContainer.meta_lic", "gplContainer.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"gplContainer.meta_lic", "apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
			},
		},
		{
			name:  "gploncontainerrestricted",
			roots: []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "gplonbinrestricted",
			roots: []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "gplonfpdynamicrestricted",
			roots: []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:  "gplonfpdynamicrestrictedshiplib",
			roots: []string{"gplBin.meta_lic", "apacheLib.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"gplBin.meta_lic", "apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:  "independentmodulereverserestricted",
			roots: []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "independentmodulereversestaticrestricted",
			roots: []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "dependentmodulereverserestricted",
			roots: []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "dependentmodulereverserestrictedshipdependent",
			roots: []string{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "ponrrestricted",
			roots: []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"proprietary.meta_lic", "proprietary.meta_lic", "gplLib.meta_lic", "restricted"},
				{"proprietary.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:  "ronprestricted",
			roots: []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"gplBin.meta_lic", "proprietary.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:  "noticeonb_e_orestricted",
			roots: []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "b_e_oonnoticerestricted",
			roots: []string{"by_exception.meta_lic"},
			edges: []annotated{
				{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:  "noticeonreciprecip",
			roots: []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mitBin.meta_lic", "mplLib.meta_lic", "mplLib.meta_lic", "reciprocal"},
			},
		},
		{
			name:  "reciponnoticerecip",
			roots: []string{"mplBin.meta_lic"},
			edges: []annotated{
				{"mplBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mplBin.meta_lic", "mplBin.meta_lic", "mplBin.meta_lic", "reciprocal"},
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
			actualRs := ResolveSourceSharing(lg)
			checkResolves(actualRs, expectedRs, t)
		})
	}
}
