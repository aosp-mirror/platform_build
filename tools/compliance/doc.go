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

// Much of this content appears too in README.md
// When changing this file consider whether the change also applies to README.md

/*

Package compliance provides an approved means for reading, consuming, and
analyzing license metadata graphs.

Assuming the license metadata and dependencies are fully and accurately
recorded in the build system, any discrepancy between the official policy for
open source license compliance and this code is a bug in this code.

A few principal types to understand are LicenseGraph, LicenseCondition, and
ResolutionSet.

LicenseGraph
------------

A LicenseGraph is an immutable graph of the targets and dependencies reachable
from a specific set of root targets. In general, the root targets will be the
artifacts in a release or distribution. While conceptually immutable, parts of
the graph may be loaded or evaluated lazily.

Conceptually, the graph itself will always be a directed acyclic graph. One
representation is a set of directed edges. Another is a set of nodes with
directed edges to their dependencies.

The edges have annotations, which can distinguish between build tools, runtime
dependencies, and dependencies like 'contains' that make a derivative work.

LicenseCondition
----------------

A LicenseCondition is an immutable tuple pairing a condition name with an
originating target. e.g. Per current policy, a static library licensed under an
MIT license would pair a "notice" condition with the static library target, and
a dynamic license licensed under GPL would pair a "restricted" condition with
the dynamic library target.

ResolutionSet
-------------

A ResolutionSet is an immutable set of `AttachesTo`, `ActsOn`, `Resolves`
tuples describing how license conditions apply to targets.

`AttachesTo` is the trigger for acting. Distribution of the target invokes
the policy.

`ActsOn` is the target to share, give notice for, hide etc.

`Resolves` is the set of condition types that the action resolves.

For most condition types, `ActsOn` will be the target where the condition
originated. For example, a notice condition policy means attribution or notice
must be given for the target where the condition originates. Likewise, a
proprietary condition policy means the privacy of the target where the
condition originates must be respected. i.e. The thing acted on is the origin.

Restricted conditions are different. The infectious nature of restricted often
means sharing code that is not the target where the restricted condition
originates. Linking an MIT library to a GPL library implies a policy to share
the MIT library despite the MIT license having no source sharing requirement.

In this case, one or more resolution tuples will have the MIT license module in
`ActsOn` and the restricted condition originating at the GPL library module in
`Resolves`. These tuples will `AttachTo` every target that depends on the GPL
library because shipping any of those targets trigger the policy to share the
code.
*/
package compliance
