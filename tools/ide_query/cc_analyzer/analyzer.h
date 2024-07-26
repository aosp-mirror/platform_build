/*
 * Copyright (C) 2024 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _TOOLS_IDE_QUERY_CC_ANALYZER_ANALYZER_H_
#define _TOOLS_IDE_QUERY_CC_ANALYZER_ANALYZER_H_

#include "cc_analyzer.pb.h"

namespace tools::ide_query::cc_analyzer {

// Scans the build graph and returns target names from the build graph to
// generate all the dependencies for the active files.
::cc_analyzer::DepsResponse GetDeps(::cc_analyzer::RepoState state);

// Scans the sources and returns all the source files required for analyzing the
// active files.
::cc_analyzer::IdeAnalysis GetBuildInputs(::cc_analyzer::RepoState state);

}  // namespace tools::ide_query::cc_analyzer

#endif
