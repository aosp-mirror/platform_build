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
	edges TargetEdgeList

	// targets identifies, indexes, and describes the entire set of target node files.
	/// (guarded by mu)
	targets map[string]*TargetNode

	// onceBottomUp makes sure the bottom-up resolve walk only happens one time.
	onceBottomUp sync.Once

	// onceTopDown makes sure the top-down resolve walk only happens one time.
	onceTopDown sync.Once

	// shippedNodes caches the results of a full walk of nodes identifying targets
	// distributed either directly or as derivative works. (creation guarded by mu)
	shippedNodes *TargetNodeSet

	// mu guards against concurrent update.
	mu sync.Mutex
}

// Edges returns the list of edges in the graph. (unordered)
func (lg *LicenseGraph) Edges() TargetEdgeList {
	edges := make(TargetEdgeList, 0, len(lg.edges))
	edges = append(edges, lg.edges...)
	return edges
}

// Targets returns the list of target nodes in the graph. (unordered)
func (lg *LicenseGraph) Targets() TargetNodeList {
	targets := make(TargetNodeList, 0, len(lg.targets))
	for _, target := range lg.targets {
		targets = append(targets, target)
	}
	return targets
}

// TargetNames returns the list of target node names in the graph. (unordered)
func (lg *LicenseGraph) TargetNames() []string {
	targets := make([]string, 0, len(lg.targets))
	for target := range lg.targets {
		targets = append(targets, target)
	}
	return targets
}

// compliance-only LicenseGraph methods

