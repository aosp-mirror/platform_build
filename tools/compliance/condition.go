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

// LicenseCondition describes an individual license condition or requirement
// originating at a specific target node. (immutable)
//
// e.g. A module licensed under GPL terms would originate a `restricted` condition.
type LicenseCondition struct {
	name   string
	origin *TargetNode
}

// Name returns the name of the condition. e.g. "restricted" or "notice"
func (lc LicenseCondition) Name() string {
	return lc.name
}

// Origin identifies the TargetNode where the condition originates.
func (lc LicenseCondition) Origin() *TargetNode {
	return lc.origin
}

// asString returns a string representation of a license condition:
// origin+separator+condition.
func (lc LicenseCondition) asString(separator string) string {
	return lc.origin.name + separator + lc.name
}

// ConditionList implements introspection methods to arrays of LicenseCondition.
type ConditionList []LicenseCondition


// ConditionList orders arrays of LicenseCondition by Origin and Name.

// Len returns the length of the list.
func (l ConditionList) Len() int      { return len(l) }

// Swap rearranges 2 elements in the list so each occupies the other's former position.
func (l ConditionList) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographically less than tht `j`th element.
func (l ConditionList) Less(i, j int) bool {
	if l[i].origin.name == l[j].origin.name {
		return l[i].name < l[j].name
	}
	return l[i].origin.name < l[j].origin.name
}

// String returns a string representation of the set.
func (cl ConditionList) String() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "[")
	sep := ""
	for _, lc := range cl {
		fmt.Fprintf(&sb, "%s%s:%s", sep, lc.origin.name, lc.name)
		sep = ", "
	}
	fmt.Fprintf(&sb, "]")
	return sb.String()
}

// HasByName returns true if the list contains any condition matching `name`.
func (cl ConditionList) HasByName(name ConditionNames) bool {
	for _, lc := range cl {
		if name.Contains(lc.name) {
			return true
		}
	}
	return false
}

// ByName returns the sublist of conditions that match `name`.
func (cl ConditionList) ByName(name ConditionNames) ConditionList {
	result := make(ConditionList, 0, cl.CountByName(name))
	for _, lc := range cl {
		if name.Contains(lc.name) {
			result = append(result, lc)
		}
	}
	return result
}

// CountByName returns the size of the sublist of conditions that match `name`.
func (cl ConditionList) CountByName(name ConditionNames) int {
	size := 0
	for _, lc := range cl {
		if name.Contains(lc.name) {
			size++
		}
	}
	return size
}

// HasByOrigin returns true if the list contains any condition originating at `origin`.
func (cl ConditionList) HasByOrigin(origin *TargetNode) bool {
	for _, lc := range cl {
		if lc.origin.name == origin.name {
			return true
		}
	}
	return false
}

// ByOrigin returns the sublist of conditions that originate at `origin`.
func (cl ConditionList) ByOrigin(origin *TargetNode) ConditionList {
	result := make(ConditionList, 0, cl.CountByOrigin(origin))
	for _, lc := range cl {
		if lc.origin.name == origin.name {
			result = append(result, lc)
		}
	}
	return result
}

// CountByOrigin returns the size of the sublist of conditions that originate at `origin`.
func (cl ConditionList) CountByOrigin(origin *TargetNode) int {
	size := 0
	for _, lc := range cl {
		if lc.origin.name == origin.name {
			size++
		}
	}
	return size
}

// ConditionNames implements the Contains predicate for slices of condition
// name strings.
type ConditionNames []string

// Contains returns true if the name matches one of the ConditionNames.
func (cn ConditionNames) Contains(name string) bool {
	for _, cname := range cn {
		if cname == name {
			return true
		}
	}
	return false
}
