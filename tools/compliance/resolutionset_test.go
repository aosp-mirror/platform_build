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
		{"image", "image", "notice|restricted"},
		{"image", "bin1", "reciprocal"},
		{"image", "bin2", "restricted"},
		{"image", "lib1", "notice"},
		{"image", "lib2", "notice"},
		{"binc", "binc", "proprietary"},
		{"bin1", "bin1", "reciprocal"},
		{"bin1", "lib1", "notice"},
		{"bin2", "bin2", "restricted"},
		{"bin2", "lib2", "notice"},
		{"lib1", "lib1", "notice"},
		{"lib2", "lib2", "notice"},
	}

	// notice describes bottomUp after a top-down notice resolve.
	notice = []res{
		{"image", "image", "notice|restricted"},
		{"image", "bin1", "reciprocal"},
		{"image", "bin2", "restricted"},
		{"image", "lib1", "notice"},
		{"image", "lib2", "notice|restricted"},
		{"bin1", "bin1", "reciprocal"},
		{"bin1", "lib1", "notice"},
		{"bin2", "bin2", "restricted"},
		{"bin2", "lib2", "notice|restricted"},
		{"lib1", "lib1", "notice"},
		{"lib2", "lib2", "notice"},
	}

	// share describes bottomUp after a top-down share resolve.
	share = []res{
		{"image", "image", "restricted"},
		{"image", "bin1", "reciprocal"},
		{"image", "bin2", "restricted"},
		{"image", "lib2", "restricted"},
		{"bin1", "bin1", "reciprocal"},
		{"bin2", "bin2", "restricted"},
		{"bin2", "lib2", "restricted"},
	}

	// proprietary describes bottomUp after a top-down proprietary resolve.
	// Note that the proprietary binc is not reachable through the toolchain
	// dependency.
	proprietary = []res{}
)

func TestResolutionSet_AttachesTo(t *testing.T) {
	lg := newLicenseGraph()

	rsShare := toResolutionSet(lg, share)

	t.Logf("checking resolution set %s", rsShare.String())

	actual := rsShare.AttachesTo().Names()
	sort.Strings(actual)

	expected := []string{"bin1", "bin2", "image"}

	t.Logf("actual rsShare: %v", actual)
	t.Logf("expected rsShare: %v", expected)

	if len(actual) != len(expected) {
		t.Errorf("rsShare: wrong number of targets: got %d, want %d", len(actual), len(expected))
		return
	}
	for i := 0; i < len(actual); i++ {
		if actual[i] != expected[i] {
			t.Errorf("rsShare: unexpected target at index %d: got %s, want %s", i, actual[i], expected[i])
		}
	}

	rsPrivate := toResolutionSet(lg, proprietary)
	actual = rsPrivate.AttachesTo().Names()
	expected = []string{}

	t.Logf("actual rsPrivate: %v", actual)
	t.Logf("expected rsPrivate: %v", expected)

	if len(actual) != len(expected) {
		t.Errorf("rsPrivate: wrong number of targets: got %d, want %d", len(actual), len(expected))
		return
	}
	for i := 0; i < len(actual); i++ {
		if actual[i] != expected[i] {
			t.Errorf("rsPrivate: unexpected target at index %d: got %s, want %s", i, actual[i], expected[i])
		}
	}
}

func TestResolutionSet_AttachesToTarget(t *testing.T) {
	lg := newLicenseGraph()

	rsShare := toResolutionSet(lg, share)

	t.Logf("checking resolution set %s", rsShare.String())

	if rsShare.AttachesToTarget(newTestNode(lg, "binc")) {
		t.Errorf("actual.AttachesToTarget(\"binc\"): got true, want false")
	}
	if !rsShare.AttachesToTarget(newTestNode(lg, "image")) {
		t.Errorf("actual.AttachesToTarget(\"image\"): got false want true")
	}
}
