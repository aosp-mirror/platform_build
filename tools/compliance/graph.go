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
	"fmt"
	"sort"
	"strings"
	"sync"
)

// LicenseGraph describes the immutable license metadata for a set of root
// targets and the transitive closure of their dependencies.
//
// Alternatively, a graph is a set of edges. In this case directed, annotated
// edges from targets to dependencies.
//
// A LicenseGraph provides the frame of reference for all of the other types
// defined here. It is possible to have multiple graphs, and to have targets,
// edges, and resolutions from multiple graphs. But it is an error to try to
// mix items from different graphs in the same operation.
// May panic if attempted.
//
// The compliance package assumes specific private implementations of each of
// these interfaces. May panic if attempts are made to combine different
// implementations of some interfaces with expected implementations of other
// interfaces here.
type LicenseGraph struct {
	// rootFiles identifies the original set of files to read. (immutable)
	//
	// Defines the starting "top" for top-down walks.
	//
	// Alternatively, an instance of licenseGraphImp conceptually defines a scope within
	// the universe of build graphs as a sub-graph rooted at rootFiles where all edges
	// and targets for the instance are defined relative to and within that scope. For
	// most analyses, the correct scope is to root the graph at all of the distributed
	// artifacts.
	rootFiles []string

	// edges lists the directed edges in the graph from target to dependency. (guarded by mu)
	//
	// Alternatively, the graph is the set of `edges`.
	edges []*dependencyEdge

	// targets identifies, indexes by name, and describes the entire set of target node files.
	/// (guarded by mu)
	targets map[string]*TargetNode

	// index facilitates looking up edges from targets. (creation guarded by my)
	//
	// This is a forward index from target to dependencies. i.e. "top-down"
	index map[string][]*dependencyEdge

	// rsBU caches the results of a full bottom-up resolve. (creation guarded by mu)
	//
	// A bottom-up resolve is a prerequisite for all of the top-down resolves so caching
	// the result is a performance win.
	rsBU *ResolutionSet

	// rsTD caches the results of a full top-down resolve. (creation guarded by mu)
	//
	// A top-down resolve is a prerequisite for final resolutions.
	// e.g. a shipped node inheriting a `restricted` condition from a parent through a
	// dynamic dependency implies a notice dependency on the parent; even though, the
	// distribution does not happen as a result of the dynamic dependency itself.
	rsTD *ResolutionSet

	// shippedNodes caches the results of a full walk of nodes identifying targets
	// distributed either directly or as derivative works. (creation guarded by mu)
	shippedNodes *TargetNodeSet

	// mu guards against concurrent update.
	mu sync.Mutex
}

// TargetNode returns the target node identified by `name`.
func (lg *LicenseGraph) TargetNode(name string) *TargetNode {
	if _, ok := lg.targets[name]; !ok {
		panic(fmt.Errorf("target node %q missing from graph", name))
	}
	return lg.targets[name]
}

// HasTargetNode returns true if a target node identified by `name` appears in
// the graph.
func (lg *LicenseGraph) HasTargetNode(name string) bool {
	_, isPresent := lg.targets[name]
	return isPresent
}

// Edges returns the list of edges in the graph. (unordered)
func (lg *LicenseGraph) Edges() TargetEdgeList {
	edges := make(TargetEdgeList, 0, len(lg.edges))
	for _, e := range lg.edges {
		edges = append(edges, TargetEdge{lg, e})
	}
	return edges
}

// Targets returns the list of target nodes in the graph. (unordered)
func (lg *LicenseGraph) Targets() TargetNodeList {
	targets := make(TargetNodeList, 0, len(lg.targets))
	for target := range lg.targets {
		targets = append(targets, lg.targets[target])
	}
	return targets
}

// compliance-only LicenseGraph methods

