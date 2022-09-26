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

// LicenseCondition identifies a recognized license condition by setting the
// corresponding bit.
type LicenseCondition uint16

// LicenseConditionMask is a bitmask for the recognized license conditions.
const LicenseConditionMask = LicenseCondition(0x1ff)

const (
	// UnencumberedCondition identifies public domain or public domain-
	// like license that disclaims copyright.
	UnencumberedCondition = LicenseCondition(0x0001)
	// PermissiveCondition identifies a license without notice or other
	// significant requirements.
	PermissiveCondition = LicenseCondition(0x0002)
	// NoticeCondition identifies a typical open-source license with only
	// notice or attribution requirements.
	NoticeCondition = LicenseCondition(0x0004)
	// ReciprocalCondition identifies a license with requirement to share
	// the module's source only.
	ReciprocalCondition = LicenseCondition(0x0008)
	// RestrictedCondition identifies a license with requirement to share
	// all source code linked to the module's source.
	RestrictedCondition = LicenseCondition(0x0010)
	// WeaklyRestrictedCondition identifies a RestrictedCondition waived
	// for dynamic linking.
	WeaklyRestrictedCondition = LicenseCondition(0x0020)
	// ProprietaryCondition identifies a license with source privacy
	// requirements.
	ProprietaryCondition = LicenseCondition(0x0040)
	// ByExceptionOnly identifies a license where policy requires product
	// counsel review prior to use.
	ByExceptionOnlyCondition = LicenseCondition(0x0080)
	// NotAllowedCondition identifies a license with onerous conditions
	// where policy prohibits use.
	NotAllowedCondition = LicenseCondition(0x0100)
)

var (
	// RecognizedConditionNames maps condition strings to LicenseCondition.
	RecognizedConditionNames = map[string]LicenseCondition{
		"unencumbered":                        UnencumberedCondition,
		"permissive":                          PermissiveCondition,
		"notice":                              NoticeCondition,
		"reciprocal":                          ReciprocalCondition,
		"restricted":                          RestrictedCondition,
		"restricted_allows_dynamic_linking":   WeaklyRestrictedCondition,
		"proprietary":                         ProprietaryCondition,
		"by_exception_only":                   ByExceptionOnlyCondition,
		"not_allowed":                         NotAllowedCondition,
	}
)

// Name returns the condition string corresponding to the LicenseCondition.
func (lc LicenseCondition) Name() string {
	switch lc {
	case UnencumberedCondition:
		return "unencumbered"
	case PermissiveCondition:
		return "permissive"
	case NoticeCondition:
		return "notice"
	case ReciprocalCondition:
		return "reciprocal"
	case RestrictedCondition:
		return "restricted"
	case WeaklyRestrictedCondition:
		return "restricted_allows_dynamic_linking"
	case ProprietaryCondition:
		return "proprietary"
	case ByExceptionOnlyCondition:
		return "by_exception_only"
	case NotAllowedCondition:
		return "not_allowed"
	}
	panic(fmt.Errorf("unrecognized license condition: %#v", lc))
}
