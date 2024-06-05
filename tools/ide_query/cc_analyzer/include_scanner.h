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
#ifndef _TOOLS_IDE_QUERY_CC_ANALYZER_INCLUDE_SCANNER_H_
#define _TOOLS_IDE_QUERY_CC_ANALYZER_INCLUDE_SCANNER_H_

#include <string>
#include <utility>
#include <vector>

#include "clang/Tooling/CompilationDatabase.h"
#include "llvm/ADT/IntrusiveRefCntPtr.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/VirtualFileSystem.h"

namespace tools::ide_query::cc_analyzer {

// Returns absolute paths and contents for all the includes necessary for
// compiling source file in command.
llvm::Expected<std::vector<std::pair<std::string, std::string>>> ScanIncludes(
    const clang::tooling::CompileCommand &cmd,
    llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem> fs);

}  // namespace tools::ide_query::cc_analyzer

#endif
