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

// EdgeContextProvider is an interface for injecting edge-specific context
// into walk paths.
type EdgeContextProvider interface {
	// Context returns the context for `edge` when added to `path`.
	Context(lg *LicenseGraph, path TargetEdgePath, edge *TargetEdge) interface{}
}

// NoEdgeContext implements EdgeContextProvider for walks that use no context.
type NoEdgeContext struct{}

// Context returns nil.
func (ctx NoEdgeContext) Context(lg *LicenseGraph, path TargetEdgePath, edge *TargetEdge) interface{} {
	return nil
}

// ApplicableConditionsContext provides the subset of conditions in `universe`
// that apply to each edge in a path.
type ApplicableConditionsContext struct {
	universe LicenseConditionSet
}

// Context returns the LicenseConditionSet applicable to the edge.
func (ctx ApplicableConditionsContext) Context(lg *LicenseGraph, path TargetEdgePath, edge *TargetEdge) interface{} {
	universe := ctx.universe
	if len(path) > 0 {
		universe = path[len(path)-1].ctx.(LicenseConditionSet)
	}
	return conditionsAttachingAcrossEdge(lg, edge, universe)
}

// VisitNode is called for each root and for each walked dependency node by
// WalkTopDown and WalkTopDownBreadthFirst. When VisitNode returns true, WalkTopDown will proceed to walk
// down the dependences of the node
type VisitNode func(lg *LicenseGraph, target *TargetNode, path TargetEdgePath) bool

// WalkTopDown does a top-down walk of `lg` calling `visit` and descending
// into depenencies when `visit` returns true.
func WalkTopDown(ctx EdgeContextProvider, lg *LicenseGraph, visit VisitNode) {
	path := NewTargetEdgePath(32)

	var walk func(fnode *TargetNode)
	walk = func(fnode *TargetNode) {
		visitChildren := visit(lg, fnode, *path)
		if !visitChildren {
			return
		}
		for _, edge := range fnode.edges {
			var edgeContext interface{}
			if ctx == nil {
				edgeContext = nil
			} else {
				edgeContext = ctx.Context(lg, *path, edge)
			}
			path.Push(edge, edgeContext)
			walk(edge.dependency)
			path.Pop()
		}
	}

	for _, r := range lg.rootFiles {
		path.Clear()
		walk(lg.targets[r])
	}
}

// WalkTopDownBreadthFirst performs a Breadth-first top down walk of `lg` calling `visit` and descending
// into depenencies when `visit` returns true.
func WalkTopDownBreadthFirst(ctx EdgeContextProvider, lg *LicenseGraph, visit VisitNode) {
	path := NewTargetEdgePath(32)

	var walk func(fnode *TargetNode)
	walk = func(fnode *TargetNode) {
		edgesToWalk := make(TargetEdgeList, 0, len(fnode.edges))
		for _, edge := range fnode.edges {
			var edgeContext interface{}
			if ctx == nil {
				edgeContext = nil
			} else {
				edgeContext = ctx.Context(lg, *path, edge)
			}
			path.Push(edge, edgeContext)
			if visit(lg, edge.dependency, *path){
				edgesToWalk = append(edgesToWalk, edge)
			}
			path.Pop()
		}

		for _, edge := range(edgesToWalk) {
			var edgeContext interface{}
			if ctx == nil {
				edgeContext = nil
			} else {
				edgeContext = ctx.Context(lg, *path, edge)
			}
			path.Push(edge, edgeContext)
			walk(edge.dependency)
			path.Pop()
		}
	}

	path.Clear()
	rootsToWalk := make([]*TargetNode, 0, len(lg.rootFiles))
	for _, r := range lg.rootFiles {
		if visit(lg, lg.targets[r], *path){
			rootsToWalk = append(rootsToWalk, lg.targets[r])
		}
	}

	for _, rnode := range(rootsToWalk) {
		walk(rnode)
	}
}

// resolutionKey identifies results from walking a specific target for a
// specific set of conditions.
type resolutionKey struct {
	target *TargetNode
	cs     LicenseConditionSet
}

