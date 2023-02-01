# Compliance

<!-- Much of this content appears too in doc.go
When changing this file consider whether the change also applies to doc.go -->

Package compliance provides an approved means for reading, consuming, and
analyzing license metadata graphs.

Assuming the license metadata and dependencies are fully and accurately
recorded in the build system, any discrepancy between the official policy for
open source license compliance and this code is **a bug in this code.**

## Naming

All of the code that directly reflects a policy decision belongs in a file with
a name begninning `policy_`. Changes to these files need to be authored or
reviewed by someone in OSPO or whichever successor group governs policy.

The files with names not beginning `policy_` describe data types, and general,
reusable algorithms.

The source code for binary tools and utilities appears under the `cmd/`
subdirectory. Other subdirectories contain reusable components that are not
`compliance` per se.

## Data Types

A few principal types to understand are LicenseGraph, LicenseCondition, and
ResolutionSet.

### LicenseGraph

A LicenseGraph is an immutable graph of the targets and dependencies reachable
from a specific set of root targets. In general, the root targets will be the
artifacts in a release or distribution. While conceptually immutable, parts of
the graph may be loaded or evaluated lazily.

Conceptually, the graph itself will always be a directed acyclic graph. One
representation is a set of directed edges. Another is a set of nodes with
directed edges to their dependencies.

The edges have annotations, which can distinguish between build tools, runtime
dependencies, and dependencies like 'contains' that make a derivative work.

### LicenseCondition

A LicenseCondition is an immutable tuple pairing a condition name with an
originating target. e.g. Per current policy, a static library licensed under an
MIT license would pair a "notice" condition with the static library target, and
a dynamic license licensed under GPL would pair a "restricted" condition with
the dynamic library target.

### ResolutionSet

A ResolutionSet is an immutable set of `AttachesTo`, `ActsOn`, `Resolves`
tuples describing how license conditions apply to targets.

`AttachesTo` is the trigger for acting. Distribution of the target invokes
the policy.

`ActsOn` is the target to share, give notice for, hide etc.

`Resolves` is the set of conditions that the action resolves.

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

## Processes

### ReadLicenseGraph

The principal means to ingest license metadata. Given the distribution targets,
ReadLicenseGraph populates the LicenseGraph for those root targets.

### NoticeIndex.IndexLicenseTexts

IndexLicenseTexts reads, deduplicates and caches license texts for notice
files. Also reads and caches project metadata for deriving library names.

The algorithm for deriving library names has not been dictated by OSPO policy,
but reflects a pragmatic attempt to comply with Android policy regarding
unreleased product names, proprietary partner names etc.

### projectmetadata.Index.MetadataForProjects

MetadataForProjects reads, deduplicates and caches project METADATA files used
for notice library names, and various properties appearing in SBOMs.
