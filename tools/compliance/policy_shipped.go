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

// ShippedNodes returns the set of nodes in a license graph where the target or
// a derivative work gets distributed. (caches result)
func ShippedNodes(lg *LicenseGraph) TargetNodeSet {
	lg.mu.Lock()
	shipped := lg.shippedNodes
	lg.mu.Unlock()
	if shipped != nil {
		return *shipped
	}

	tset := make(TargetNodeSet)

	WalkTopDown(NoEdgeContext{}, lg, func(lg *LicenseGraph, tn *TargetNode, path TargetEdgePath) bool {
		if _, alreadyWalked := tset[tn]; alreadyWalked {
			return false
		}
		if len(path) > 0 {
			if !edgeIsDerivation(path[len(path)-1].edge) {
				return false
			}
		}
		tset[tn] = struct{}{}
		return true
	})

	shipped = &tset

	lg.mu.Lock()
	if lg.shippedNodes == nil {
		lg.shippedNodes = shipped
	} else {
		// if we end up with 2, release the later for garbage collection.
		shipped = lg.shippedNodes
	}
	lg.mu.Unlock()

	return *shipped
}
