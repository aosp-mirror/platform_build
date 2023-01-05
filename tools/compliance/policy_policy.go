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
	"regexp"
	"strings"
)

var (
	// RecognizedAnnotations identifies the set of annotations that have
	// meaning for compliance policy.
	RecognizedAnnotations = map[string]string{
		// used in readgraph.go to avoid creating 1000's of copies of the below 3 strings.
		"static":    "static",
		"dynamic":   "dynamic",
		"toolchain": "toolchain",
	}

	// safePathPrefixes maps the path prefixes presumed not to contain any
	// proprietary or confidential pathnames to whether to strip the prefix
	// from the path when used as the library name for notices.
	safePathPrefixes = []safePathPrefixesType{
		{"external/", true},
		{"art/", false},
		{"build/", false},
		{"cts/", false},
		{"dalvik/", false},
		{"developers/", false},
		{"development/", false},
		{"frameworks/", false},
		{"packages/", true},
		{"prebuilts/module_sdk/", true},
		{"prebuilts/", false},
		{"sdk/", false},
		{"system/", false},
		{"test/", false},
		{"toolchain/", false},
		{"tools/", false},
	}

	// safePrebuiltPrefixes maps the regular expression to match a prebuilt
	// containing the path of a safe prefix to the safe prefix.
	safePrebuiltPrefixes []safePrebuiltPrefixesType

	// ImpliesUnencumbered lists the condition names representing an author attempt to disclaim copyright.
	ImpliesUnencumbered = LicenseConditionSet(UnencumberedCondition)

	// ImpliesPermissive lists the condition names representing copyrighted but "licensed without policy requirements".
	ImpliesPermissive = LicenseConditionSet(PermissiveCondition)

	// ImpliesNotice lists the condition names implying a notice or attribution policy.
	ImpliesNotice = LicenseConditionSet(UnencumberedCondition | PermissiveCondition | NoticeCondition | ReciprocalCondition |
		RestrictedCondition | WeaklyRestrictedCondition | ProprietaryCondition | ByExceptionOnlyCondition)

	// ImpliesReciprocal lists the condition names implying a local source-sharing policy.
	ImpliesReciprocal = LicenseConditionSet(ReciprocalCondition)

	// Restricted lists the condition names implying an infectious source-sharing policy.
	ImpliesRestricted = LicenseConditionSet(RestrictedCondition | WeaklyRestrictedCondition)

	// ImpliesProprietary lists the condition names implying a confidentiality policy.
	ImpliesProprietary = LicenseConditionSet(ProprietaryCondition)

	// ImpliesByExceptionOnly lists the condition names implying a policy for "license review and approval before use".
	ImpliesByExceptionOnly = LicenseConditionSet(ProprietaryCondition | ByExceptionOnlyCondition)

	// ImpliesPrivate lists the condition names implying a source-code privacy policy.
	ImpliesPrivate = LicenseConditionSet(ProprietaryCondition)

	// ImpliesShared lists the condition names implying a source-code sharing policy.
	ImpliesShared = LicenseConditionSet(ReciprocalCondition | RestrictedCondition | WeaklyRestrictedCondition)
)

type safePathPrefixesType struct {
	prefix string
	strip  bool
}

type safePrebuiltPrefixesType struct {
	safePathPrefixesType
	re *regexp.Regexp
}

var (
	anyLgpl      = regexp.MustCompile(`^SPDX-license-identifier-LGPL.*`)
	versionedGpl = regexp.MustCompile(`^SPDX-license-identifier-GPL-\p{N}.*`)
	genericGpl   = regexp.MustCompile(`^SPDX-license-identifier-GPL$`)
	ccBySa       = regexp.MustCompile(`^SPDX-license-identifier-CC-BY.*-SA.*`)
)

func init() {
	for _, safePathPrefix := range safePathPrefixes {
		if strings.HasPrefix(safePathPrefix.prefix, "prebuilts/") {
			continue
		}
		r := regexp.MustCompile("^prebuilts/(?:runtime/mainline/)?" + safePathPrefix.prefix)
		safePrebuiltPrefixes = append(safePrebuiltPrefixes,
			safePrebuiltPrefixesType{safePathPrefix, r})
	}
}

// LicenseConditionSetFromNames returns a set containing the recognized `names` and
// silently ignoring or discarding the unrecognized `names`.
func LicenseConditionSetFromNames(names ...string) LicenseConditionSet {
	cs := NewLicenseConditionSet()
	for _, name := range names {
		if lc, ok := RecognizedConditionNames[name]; ok {
			cs |= LicenseConditionSet(lc)
		}
	}
	return cs
}

