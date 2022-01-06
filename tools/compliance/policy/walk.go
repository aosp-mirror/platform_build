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

// VisitNode is called for each root and for each walked dependency node by
// WalkTopDown. When VisitNode returns true, WalkTopDown will proceed to walk
// down the dependences of the node
type VisitNode func(*LicenseGraph, *TargetNode, TargetEdgePath) bool

// WalkTopDown does a top-down walk of `lg` calling `visit` and descending
// into depenencies when `visit` returns true.
func WalkTopDown(lg *LicenseGraph, visit VisitNode) {
	path := NewTargetEdgePath(32)

	// must be indexed for fast lookup
	lg.indexForward()

	var walk func(f string)
	walk = func(f string) {
		visitChildren := visit(lg, lg.targets[f], *path)
		if !visitChildren {
			return
		}
		for _, edge := range lg.index[f] {
			path.Push(TargetEdge{lg, edge})
			walk(edge.dependency)
			path.Pop()
		}
	}

	for _, r := range lg.rootFiles {
		path.Clear()
		walk(r)
	}
}

// WalkResolutionsForCondition performs a top-down walk of the LicenseGraph
// resolving all distributed works for condition `names`.
func WalkResolutionsForCondition(lg *LicenseGraph, rs *ResolutionSet, names ConditionNames) *ResolutionSet {
	shipped := ShippedNodes(lg)

	// rmap maps 'attachesTo' targets to the `actsOn` targets and applicable conditions
	//
	// rmap is the resulting ResolutionSet
	rmap := make(map[*TargetNode]actionSet)

	WalkTopDown(lg, func(lg *LicenseGraph, tn *TargetNode, _ TargetEdgePath) bool {
		if _, ok := rmap[tn]; ok {
			return false
		}
		if !shipped.Contains(tn) {
			return false
		}
		if as, ok := rs.resolutions[tn]; ok {
			fas := as.byActsOn(shipped).byName(names)
			if !fas.isEmpty() {
				rmap[tn] = fas
			}
		}
		return tn.IsContainer() // descend into containers
	})

	return &ResolutionSet{rmap}
}
