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
	"sort"
	"strings"
)

// Resolution describes an action to resolve one or more license conditions.
//
// `AttachesTo` identifies the target node that when distributed triggers the action.
// `ActsOn` identifies the target node that is the object of the action.
// `Resolves` identifies one or more license conditions that the action resolves.
//
// e.g. Suppose an MIT library is linked to a binary that also links to GPL code.
//
// A resolution would attach to the binary to share (act on) the MIT library to
// resolve the restricted condition originating from the GPL code.
type Resolution struct {
	attachesTo, actsOn *TargetNode
	cs                 LicenseConditionSet
}

// AttachesTo returns the target node the resolution attaches to.
func (r Resolution) AttachesTo() *TargetNode {
	return r.attachesTo
}

// ActsOn returns the target node that must be acted on to resolve the condition.
//
// i.e. The node for which notice must be given or whose source must be shared etc.
func (r Resolution) ActsOn() *TargetNode {
	return r.actsOn
}

// Resolves returns the set of license condition the resolution satisfies.
func (r Resolution) Resolves() LicenseConditionSet {
	return r.cs
}

// asString returns a string representation of the resolution.
func (r Resolution) asString() string {
	var sb strings.Builder
	names := r.cs.Names()
	sort.Strings(names)
	fmt.Fprintf(&sb, "%s -> %s{%s}", r.attachesTo.name, r.actsOn.name, strings.Join(names, ", "))
	return sb.String()
}

// ResolutionList represents a partial order of Resolutions ordered by
// AttachesTo() and ActsOn() leaving `Resolves()` unordered.
type ResolutionList []Resolution

// Len returns the count of elements in the list.
func (l ResolutionList) Len() int { return len(l) }

// Swap rearranges 2 elements so that each occupies the other's former position.
func (l ResolutionList) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographically less than tht `j`th.
func (l ResolutionList) Less(i, j int) bool {
	if l[i].attachesTo.name == l[j].attachesTo.name {
		return l[i].actsOn.name < l[j].actsOn.name
	}
	return l[i].attachesTo.name < l[j].attachesTo.name
}

// String returns a string representation of the list.
func (rl ResolutionList) String() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "[")
	sep := ""
	for _, r := range rl {
		fmt.Fprintf(&sb, "%s%s", sep, r.asString())
		sep = ", "
	}
	fmt.Fprintf(&sb, "]")
	return sb.String()
}

// AllConditions returns the union of all license conditions resolved by any
// element of the list.
func (rl ResolutionList) AllConditions() LicenseConditionSet {
	result := NewLicenseConditionSet()
	for _, r := range rl {
		result = result.Union(r.cs)
	}
	return result
}

// ByName returns the sub-list of resolutions resolving conditions matching
// `names`.
func (rl ResolutionList) Matching(conditions LicenseConditionSet) ResolutionList {
	result := make(ResolutionList, 0, rl.CountMatching(conditions))
	for _, r := range rl {
		if r.Resolves().MatchesAnySet(conditions) {
			result = append(result, Resolution{r.attachesTo, r.actsOn, r.cs.MatchingAnySet(conditions)})
		}
	}
	return result
}

// CountMatching returns the number of resolutions resolving conditions matching
// `conditions`.
func (rl ResolutionList) CountMatching(conditions LicenseConditionSet) int {
	c := 0
	for _, r := range rl {
		if r.Resolves().MatchesAnySet(conditions) {
			c++
		}
	}
	return c
}

// ByActsOn returns the sub-list of resolutions matching `actsOn`.
func (rl ResolutionList) ByActsOn(actsOn *TargetNode) ResolutionList {
	result := make(ResolutionList, 0, rl.CountByActsOn(actsOn))
	for _, r := range rl {
		if r.actsOn == actsOn {
			result = append(result, r)
		}
	}
	return result
}

// CountByActsOn returns the number of resolutions matching `actsOn`.
func (rl ResolutionList) CountByActsOn(actsOn *TargetNode) int {
	c := 0
	for _, r := range rl {
		if r.actsOn == actsOn {
			c++
		}
	}
	return c
}
