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
	"fmt"
	"io"
	"sort"
	"strings"
	"testing"

	"android/soong/tools/compliance/testfs"
)

const (
	// AOSP starts a test metadata file for Android Apache-2.0 licensing.
	AOSP = `` +
		`package_name: "Android"
license_kinds: "SPDX-license-identifier-Apache-2.0"
license_conditions: "notice"
`

	// GPL starts a test metadata file for GPL 2.0 licensing.
	GPL = `` +
		`package_name: "Free Software"
license_kinds: "SPDX-license-identifier-GPL-2.0"
license_conditions: "restricted"
`

	// Classpath starts a test metadata file for GPL 2.0 with classpath exception licensing.
	Classpath = `` +
		`package_name: "Free Software"
license_kinds: "SPDX-license-identifier-GPL-2.0-with-classpath-exception"
license_conditions: "permissive"
`

	// DependentModule starts a test metadata file for a module in the same package as `Classpath`.
	DependentModule = `` +
		`package_name: "Free Software"
license_kinds: "SPDX-license-identifier-MIT"
license_conditions: "notice"
`

	// LGPL starts a test metadata file for a module with LGPL 2.0 licensing.
	LGPL = `` +
		`package_name: "Free Library"
license_kinds: "SPDX-license-identifier-LGPL-2.0"
license_conditions: "restricted_allows_dynamic_linking"
`

	// MPL starts a test metadata file for a module with MPL 2.0 reciprical licensing.
	MPL = `` +
		`package_name: "Reciprocal"
license_kinds: "SPDX-license-identifier-MPL-2.0"
license_conditions: "reciprocal"
`

	// MIT starts a test metadata file for a module with generic notice (MIT) licensing.
	MIT = `` +
		`package_name: "Android"
license_kinds: "SPDX-license-identifier-MIT"
license_conditions: "notice"
`

	// Proprietary starts a test metadata file for a module with proprietary licensing.
	Proprietary = `` +
		`package_name: "Android"
license_kinds: "legacy_proprietary"
license_conditions: "proprietary"
`

	// ByException starts a test metadata file for a module with by_exception_only licensing.
	ByException = `` +
		`package_name: "Special"
license_kinds: "legacy_by_exception_only"
license_conditions: "by_exception_only"
`
)

var (
	// meta maps test file names to metadata file content without dependencies.
	meta = map[string]string{
		"apacheBin.meta_lic":                 AOSP,
		"apacheLib.meta_lic":                 AOSP,
		"apacheContainer.meta_lic":           AOSP + "is_container: true\n",
		"dependentModule.meta_lic":           DependentModule,
		"gplWithClasspathException.meta_lic": Classpath,
		"gplBin.meta_lic":                    GPL,
		"gplLib.meta_lic":                    GPL,
		"gplContainer.meta_lic":              GPL + "is_container: true\n",
		"lgplBin.meta_lic":                   LGPL,
		"lgplLib.meta_lic":                   LGPL,
		"mitBin.meta_lic":                    MIT,
		"mitLib.meta_lic":                    MIT,
		"mplBin.meta_lic":                    MPL,
		"mplLib.meta_lic":                    MPL,
		"proprietary.meta_lic":               Proprietary,
		"by_exception.meta_lic":              ByException,
	}
)

// newTestNode constructs a test node in the license graph.
func newTestNode(lg *LicenseGraph, targetName string) *TargetNode {
	if tn, alreadyExists := lg.targets[targetName]; alreadyExists {
		return tn
	}
	tn := &TargetNode{name: targetName}
	lg.targets[targetName] = tn
	return tn
}

// newTestCondition constructs a test license condition in the license graph.
func newTestCondition(lg *LicenseGraph, targetName string, conditionName string) LicenseCondition {
	tn := newTestNode(lg, targetName)
	cl := LicenseConditionSetFromNames(tn, conditionName).AsList()
	if len(cl) == 0 {
		panic(fmt.Errorf("attempt to create unrecognized condition: %q", conditionName))
	} else if len(cl) != 1 {
		panic(fmt.Errorf("unexpected multiple conditions from condition name: %q: got %d, want 1", conditionName, len(cl)))
	}
	lc := cl[0]
	tn.licenseConditions = tn.licenseConditions.Plus(lc)
	return lc
}

// newTestConditionSet constructs a test license condition set in the license graph.
func newTestConditionSet(lg *LicenseGraph, targetName string, conditionName []string) LicenseConditionSet {
	tn := newTestNode(lg, targetName)
	cs := LicenseConditionSetFromNames(tn, conditionName...)
	if cs.IsEmpty() {
		panic(fmt.Errorf("attempt to create unrecognized condition: %q", conditionName))
	}
	tn.licenseConditions = tn.licenseConditions.Union(cs)
	return cs
}

