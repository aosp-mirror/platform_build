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

// actionSet maps `actOn` target nodes to the license conditions the actions resolve.
type actionSet map[*TargetNode]*LicenseConditionSet

// String returns a string representation of the set.
func (as actionSet) String() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "{")
	osep := ""
	for actsOn, cs := range as {
		cl := cs.AsList()
		sort.Sort(cl)
		fmt.Fprintf(&sb, "%s%s -> %s", osep, actsOn.name, cl.String())
		osep = ", "
	}
	fmt.Fprintf(&sb, "}")
	return sb.String()
}

// byName returns the subset of `as` actions where the condition name is in `names`.
func (as actionSet) byName(names ConditionNames) actionSet {
	result := make(actionSet)
	for actsOn, cs := range as {
		bn := cs.ByName(names)
		if bn.IsEmpty() {
			continue
		}
		result[actsOn] = bn
	}
	return result
}

// byActsOn returns the subset of `as` where `actsOn` is in the `reachable` target node set.
func (as actionSet) byActsOn(reachable *TargetNodeSet) actionSet {
	result := make(actionSet)
	for actsOn, cs := range as {
		if !reachable.Contains(actsOn) || cs.IsEmpty() {
			continue
		}
		result[actsOn] = cs.Copy()
	}
	return result
}

// copy returns another actionSet with the same value as `as`
func (as actionSet) copy() actionSet {
	result := make(actionSet)
	for actsOn, cs := range as {
		if cs.IsEmpty() {
			continue
		}
		result[actsOn] = cs.Copy()
	}
	return result
}

// addSet adds all of the actions of `other` if not already present.
func (as actionSet) addSet(other actionSet) {
	for actsOn, cs := range other {
		as.add(actsOn, cs)
	}
}

// add makes the action on `actsOn` to resolve the conditions in `cs` a member of the set.
func (as actionSet) add(actsOn *TargetNode, cs *LicenseConditionSet) {
	if acs, ok := as[actsOn]; ok {
		acs.AddSet(cs)
	} else {
		as[actsOn] = cs.Copy()
	}
}

// addCondition makes the action on `actsOn` to resolve `lc` a member of the set.
func (as actionSet) addCondition(actsOn *TargetNode, lc LicenseCondition) {
	if _, ok := as[actsOn]; !ok {
		as[actsOn] = newLicenseConditionSet()
	}
	as[actsOn].Add(lc)
}

// isEmpty returns true if no action to resolve a condition exists.
func (as actionSet) isEmpty() bool {
	for _, cs := range as {
		if !cs.IsEmpty() {
			return false
		}
	}
	return true
}
