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
	"testing"
)

var (
	// bottomUp describes the bottom-up resolve of a hypothetical graph
	// the graph has a container image, a couple binaries, and a couple
	// libraries. bin1 statically links lib1 and dynamically links lib2;
	// bin2 dynamically links lib1 and statically links lib2.
	// binc represents a compiler or other toolchain binary used for
	// building the other binaries.
	bottomUp = []res{
		{"image", "image", "image", "notice"},
		{"image", "image", "bin2", "restricted"},
		{"image", "bin1", "bin1", "reciprocal"},
		{"image", "bin2", "bin2", "restricted"},
		{"image", "lib1", "lib1", "notice"},
		{"image", "lib2", "lib2", "notice"},
		{"binc", "binc", "binc", "proprietary"},
		{"bin1", "bin1", "bin1", "reciprocal"},
		{"bin1", "lib1", "lib1", "notice"},
		{"bin2", "bin2", "bin2", "restricted"},
		{"bin2", "lib2", "lib2", "notice"},
		{"lib1", "lib1", "lib1", "notice"},
		{"lib2", "lib2", "lib2", "notice"},
	}

	// notice describes bottomUp after a top-down notice resolve.
	notice = []res{
		{"image", "image", "image", "notice"},
		{"image", "image", "bin2", "restricted"},
		{"image", "bin1", "bin1", "reciprocal"},
		{"image", "bin2", "bin2", "restricted"},
		{"image", "lib1", "lib1", "notice"},
		{"image", "lib2", "bin2", "restricted"},
		{"image", "lib2", "lib2", "notice"},
		{"bin1", "bin1", "bin1", "reciprocal"},
		{"bin1", "lib1", "lib1", "notice"},
		{"bin2", "bin2", "bin2", "restricted"},
		{"bin2", "lib2", "bin2", "restricted"},
		{"bin2", "lib2", "lib2", "notice"},
		{"lib1", "lib1", "lib1", "notice"},
		{"lib2", "lib2", "lib2", "notice"},
	}

	// share describes bottomUp after a top-down share resolve.
	share = []res{
		{"image", "image", "bin2", "restricted"},
		{"image", "bin1", "bin1", "reciprocal"},
		{"image", "bin2", "bin2", "restricted"},
		{"image", "lib2", "bin2", "restricted"},
		{"bin1", "bin1", "bin1", "reciprocal"},
		{"bin2", "bin2", "bin2", "restricted"},
		{"bin2", "lib2", "bin2", "restricted"},
	}

	// proprietary describes bottomUp after a top-down proprietary resolve.
	// Note that the proprietary binc is not reachable through the toolchain
	// dependency.
	proprietary = []res{}
)

func TestResolutionSet_JoinResolutionSets(t *testing.T) {
	lg := newLicenseGraph()

	rsNotice := toResolutionSet(lg, notice)
	rsShare := toResolutionSet(lg, share)
	rsExpected := toResolutionSet(lg, append(notice, share...))

	rsActual := JoinResolutionSets(rsNotice, rsShare)
	checkSame(rsActual, rsExpected, t)
}

func TestResolutionSet_JoinResolutionsEmpty(t *testing.T) {
	lg := newLicenseGraph()

	rsShare := toResolutionSet(lg, share)
	rsProprietary := toResolutionSet(lg, proprietary)
	rsExpected := toResolutionSet(lg, append(share, proprietary...))

	rsActual := JoinResolutionSets(rsShare, rsProprietary)
	checkSame(rsActual, rsExpected, t)
}

func TestResolutionSet_Origins(t *testing.T) {
	lg := newLicenseGraph()

	rsShare := toResolutionSet(lg, share)

	origins := make([]string, 0)
	for _, target := range rsShare.Origins() {
		origins = append(origins, target.Name())
	}
	sort.Strings(origins)
	if len(origins) != 2 {
		t.Errorf("unexpected number of origins: got %v with %d elements, want [\"bin1\", \"bin2\"] with 2 elements", origins, len(origins))
	}
	if origins[0] != "bin1" {
		t.Errorf("unexpected origin at element 0: got %s, want \"bin1\"", origins[0])
	}
	if origins[1] != "bin2" {
		t.Errorf("unexpected origin at element 0: got %s, want \"bin2\"", origins[0])
	}
}