// edge describes test data edges to define test graphs.
type edge struct {
	target, dep string
}

// String returns a string representation of the edge.
func (e edge) String() string {
	return e.target + " -> " + e.dep
}

// byEdge orders edges by target then dep name then annotations.
type byEdge []edge

// Len returns the count of elements in the slice.
func (l byEdge) Len() int { return len(l) }

// Swap rearranges 2 elements of the slice so that each occupies the other's
// former position.
func (l byEdge) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographically less than
// the `j`th element.
func (l byEdge) Less(i, j int) bool {
	if l[i].target == l[j].target {
		return l[i].dep < l[j].dep
	}
	return l[i].target < l[j].target
}

// annotated describes annotated test data edges to define test graphs.
type annotated struct {
	target, dep string
	annotations []string
}

func (e annotated) String() string {
	if e.annotations != nil {
		return e.target + " -> " + e.dep + " [" + strings.Join(e.annotations, ", ") + "]"
	}
	return e.target + " -> " + e.dep
}

func (e annotated) IsEqualTo(other annotated) bool {
	if e.target != other.target {
		return false
	}
	if e.dep != other.dep {
		return false
	}
	if len(e.annotations) != len(other.annotations) {
		return false
	}
	a1 := append([]string{}, e.annotations...)
	a2 := append([]string{}, other.annotations...)
	for i := 0; i < len(a1); i++ {
		if a1[i] != a2[i] {
			return false
		}
	}
	return true
}

// toGraph converts a list of roots and a list of annotated edges into a test license graph.
func toGraph(stderr io.Writer, roots []string, edges []annotated) (*LicenseGraph, error) {
	deps := make(map[string][]annotated)
	for _, root := range roots {
		deps[root] = []annotated{}
	}
	for _, edge := range edges {
		if prev, ok := deps[edge.target]; ok {
			deps[edge.target] = append(prev, edge)
		} else {
			deps[edge.target] = []annotated{edge}
		}
		if _, ok := deps[edge.dep]; !ok {
			deps[edge.dep] = []annotated{}
		}
	}
	fs := make(testfs.TestFS)
	for file, edges := range deps {
		body := meta[file]
		for _, edge := range edges {
			body += fmt.Sprintf("deps: {\n  file: %q\n", edge.dep)
			for _, ann := range edge.annotations {
				body += fmt.Sprintf("  annotations: %q\n", ann)
			}
			body += "}\n"
		}
		fs[file] = []byte(body)
	}

	return ReadLicenseGraph(&fs, stderr, roots)
}

// logGraph outputs a representation of the graph to a test log.
func logGraph(lg *LicenseGraph, t *testing.T) {
	t.Logf("license graph:")
	t.Logf("  targets:")
	for _, target := range lg.Targets() {
		t.Logf("    %s%s in package %q", target.Name(), target.LicenseConditions().String(), target.PackageName())
	}
	t.Logf("  /targets")
	t.Logf("  edges:")
	for _, edge := range lg.Edges() {
		t.Logf("    %s", edge.String())
	}
	t.Logf("  /edges")
	t.Logf("/license graph")
}

// byAnnotatedEdge orders edges by target then dep name then annotations.
type byAnnotatedEdge []annotated

func (l byAnnotatedEdge) Len() int      { return len(l) }
func (l byAnnotatedEdge) Swap(i, j int) { l[i], l[j] = l[j], l[i] }
func (l byAnnotatedEdge) Less(i, j int) bool {
	if l[i].target == l[j].target {
		if l[i].dep == l[j].dep {
			ai := append([]string{}, l[i].annotations...)
			aj := append([]string{}, l[j].annotations...)
			sort.Strings(ai)
			sort.Strings(aj)
			for k := 0; k < len(ai) && k < len(aj); k++ {
				if ai[k] == aj[k] {
					continue
				}
				return ai[k] < aj[k]
			}
			return len(ai) < len(aj)
		}
		return l[i].dep < l[j].dep
	}
	return l[i].target < l[j].target
}

// act describes test data resolution actions to define test action sets.
type act struct {
	actsOn, origin, condition string
}

// String returns a human-readable string representing the test action.
func (a act) String() string {
	return fmt.Sprintf("%s{%s:%s}", a.actsOn, a.origin, a.condition)
}

// toActionSet converts a list of act test data into a test action set.
func toActionSet(lg *LicenseGraph, data []act) ActionSet {
	as := make(ActionSet)
	for _, a := range data {
		actsOn := newTestNode(lg, a.actsOn)
		cs := newTestConditionSet(lg, a.origin, strings.Split(a.condition, "|"))
		as[actsOn] = cs
	}
	return as
}

