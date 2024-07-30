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

// Driver for c++ extractor. Operates in two modes:
// - DEPS, scans build graph for active files and reports targets that need to
// be build for analyzing that file.
// - INPUTS, scans the source code for active files and returns all the sources
// required for analyzing that file.
//
// Uses stdin/stdout to take in requests and provide responses.
#include <unistd.h>

#include <memory>
#include <utility>

#include "analyzer.h"
#include "google/protobuf/message.h"
#include "cc_analyzer.pb.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"

namespace {
enum class OpMode {
  DEPS = 0,
  INPUTS = 1,
};
llvm::cl::opt<OpMode> mode{
    "mode",
    llvm::cl::values(clEnumValN(OpMode::DEPS, "deps",
                                "Figure out targets that need to be build"),
                     clEnumValN(OpMode::INPUTS, "inputs",
                                "Figure out generated files used")),
    llvm::cl::desc("Print the list of headers to insert and remove"),
};

cc_analyzer::IdeAnalysis ReturnError(llvm::StringRef message) {
  cc_analyzer::IdeAnalysis result;
  result.mutable_status()->set_code(cc_analyzer::Status::FAILURE);
  result.mutable_status()->set_message(message.str());
  return result;
}

}  // namespace

int main(int argc, char* argv[]) {
  llvm::InitializeAllTargetInfos();
  llvm::cl::ParseCommandLineOptions(argc, argv);

  cc_analyzer::RepoState state;
  if (!state.ParseFromFileDescriptor(STDIN_FILENO)) {
    llvm::errs() << "Failed to parse input!\n";
    return 1;
  }

  std::unique_ptr<google::protobuf::Message> result;
  switch (mode) {
    case OpMode::DEPS: {
      result = std::make_unique<cc_analyzer::DepsResponse>(
          tools::ide_query::cc_analyzer::GetDeps(std::move(state)));
      break;
    }
    case OpMode::INPUTS: {
      result = std::make_unique<cc_analyzer::IdeAnalysis>(
          tools::ide_query::cc_analyzer::GetBuildInputs(std::move(state)));
      break;
    }
    default:
      llvm::errs() << "Unknown operation mode!\n";
      return 1;
  }
  if (!result->SerializeToFileDescriptor(STDOUT_FILENO)) {
    llvm::errs() << "Failed to serialize result!\n";
    return 1;
  }

  return 0;
}
