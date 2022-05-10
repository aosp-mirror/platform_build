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
	"strings"
)

// LicenseConditionSet identifies sets of license conditions.
type LicenseConditionSet LicenseCondition

// AllLicenseConditions is the set of all recognized license conditions.
const AllLicenseConditions = LicenseConditionSet(LicenseConditionMask)

// NewLicenseConditionSet returns a set containing exactly the elements of
// `conditions`.
func NewLicenseConditionSet(conditions ...LicenseCondition) LicenseConditionSet {
	cs := LicenseConditionSet(0x00)
	for _, lc := range conditions {
		cs |= LicenseConditionSet(lc)
	}
	return cs
}

// Plus returns a new set containing all of the elements of `cs` and all of the
// `conditions`.
func (cs LicenseConditionSet) Plus(conditions ...LicenseCondition) LicenseConditionSet {
	result := cs
	for _, lc := range conditions {
		result |= LicenseConditionSet(lc)
	}
	return result
}

// Union returns a new set containing all of the elements of `cs` and all of the
// elements of the `other` sets.
func (cs LicenseConditionSet) Union(other ...LicenseConditionSet) LicenseConditionSet {
	result := cs
	for _, ls := range other {
		result |= ls
	}
	return result
}

// MatchingAny returns the subset of `cs` equal to any of the `conditions`.
func (cs LicenseConditionSet) MatchingAny(conditions ...LicenseCondition) LicenseConditionSet {
	result := LicenseConditionSet(0x00)
	for _, lc := range conditions {
		result |= cs & LicenseConditionSet(lc)
	}
	return result
}

// MatchingAnySet returns the subset of `cs` that are members of any of the
// `other` sets.
func (cs LicenseConditionSet) MatchingAnySet(other ...LicenseConditionSet) LicenseConditionSet {
	result := LicenseConditionSet(0x00)
	for _, ls := range other {
		result |= cs & ls
	}
	return result
}

// HasAny returns true when `cs` contains at least one of the `conditions`.
func (cs LicenseConditionSet) HasAny(conditions ...LicenseCondition) bool {
	for _, lc := range conditions {
		if 0x0000 != (cs & LicenseConditionSet(lc)) {
			return true
		}
	}
	return false
}

// MatchesAnySet returns true when `cs` has a non-empty intersection with at
// least one of the `other` condition sets.
func (cs LicenseConditionSet) MatchesAnySet(other ...LicenseConditionSet) bool {
	for _, ls := range other {
		if 0x0000 != (cs & ls) {
			return true
		}
	}
	return false
}

// HasAll returns true when `cs` contains every one of the `conditions`.
func (cs LicenseConditionSet) HasAll(conditions ...LicenseCondition) bool {
	for _, lc := range conditions {
		if 0x0000 == (cs & LicenseConditionSet(lc)) {
			return false
		}
	}
	return true
}

// MatchesEverySet returns true when `cs` has a non-empty intersection with
// each of the `other` condition sets.
func (cs LicenseConditionSet) MatchesEverySet(other ...LicenseConditionSet) bool {
	for _, ls := range other {
		if 0x0000 == (cs & ls) {
			return false
		}
	}
	return true
}

// Intersection returns the subset of `cs` that are members of every `other`
// set.
func (cs LicenseConditionSet) Intersection(other ...LicenseConditionSet) LicenseConditionSet {
	result := cs
	for _, ls := range other {
		result &= ls
	}
	return result
}

// Minus returns the subset of `cs` that are not equaal to any `conditions`.
func (cs LicenseConditionSet) Minus(conditions ...LicenseCondition) LicenseConditionSet {
	result := cs
	for _, lc := range conditions {
		result &^= LicenseConditionSet(lc)
	}
	return result
}

// Difference returns the subset of `cs` that are not members of any `other`
// set.
func (cs LicenseConditionSet) Difference(other ...LicenseConditionSet) LicenseConditionSet {
	result := cs
	for _, ls := range other {
		result &^= ls
	}
	return result
}

// Len returns the number of license conditions in the set.
func (cs LicenseConditionSet) Len() int {
	size := 0
	for lc := LicenseConditionSet(0x01); 0x00 != (AllLicenseConditions & lc); lc <<= 1 {
		if 0x00 != (cs & lc) {
			size++
		}
	}
	return size
}

// AsList returns an array of the license conditions in the set.
func (cs LicenseConditionSet) AsList() []LicenseCondition {
	result := make([]LicenseCondition, 0, cs.Len())
	for lc := LicenseConditionSet(0x01); 0x00 != (AllLicenseConditions & lc); lc <<= 1 {
		if 0x00 != (cs & lc) {
			result = append(result, LicenseCondition(lc))
		}
	}
	return result
}

// Names returns an array of the names of the license conditions in the set.
func (cs LicenseConditionSet) Names() []string {
	result := make([]string, 0, cs.Len())
	for lc := LicenseConditionSet(0x01); 0x00 != (AllLicenseConditions & lc); lc <<= 1 {
		if 0x00 != (cs & lc) {
			result = append(result, LicenseCondition(lc).Name())
		}
	}
	return result
}

// IsEmpty returns true when the set contains no license conditions.
func (cs LicenseConditionSet) IsEmpty() bool {
	return 0x00 == (cs & AllLicenseConditions)
}

// String returns a human-readable string representation of the set.
func (cs LicenseConditionSet) String() string {
	return fmt.Sprintf("{%s}", strings.Join(cs.Names(), "|"))
}
