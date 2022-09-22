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

func TestWalkResolutionsForCondition(t *testing.T) {
	tests := []struct {
		name                string
		condition           LicenseConditionSet
		roots               []string
		edges               []annotated
		expectedResolutions []res
	}{
		{
			name:      "firstparty",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:      "notice",
			condition: ImpliesNotice,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mitBin.meta_lic", "mitBin.meta_lic", "mitBin.meta_lic", "notice"},
				{"mitBin.meta_lic", "mitLib.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:      "fponlgplnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "lgplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", "lgplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "fponlgpldynamicnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:      "independentmodulenotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:      "independentmodulerestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "independentmodulestaticnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:      "independentmodulestaticrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "dependentmodulenotice",
			condition: ImpliesNotice,
			roots:     []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"dependentModule.meta_lic", "dependentModule.meta_lic", "dependentModule.meta_lic", "notice"},
			},
		},
		{
			name:      "dependentmodulerestricted",
			condition: ImpliesRestricted,
			roots:     []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "lgplonfpnotice",
			condition: ImpliesNotice,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
				{"lgplBin.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"lgplBin.meta_lic", "apacheLib.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "lgplonfprestricted",
			condition: ImpliesRestricted,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
				{"lgplBin.meta_lic", "apacheLib.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "lgplonfpdynamicnotice",
			condition: ImpliesNotice,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "lgplonfpdynamicrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"gplBin.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"gplBin.meta_lic", "apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfprestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"gplBin.meta_lic", "apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplcontainernotice",
			condition: ImpliesNotice,
			roots:     []string{"gplContainer.meta_lic"},
			edges: []annotated{
				{"gplContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplContainer.meta_lic", "gplContainer.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"gplContainer.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"gplContainer.meta_lic", "apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplcontainerrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplContainer.meta_lic"},
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
			name:      "gploncontainernotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "gploncontainerrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheContainer.meta_lic"},
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
			name:      "gplonbinnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonbinrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "apacheLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheBin.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpdynamicnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpdynamicrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpdynamicrestrictedshipped",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic", "apacheLib.meta_lic"},
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
			name:      "independentmodulereversenotice",
			condition: ImpliesNotice,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:      "independentmodulereverserestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "independentmodulereverserestrictedshipped",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "independentmodulereversestaticnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:      "independentmodulereversestaticrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "dependentmodulereversenotice",
			condition: ImpliesNotice,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:      "dependentmodulereverserestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "dependentmodulereverserestrictedshipped",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "ponrnotice",
			condition: ImpliesNotice,
			roots:     []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"proprietary.meta_lic", "proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
				{"proprietary.meta_lic", "proprietary.meta_lic", "gplLib.meta_lic", "restricted"},
				{"proprietary.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "ponrrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"proprietary.meta_lic", "gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"proprietary.meta_lic", "proprietary.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "ponrproprietary",
			condition: ImpliesProprietary,
			roots:     []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"proprietary.meta_lic", "proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
			},
		},
		{
			name:      "ronpnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"gplBin.meta_lic", "proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
				{"gplBin.meta_lic", "proprietary.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "ronprestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"gplBin.meta_lic", "proprietary.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "ronpproprietary",
			condition: ImpliesProprietary,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"gplBin.meta_lic", "proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
			},
		},
		{
			name:      "noticeonb_e_onotice",
			condition: ImpliesNotice,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mitBin.meta_lic", "mitBin.meta_lic", "mitBin.meta_lic", "notice"},
				{"mitBin.meta_lic", "by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
			},
		},
		{
			name:      "noticeonb_e_orestricted",
			condition: ImpliesRestricted,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "noticeonb_e_ob_e_o",
			condition: ImpliesByExceptionOnly,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mitBin.meta_lic", "by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
			},
		},
		{
			name:      "b_e_oonnoticenotice",
			condition: ImpliesNotice,
			roots:     []string{"by_exception.meta_lic"},
			edges: []annotated{
				{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"by_exception.meta_lic", "by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
				{"by_exception.meta_lic", "mitLib.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:      "b_e_oonnoticerestricted",
			condition: ImpliesRestricted,
			roots:     []string{"by_exception.meta_lic"},
			edges: []annotated{
				{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{},
		},
		{
			name:      "b_e_oonnoticeb_e_o",
			condition: ImpliesByExceptionOnly,
			roots:     []string{"by_exception.meta_lic"},
			edges: []annotated{
				{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"by_exception.meta_lic", "by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
			},
		},
		{
			name:      "noticeonrecipnotice",
			condition: ImpliesNotice,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mitBin.meta_lic", "mitBin.meta_lic", "mitBin.meta_lic", "notice"},
				{"mitBin.meta_lic", "mplLib.meta_lic", "mplLib.meta_lic", "reciprocal"},
			},
		},
		{
			name:      "noticeonreciprecip",
			condition: ImpliesReciprocal,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mplLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mitBin.meta_lic", "mplLib.meta_lic", "mplLib.meta_lic", "reciprocal"},
			},
		},
		{
			name:      "reciponnoticenotice",
			condition: ImpliesNotice,
			roots:     []string{"mplBin.meta_lic"},
			edges: []annotated{
				{"mplBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedResolutions: []res{
				{"mplBin.meta_lic", "mplBin.meta_lic", "mplBin.meta_lic", "reciprocal"},
				{"mplBin.meta_lic", "mitLib.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:      "reciponnoticerecip",
			condition: ImpliesReciprocal,
			roots:     []string{"mplBin.meta_lic"},
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
			ResolveTopDownConditions(lg)
			actualRs := WalkResolutionsForCondition(lg, tt.condition)
			checkResolves(actualRs, expectedRs, t)
		})
	}
}

func TestWalkActionsForCondition(t *testing.T) {
	tests := []struct {
		name            string
		condition       LicenseConditionSet
		roots           []string
		edges           []annotated
		expectedActions []act
	}{
		{
			name:      "firstparty",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
			},
		},
		{
			name:      "notice",
			condition: ImpliesNotice,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"mitBin.meta_lic", "mitBin.meta_lic", "notice"},
				{"mitLib.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:      "fponlgplnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "lgplLib.meta_lic", "restricted"},
				{"lgplLib.meta_lic", "lgplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "fponlgpldynamicnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:      "independentmodulenotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:      "independentmodulerestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "independentmodulestaticnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:      "independentmodulestaticrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "dependentmodulenotice",
			condition: ImpliesNotice,
			roots:     []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"dependentModule.meta_lic", "dependentModule.meta_lic", "notice"},
			},
		},
		{
			name:      "dependentmodulerestricted",
			condition: ImpliesRestricted,
			roots:     []string{"dependentModule.meta_lic"},
			edges: []annotated{
				{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "lgplonfpnotice",
			condition: ImpliesNotice,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheLib.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "lgplonfprestricted",
			condition: ImpliesRestricted,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "lgplonfpdynamicnotice",
			condition: ImpliesNotice,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "lgplonfpdynamicrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"lgplBin.meta_lic"},
			edges: []annotated{
				{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"lgplBin.meta_lic", "lgplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfprestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplcontainernotice",
			condition: ImpliesNotice,
			roots:     []string{"gplContainer.meta_lic"},
			edges: []annotated{
				{"gplContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplContainer.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplcontainerrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplContainer.meta_lic"},
			edges: []annotated{
				{"gplContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplContainer.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "gplContainer.meta_lic", "restricted"},
			},
		},
		{
			name:      "gploncontainernotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"apacheContainer.meta_lic", "apacheContainer.meta_lic", "notice"},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "gploncontainerrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheContainer.meta_lic"},
			edges: []annotated{
				{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheContainer.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"apacheContainer.meta_lic", "gplLib.meta_lic", "restricted"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonbinnotice",
			condition: ImpliesNotice,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
				{"apacheBin.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "apacheLib.meta_lic", "notice"},
				{"apacheLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonbinrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"apacheBin.meta_lic"},
			edges: []annotated{
				{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
				{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"apacheBin.meta_lic", "gplLib.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpdynamicnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpdynamicrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "gplonfpdynamicrestrictedshipped",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic", "apacheLib.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"apacheLib.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "independentmodulereversenotice",
			condition: ImpliesNotice,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:      "independentmodulereverserestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "independentmodulereverserestrictedshipped",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "independentmodulereversestaticnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
				{"apacheBin.meta_lic", "apacheBin.meta_lic", "notice"},
			},
		},
		{
			name:      "independentmodulereversestaticrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"static"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "dependentmodulereversenotice",
			condition: ImpliesNotice,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{
				{"gplWithClasspathException.meta_lic", "gplWithClasspathException.meta_lic", "permissive"},
			},
		},
		{
			name:      "dependentmodulereverserestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "dependentmodulereverserestrictedshipped",
			condition: ImpliesRestricted,
			roots:     []string{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic"},
			edges: []annotated{
				{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "ponrnotice",
			condition: ImpliesNotice,
			roots:     []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
				{"proprietary.meta_lic", "gplLib.meta_lic", "restricted"},
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "ponrrestricted",
			condition: ImpliesRestricted,
			roots:     []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplLib.meta_lic", "gplLib.meta_lic", "restricted"},
				{"proprietary.meta_lic", "gplLib.meta_lic", "restricted"},
			},
		},
		{
			name:      "ponrproprietary",
			condition: ImpliesProprietary,
			roots:     []string{"proprietary.meta_lic"},
			edges: []annotated{
				{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
			},
		},
		{
			name:      "ronpnotice",
			condition: ImpliesNotice,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
				{"proprietary.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "ronprestricted",
			condition: ImpliesRestricted,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"gplBin.meta_lic", "gplBin.meta_lic", "restricted"},
				{"proprietary.meta_lic", "gplBin.meta_lic", "restricted"},
			},
		},
		{
			name:      "ronpproprietary",
			condition: ImpliesProprietary,
			roots:     []string{"gplBin.meta_lic"},
			edges: []annotated{
				{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"proprietary.meta_lic", "proprietary.meta_lic", "proprietary"},
			},
		},
		{
			name:      "noticeonb_e_onotice",
			condition: ImpliesNotice,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"mitBin.meta_lic", "mitBin.meta_lic", "notice"},
				{"by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
			},
		},
		{
			name:      "noticeonb_e_orestricted",
			condition: ImpliesRestricted,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "noticeonb_e_ob_e_o",
			condition: ImpliesByExceptionOnly,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
			},
		},
		{
			name:      "b_e_oonnoticenotice",
			condition: ImpliesNotice,
			roots:     []string{"by_exception.meta_lic"},
			edges: []annotated{
				{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
				{"mitLib.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:      "b_e_oonnoticerestricted",
			condition: ImpliesRestricted,
			roots:     []string{"by_exception.meta_lic"},
			edges: []annotated{
				{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{},
		},
		{
			name:      "b_e_oonnoticeb_e_o",
			condition: ImpliesByExceptionOnly,
			roots:     []string{"by_exception.meta_lic"},
			edges: []annotated{
				{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"by_exception.meta_lic", "by_exception.meta_lic", "by_exception_only"},
			},
		},
		{
			name:      "noticeonrecipnotice",
			condition: ImpliesNotice,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"mitBin.meta_lic", "mitBin.meta_lic", "notice"},
				{"mplLib.meta_lic", "mplLib.meta_lic", "reciprocal"},
			},
		},
		{
			name:      "noticeonreciprecip",
			condition: ImpliesReciprocal,
			roots:     []string{"mitBin.meta_lic"},
			edges: []annotated{
				{"mitBin.meta_lic", "mplLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"mplLib.meta_lic", "mplLib.meta_lic", "reciprocal"},
			},
		},
		{
			name:      "reciponnoticenotice",
			condition: ImpliesNotice,
			roots:     []string{"mplBin.meta_lic"},
			edges: []annotated{
				{"mplBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"mplBin.meta_lic", "mplBin.meta_lic", "reciprocal"},
				{"mitLib.meta_lic", "mitLib.meta_lic", "notice"},
			},
		},
		{
			name:      "reciponnoticerecip",
			condition: ImpliesReciprocal,
			roots:     []string{"mplBin.meta_lic"},
			edges: []annotated{
				{"mplBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			},
			expectedActions: []act{
				{"mplBin.meta_lic", "mplBin.meta_lic", "reciprocal"},
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
			expectedAs := toActionSet(lg, tt.expectedActions)
			ResolveTopDownConditions(lg)
			actualAs := WalkActionsForCondition(lg, tt.condition)
			checkResolvesActions(lg, actualAs, expectedAs, t)
		})
	}
}
