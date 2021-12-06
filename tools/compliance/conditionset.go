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
)

// NewLicenseConditionSet creates a new instance or variable of *LicenseConditionSet.
func NewLicenseConditionSet(conditions ...LicenseCondition) *LicenseConditionSet {
	cs := newLicenseConditionSet()
	cs.Add(conditions...)
	return cs
}

// LicenseConditionSet describes a mutable set of immutable license conditions.
type LicenseConditionSet struct {
	// conditions describes the set of license conditions i.e. (condition name, origin target) pairs
	// by mapping condition name -> origin target -> true.
	conditions map[string]map[*TargetNode]bool
}

// Add makes all `conditions` members of the set if they were not previously.
func (cs *LicenseConditionSet) Add(conditions ...LicenseCondition) {
	if len(conditions) == 0 {
		return
	}
	for _, lc := range conditions {
		if _, ok := cs.conditions[lc.name]; !ok {
			cs.conditions[lc.name] = make(map[*TargetNode]bool)
		}
		cs.conditions[lc.name][lc.origin] = true
	}
}

// AddSet makes all elements of `conditions` members of the set if they were not previously.
func (cs *LicenseConditionSet) AddSet(other *LicenseConditionSet) {
	if len(other.conditions) == 0 {
		return
	}
	for name, origins := range other.conditions {
		if len(origins) == 0 {
			continue
		}
		if _, ok := cs.conditions[name]; !ok {
			cs.conditions[name] = make(map[*TargetNode]bool)
		}
		for origin := range origins {
			cs.conditions[name][origin] = other.conditions[name][origin]
		}
	}
}

// ByName returns a list of the conditions in the set matching `names`.
func (cs *LicenseConditionSet) ByName(names ...ConditionNames) *LicenseConditionSet {
	other := newLicenseConditionSet()
	for _, cn := range names {
		for _, name := range cn {
			if origins, ok := cs.conditions[name]; ok {
				other.conditions[name] = make(map[*TargetNode]bool)
				for origin := range origins {
					other.conditions[name][origin] = true
				}
			}
		}
	}
	return other
}

// HasAnyByName returns true if the set contains any conditions matching `names` originating at any target.
func (cs *LicenseConditionSet) HasAnyByName(names ...ConditionNames) bool {
	for _, cn := range names {
		for _, name := range cn {
			if origins, ok := cs.conditions[name]; ok {
				if len(origins) > 0 {
					return true
				}
			}
		}
	}
	return false
}

// CountByName returns the number of conditions matching `names` originating at any target.
func (cs *LicenseConditionSet) CountByName(names ...ConditionNames) int {
	size := 0
	for _, cn := range names {
		for _, name := range cn {
			if origins, ok := cs.conditions[name]; ok {
				size += len(origins)
			}
		}
	}
	return size
}

// ByOrigin returns all of the conditions that originate at `origin` regardless of name.
func (cs *LicenseConditionSet) ByOrigin(origin *TargetNode) *LicenseConditionSet {
	other := newLicenseConditionSet()
	for name, origins := range cs.conditions {
		if _, ok := origins[origin]; ok {
			other.conditions[name] = make(map[*TargetNode]bool)
			other.conditions[name][origin] = true
		}
	}
	return other
}

// HasAnyByOrigin returns true if the set contains any conditions originating at `origin` regardless of condition name.
func (cs *LicenseConditionSet) HasAnyByOrigin(origin *TargetNode) bool {
	for _, origins := range cs.conditions {
		if _, ok := origins[origin]; ok {
			return true
		}
	}
	return false
}

// CountByOrigin returns the number of conditions originating at `origin` regardless of condition name.
func (cs *LicenseConditionSet) CountByOrigin(origin *TargetNode) int {
	size := 0
	for _, origins := range cs.conditions {
		if _, ok := origins[origin]; ok {
			size++
		}
	}
	return size
}