// newLicenseGraph constructs a new, empty instance of LicenseGraph.
func newLicenseGraph() *LicenseGraph {
	return &LicenseGraph{
		rootFiles: []string{},
		edges:     make([]*dependencyEdge, 0, 1000),
		targets:   make(map[string]*TargetNode),
	}
}

// indexForward guarantees the `index` map is populated to look up edges by
// `target`.
func (lg *LicenseGraph) indexForward() {
	lg.mu.Lock()
	defer func() {
		lg.mu.Unlock()
	}()

	if lg.index != nil {
		return
	}

	lg.index = make(map[string][]*dependencyEdge)
	for _, e := range lg.edges {
		if _, ok := lg.index[e.target]; ok {
			lg.index[e.target] = append(lg.index[e.target], e)
		} else {
			lg.index[e.target] = []*dependencyEdge{e}
		}
	}
}

// TargetEdge describes a directed, annotated edge from a target to a
// dependency. (immutable)
//
// A LicenseGraph, above, is a set of TargetEdges.
//
// i.e. `Target` depends on `Dependency` in the manner described by
// `Annotations`.
type TargetEdge struct {
	// lg identifies the scope, i.e. license graph, in which the edge appears.
	lg *LicenseGraph

	// e identifies describes the target, dependency, and annotations of the edge.
	e *dependencyEdge
}

// Target identifies the target that depends on the dependency.
//
// Target needs Dependency to build.
func (e TargetEdge) Target() *TargetNode {
	return e.lg.targets[e.e.target]
}

// Dependency identifies the target depended on by the target.
//
// Dependency builds without Target, but Target needs Dependency to build.
func (e TargetEdge) Dependency() *TargetNode {
	return e.lg.targets[e.e.dependency]
}

// Annotations describes the type of edge by the set of annotations attached to
// it.
//
// Only annotations prescribed by policy have any meaning for licensing, and
// the meaning for licensing is likewise prescribed by policy. Other annotations
// are preserved and ignored by policy.
func (e TargetEdge) Annotations() TargetEdgeAnnotations {
	return e.e.annotations
}

// TargetEdgeList orders lists of edges by target then dependency then annotations.
type TargetEdgeList []TargetEdge

// Len returns the count of the elmements in the list.
func (l TargetEdgeList) Len() int      { return len(l) }

// Swap rearranges 2 elements so that each occupies the other's former position.
func (l TargetEdgeList) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographically less than the `j`th.
func (l TargetEdgeList) Less(i, j int) bool {
	if l[i].e.target == l[j].e.target {
		if l[i].e.dependency == l[j].e.dependency {
			return l[i].e.annotations.Compare(l[j].e.annotations) < 0
		}
		return l[i].e.dependency < l[j].e.dependency
	}
	return l[i].e.target < l[j].e.target
}

// TargetEdgePath describes a sequence of edges starting at a root and ending
// at some final dependency.
type TargetEdgePath []TargetEdge

// NewTargetEdgePath creates a new, empty path with capacity `cap`.
func NewTargetEdgePath(cap int) *TargetEdgePath {
	p := make(TargetEdgePath, 0, cap)
	return &p
}

// Push appends a new edge to the list verifying that the target of the new
// edge is the dependency of the prior.
func (p *TargetEdgePath) Push(edge TargetEdge) {
	if len(*p) == 0 {
		*p = append(*p, edge)
		return
	}
	if (*p)[len(*p)-1].e.dependency != edge.e.target {
		panic(fmt.Errorf("disjoint path %s does not end at %s", p.String(), edge.e.target))
	}
	*p = append(*p, edge)
}

// Pop shortens the path by 1 edge.
func (p *TargetEdgePath) Pop() {
	if len(*p) == 0 {
		panic(fmt.Errorf("attempt to remove edge from empty path"))
	}
	*p = (*p)[:len(*p)-1]
}

// Clear makes the path length 0.
func (p *TargetEdgePath) Clear() {
	*p = (*p)[:0]
}