func TestResolutionSet_AttachedToTarget(t *testing.T) {
	lg := newLicenseGraph()

	rsShare := toResolutionSet(lg, share)

	if rsShare.AttachedToTarget(newTestNode(lg, "binc")) {
		t.Errorf("unexpected AttachedToTarget(\"binc\"): got true, want false")
	}
	if !rsShare.AttachedToTarget(newTestNode(lg, "image")) {
		t.Errorf("unexpected AttachedToTarget(\"image\"): got false want true")
	}
}

func TestResolutionSet_AnyByNameAttachToTarget(t *testing.T) {
	lg := newLicenseGraph()

	rs := toResolutionSet(lg, bottomUp)

	pandp := ConditionNames{"permissive", "proprietary"}
	pandn := ConditionNames{"permissive", "notice"}
	p := ConditionNames{"proprietary"}
	r := ConditionNames{"restricted"}

	if rs.AnyByNameAttachToTarget(newTestNode(lg, "image"), pandp, p) {
		t.Errorf("unexpected AnyByNameAttachToTarget(\"image\", \"proprietary\", \"permissive\"): want false, got true")
	}
	if !rs.AnyByNameAttachToTarget(newTestNode(lg, "binc"), p) {
		t.Errorf("unexpected AnyByNameAttachToTarget(\"binc\", \"proprietary\"): want true, got false")
	}
	if !rs.AnyByNameAttachToTarget(newTestNode(lg, "image"), pandn) {
		t.Errorf("unexpected AnyByNameAttachToTarget(\"image\", \"permissive\", \"notice\"): want true, got false")
	}
	if !rs.AnyByNameAttachToTarget(newTestNode(lg, "image"), r, pandn) {
		t.Errorf("unexpected AnyByNameAttachToTarget(\"image\", \"restricted\", \"notice\"): want true, got false")
	}
	if !rs.AnyByNameAttachToTarget(newTestNode(lg, "image"), r, p) {
		t.Errorf("unexpected AnyByNameAttachToTarget(\"image\", \"restricted\", \"proprietary\"): want true, got false")
	}
}

func TestResolutionSet_AllByNameAttachToTarget(t *testing.T) {
	lg := newLicenseGraph()

	rs := toResolutionSet(lg, bottomUp)

	pandp := ConditionNames{"permissive", "proprietary"}
	pandn := ConditionNames{"permissive", "notice"}
	p := ConditionNames{"proprietary"}
	r := ConditionNames{"restricted"}

	if rs.AllByNameAttachToTarget(newTestNode(lg, "image"), pandp, p) {
		t.Errorf("unexpected AllByNameAttachToTarget(\"image\", \"proprietary\", \"permissive\"): want false, got true")
	}
	if !rs.AllByNameAttachToTarget(newTestNode(lg, "binc"), p) {
		t.Errorf("unexpected AllByNameAttachToTarget(\"binc\", \"proprietary\"): want true, got false")
	}
	if !rs.AllByNameAttachToTarget(newTestNode(lg, "image"), pandn) {
		t.Errorf("unexpected AllByNameAttachToTarget(\"image\", \"notice\"): want true, got false")
	}
	if !rs.AllByNameAttachToTarget(newTestNode(lg, "image"), r, pandn) {
		t.Errorf("unexpected AllByNameAttachToTarget(\"image\", \"restricted\", \"notice\"): want true, got false")
	}
	if rs.AllByNameAttachToTarget(newTestNode(lg, "image"), r, p) {
		t.Errorf("unexpected AllByNameAttachToTarget(\"image\", \"restricted\", \"proprietary\"): want false, got true")
	}
}

func TestResolutionSet_AttachesToTarget(t *testing.T) {
	lg := newLicenseGraph()

	rsShare := toResolutionSet(lg, share)

	if rsShare.AttachesToTarget(newTestNode(lg, "binc")) {
		t.Errorf("unexpected hasTarget(\"binc\"): got true, want false")
	}
	if !rsShare.AttachesToTarget(newTestNode(lg, "image")) {
		t.Errorf("unexpected AttachesToTarget(\"image\"): got false want true")
	}
}
