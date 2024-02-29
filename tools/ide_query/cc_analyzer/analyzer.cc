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
#include "analyzer.h"

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "clang/Tooling/CompilationDatabase.h"
#include "clang/Tooling/JSONCompilationDatabase.h"
#include "ide_query.pb.h"
#include "include_scanner.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/VirtualFileSystem.h"

namespace tools::ide_query::cc_analyzer {
namespace {
llvm::Expected<std::unique_ptr<clang::tooling::CompilationDatabase>> LoadCompDB(
    llvm::StringRef comp_db_path) {
  std::string err;
  std::unique_ptr<clang::tooling::CompilationDatabase> db =
      clang::tooling::JSONCompilationDatabase::loadFromFile(
          comp_db_path, err, clang::tooling::JSONCommandLineSyntax::AutoDetect);
  if (!db) {
    return llvm::createStringError(llvm::inconvertibleErrorCode(),
                                   "Failed to load CDB: " + err);
  }
  // Provide some heuristic support for missing files.
  return inferMissingCompileCommands(std::move(db));
}
}  // namespace

::ide_query::DepsResponse GetDeps(::ide_query::RepoState state) {
  ::ide_query::DepsResponse results;
  auto db = LoadCompDB(state.comp_db_path());
  if (!db) {
    results.mutable_status()->set_code(::ide_query::Status::FAILURE);
    results.mutable_status()->set_message(llvm::toString(db.takeError()));
    return results;
  }
  for (llvm::StringRef active_file : state.active_file_path()) {
    auto& result = *results.add_deps();

    llvm::SmallString<256> abs_file(state.repo_dir());
    llvm::sys::path::append(abs_file, active_file);
    auto cmds = db->get()->getCompileCommands(active_file);
    if (cmds.empty()) {
      result.mutable_status()->set_code(::ide_query::Status::FAILURE);
      result.mutable_status()->set_message(
          llvm::Twine("Can't find compile flags for file: ", abs_file).str());
      continue;
    }
    result.set_source_file(active_file.str());
    llvm::StringRef file = cmds[0].Filename;
    if (llvm::StringRef actual_file(cmds[0].Heuristic);
        actual_file.consume_front("inferred from ")) {
      file = actual_file;
    }
    // TODO: Query ninja graph to figure out a minimal set of targets to build.
    result.add_build_target(file.str() + "^");
  }
  return results;
}

::ide_query::IdeAnalysis GetBuildInputs(::ide_query::RepoState state) {
  auto db = LoadCompDB(state.comp_db_path());
  ::ide_query::IdeAnalysis results;
  if (!db) {
    results.mutable_status()->set_code(::ide_query::Status::FAILURE);
    results.mutable_status()->set_message(llvm::toString(db.takeError()));
    return results;
  }
  std::string repo_dir = state.repo_dir();
  if (!repo_dir.empty() && repo_dir.back() == '/') repo_dir.pop_back();

  llvm::SmallString<256> genfile_root_abs(repo_dir);
  llvm::sys::path::append(genfile_root_abs, state.out_dir());
  if (genfile_root_abs.empty() || genfile_root_abs.back() != '/') {
    genfile_root_abs.push_back('/');
  }

  results.set_build_artifact_root(state.out_dir());
  for (llvm::StringRef active_file : state.active_file_path()) {
    auto& result = *results.add_sources();
    result.set_path(active_file.str());

    llvm::SmallString<256> abs_file(repo_dir);
    llvm::sys::path::append(abs_file, active_file);
    auto cmds = db->get()->getCompileCommands(abs_file);
    if (cmds.empty()) {
      result.mutable_status()->set_code(::ide_query::Status::FAILURE);
      result.mutable_status()->set_message(
          llvm::Twine("Can't find compile flags for file: ", abs_file).str());
      continue;
    }
    const auto& cmd = cmds.front();
    llvm::StringRef working_dir = cmd.Directory;
    if (!working_dir.consume_front(repo_dir)) {
      result.mutable_status()->set_code(::ide_query::Status::FAILURE);
      result.mutable_status()->set_message("Command working dir " +
                                           working_dir.str() +
                                           "outside repository " + repo_dir);
      continue;
    }
    working_dir = working_dir.ltrim('/');
    result.set_working_dir(working_dir.str());
    for (auto& arg : cmd.CommandLine) result.add_compiler_arguments(arg);

    auto includes =
        ScanIncludes(cmds.front(), llvm::vfs::createPhysicalFileSystem());
    if (!includes) {
      result.mutable_status()->set_code(::ide_query::Status::FAILURE);
      result.mutable_status()->set_message(
          llvm::toString(includes.takeError()));
      continue;
    }

    for (auto& [req_input, contents] : *includes) {
      llvm::StringRef req_input_ref(req_input);
      // We're only interested in generated files.
      if (!req_input_ref.consume_front(genfile_root_abs)) continue;
      auto& genfile = *result.add_generated();
      genfile.set_path(req_input_ref.str());
      genfile.set_contents(std::move(contents));
    }
  }
  return results;
}
}  // namespace tools::ide_query::cc_analyzer