// String returns a string representation of the path: [n1 -> n2 -> ... -> nn].
func (p *TargetEdgePath) String() string {
	if p == nil {
		return "nil"
	}
	if len(*p) == 0 {
		return "[]"
	}
	var sb strings.Builder
	fmt.Fprintf(&sb, "[")
	for _, e := range *p {
		fmt.Fprintf(&sb, "%s -> ", e.e.target)
	}
	fmt.Fprintf(&sb, "%s]", (*p)[len(*p)-1].e.dependency)
	return sb.String()
}

// TargetNode describes a module or target identified by the name of a specific
// metadata file. (immutable)
//
// Each metadata file corresponds to a Soong module or to a Make target.
//
// A target node can appear as the target or as the dependency in edges.
// Most target nodes appear as both target in one edge and as dependency in
// other edges.
type TargetNode targetNode

// Name returns the string that identifies the target node.
// i.e. path to license metadata file
func (tn *TargetNode) Name() string {
	return tn.name
}

// PackageName returns the string that identifes the package for the target.
func (tn *TargetNode) PackageName() string {
	return tn.proto.GetPackageName()
}

// ModuleTypes returns the list of module types implementing the target.
// (unordered)
//
// In an ideal world, only 1 module type would implement each target, but the
// interactions between Soong and Make for host versus product and for a
// variety of architectures sometimes causes multiple module types per target
// (often a regular build target and a prebuilt.)
func (tn *TargetNode) ModuleTypes() []string {
	return append([]string{}, tn.proto.ModuleTypes...)
}

// ModuleClasses returns the list of module classes implementing the target.
// (unordered)
func (tn *TargetNode) ModuleClasses() []string {
	return append([]string{}, tn.proto.ModuleClasses...)
}

// Projects returns the projects defining the target node. (unordered)
//
// In an ideal world, only 1 project defines a target, but the interaction
// between Soong and Make for a variety of architectures and for host versus
// product means a module is sometimes defined more than once.
func (tn *TargetNode) Projects() []string {
	return append([]string{}, tn.proto.Projects...)
}

// LicenseKinds returns the list of license kind names for the module or
// target. (unordered)
//
// e.g. SPDX-license-identifier-MIT or legacy_proprietary
func (tn *TargetNode) LicenseKinds() []string {
	return append([]string{}, tn.proto.LicenseKinds...)
}

// LicenseConditions returns a copy of the set of license conditions
// originating at the target. The values that appear and how each is resolved
// is a matter of policy. (unordered)
//
// e.g. notice or proprietary
func (tn *TargetNode) LicenseConditions() *LicenseConditionSet {
	result := newLicenseConditionSet()
	result.add(tn, tn.proto.LicenseConditions...)
	return result
}

// LicenseTexts returns the paths to the files containing the license texts for
// the target. (unordered)
func (tn *TargetNode) LicenseTexts() []string {
	return append([]string{}, tn.proto.LicenseTexts...)
}

// IsContainer returns true if the target represents a container that merely
// aggregates other targets.
func (tn *TargetNode) IsContainer() bool {
	return tn.proto.GetIsContainer()
}

// Built returns the list of files built by the module or target. (unordered)
func (tn *TargetNode) Built() []string {
	return append([]string{}, tn.proto.Built...)
}

// Installed returns the list of files installed by the module or target.
// (unordered)
func (tn *TargetNode) Installed() []string {
	return append([]string{}, tn.proto.Installed...)
}

// InstallMap returns the list of path name transformations to make to move
// files from their original location in the file system to their destination
// inside a container. (unordered)
func (tn *TargetNode) InstallMap() []InstallMap {
	result := make([]InstallMap, 0, len(tn.proto.InstallMap))
	for _, im := range tn.proto.InstallMap {
		result = append(result, InstallMap{im.GetFromPath(), im.GetContainerPath()})
	}
	return result
}

// Sources returns the list of file names depended on by the target, which may
// be a proper subset of those made available by dependency modules.
// (unordered)
func (tn *TargetNode) Sources() []string {
	return append([]string{}, tn.proto.Sources...)
}