// Resolution happens in three phases:
//
// 1. A bottom-up traversal propagates (restricted) license conditions up to
// targets from dendencies as needed.
//
// 2. For each condition of interest, a top-down traversal propagates
// (restricted) conditions down from targets into linked dependencies.
//
// 3. Finally, a walk of the shipped target nodes attaches resolutions to the
// ancestor nodes from the root down to and including the first non-container.
//
// e.g. If a disk image contains a binary bin1 that links a library liba, the
// notice requirement for liba gets attached to the disk image and to bin1.
// Because liba doesn't actually get shipped as a separate artifact, but only
// as bits in bin1, it has no actions 'attached' to it. The actions attached
// to the image and to bin1 'act on' liba by providing notice.
//
// The behavior of the 3 phases gets controlled by the 3 functions below.
//
// The first function controls what happens during the bottom-up propagation.
// Restricted conditions propagate up all non-toolchain dependencies; except,
// some do not propagate up dynamic links, which may depend on whether the
// modules are independent.
//
// The second function controls what happens during the top-down propagation.
// Restricted conditions propagate down as above with the added caveat that
// inherited restricted conditions do not propagate from pure aggregates to
// their dependencies.
//
// The final function controls which conditions apply/get attached to ancestors
// depending on the types of dependencies involved. All conditions apply across
// normal derivation dependencies. No conditions apply across toolchain
// dependencies. Some restricted conditions apply across dynamic link
// dependencies.
//
// Not all restricted licenses are create equal. Some have special rules or
// exceptions. e.g. LGPL or "with classpath excption".

// depConditionsPropagatingToTarget returns the conditions which propagate up an
// edge from dependency to target.
//
// This function sets the policy for the bottom-up propagation and how conditions
// flow up the graph from dependencies to targets.
//
// If a pure aggregation is built into a derivative work that is not a pure
// aggregation, per policy it ceases to be a pure aggregation in the context of
// that derivative work. The `treatAsAggregate` parameter will be false for
// non-aggregates and for aggregates in non-aggregate contexts.
func depConditionsPropagatingToTarget(lg *LicenseGraph, e *TargetEdge, depConditions LicenseConditionSet, treatAsAggregate bool) LicenseConditionSet {
	result := LicenseConditionSet(0x0000)
	if edgeIsDerivation(e) {
		result |= depConditions & ImpliesRestricted
		return result
	}
	if !edgeIsDynamicLink(e) {
		return result
	}

	result |= depConditions & LicenseConditionSet(RestrictedCondition)
	return result
}

// targetConditionsPropagatingToDep returns the conditions which propagate down
// an edge from target to dependency.
//
// This function sets the policy for the top-down traversal and how conditions
// flow down the graph from targets to dependencies.
//
// If a pure aggregation is built into a derivative work that is not a pure
// aggregation, per policy it ceases to be a pure aggregation in the context of
// that derivative work. The `treatAsAggregate` parameter will be false for
// non-aggregates and for aggregates in non-aggregate contexts.
func targetConditionsPropagatingToDep(lg *LicenseGraph, e *TargetEdge, targetConditions LicenseConditionSet, treatAsAggregate bool, conditionsFn TraceConditions) LicenseConditionSet {
	result := targetConditions

	// reverse direction -- none of these apply to things depended-on, only to targets depending-on.
	result = result.Minus(UnencumberedCondition, PermissiveCondition, NoticeCondition, ReciprocalCondition, ProprietaryCondition, ByExceptionOnlyCondition)

	if !edgeIsDerivation(e) && !edgeIsDynamicLink(e) {
		// target is not a derivative work of dependency and is not linked to dependency
		result = result.Difference(ImpliesRestricted)
		return result
	}
	if treatAsAggregate {
		// If the author of a pure aggregate licenses it restricted, apply restricted to immediate dependencies.
		// Otherwise, restricted does not propagate back down to dependencies.
		if !conditionsFn(e.target).MatchesAnySet(ImpliesRestricted) {
			result = result.Difference(ImpliesRestricted)
		}
		return result
	}
	if edgeIsDerivation(e) {
		return result
	}
	result = result.Minus(WeaklyRestrictedCondition)
	return result
}

// conditionsAttachingAcrossEdge returns the subset of conditions in `universe`
// that apply across edge `e`.
//
// This function sets the policy for attaching actions to ancestor nodes in the
// final resolution walk.
func conditionsAttachingAcrossEdge(lg *LicenseGraph, e *TargetEdge, universe LicenseConditionSet) LicenseConditionSet {
	result := universe
	if edgeIsDerivation(e) {
		return result
	}
	if !edgeIsDynamicLink(e) {
		return NewLicenseConditionSet()
	}

	result &= LicenseConditionSet(RestrictedCondition)
	return result
}

// edgeIsDynamicLink returns true for edges representing shared libraries
// linked dynamically at runtime.
func edgeIsDynamicLink(e *TargetEdge) bool {
	return e.annotations.HasAnnotation("dynamic")
}

// edgeIsDerivation returns true for edges where the target is a derivative
// work of dependency.
func edgeIsDerivation(e *TargetEdge) bool {
	isDynamic := e.annotations.HasAnnotation("dynamic")
	isToolchain := e.annotations.HasAnnotation("toolchain")
	return !isDynamic && !isToolchain
}