// res describes test data resolutions to define test resolution sets.
type res struct {
	attachesTo, actsOn, origin, condition string
}

// toResolutionSet converts a list of res test data into a test resolution set.
func toResolutionSet(lg *LicenseGraph, data []res) ResolutionSet {
	rmap := make(ResolutionSet)
	for _, r := range data {
		attachesTo := newTestNode(lg, r.attachesTo)
		actsOn := newTestNode(lg, r.actsOn)
		if _, ok := rmap[attachesTo]; !ok {
			rmap[attachesTo] = make(ActionSet)
		}
		cs := newTestConditionSet(lg, r.origin, strings.Split(r.condition, ":"))
		rmap[attachesTo][actsOn] |= cs
	}
	return rmap
}

// tcond associates a target name with '|' separated string conditions.
type tcond struct {
	target, conditions string
}

// action represents a single element of an ActionSet for testing.
type action struct {
	target *TargetNode
	cs     LicenseConditionSet
}

// String returns a human-readable string representation of the action.
func (a action) String() string {
	return fmt.Sprintf("%s%s", a.target.Name(), a.cs.String())
}

// actionList represents an array of actions and a total order defined by
// target name followed by license condition set.
type actionList []action

// String returns a human-readable string representation of the list.
func (l actionList) String() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "[")
	sep := ""
	for _, a := range l {
		fmt.Fprintf(&sb, "%s%s", sep, a.String())
		sep = ", "
	}
	fmt.Fprintf(&sb, "]")
	return sb.String()
}

// Len returns the count of elements in the slice.
func (l actionList) Len() int { return len(l) }

// Swap rearranges 2 elements of the slice so that each occupies the other's
// former position.
func (l actionList) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographically less than
// the `j`th element.
func (l actionList) Less(i, j int) bool {
	if l[i].target == l[j].target {
		return l[i].cs < l[j].cs
	}
	return l[i].target.Name() < l[j].target.Name()
}

// asActionList represents the resolved license conditions in a license graph
// as an actionList for comparison in a test.
func asActionList(lg *LicenseGraph) actionList {
	result := make(actionList, 0, len(lg.targets))
	for _, target := range lg.targets {
		cs := target.resolution
		if cs.IsEmpty() {
			continue
		}
		result = append(result, action{target, cs})
	}
	return result
}

// toActionList converts an array of tcond into an actionList for comparison
// in a test.
func toActionList(lg *LicenseGraph, actions []tcond) actionList {
	result := make(actionList, 0, len(actions))
	for _, actn := range actions {
		target := newTestNode(lg, actn.target)
		cs := NewLicenseConditionSet()
		for _, name := range strings.Split(actn.conditions, "|") {
			lc, ok := RecognizedConditionNames[name]
			if !ok {
				panic(fmt.Errorf("Unrecognized test condition name: %q", name))
			}
			cs = cs.Plus(lc)
		}
		result = append(result, action{target, cs})
	}
	return result
}

// confl defines test data for a SourceSharePrivacyConflict as a target name,
// source condition name, privacy condition name triple.
type confl struct {
	sourceNode, share, privacy string
}

// toConflictList converts confl test data into an array of
// SourceSharePrivacyConflict for comparison in a test.
func toConflictList(lg *LicenseGraph, data []confl) []SourceSharePrivacyConflict {
	result := make([]SourceSharePrivacyConflict, 0, len(data))
	for _, c := range data {
		fields := strings.Split(c.share, ":")
		oshare := fields[0]
		cshare := fields[1]
		fields = strings.Split(c.privacy, ":")
		oprivacy := fields[0]
		cprivacy := fields[1]
		result = append(result, SourceSharePrivacyConflict{
			newTestNode(lg, c.sourceNode),
			newTestCondition(lg, oshare, cshare),
			newTestCondition(lg, oprivacy, cprivacy),
		})
	}
	return result
}

// checkSameActions compares an actual action set to an expected action set for a test.
func checkSameActions(lg *LicenseGraph, asActual, asExpected ActionSet, t *testing.T) {
	rsActual := make(ResolutionSet)
	rsExpected := make(ResolutionSet)
	testNode := newTestNode(lg, "test")
	rsActual[testNode] = asActual
	rsExpected[testNode] = asExpected
	checkSame(rsActual, rsExpected, t)
}