// WalkResolutionsForCondition performs a top-down walk of the LicenseGraph
// resolving all distributed works for `conditions`.
func WalkResolutionsForCondition(lg *LicenseGraph, conditions LicenseConditionSet) ResolutionSet {
	shipped := ShippedNodes(lg)

	// rmap maps 'attachesTo' targets to the `actsOn` targets and applicable conditions
	rmap := make(map[resolutionKey]ActionSet)

	// cmap identifies previously walked target/condition pairs.
	cmap := make(map[resolutionKey]struct{})

	// result accumulates the resolutions to return.
	result := make(ResolutionSet)
	WalkTopDown(ApplicableConditionsContext{conditions}, lg, func(lg *LicenseGraph, tn *TargetNode, path TargetEdgePath) bool {
		universe := conditions
		if len(path) > 0 {
			universe = path[len(path)-1].ctx.(LicenseConditionSet)
		}

		if universe.IsEmpty() {
			return false
		}
		key := resolutionKey{tn, universe}

		if _, alreadyWalked := cmap[key]; alreadyWalked {
			pure := true
			for _, p := range path {
				target := p.Target()
				tkey := resolutionKey{target, universe}
				if _, ok := rmap[tkey]; !ok {
					rmap[tkey] = make(ActionSet)
				}
				// attach prior walk outcome to ancestor
				for actsOn, cs := range rmap[key] {
					rmap[tkey][actsOn] = cs
				}
				// if prior walk produced results, copy results
				// to ancestor.
				if _, ok := result[tn]; ok && pure {
					if _, ok := result[target]; !ok {
						result[target] = make(ActionSet)
					}
					for actsOn, cs := range result[tn] {
						result[target][actsOn] = cs
					}
					pure = target.IsContainer()
				}
			}
			// if all ancestors are pure aggregates, attach
			// matching prior walk conditions to self. Prior walk
			// will not have done so if any ancestor was not an
			// aggregate.
			if pure {
				match := rmap[key][tn].Intersection(universe)
				if !match.IsEmpty() {
					if _, ok := result[tn]; !ok {
						result[tn] = make(ActionSet)
					}
					result[tn][tn] = match
				}
			}
			return false
		}
		// no need to walk node or dependencies if not shipped
		if !shipped.Contains(tn) {
			return false
		}
		if _, ok := rmap[key]; !ok {
			rmap[key] = make(ActionSet)
		}
		// add self to walk outcome
		rmap[key][tn] = tn.resolution
		cmap[key] = struct{}{}
		cs := tn.resolution
		if !cs.IsEmpty() {
			cs = cs.Intersection(universe)
			pure := true
			for _, p := range path {
				target := p.Target()
				tkey := resolutionKey{target, universe}
				if _, ok := rmap[tkey]; !ok {
					rmap[tkey] = make(ActionSet)
				}
				// copy current node's action into ancestor
				rmap[tkey][tn] = tn.resolution
				// conditionally put matching conditions into
				// result
				if pure && !cs.IsEmpty() {
					if _, ok := result[target]; !ok {
						result[target] = make(ActionSet)
					}
					result[target][tn] = cs
					pure = target.IsContainer()
				}
			}
			// if all ancestors are pure aggregates, attach
			// matching conditions to self.
			if pure && !cs.IsEmpty() {
				if _, ok := result[tn]; !ok {
					result[tn] = make(ActionSet)
				}
				result[tn][tn] = cs
			}
		}
		return true
	})

	return result
}

// WalkActionsForCondition performs a top-down walk of the LicenseGraph
// resolving all distributed works for `conditions`.
func WalkActionsForCondition(lg *LicenseGraph, conditions LicenseConditionSet) ActionSet {
	shipped := ShippedNodes(lg)

	// cmap identifies previously walked target/condition pairs.
	cmap := make(map[resolutionKey]struct{})

	// amap maps 'actsOn' targets to the applicable conditions
	//
	// amap is the resulting ActionSet
	amap := make(ActionSet)
	WalkTopDown(ApplicableConditionsContext{conditions}, lg, func(lg *LicenseGraph, tn *TargetNode, path TargetEdgePath) bool {
		universe := conditions
		if len(path) > 0 {
			universe = path[len(path)-1].ctx.(LicenseConditionSet)
		}
		if universe.IsEmpty() {
			return false
		}
		key := resolutionKey{tn, universe}
		if _, ok := cmap[key]; ok {
			return false
		}
		if !shipped.Contains(tn) {
			return false
		}
		cs := universe.Intersection(tn.resolution)
		if !cs.IsEmpty() {
			if _, ok := amap[tn]; ok {
				amap[tn] = cs
			} else {
				amap[tn] = amap[tn].Union(cs)
			}
		}
		return true
	})

	return amap
}
