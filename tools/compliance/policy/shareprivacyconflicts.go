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

// SourceSharePrivacyConflict describes an individual conflict between a source-sharing
// condition and a source privacy condition
type SourceSharePrivacyConflict struct {
	SourceNode       *TargetNode
	ShareCondition   LicenseCondition
	PrivacyCondition LicenseCondition
}

// Error returns a string describing the conflict.
func (conflict SourceSharePrivacyConflict) Error() string {
	return fmt.Sprintf("%s %s from %s and must share from %s %s\n",
		conflict.SourceNode.name,
		conflict.PrivacyCondition.name, conflict.PrivacyCondition.origin.name,
		conflict.ShareCondition.name, conflict.ShareCondition.origin.name)
}

// IsEqualTo returns true when `conflict` and `other` describe the same conflict.
func (conflict SourceSharePrivacyConflict) IsEqualTo(other SourceSharePrivacyConflict) bool {
	return conflict.SourceNode.name == other.SourceNode.name &&
		conflict.ShareCondition.name == other.ShareCondition.name &&
		conflict.ShareCondition.origin.name == other.ShareCondition.origin.name &&
		conflict.PrivacyCondition.name == other.PrivacyCondition.name &&
		conflict.PrivacyCondition.origin.name == other.PrivacyCondition.origin.name
}

// ConflictingSharedPrivateSource lists all of the targets where conflicting conditions to
// share the source and to keep the source private apply to the target.
func ConflictingSharedPrivateSource(lg *LicenseGraph) []SourceSharePrivacyConflict {
	// shareSource is the set of all source-sharing resolutions.
	shareSource := ResolveSourceSharing(lg)
	if shareSource.IsEmpty() {
		return []SourceSharePrivacyConflict{}
	}

	// privateSource is the set of all source privacy resolutions.
	privateSource := ResolveSourcePrivacy(lg)
	if privateSource.IsEmpty() {
		return []SourceSharePrivacyConflict{}
	}

	// combined is the combination of source-sharing and source privacy.
	combined := JoinResolutionSets(shareSource, privateSource)

	// size is the size of the result
	size := 0
	for _, actsOn := range combined.ActsOn() {
		rl := combined.ResolutionsByActsOn(actsOn)
		size += rl.CountConditionsByName(ImpliesShared) * rl.CountConditionsByName(ImpliesPrivate)
	}
	if size == 0 {
		return []SourceSharePrivacyConflict{}
	}
	result := make([]SourceSharePrivacyConflict, 0, size)
	for _, actsOn := range combined.ActsOn() {
		rl := combined.ResolutionsByActsOn(actsOn)
		if len(rl) == 0 {
			continue
		}

		pconditions := rl.ByName(ImpliesPrivate).AllConditions().AsList()
		ssconditions := rl.ByName(ImpliesShared).AllConditions().AsList()

		// report all conflicting condition combinations
		for _, p := range pconditions {
			for _, ss := range ssconditions {
				result = append(result, SourceSharePrivacyConflict{actsOn, ss, p})
			}
		}
	}
	return result
}