// InstallMap describes the mapping from an input filesystem file to file in a
// container.
type InstallMap struct {
	// FromPath is the input path on the filesystem.
	FromPath string

	// ContainerPath is the path to the same file inside the container or
	// installed location.
	ContainerPath string
}

// TargetEdgeAnnotations describes an immutable set of annotations attached to
// an edge from a target to a dependency.
//
// Annotations typically distinguish between static linkage versus dynamic
// versus tools that are used at build time but are not linked in any way.
type TargetEdgeAnnotations struct {
	annotations map[string]bool
}

// newEdgeAnnotations creates a new instance of TargetEdgeAnnotations.
func newEdgeAnnotations() TargetEdgeAnnotations {
	return TargetEdgeAnnotations{make(map[string]bool)}
}

// HasAnnotation returns true if an annotation `ann` is in the set.
func (ea TargetEdgeAnnotations) HasAnnotation(ann string) bool {
	_, ok := ea.annotations[ann]
	return ok
}

// Compare orders TargetAnnotations returning:
// -1 when ea < other,
// +1 when ea > other, and
// 0 when ea == other.
func (ea TargetEdgeAnnotations) Compare(other TargetEdgeAnnotations) int {
	a1 := ea.AsList()
	a2 := other.AsList()
	sort.Strings(a1)
	sort.Strings(a2)
	for k := 0; k < len(a1) && k < len(a2); k++ {
		if a1[k] < a2[k] {
			return -1
		}
		if a1[k] > a2[k] {
			return 1
		}
	}
	if len(a1) < len(a2) {
		return -1
	}
	if len(a1) > len(a2) {
		return 1
	}
	return 0
}

// AsList returns the list of annotation names attached to the edge.
// (unordered)
func (ea TargetEdgeAnnotations) AsList() []string {
	l := make([]string, 0, len(ea.annotations))
	for ann := range ea.annotations {
		l = append(l, ann)
	}
	return l
}

// TargetNodeSet describes a set of distinct nodes in a license graph.
type TargetNodeSet struct {
	nodes map[*TargetNode]bool
}

// Contains returns true when `target` is an element of the set.
func (ts *TargetNodeSet) Contains(target *TargetNode) bool {
	_, isPresent := ts.nodes[target]
	return isPresent
}

// AsList returns the list of target nodes in the set. (unordered)
func (ts *TargetNodeSet) AsList() TargetNodeList {
	result := make(TargetNodeList, 0, len(ts.nodes))
	for tn := range ts.nodes {
		result = append(result, tn)
	}
	return result
}

// Names returns the array of target node namess in the set. (unordered)
func (ts *TargetNodeSet) Names() []string {
	result := make([]string, 0, len(ts.nodes))
	for tn := range ts.nodes {
		result = append(result, tn.name)
	}
	return result
}

// TargetNodeList orders a list of targets by name.
type TargetNodeList []*TargetNode

// Len returns the count of elements in the list.
func (l TargetNodeList) Len() int      { return len(l) }

// Swap rearranges 2 elements so that each occupies the other's former position.
func (l TargetNodeList) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographicallt less than the `j`th.
func (l TargetNodeList) Less(i, j int) bool {
	return l[i].name < l[j].name
}

// String returns a string representation of the list.
func (l TargetNodeList) String() string {
	var sb strings.Builder
	fmt.Fprintf(&sb, "[")
	sep := ""
	for _, tn := range l {
		fmt.Fprintf(&sb, "%s%s", sep, tn.name)
		sep = " "
	}
	fmt.Fprintf(&sb, "]")
	return sb.String()
}

// Names returns an array the names of the nodes in the same order as the nodes in the list.
func (l TargetNodeList) Names() []string {
	result := make([]string, 0, len(l))
	for _, tn := range l {
		result = append(result, tn.name)
	}
	return result
}
