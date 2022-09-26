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
	"fmt"
	"sort"
	"strings"
	"testing"
)

func TestPolicy_edgeConditions(t *testing.T) {
	tests := []struct {
		name                     string
		edge                     annotated
		treatAsAggregate         bool
		otherCondition           string
		expectedDepActions       []string
		expectedTargetConditions []string
	}{
		{
			name:                     "firstparty",
			edge:                     annotated{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "notice",
			edge:                     annotated{"mitBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name: "fponlgpl",
			edge: annotated{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"static"}},
			expectedDepActions: []string{
				"apacheBin.meta_lic:lgplLib.meta_lic:restricted_allows_dynamic_linking",
				"lgplLib.meta_lic:lgplLib.meta_lic:restricted_allows_dynamic_linking",
			},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "fponlgpldynamic",
			edge:                     annotated{"apacheBin.meta_lic", "lgplLib.meta_lic", []string{"dynamic"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name: "fpongpl",
			edge: annotated{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"static"}},
			expectedDepActions: []string{
				"apacheBin.meta_lic:gplLib.meta_lic:restricted",
				"gplLib.meta_lic:gplLib.meta_lic:restricted",
			},
			expectedTargetConditions: []string{},
		},
		{
			name: "fpongpldynamic",
			edge: annotated{"apacheBin.meta_lic", "gplLib.meta_lic", []string{"dynamic"}},
			expectedDepActions: []string{
				"apacheBin.meta_lic:gplLib.meta_lic:restricted",
				"gplLib.meta_lic:gplLib.meta_lic:restricted",
			},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "independentmodule",
			edge:                     annotated{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name: "independentmodulestatic",
			edge: annotated{"apacheBin.meta_lic", "gplWithClasspathException.meta_lic", []string{"static"}},
			expectedDepActions: []string{},
			expectedTargetConditions: []string{},
		},
		{
			name: "dependentmodule",
			edge: annotated{"dependentModule.meta_lic", "gplWithClasspathException.meta_lic", []string{"dynamic"}},
			expectedDepActions: []string{},
			expectedTargetConditions: []string{},
		},

		{
			name:                     "lgplonfp",
			edge:                     annotated{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{"lgplBin.meta_lic:restricted_allows_dynamic_linking"},
		},
		{
			name:                     "lgplonfpdynamic",
			edge:                     annotated{"lgplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "gplonfp",
			edge:                     annotated{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{"gplBin.meta_lic:restricted"},
		},
		{
			name:                     "gplcontainer",
			edge:                     annotated{"gplContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			treatAsAggregate:         true,
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{"gplContainer.meta_lic:restricted"},
		},
		{
			name:             "gploncontainer",
			edge:             annotated{"apacheContainer.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			treatAsAggregate: true,
			otherCondition:   "gplLib.meta_lic:restricted",
			expectedDepActions: []string{
				"apacheContainer.meta_lic:gplLib.meta_lic:restricted",
				"apacheLib.meta_lic:gplLib.meta_lic:restricted",
				"gplLib.meta_lic:gplLib.meta_lic:restricted",
			},
			expectedTargetConditions: []string{},
		},
		{
			name:             "gplonbin",
			edge:             annotated{"apacheBin.meta_lic", "apacheLib.meta_lic", []string{"static"}},
			treatAsAggregate: false,
			otherCondition:   "gplLib.meta_lic:restricted",
			expectedDepActions: []string{
				"apacheBin.meta_lic:gplLib.meta_lic:restricted",
				"apacheLib.meta_lic:gplLib.meta_lic:restricted",
				"gplLib.meta_lic:gplLib.meta_lic:restricted",
			},
			expectedTargetConditions: []string{"gplLib.meta_lic:restricted"},
		},
		{
			name:                     "gplonfpdynamic",
			edge:                     annotated{"gplBin.meta_lic", "apacheLib.meta_lic", []string{"dynamic"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{"gplBin.meta_lic:restricted"},
		},
		{
			name:                     "independentmodulereverse",
			edge:                     annotated{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"dynamic"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "independentmodulereversestatic",
			edge:                     annotated{"gplWithClasspathException.meta_lic", "apacheBin.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "dependentmodulereverse",
			edge:                     annotated{"gplWithClasspathException.meta_lic", "dependentModule.meta_lic", []string{"dynamic"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name: "ponr",
			edge: annotated{"proprietary.meta_lic", "gplLib.meta_lic", []string{"static"}},
			expectedDepActions: []string{
				"proprietary.meta_lic:gplLib.meta_lic:restricted",
				"gplLib.meta_lic:gplLib.meta_lic:restricted",
			},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "ronp",
			edge:                     annotated{"gplBin.meta_lic", "proprietary.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{"gplBin.meta_lic:restricted"},
		},
		{
			name:                     "noticeonb_e_o",
			edge:                     annotated{"mitBin.meta_lic", "by_exception.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "b_e_oonnotice",
			edge:                     annotated{"by_exception.meta_lic", "mitLib.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "noticeonrecip",
			edge:                     annotated{"mitBin.meta_lic", "mplLib.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
		{
			name:                     "reciponnotice",
			edge:                     annotated{"mplBin.meta_lic", "mitLib.meta_lic", []string{"static"}},
			expectedDepActions:       []string{},
			expectedTargetConditions: []string{},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fs := make(testFS)
			stderr := &bytes.Buffer{}
			target := meta[tt.edge.target] + fmt.Sprintf("deps: {\n  file: \"%s\"\n", tt.edge.dep)
			for _, ann := range tt.edge.annotations {
				target += fmt.Sprintf("  annotations: \"%s\"\n", ann)
			}
			fs[tt.edge.target] = []byte(target + "}\n")
			fs[tt.edge.dep] = []byte(meta[tt.edge.dep])
			lg, err := ReadLicenseGraph(&fs, stderr, []string{tt.edge.target})
			if err != nil {
				t.Errorf("unexpected error reading graph: %s", err)
				return
			}
			edge := lg.Edges()[0]
			// simulate a condition inherited from another edge/dependency.
			otherTarget := ""
			otherCondition := ""
			var otn *TargetNode
			if len(tt.otherCondition) > 0 {
				fields := strings.Split(tt.otherCondition, ":")
				otherTarget = fields[0]
				otherCondition = fields[1]
				otn = &TargetNode{name: otherTarget}
				// other target must exist in graph
				lg.targets[otherTarget] = otn
				otn.licenseConditions = LicenseConditionSet(RecognizedConditionNames[otherCondition])
			}
			targets := make(map[string]*TargetNode)
			targets[edge.target.name] = edge.target
			targets[edge.dependency.name] = edge.dependency
			if otn != nil {
				targets[otn.name] = otn
			}
			if tt.expectedDepActions != nil {
				t.Run("depConditionsPropagatingToTarget", func(t *testing.T) {
					depConditions := edge.dependency.LicenseConditions()
					if otherTarget != "" {
						// simulate a sub-dependency's condition having already propagated up to dep and about to go to target
						otherCs := otn.LicenseConditions()
						depConditions |= otherCs
					}
					t.Logf("calculate target actions for edge=%s, dep conditions=%#v %s, treatAsAggregate=%v", edge.String(), depConditions, depConditions, tt.treatAsAggregate)
					csActual := depConditionsPropagatingToTarget(lg, edge, depConditions, tt.treatAsAggregate)
					t.Logf("calculated target conditions as %#v %s", csActual, csActual)
					csExpected := NewLicenseConditionSet()
					for _, triple := range tt.expectedDepActions {
						fields := strings.Split(triple, ":")
						expectedConditions := NewLicenseConditionSet()
						for _, cname := range fields[2:] {
							expectedConditions = expectedConditions.Plus(RecognizedConditionNames[cname])
						}
						csExpected |= expectedConditions
					}
					t.Logf("expected target conditions as %#v %s", csExpected, csExpected)
					if csActual != csExpected {
						t.Errorf("unexpected license conditions: got %#v, want %#v", csActual, csExpected)
					}
				})
			}
			if tt.expectedTargetConditions != nil {
				t.Run("targetConditionsPropagatingToDep", func(t *testing.T) {
					targetConditions := edge.target.LicenseConditions()
					if otherTarget != "" {
						targetConditions = targetConditions.Union(otn.licenseConditions)
					}
					t.Logf("calculate dep conditions for edge=%s, target conditions=%v, treatAsAggregate=%v", edge.String(), targetConditions.Names(), tt.treatAsAggregate)
					cs := targetConditionsPropagatingToDep(lg, edge, targetConditions, tt.treatAsAggregate, AllResolutions)
					t.Logf("calculated dep conditions as %v", cs.Names())
					actual := cs.Names()
					sort.Strings(actual)
					expected := make([]string, 0)
					for _, expectedDepCondition := range tt.expectedTargetConditions {
						expected = append(expected, strings.Split(expectedDepCondition, ":")[1])
					}
					sort.Strings(expected)
					if len(actual) != len(expected) {
						t.Errorf("unexpected number of target conditions: got %v with %d conditions, want %v with %d conditions",
							actual, len(actual), expected, len(expected))
					} else {
						for i := 0; i < len(actual); i++ {
							if actual[i] != expected[i] {
								t.Errorf("unexpected target condition at element %d: got %q, want %q",
									i, actual[i], expected[i])
							}
						}
					}
				})
			}
		})
	}
}