// AsList returns a list of all the conditions in the set.
func (cs *LicenseConditionSet) AsList() ConditionList {
	result := make(ConditionList, 0, cs.Count())
	for name, origins := range cs.conditions {
		for origin := range origins {
			result = append(result, LicenseCondition{name, origin})
		}
	}
	return result
}

// Count returns the number of conditions in the set.
func (cs *LicenseConditionSet) Count() int {
	size := 0
	for _, origins := range cs.conditions {
		size += len(origins)
	}
	return size
}

// Copy creates a new LicenseCondition variable with the same value.
func (cs *LicenseConditionSet) Copy() *LicenseConditionSet {
	other := newLicenseConditionSet()
	for name := range cs.conditions {
		other.conditions[name] = make(map[*TargetNode]bool)
		for origin := range cs.conditions[name] {
			other.conditions[name][origin] = cs.conditions[name][origin]
		}
	}
	return other
}

// HasCondition returns true if the set contains any condition matching both `names` and `origin`.
func (cs *LicenseConditionSet) HasCondition(names ConditionNames, origin *TargetNode) bool {
	for _, name := range names {
		if origins, ok := cs.conditions[name]; ok {
			_, isPresent := origins[origin]
			if isPresent {
				return true
			}
		}
	}
	return false
}

// IsEmpty returns true when the set of conditions contains zero elements.
func (cs *LicenseConditionSet) IsEmpty() bool {
	for _, origins := range cs.conditions {
		if 0 < len(origins) {
			return false
		}
	}
	return true
}

// RemoveAllByName changes the set to delete all conditions matching `names`.
func (cs *LicenseConditionSet) RemoveAllByName(names ...ConditionNames) {
	for _, cn := range names {
		for _, name := range cn {
			delete(cs.conditions, name)
		}
	}
}

// Remove changes the set to delete `conditions`.
func (cs *LicenseConditionSet) Remove(conditions ...LicenseCondition) {
	for _, lc := range conditions {
		if _, isPresent := cs.conditions[lc.name]; !isPresent {
			panic(fmt.Errorf("attempt to remove non-existent condition: %q", lc.asString(":")))
		}
		if _, isPresent := cs.conditions[lc.name][lc.origin]; !isPresent {
			panic(fmt.Errorf("attempt to remove non-existent origin: %q", lc.asString(":")))
		}
		delete(cs.conditions[lc.name], lc.origin)
	}
}

// removeSet changes the set to delete all conditions also present in `other`.
func (cs *LicenseConditionSet) RemoveSet(other *LicenseConditionSet) {
	for name, origins := range other.conditions {
		if _, isPresent := cs.conditions[name]; !isPresent {
			continue
		}
		for origin := range origins {
			delete(cs.conditions[name], origin)
		}
	}
}

// compliance-only LicenseConditionSet methods

// newLicenseConditionSet constructs a set of `conditions`.
func newLicenseConditionSet() *LicenseConditionSet {
	return &LicenseConditionSet{make(map[string]map[*TargetNode]bool)}
}

// add changes the set to include each element of `conditions` originating at `origin`.
func (cs *LicenseConditionSet) add(origin *TargetNode, conditions ...string) {
	for _, name := range conditions {
		if _, ok := cs.conditions[name]; !ok {
			cs.conditions[name] = make(map[*TargetNode]bool)
		}
		cs.conditions[name][origin] = true
	}
}

// asStringList returns the conditions in the set as `separator`-separated (origin, condition-name) pair strings.
func (cs *LicenseConditionSet) asStringList(separator string) []string {
	result := make([]string, 0, cs.Count())
	for name, origins := range cs.conditions {
		for origin := range origins {
			result = append(result, origin.name+separator+name)
		}
	}
	return result
}

// conditionNamesArray implements a `contains` predicate for arrays of ConditionNames
type conditionNamesArray []ConditionNames

func (cn conditionNamesArray) contains(name string) bool {
	for _, names := range cn {
		if names.Contains(name) {
			return true
		}
	}
	return false
}
