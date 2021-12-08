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
	"sort"
	"strings"
	"testing"
)

func TestConditionNames(t *testing.T) {
	impliesShare := ConditionNames([]string{"restricted", "reciprocal"})

	if impliesShare.Contains("notice") {
		t.Errorf("impliesShare.Contains(\"notice\") got true, want false")
	}

	if !impliesShare.Contains("restricted") {
		t.Errorf("impliesShare.Contains(\"restricted\") got false, want true")
	}

	if !impliesShare.Contains("reciprocal") {
		t.Errorf("impliesShare.Contains(\"reciprocal\") got false, want true")
	}

	if impliesShare.Contains("") {
		t.Errorf("impliesShare.Contains(\"\") got true, want false")
	}
}

func TestConditionList(t *testing.T) {
	tests := []struct {
		name       string
		conditions map[string][]string
		byName     map[string][]string
		byOrigin   map[string][]string
	}{
		{
			name: "noticeonly",
			conditions: map[string][]string{
				"notice": []string{"bin1", "lib1"},
			},
			byName: map[string][]string{
				"notice":     []string{"bin1", "lib1"},
				"restricted": []string{},
			},
			byOrigin: map[string][]string{
				"bin1": []string{"notice"},
				"lib1": []string{"notice"},
				"bin2": []string{},
				"lib2": []string{},
			},
		},
		{
			name:       "empty",
			conditions: map[string][]string{},
			byName: map[string][]string{
				"notice":     []string{},
				"restricted": []string{},
			},
			byOrigin: map[string][]string{
				"bin1": []string{},
				"lib1": []string{},
				"bin2": []string{},
				"lib2": []string{},
			},
		},
		{
			name: "everything",
			conditions: map[string][]string{
				"notice":            []string{"bin1", "bin2", "lib1", "lib2"},
				"reciprocal":        []string{"bin1", "bin2", "lib1", "lib2"},
				"restricted":        []string{"bin1", "bin2", "lib1", "lib2"},
				"by_exception_only": []string{"bin1", "bin2", "lib1", "lib2"},
			},
			byName: map[string][]string{
				"permissive":        []string{},
				"notice":            []string{"bin1", "bin2", "lib1", "lib2"},
				"reciprocal":        []string{"bin1", "bin2", "lib1", "lib2"},
				"restricted":        []string{"bin1", "bin2", "lib1", "lib2"},
				"by_exception_only": []string{"bin1", "bin2", "lib1", "lib2"},
			},
			byOrigin: map[string][]string{
				"bin1":  []string{"notice", "reciprocal", "restricted", "by_exception_only"},
				"bin2":  []string{"notice", "reciprocal", "restricted", "by_exception_only"},
				"lib1":  []string{"notice", "reciprocal", "restricted", "by_exception_only"},
				"lib2":  []string{"notice", "reciprocal", "restricted", "by_exception_only"},
				"other": []string{},
			},
		},
		{
			name: "allbutoneeach",
			conditions: map[string][]string{
				"notice":            []string{"bin2", "lib1", "lib2"},
				"reciprocal":        []string{"bin1", "lib1", "lib2"},
				"restricted":        []string{"bin1", "bin2", "lib2"},
				"by_exception_only": []string{"bin1", "bin2", "lib1"},
			},
			byName: map[string][]string{
				"permissive":        []string{},
				"notice":            []string{"bin2", "lib1", "lib2"},
				"reciprocal":        []string{"bin1", "lib1", "lib2"},
				"restricted":        []string{"bin1", "bin2", "lib2"},
				"by_exception_only": []string{"bin1", "bin2", "lib1"},
			},
			byOrigin: map[string][]string{
				"bin1":  []string{"reciprocal", "restricted", "by_exception_only"},
				"bin2":  []string{"notice", "restricted", "by_exception_only"},
				"lib1":  []string{"notice", "reciprocal", "by_exception_only"},
				"lib2":  []string{"notice", "reciprocal", "restricted"},
				"other": []string{},
			},
		},
		{
			name: "oneeach",
			conditions: map[string][]string{
				"notice":            []string{"bin1"},
				"reciprocal":        []string{"bin2"},
				"restricted":        []string{"lib1"},
				"by_exception_only": []string{"lib2"},
			},
			byName: map[string][]string{
				"permissive":        []string{},
				"notice":            []string{"bin1"},
				"reciprocal":        []string{"bin2"},
				"restricted":        []string{"lib1"},
				"by_exception_only": []string{"lib2"},
			},
			byOrigin: map[string][]string{
				"bin1":  []string{"notice"},
				"bin2":  []string{"reciprocal"},
				"lib1":  []string{"restricted"},
				"lib2":  []string{"by_exception_only"},
				"other": []string{},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lg := newLicenseGraph()
			cl := toConditionList(lg, tt.conditions)
			for names, expected := range tt.byName {
				name := ConditionNames(strings.Split(names, ":"))
				if cl.HasByName(name) {
					if len(expected) == 0 {
						t.Errorf("unexpected ConditionList.HasByName(%q): got true, want false", name)
					}
				} else {
					if len(expected) != 0 {
						t.Errorf("unexpected ConditionList.HasByName(%q): got false, want true", name)
					}
				}
				if len(expected) != cl.CountByName(name) {
					t.Errorf("unexpected ConditionList.CountByName(%q): got %d, want %d", name, cl.CountByName(name), len(expected))
				}
				byName := cl.ByName(name)
				if len(expected) != len(byName) {
					t.Errorf("unexpected ConditionList.ByName(%q): got %v, want %v", name, byName, expected)
				} else {
					sort.Strings(expected)
					actual := make([]string, 0, len(byName))
					for _, lc := range byName {
						actual = append(actual, lc.Origin().Name())
					}
					sort.Strings(actual)
					for i := 0; i < len(expected); i++ {
						if expected[i] != actual[i] {
							t.Errorf("unexpected ConditionList.ByName(%q) index %d in %v: got %s, want %s", name, i, actual, actual[i], expected[i])
						}
					}
				}
			}
			for origin, expected := range tt.byOrigin {
				onode := newTestNode(lg, origin)
				if cl.HasByOrigin(onode) {
					if len(expected) == 0 {
						t.Errorf("unexpected ConditionList.HasByOrigin(%q): got true, want false", origin)
					}
				} else {
					if len(expected) != 0 {
						t.Errorf("unexpected ConditionList.HasByOrigin(%q): got false, want true", origin)
					}
				}
				if len(expected) != cl.CountByOrigin(onode) {
					t.Errorf("unexpected ConditionList.CountByOrigin(%q): got %d, want %d", origin, cl.CountByOrigin(onode), len(expected))
				}
				byOrigin := cl.ByOrigin(onode)
				if len(expected) != len(byOrigin) {
					t.Errorf("unexpected ConditionList.ByOrigin(%q): got %v, want %v", origin, byOrigin, expected)
				} else {
					sort.Strings(expected)
					actual := make([]string, 0, len(byOrigin))
					for _, lc := range byOrigin {
						actual = append(actual, lc.Name())
					}
					sort.Strings(actual)
					for i := 0; i < len(expected); i++ {
						if expected[i] != actual[i] {
							t.Errorf("unexpected ConditionList.ByOrigin(%q) index %d in %v: got %s, want %s", origin, i, actual, actual[i], expected[i])
						}
					}
				}
			}
		})
	}
}
