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
	"testing"
)

func TestConditionSetHas(t *testing.T) {
	impliesShare := ImpliesShared

	t.Logf("testing with imliesShare=%#v", impliesShare)

	if impliesShare.HasAny(NoticeCondition) {
		t.Errorf("impliesShare.HasAny(\"notice\"=%#v) got true, want false", NoticeCondition)
	}

	if !impliesShare.HasAny(RestrictedCondition) {
		t.Errorf("impliesShare.HasAny(\"restricted\"=%#v) got false, want true", RestrictedCondition)
	}

	if !impliesShare.HasAny(ReciprocalCondition) {
		t.Errorf("impliesShare.HasAny(\"reciprocal\"=%#v) got false, want true", ReciprocalCondition)
	}

	if impliesShare.HasAny(LicenseCondition(0x0000)) {
		t.Errorf("impliesShare.HasAny(nil=%#v) got true, want false", LicenseCondition(0x0000))
	}
}

func TestConditionName(t *testing.T) {
	for expected, condition := range RecognizedConditionNames {
		actual := condition.Name()
		if expected != actual {
			t.Errorf("unexpected name for condition %#v: got %s, want %s", condition, actual, expected)
		}
	}
}

func TestConditionName_InvalidCondition(t *testing.T) {
	panicked := false
	var lc LicenseCondition
	func() {
		defer func() {
			if err := recover(); err != nil {
				panicked = true
			}
		}()
		name := lc.Name()
		t.Errorf("invalid condition unexpected name: got %s, wanted panic", name)
	}()
	if !panicked {
		t.Errorf("no expected panic for %#v.Name(): got no panic, wanted panic", lc)
	}
}
