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
#include "include_scanner.h"

#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#include "builtin_headers.h"
#include "clang/Basic/FileEntry.h"
#include "clang/Basic/FileManager.h"
#include "clang/Basic/Module.h"
#include "clang/Basic/SourceLocation.h"
#include "clang/Basic/SourceManager.h"
#include "clang/Frontend/ASTUnit.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Frontend/FrontendActions.h"
#include "clang/Lex/PPCallbacks.h"
#include "clang/Tooling/ArgumentsAdjusters.h"
#include "clang/Tooling/CompilationDatabase.h"
#include "clang/Tooling/Tooling.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/ADT/IntrusiveRefCntPtr.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/Twine.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/VirtualFileSystem.h"

namespace tools::ide_query::cc_analyzer {
namespace {
std::string CleanPath(llvm::StringRef path) {
  // both ./ and ../ has `./` in them.
  if (!path.contains("./")) return path.str();
  llvm::SmallString<256> clean_path(path);
  llvm::sys::path::remove_dots(clean_path, /*remove_dot_dot=*/true);
  return clean_path.str().str();
}

// Returns the absolute path to file_name, treating it as relative to cwd if it
// isn't already absolute.
std::string GetAbsolutePath(llvm::StringRef cwd, llvm::StringRef file_name) {
  if (llvm::sys::path::is_absolute(file_name)) return CleanPath(file_name);
  llvm::SmallString<256> abs_path(cwd);
  llvm::sys::path::append(abs_path, file_name);
  llvm::sys::path::remove_dots(abs_path, /*remove_dot_dot=*/true);
  return abs_path.str().str();
}

class IncludeRecordingPP : public clang::PPCallbacks {
 public:
  explicit IncludeRecordingPP(
      std::unordered_map<std::string, std::string> &abs_paths, std::string cwd,
      const clang::SourceManager &sm)
      : abs_paths_(abs_paths), cwd_(std::move(cwd)), sm_(sm) {}

  void LexedFileChanged(clang::FileID FID, LexedFileChangeReason Reason,
                        clang::SrcMgr::CharacteristicKind FileType,
                        clang::FileID PrevFID,
                        clang::SourceLocation Loc) override {
    auto file_entry = sm_.getFileEntryRefForID(FID);
    if (!file_entry) return;
    auto abs_path = GetAbsolutePath(cwd_, file_entry->getName());
    auto [it, inserted] = abs_paths_.try_emplace(abs_path);
    if (inserted) it->second = sm_.getBufferData(FID);
  }

  std::unordered_map<std::string, std::string> &abs_paths_;
  const std::string cwd_;
  const clang::SourceManager &sm_;
};

class IncludeScanningAction final : public clang::PreprocessOnlyAction {
 public:
  explicit IncludeScanningAction(
      std::unordered_map<std::string, std::string> &abs_paths)
      : abs_paths_(abs_paths) {}
  bool BeginSourceFileAction(clang::CompilerInstance &ci) override {
    std::string cwd;
    auto cwd_or_err = ci.getVirtualFileSystem().getCurrentWorkingDirectory();
    if (!cwd_or_err || cwd_or_err.get().empty()) return false;
    cwd = cwd_or_err.get();
    ci.getPreprocessor().addPPCallbacks(std::make_unique<IncludeRecordingPP>(
        abs_paths_, std::move(cwd), ci.getSourceManager()));
    return true;
  }

 private:
  std::unordered_map<std::string, std::string> &abs_paths_;
};

llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem> OverlayBuiltinHeaders(
    std::vector<std::string> &argv,
    llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem> base) {
  static constexpr llvm::StringLiteral kResourceDir = "/resources";
  llvm::IntrusiveRefCntPtr<llvm::vfs::OverlayFileSystem> overlay(
      new llvm::vfs::OverlayFileSystem(std::move(base)));
  llvm::IntrusiveRefCntPtr<llvm::vfs::InMemoryFileSystem> builtin_headers(
      new llvm::vfs::InMemoryFileSystem);

  llvm::SmallString<256> file_path;
  for (const auto &builtin_header :
       llvm::ArrayRef(builtin_headers_create(), builtin_headers_size())) {
    file_path.clear();
    llvm::sys::path::append(file_path, kResourceDir, "include",
                            builtin_header.name);
    builtin_headers->addFile(
        file_path,
        /*ModificationTime=*/0,
        llvm::MemoryBuffer::getMemBuffer(builtin_header.data));
  }
  overlay->pushOverlay(std::move(builtin_headers));
  argv.insert(llvm::find(argv, "--"),
              llvm::Twine("-resource-dir=", kResourceDir).str());
  return overlay;
}

}  // namespace

llvm::Expected<std::vector<std::pair<std::string, std::string>>> ScanIncludes(
    const clang::tooling::CompileCommand &cmd,
    llvm::IntrusiveRefCntPtr<llvm::vfs::FileSystem> fs) {
  if (fs->setCurrentWorkingDirectory(cmd.Directory)) {
    return llvm::createStringError(
        llvm::inconvertibleErrorCode(),
        "Failed to set working directory to: " + cmd.Directory);
  }

  auto main_file = fs->getBufferForFile(cmd.Filename);
  if (!main_file) {
    return llvm::createStringError(llvm::inconvertibleErrorCode(),
                                   "Main file doesn't exist: " + cmd.Filename);
  }
  std::unordered_map<std::string, std::string> abs_paths;
  abs_paths.try_emplace(GetAbsolutePath(cmd.Directory, cmd.Filename),
                        main_file.get()->getBuffer().str());

  std::vector<std::string> argv = cmd.CommandLine;
  fs = OverlayBuiltinHeaders(argv, std::move(fs));

  llvm::IntrusiveRefCntPtr<clang::FileManager> files(
      new clang::FileManager(/*FileSystemOpts=*/{}, std::move(fs)));
  clang::tooling::ToolInvocation tool(
      argv, std::make_unique<IncludeScanningAction>(abs_paths), files.get());
  if (!tool.run()) {
    return llvm::createStringError(
        llvm::inconvertibleErrorCode(),
        "Failed to scan includes for: " + cmd.Filename);
  }

  std::vector<std::pair<std::string, std::string>> result;
  result.reserve(abs_paths.size());
  for (auto &entry : abs_paths) {
    result.emplace_back(entry.first, std::move(entry.second));
  }
  return result;
}
}  // namespace tools::ide_query::cc_analyzer