// newLicenseGraph constructs a new, empty instance of LicenseGraph.
func newLicenseGraph() *LicenseGraph {
	return &LicenseGraph{
		rootFiles: []string{},
		targets:   make(map[string]*TargetNode),
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
	// target and dependency identify the nodes connected by the edge.
	target, dependency *TargetNode

	// annotations identifies the set of compliance-relevant annotations describing the edge.
	annotations TargetEdgeAnnotations
}

// Target identifies the target that depends on the dependency.
//
// Target needs Dependency to build.
func (e *TargetEdge) Target() *TargetNode {
	return e.target
}

// Dependency identifies the target depended on by the target.
//
// Dependency builds without Target, but Target needs Dependency to build.
func (e *TargetEdge) Dependency() *TargetNode {
	return e.dependency
}

// Annotations describes the type of edge by the set of annotations attached to
// it.
//
// Only annotations prescribed by policy have any meaning for licensing, and
// the meaning for licensing is likewise prescribed by policy. Other annotations
// are preserved and ignored by policy.
func (e *TargetEdge) Annotations() TargetEdgeAnnotations {
	return e.annotations
}

// IsRuntimeDependency returns true for edges representing shared libraries
// linked dynamically at runtime.
func (e *TargetEdge) IsRuntimeDependency() bool {
	return edgeIsDynamicLink(e)
}

// IsDerivation returns true for edges where the target is a derivative
// work of dependency.
func (e *TargetEdge) IsDerivation() bool {
	return edgeIsDerivation(e)
}

// IsBuildTool returns true for edges where the target is built
// by dependency.
func (e *TargetEdge) IsBuildTool() bool {
	return !edgeIsDerivation(e) && !edgeIsDynamicLink(e)
}

// String returns a human-readable string representation of the edge.
func (e *TargetEdge) String() string {
	return fmt.Sprintf("%s -[%s]> %s", e.target.name, strings.Join(e.annotations.AsList(), ", "), e.dependency.name)
}

// TargetEdgeList orders lists of edges by target then dependency then annotations.
type TargetEdgeList []*TargetEdge

// Len returns the count of the elmements in the list.
func (l TargetEdgeList) Len() int { return len(l) }

// Swap rearranges 2 elements so that each occupies the other's former position.
func (l TargetEdgeList) Swap(i, j int) { l[i], l[j] = l[j], l[i] }

// Less returns true when the `i`th element is lexicographically less than the `j`th.
func (l TargetEdgeList) Less(i, j int) bool {
	namei := l[i].target.name
	namej := l[j].target.name
	if namei == namej {
		namei = l[i].dependency.name
		namej = l[j].dependency.name
	}
	if namei == namej {
		return l[i].annotations.Compare(l[j].annotations) < 0
	}
	return namei < namej
}

// TargetEdgePathSegment describes a single arc in a TargetPath associating the
// edge with a context `ctx` defined by whatever process is creating the path.
type TargetEdgePathSegment struct {
	edge *TargetEdge
	ctx  interface{}
}

// Target identifies the target that depends on the dependency.
//
// Target needs Dependency to build.
func (s TargetEdgePathSegment) Target() *TargetNode {
	return s.edge.target
}

// Dependency identifies the target depended on by the target.
//
// Dependency builds without Target, but Target needs Dependency to build.
func (s TargetEdgePathSegment) Dependency() *TargetNode {
	return s.edge.dependency
}

// Edge describes the target edge.
func (s TargetEdgePathSegment) Edge() *TargetEdge {
	return s.edge
}

// Annotations describes the type of edge by the set of annotations attached to
// it.
//
// Only annotations prescribed by policy have any meaning for licensing, and
// the meaning for licensing is likewise prescribed by policy. Other annotations
// are preserved and ignored by policy.
func (s TargetEdgePathSegment) Annotations() TargetEdgeAnnotations {
	return s.edge.annotations
}

// Context returns the context associated with the path segment. The type and
// value of the context defined by the process creating the path.
func (s TargetEdgePathSegment) Context() interface{} {
	return s.ctx
}

// String returns a human-readable string representation of the edge.
func (s TargetEdgePathSegment) String() string {
	return fmt.Sprintf("%s -[%s]> %s", s.edge.target.name, strings.Join(s.edge.annotations.AsList(), ", "), s.edge.dependency.name)
}

// TargetEdgePath describes a sequence of edges starting at a root and ending
// at some final dependency.
type TargetEdgePath []TargetEdgePathSegment

// NewTargetEdgePath creates a new, empty path with capacity `cap`.
func NewTargetEdgePath(cap int) *TargetEdgePath {
	p := make(TargetEdgePath, 0, cap)
	return &p
}

// Push appends a new edge to the list verifying that the target of the new
// edge is the dependency of the prior.
func (p *TargetEdgePath) Push(edge *TargetEdge, ctx interface{}) {
	if len(*p) == 0 {
		*p = append(*p, TargetEdgePathSegment{edge, ctx})
		return
	}
	if (*p)[len(*p)-1].edge.dependency != edge.target {
		panic(fmt.Errorf("disjoint path %s does not end at %s", p.String(), edge.target.name))
	}
	*p = append(*p, TargetEdgePathSegment{edge, ctx})
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

// Copy makes a new path with the same value.
func (p *TargetEdgePath) Copy() *TargetEdgePath {
	result := make(TargetEdgePath, 0, len(*p))
	for _, e := range *p {
		result = append(result, e)
	}
	return &result
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
	for _, s := range *p {
		fmt.Fprintf(&sb, "%s -> ", s.edge.target.name)
	}
	lastSegment := (*p)[len(*p)-1]
	fmt.Fprintf(&sb, "%s]", lastSegment.edge.dependency.name)
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

// Dependencies returns the list of edges to dependencies of `tn`.
func (tn *TargetNode) Dependencies() TargetEdgeList {
	edges := make(TargetEdgeList, 0, len(tn.edges))
	edges = append(edges, tn.edges...)
	return edges
}

// PackageName returns the string that identifes the package for the target.
func (tn *TargetNode) PackageName() string {
	return tn.proto.GetPackageName()
}

// ModuleName returns the module name of the target.
func (tn *TargetNode) ModuleName() string {
	return tn.proto.GetModuleName()
}

// Projects returns the projects defining the target node. (unordered)
//
// In an ideal world, only 1 project defines a target, but the interaction
// between Soong and Make for a variety of architectures and for host versus
// product means a module is sometimes defined more than once.
func (tn *TargetNode) Projects() []string {
	return append([]string{}, tn.proto.Projects...)
}

// LicenseConditions returns a copy of the set of license conditions
// originating at the target. The values that appear and how each is resolved
// is a matter of policy. (unordered)
//
// e.g. notice or proprietary
func (tn *TargetNode) LicenseConditions() LicenseConditionSet {
	return tn.licenseConditions
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

// TargetFiles returns the list of files built or installed by the module or
// target. (unordered)
func (tn *TargetNode) TargetFiles() []string {
	return append(tn.proto.Built, tn.proto.Installed...)
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
	annotations map[string]struct{}
}

// newEdgeAnnotations creates a new instance of TargetEdgeAnnotations.
func newEdgeAnnotations() TargetEdgeAnnotations {
	return TargetEdgeAnnotations{make(map[string]struct{})}
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
type TargetNodeSet map[*TargetNode]struct{}

// Contains returns true when `target` is an element of the set.
func (ts TargetNodeSet) Contains(target *TargetNode) bool {
	_, isPresent := ts[target]
	return isPresent
}

// Names returns the array of target node namess in the set. (unordered)
func (ts TargetNodeSet) Names() []string {
	result := make([]string, 0, len(ts))
	for tn := range ts {
		result = append(result, tn.name)
	}
	return result
}

// String returns a human-readable string representation of the set.
func (ts TargetNodeSet) String() string {
	return fmt.Sprintf("{%s}", strings.Join(ts.Names(), ", "))
}

// TargetNodeList orders a list of targets by name.
type TargetNodeList []*TargetNode

// Len returns the count of elements in the list.
func (l TargetNodeList) Len() int { return len(l) }

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
