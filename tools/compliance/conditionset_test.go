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
	"strings"
	"testing"
)

func TestConditionSet(t *testing.T) {
	tests := []struct {
		name        string
		conditions  []string
		plus        *[]string
		minus       *[]string
		matchingAny map[string][]string
		expected    []string
	}{
		{
			name:       "empty",
			conditions: []string{},
			plus:       &[]string{},
			matchingAny: map[string][]string{
				"notice":                []string{},
				"restricted":            []string{},
				"restricted|reciprocal": []string{},
			},
			expected: []string{},
		},
		{
			name:       "emptyminusnothing",
			conditions: []string{},
			minus:      &[]string{},
			matchingAny: map[string][]string{
				"notice":                []string{},
				"restricted":            []string{},
				"restricted|reciprocal": []string{},
			},
			expected: []string{},
		},
		{
			name:       "emptyminusnotice",
			conditions: []string{},
			minus:      &[]string{"notice"},
			matchingAny: map[string][]string{
				"notice":                []string{},
				"restricted":            []string{},
				"restricted|reciprocal": []string{},
			},
			expected: []string{},
		},
		{
			name:       "noticeonly",
			conditions: []string{"notice"},
			matchingAny: map[string][]string{
				"notice":             []string{"notice"},
				"notice|proprietary": []string{"notice"},
				"restricted":         []string{},
			},
			expected: []string{"notice"},
		},
		{
			name:       "allnoticeonly",
			conditions: []string{"notice"},
			plus:       &[]string{"notice"},
			matchingAny: map[string][]string{
				"notice":             []string{"notice"},
				"notice|proprietary": []string{"notice"},
				"restricted":         []string{},
			},
			expected: []string{"notice"},
		},
		{
			name:       "emptyplusnotice",
			conditions: []string{},
			plus:       &[]string{"notice"},
			matchingAny: map[string][]string{
				"notice":             []string{"notice"},
				"notice|proprietary": []string{"notice"},
				"restricted":         []string{},
			},
			expected: []string{"notice"},
		},
		{
			name:       "everything",
			conditions: []string{"unencumbered", "permissive", "notice", "reciprocal", "restricted", "proprietary"},
			plus:       &[]string{"restricted_if_statically_linked", "by_exception_only", "not_allowed"},
			matchingAny: map[string][]string{
				"unencumbered":                    []string{"unencumbered"},
				"permissive":                      []string{"permissive"},
				"notice":                          []string{"notice"},
				"reciprocal":                      []string{"reciprocal"},
				"restricted":                      []string{"restricted"},
				"restricted_if_statically_linked": []string{"restricted_if_statically_linked"},
				"proprietary":                     []string{"proprietary"},
				"by_exception_only":               []string{"by_exception_only"},
				"not_allowed":                     []string{"not_allowed"},
				"notice|proprietary":              []string{"notice", "proprietary"},
			},
			expected: []string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"restricted_if_statically_linked",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
		},
		{
			name: "everythingplusminusnothing",
			conditions: []string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"restricted_if_statically_linked",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
			plus:  &[]string{},
			minus: &[]string{},
			matchingAny: map[string][]string{
				"unencumbered|permissive|notice": []string{"unencumbered", "permissive", "notice"},
				"restricted|reciprocal":          []string{"reciprocal", "restricted"},
				"proprietary|by_exception_only":  []string{"proprietary", "by_exception_only"},
				"not_allowed":                    []string{"not_allowed"},
			},
			expected: []string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"restricted_if_statically_linked",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
		},
		{
			name:       "allbutone",
			conditions: []string{"unencumbered", "permissive", "notice", "reciprocal", "restricted", "proprietary"},
			plus:       &[]string{"restricted_if_statically_linked", "by_exception_only", "not_allowed"},
			matchingAny: map[string][]string{
				"unencumbered":                    []string{"unencumbered"},
				"permissive":                      []string{"permissive"},
				"notice":                          []string{"notice"},
				"reciprocal":                      []string{"reciprocal"},
				"restricted":                      []string{"restricted"},
				"restricted_if_statically_linked": []string{"restricted_if_statically_linked"},
				"proprietary":                     []string{"proprietary"},
				"by_exception_only":               []string{"by_exception_only"},
				"not_allowed":                     []string{"not_allowed"},
				"notice|proprietary":              []string{"notice", "proprietary"},
			},
			expected: []string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"restricted_if_statically_linked",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
		},
		{
			name: "everythingminusone",
			conditions: []string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"restricted_if_statically_linked",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
			minus: &[]string{"restricted_if_statically_linked"},
			matchingAny: map[string][]string{
				"unencumbered":                    []string{"unencumbered"},
				"permissive":                      []string{"permissive"},
				"notice":                          []string{"notice"},
				"reciprocal":                      []string{"reciprocal"},
				"restricted":                      []string{"restricted"},
				"restricted_if_statically_linked": []string{},
				"proprietary":                     []string{"proprietary"},
				"by_exception_only":               []string{"by_exception_only"},
				"not_allowed":                     []string{"not_allowed"},
				"restricted|proprietary":          []string{"restricted", "proprietary"},
			},
			expected: []string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
		},
		{
			name: "everythingminuseverything",
			conditions: []string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"restricted_if_statically_linked",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
			minus: &[]string{
				"unencumbered",
				"permissive",
				"notice",
				"reciprocal",
				"restricted",
				"restricted_if_statically_linked",
				"proprietary",
				"by_exception_only",
				"not_allowed",
			},
			matchingAny: map[string][]string{
				"unencumbered":                    []string{},
				"permissive":                      []string{},
				"notice":                          []string{},
				"reciprocal":                      []string{},
				"restricted":                      []string{},
				"restricted_if_statically_linked": []string{},
				"proprietary":                     []string{},
				"by_exception_only":               []string{},
				"not_allowed":                     []string{},
				"restricted|proprietary":          []string{},
			},
			expected: []string{},
		},
		{
			name:       "restrictedplus",
			conditions: []string{"restricted", "restricted_if_statically_linked"},
			plus:       &[]string{"permissive", "notice", "restricted", "proprietary"},
			matchingAny: map[string][]string{
				"unencumbered":                    []string{},
				"permissive":                      []string{"permissive"},
				"notice":                          []string{"notice"},
				"restricted":                      []string{"restricted"},
				"restricted_if_statically_linked": []string{"restricted_if_statically_linked"},
				"proprietary":                     []string{"proprietary"},
				"restricted|proprietary":          []string{"restricted", "proprietary"},
				"by_exception_only":               []string{},
				"proprietary|by_exception_only":   []string{"proprietary"},
			},
			expected: []string{"permissive", "notice", "restricted", "restricted_if_statically_linked", "proprietary"},
		},
	}
	for _, tt := range tests {
		toConditions := func(names []string) []LicenseCondition {
			result := make([]LicenseCondition, 0, len(names))
			for _, name := range names {
				result = append(result, RecognizedConditionNames[name])
			}
			return result
		}
		populate := func() LicenseConditionSet {
			testSet := NewLicenseConditionSet(toConditions(tt.conditions)...)
			if tt.plus != nil {
				testSet = testSet.Plus(toConditions(*tt.plus)...)
			}
			if tt.minus != nil {
				testSet = testSet.Minus(toConditions(*tt.minus)...)
			}
			return testSet
		}
		populateSet := func() LicenseConditionSet {
			testSet := NewLicenseConditionSet(toConditions(tt.conditions)...)
			if tt.plus != nil {
				testSet = testSet.Union(NewLicenseConditionSet(toConditions(*tt.plus)...))
			}
			if tt.minus != nil {
				testSet = testSet.Difference(NewLicenseConditionSet(toConditions(*tt.minus)...))
			}
			return testSet
		}
		populatePlusSet := func() LicenseConditionSet {
			testSet := NewLicenseConditionSet(toConditions(tt.conditions)...)
			if tt.plus != nil {
				testSet = testSet.Union(NewLicenseConditionSet(toConditions(*tt.plus)...))
			}
			if tt.minus != nil {
				testSet = testSet.Minus(toConditions(*tt.minus)...)
			}
			return testSet
		}
		populateMinusSet := func() LicenseConditionSet {
			testSet := NewLicenseConditionSet(toConditions(tt.conditions)...)
			if tt.plus != nil {
				testSet = testSet.Plus(toConditions(*tt.plus)...)
			}
			if tt.minus != nil {
				testSet = testSet.Difference(NewLicenseConditionSet(toConditions(*tt.minus)...))
			}
			return testSet
		}
		checkMatching := func(cs LicenseConditionSet, t *testing.T) {
			for data, expectedNames := range tt.matchingAny {
				expectedConditions := toConditions(expectedNames)
				expected := NewLicenseConditionSet(expectedConditions...)
				actual := cs.MatchingAny(toConditions(strings.Split(data, "|"))...)
				actualNames := actual.Names()

				t.Logf("MatchingAny(%s): actual set %#v %s", data, actual, actual.String())
				t.Logf("MatchingAny(%s): expected set %#v %s", data, expected, expected.String())

				if actual != expected {
					t.Errorf("MatchingAny(%s): got %#v, want %#v", data, actual, expected)
					continue
				}
				if len(actualNames) != len(expectedNames) {
					t.Errorf("len(MatchinAny(%s).Names()): got %d, want %d",
						data, len(actualNames), len(expectedNames))
				} else {
					for i := 0; i < len(actualNames); i++ {
						if actualNames[i] != expectedNames[i] {
							t.Errorf("MatchingAny(%s).Names()[%d]: got %s, want %s",
								data, i, actualNames[i], expectedNames[i])
							break
						}
					}
				}
				actualConditions := actual.AsList()
				if len(actualConditions) != len(expectedConditions) {
					t.Errorf("len(MatchingAny(%s).AsList()):  got %d, want %d",
						data, len(actualNames), len(expectedNames))
				} else {
					for i := 0; i < len(actualNames); i++ {
						if actualNames[i] != expectedNames[i] {
							t.Errorf("MatchingAny(%s).AsList()[%d]: got %s, want %s",
								data, i, actualNames[i], expectedNames[i])
							break
						}
					}
				}
			}
		}
		checkMatchingSet := func(cs LicenseConditionSet, t *testing.T) {
			for data, expectedNames := range tt.matchingAny {
				expected := NewLicenseConditionSet(toConditions(expectedNames)...)
				actual := cs.MatchingAnySet(NewLicenseConditionSet(toConditions(strings.Split(data, "|"))...))
				actualNames := actual.Names()

				t.Logf("MatchingAnySet(%s): actual set %#v %s", data, actual, actual.String())
				t.Logf("MatchingAnySet(%s): expected set %#v %s", data, expected, expected.String())

				if actual != expected {
					t.Errorf("MatchingAnySet(%s): got %#v, want %#v", data, actual, expected)
					continue
				}
				if len(actualNames) != len(expectedNames) {
					t.Errorf("len(MatchingAnySet(%s).Names()): got %d, want %d",
						data, len(actualNames), len(expectedNames))
				} else {
					for i := 0; i < len(actualNames); i++ {
						if actualNames[i] != expectedNames[i] {
							t.Errorf("MatchingAnySet(%s).Names()[%d]: got %s, want %s",
								data, i, actualNames[i], expectedNames[i])
							break
						}
					}
				}
				expectedConditions := toConditions(expectedNames)
				actualConditions := actual.AsList()
				if len(actualConditions) != len(expectedConditions) {
					t.Errorf("len(MatchingAnySet(%s).AsList()): got %d, want %d",
						data, len(actualNames), len(expectedNames))
				} else {
					for i := 0; i < len(actualNames); i++ {
						if actualNames[i] != expectedNames[i] {
							t.Errorf("MatchingAnySet(%s).AsList()[%d]: got %s, want %s",
								data, i, actualNames[i], expectedNames[i])
							break
						}
					}
				}
			}
		}

		checkExpected := func(actual LicenseConditionSet, t *testing.T) bool {
			t.Logf("checkExpected{%s}", strings.Join(tt.expected, ", "))

			expectedConditions := toConditions(tt.expected)
			expected := NewLicenseConditionSet(expectedConditions...)

			actualNames := actual.Names()

			t.Logf("actual license condition set: %#v %s", actual, actual.String())
			t.Logf("expected license condition set: %#v %s", expected, expected.String())

			if actual != expected {
				t.Errorf("checkExpected: got %#v, want %#v", actual, expected)
				return false
			}

			if len(actualNames) != len(tt.expected) {
				t.Errorf("len(actual.Names()): got %d, want %d", len(actualNames), len(tt.expected))
			} else {
				for i := 0; i < len(actualNames); i++ {
					if actualNames[i] != tt.expected[i] {
						t.Errorf("actual.Names()[%d]: got %s, want %s", i, actualNames[i], tt.expected[i])
						break
					}
				}
			}

			actualConditions := actual.AsList()
			if len(actualConditions) != len(expectedConditions) {
				t.Errorf("len(actual.AsList()): got %d, want %d", len(actualConditions), len(expectedConditions))
			} else {
				for i := 0; i < len(actualConditions); i++ {
					if actualConditions[i] != expectedConditions[i] {
						t.Errorf("actual.AsList()[%d]: got %s, want %s",
							i, actualConditions[i].Name(), expectedConditions[i].Name())
						break
					}
				}
			}

			if len(tt.expected) == 0 {
				if !actual.IsEmpty() {
					t.Errorf("actual.IsEmpty(): got false, want true")
				}
				if actual.HasAny(expectedConditions...) {
					t.Errorf("actual.HasAny(): got true, want false")
				}
			} else {
				if actual.IsEmpty() {
					t.Errorf("actual.IsEmpty(): got true, want false")
				}
				if !actual.HasAny(expectedConditions...) {
					t.Errorf("actual.HasAny(all expected): got false, want true")
				}
			}
			if !actual.HasAll(expectedConditions...) {
				t.Errorf("actual.Hasll(all expected): want true, got false")
			}
			for _, expectedCondition := range expectedConditions {
				if !actual.HasAny(expectedCondition) {
					t.Errorf("actual.HasAny(%q): got false, want true", expectedCondition.Name())
				}
				if !actual.HasAll(expectedCondition) {
					t.Errorf("actual.HasAll(%q): got false, want true", expectedCondition.Name())
				}
			}

			notExpected := (AllLicenseConditions &^ expected)
			notExpectedList := notExpected.AsList()
			t.Logf("not expected license condition set: %#v %s", notExpected, notExpected.String())

			if len(tt.expected) == 0 {
				if actual.HasAny(append(expectedConditions, notExpectedList...)...) {
					t.Errorf("actual.HasAny(all conditions): want false, got true")
				}
			} else {
				if !actual.HasAny(append(expectedConditions, notExpectedList...)...) {
					t.Errorf("actual.HasAny(all conditions): want true, got false")
				}
			}
			if len(notExpectedList) == 0 {
				if !actual.HasAll(append(expectedConditions, notExpectedList...)...) {
					t.Errorf("actual.HasAll(all conditions): want true, got false")
				}
			} else {
				if actual.HasAll(append(expectedConditions, notExpectedList...)...) {
					t.Errorf("actual.HasAll(all conditions): want false, got true")
				}
			}
			for _, unexpectedCondition := range notExpectedList {
				if actual.HasAny(unexpectedCondition) {
					t.Errorf("actual.HasAny(%q): got true, want false", unexpectedCondition.Name())
				}
				if actual.HasAll(unexpectedCondition) {
					t.Errorf("actual.HasAll(%q): got true, want false", unexpectedCondition.Name())
				}
			}
			return true
		}

		checkExpectedSet := func(actual LicenseConditionSet, t *testing.T) bool {
			t.Logf("checkExpectedSet{%s}", strings.Join(tt.expected, ", "))

			expectedConditions := toConditions(tt.expected)
			expected := NewLicenseConditionSet(expectedConditions...)

			actualNames := actual.Names()

			t.Logf("actual license condition set: %#v %s", actual, actual.String())
			t.Logf("expected license condition set: %#v %s", expected, expected.String())

			if actual != expected {
				t.Errorf("checkExpectedSet: got %#v, want %#v", actual, expected)
				return false
			}

			if len(actualNames) != len(tt.expected) {
				t.Errorf("len(actual.Names()): got %d, want %d", len(actualNames), len(tt.expected))
			} else {
				for i := 0; i < len(actualNames); i++ {
					if actualNames[i] != tt.expected[i] {
						t.Errorf("actual.Names()[%d]: got %s, want %s", i, actualNames[i], tt.expected[i])
						break
					}
				}
			}

			actualConditions := actual.AsList()
			if len(actualConditions) != len(expectedConditions) {
				t.Errorf("len(actual.AsList()): got %d, want %d", len(actualConditions), len(expectedConditions))
			} else {
				for i := 0; i < len(actualConditions); i++ {
					if actualConditions[i] != expectedConditions[i] {
						t.Errorf("actual.AsList()[%d}: got %s, want %s",
							i, actualConditions[i].Name(), expectedConditions[i].Name())
						break
					}
				}
			}

			if len(tt.expected) == 0 {
				if !actual.IsEmpty() {
					t.Errorf("actual.IsEmpty(): got false, want true")
				}
				if actual.MatchesAnySet(expected) {
					t.Errorf("actual.MatchesAnySet({}): got true, want false")
				}
				if actual.MatchesEverySet(expected, expected) {
					t.Errorf("actual.MatchesEverySet({}, {}): want false, got true")
				}
			} else {
				if actual.IsEmpty() {
					t.Errorf("actual.IsEmpty(): got true, want false")
				}
				if !actual.MatchesAnySet(expected) {
					t.Errorf("actual.MatchesAnySet({all expected}): want true, got false")
				}
				if !actual.MatchesEverySet(expected, expected) {
					t.Errorf("actual.MatchesEverySet({all expected}, {all expected}): want true, got false")
				}
			}

			notExpected := (AllLicenseConditions &^ expected)
			t.Logf("not expected license condition set: %#v %s", notExpected, notExpected.String())

			if len(tt.expected) == 0 {
				if actual.MatchesAnySet(expected, notExpected) {
					t.Errorf("empty actual.MatchesAnySet({expected}, {not expected}): want false, got true")
				}
			} else {
				if !actual.MatchesAnySet(expected, notExpected) {
					t.Errorf("actual.MatchesAnySet({expected}, {not expected}): want true, got false")
				}
			}
			if actual.MatchesAnySet(notExpected) {
				t.Errorf("actual.MatchesAnySet({not expected}): want false, got true")
			}
			if actual.MatchesEverySet(notExpected) {
				t.Errorf("actual.MatchesEverySet({not expected}): want false, got true")
			}
			if actual.MatchesEverySet(expected, notExpected) {
				t.Errorf("actual.MatchesEverySet({expected}, {not expected}): want false, got true")
			}

			if !actual.Difference(expected).IsEmpty() {
				t.Errorf("actual.Difference({expected}).IsEmpty(): want true, got false")
			}
			if expected != actual.Intersection(expected) {
				t.Errorf("expected == actual.Intersection({expected}): want true, got false (%#v != %#v)", expected, actual.Intersection(expected))
			}
			if actual != actual.Intersection(expected) {
				t.Errorf("actual == actual.Intersection({expected}): want true, got false (%#v != %#v)", actual, actual.Intersection(expected))
			}
			return true
		}

		t.Run(tt.name, func(t *testing.T) {
			cs := populate()
			if checkExpected(cs, t) {
				checkMatching(cs, t)
			}
			if checkExpectedSet(cs, t) {
				checkMatchingSet(cs, t)
			}
		})

		t.Run(tt.name+"_sets", func(t *testing.T) {
			cs := populateSet()
			if checkExpected(cs, t) {
				checkMatching(cs, t)
			}
			if checkExpectedSet(cs, t) {
				checkMatchingSet(cs, t)
			}
		})

		t.Run(tt.name+"_plusset", func(t *testing.T) {
			cs := populatePlusSet()
			if checkExpected(cs, t) {
				checkMatching(cs, t)
			}
			if checkExpectedSet(cs, t) {
				checkMatchingSet(cs, t)
			}
		})

		t.Run(tt.name+"_minusset", func(t *testing.T) {
			cs := populateMinusSet()
			if checkExpected(cs, t) {
				checkMatching(cs, t)
			}
			if checkExpectedSet(cs, t) {
				checkMatchingSet(cs, t)
			}
		})
	}
}
