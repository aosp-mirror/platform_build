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

// ResolveBottomUpConditions performs a bottom-up walk of the LicenseGraph
// propagating conditions up the graph as necessary according to the properties
// of each edge and according to each license condition in question.
//
// Subsequent top-down walks of the graph will filter some resolutions and may
// introduce new resolutions.
//
// e.g. if a "restricted" condition applies to a binary, it also applies to all
// of the statically-linked libraries and the transitive closure of their static
// dependencies; even if neither they nor the transitive closure of their
// dependencies originate any "restricted" conditions. The bottom-up walk will
// not resolve the library and its transitive closure, but the later top-down
// walk will.
func ResolveBottomUpConditions(lg *LicenseGraph) *ResolutionSet {

	// short-cut if already walked and cached
	lg.mu.Lock()
	rs := lg.rsBU
	lg.mu.Unlock()

	if rs != nil {
		return rs
	}

	// must be indexed for fast lookup
	lg.indexForward()

	rs = newResolutionSet()

	// cmap contains an entry for every target that was previously walked as a pure aggregate only.
	cmap := make(map[string]bool)

	var walk func(f string, treatAsAggregate bool) actionSet

	walk = func(f string, treatAsAggregate bool) actionSet {
		target := lg.targets[f]
		result := make(actionSet)
		result[target] = newLicenseConditionSet()
		result[target].add(target, target.proto.LicenseConditions...)
		if preresolved, ok := rs.resolutions[target]; ok {
			if treatAsAggregate {
				result.addSet(preresolved)
				return result
			}
			if _, asAggregate := cmap[f]; !asAggregate {
				result.addSet(preresolved)
				return result
			}
			// previously walked in a pure aggregate context,
			// needs to walk again in non-aggregate context
			delete(cmap, f)
		}
		if treatAsAggregate {
			cmap[f] = true
		}

		// add all the conditions from all the dependencies
		for _, edge := range lg.index[f] {
			// walk dependency to get its conditions
			as := walk(edge.dependency, treatAsAggregate && lg.targets[edge.dependency].IsContainer())

			// turn those into the conditions that apply to the target
			as = depActionsApplicableToTarget(TargetEdge{lg, edge}, as, treatAsAggregate)

			// add them to the result
			result.addSet(as)
		}

		// record these conditions as applicable to the target
		rs.addConditions(target, result)
		rs.addSelf(target, result.byName(ImpliesRestricted))

		// return this up the tree
		return result
	}

	// walk each of the roots
	for _, r := range lg.rootFiles {
		_ = walk(r, lg.targets[r].IsContainer())
	}

	// if not yet cached, save the result
	lg.mu.Lock()
	if lg.rsBU == nil {
		lg.rsBU = rs
	} else {
		// if we end up with 2, release the later for garbage collection
		rs = lg.rsBU
	}
	lg.mu.Unlock()

	return rs
}

// ResolveTopDownCondtions performs a top-down walk of the LicenseGraph
// resolving all reachable nodes for `condition`. Policy establishes the rules
// for transforming and propagating resolutions down the graph.
//
// e.g. For current policy, none of the conditions propagate from target to
// dependency except restricted. For restricted, the policy is to share the
// source of any libraries linked to restricted code and to provide notice.
func ResolveTopDownConditions(lg *LicenseGraph) *ResolutionSet {

	// short-cut if already walked and cached
	lg.mu.Lock()
	rs := lg.rsTD
	lg.mu.Unlock()

	if rs != nil {
		return rs
	}

	// start with the conditions propagated up the graph
	rs = ResolveBottomUpConditions(lg)

	// rmap maps 'appliesTo' targets to their applicable conditions
	//
	// rmap is the resulting ResolutionSet
	rmap := make(map[*TargetNode]actionSet)
	for attachesTo, as := range rs.resolutions {
		rmap[attachesTo] = as.copy()
	}

	path := make([]*dependencyEdge, 0, 32)

	var walk func(f string, cs *LicenseConditionSet, treatAsAggregate bool)

	walk = func(f string, cs *LicenseConditionSet, treatAsAggregate bool) {
		fnode := lg.targets[f]
		if !cs.IsEmpty() {
			parentsAllAggregate := true
			for _, e := range path {
				target := lg.targets[e.target]
				if _, ok := rmap[target]; !ok {
					rmap[target] = make(actionSet)
				}
				rmap[target].add(fnode, cs)
				if !target.IsContainer() {
					parentsAllAggregate = false
					break
				}
			}
			if parentsAllAggregate {
				if _, ok := rmap[fnode]; !ok {
					rmap[fnode] = make(actionSet)
				}
				rmap[fnode].add(fnode, cs)
			}
		}
		// add conditions attached to `f`
		cs = cs.Copy()
		for _, fcs := range rs.resolutions[fnode] {
			cs.AddSet(fcs)
		}
		// for each dependency
		for _, edge := range lg.index[f] {
			e := TargetEdge{lg, edge}
			// dcs holds the dpendency conditions inherited from the target
			dcs := targetConditionsApplicableToDep(e, cs, treatAsAggregate)
			if dcs.IsEmpty() {
				if !treatAsAggregate || (!edgeIsDerivation(e) && !edgeIsDynamicLink(e)) {
					continue
				}
			}
			path = append(path, edge)
			// add the conditions to the dependency
			walk(edge.dependency, dcs, treatAsAggregate && lg.targets[edge.dependency].IsContainer())
			path = path[:len(path)-1]
		}
	}

	// walk each of the roots
	for _, r := range lg.rootFiles {
		as, ok := rs.resolutions[lg.targets[r]]
		if !ok {
			// no conditions in root or transitive closure of dependencies
			continue
		}
		if as.isEmpty() {
			continue
		}

		path = path[:0]
		// add the conditions to the root and its transitive closure
		walk(r, newLicenseConditionSet(), lg.targets[r].IsContainer())
	}

	rs = &ResolutionSet{rmap}

	// if not yet cached, save the result
	lg.mu.Lock()
	if lg.rsTD == nil {
		lg.rsTD = rs
	} else {
		// if we end up with 2, release the later for garbage collection
		rs = lg.rsTD
	}
	lg.mu.Unlock()

	return rs
}