// checkSame compares an actual resolution set to an expected resolution set for a test.
func checkSame(rsActual, rsExpected ResolutionSet, t *testing.T) {
	t.Logf("actual resolution set: %s", rsActual.String())
	t.Logf("expected resolution set: %s", rsExpected.String())

	actualTargets := rsActual.AttachesTo()
	sort.Sort(actualTargets)

	expectedTargets := rsExpected.AttachesTo()
	sort.Sort(expectedTargets)

	t.Logf("actual targets: %s", actualTargets.String())
	t.Logf("expected targets: %s", expectedTargets.String())

	for _, target := range expectedTargets {
		if !rsActual.AttachesToTarget(target) {
			t.Errorf("unexpected missing target: got AttachesToTarget(%q) is false, want true", target.name)
			continue
		}
		expectedRl := rsExpected.Resolutions(target)
		sort.Sort(expectedRl)
		actualRl := rsActual.Resolutions(target)
		sort.Sort(actualRl)
		if len(expectedRl) != len(actualRl) {
			t.Errorf("unexpected number of resolutions attach to %q: %d elements, %d elements",
				target.name, len(actualRl), len(expectedRl))
			continue
		}
		for i := 0; i < len(expectedRl); i++ {
			if expectedRl[i].attachesTo.name != actualRl[i].attachesTo.name || expectedRl[i].actsOn.name != actualRl[i].actsOn.name {
				t.Errorf("unexpected resolution attaches to %q at index %d: got %s, want %s",
					target.name, i, actualRl[i].asString(), expectedRl[i].asString())
				continue
			}
			expectedConditions := expectedRl[i].Resolves()
			actualConditions := actualRl[i].Resolves()
			if expectedConditions != actualConditions {
				t.Errorf("unexpected conditions apply to %q acting on %q: got %#v with names %s, want %#v with names %s",
					target.name, expectedRl[i].actsOn.name,
					actualConditions, actualConditions.Names(),
					expectedConditions, expectedConditions.Names())
				continue
			}
		}

	}
	for _, target := range actualTargets {
		if !rsExpected.AttachesToTarget(target) {
			t.Errorf("unexpected extra target: got expected.AttachesTo(%q) is false, want true", target.name)
		}
	}
}

// checkResolvesActions compares an actual action set to an expected action set for a test verifying the actual set
// resolves all of the expected conditions.
func checkResolvesActions(lg *LicenseGraph, asActual, asExpected ActionSet, t *testing.T) {
	rsActual := make(ResolutionSet)
	rsExpected := make(ResolutionSet)
	testNode := newTestNode(lg, "test")
	rsActual[testNode] = asActual
	rsExpected[testNode] = asExpected
	checkResolves(rsActual, rsExpected, t)
}

// checkResolves compares an actual resolution set to an expected resolution set for a test verifying the actual set
// resolves all of the expected conditions.
func checkResolves(rsActual, rsExpected ResolutionSet, t *testing.T) {
	t.Logf("actual resolution set: %s", rsActual.String())
	t.Logf("expected resolution set: %s", rsExpected.String())

	actualTargets := rsActual.AttachesTo()
	sort.Sort(actualTargets)

	expectedTargets := rsExpected.AttachesTo()
	sort.Sort(expectedTargets)

	t.Logf("actual targets: %s", actualTargets.String())
	t.Logf("expected targets: %s", expectedTargets.String())

	for _, target := range expectedTargets {
		if !rsActual.AttachesToTarget(target) {
			t.Errorf("unexpected missing target: got AttachesToTarget(%q) is false, want true", target.name)
			continue
		}
		expectedRl := rsExpected.Resolutions(target)
		sort.Sort(expectedRl)
		actualRl := rsActual.Resolutions(target)
		sort.Sort(actualRl)
		if len(expectedRl) != len(actualRl) {
			t.Errorf("unexpected number of resolutions attach to %q: %d elements, %d elements",
				target.name, len(actualRl), len(expectedRl))
			continue
		}
		for i := 0; i < len(expectedRl); i++ {
			if expectedRl[i].attachesTo.name != actualRl[i].attachesTo.name || expectedRl[i].actsOn.name != actualRl[i].actsOn.name {
				t.Errorf("unexpected resolution attaches to %q at index %d: got %s, want %s",
					target.name, i, actualRl[i].asString(), expectedRl[i].asString())
				continue
			}
			expectedConditions := expectedRl[i].Resolves()
			actualConditions := actualRl[i].Resolves()
			if expectedConditions != (expectedConditions & actualConditions) {
				t.Errorf("expected conditions missing from %q acting on %q: got %#v with names %s, want %#v with names %s",
					target.name, expectedRl[i].actsOn.name,
					actualConditions, actualConditions.Names(),
					expectedConditions, expectedConditions.Names())
				continue
			}
		}

	}
	for _, target := range actualTargets {
		if !rsExpected.AttachesToTarget(target) {
			t.Errorf("unexpected extra target: got expected.AttachesTo(%q) is false, want true", target.name)
		}
	}
}
