#!/usr/bin/env -S python3 -u

"""
This script helps find various build behaviors that make builds less hermetic
and repeatable. Depending on the flags, it runs a sequence of builds and looks
for files that have changed or have been improperly regenerated, updating
their timestamps incorrectly. It also looks for changes that the build has
done to the source tree, and for files whose contents are dependent on the
location of the out directory.

This utility has two major modes, full and incremental. By default, this tool
runs in full mode. To run in incremental mode, pass the --incremental flag.


FULL MODE

In full mode, this tool helps verify BUILD CORRECTNESS by examining its
REPEATABILITY. In full mode, this tool runs two complete builds in different
directories and compares the CONTENTS of the two directories. Lists of any
files that are added, removed or changed are printed, sorted by the timestamp
of that file, to aid finding which dependencies trigger the rebuilding of
other files.


INCREMENTAL MODE

In incremental mode, this tool helps verfiy the SPEED of the build. It runs two
builds and looks at the TIMESTAMPS of the generated files, and reports files
that were changed by the second build. In theory, an incremental build with no
source files touched should not have any generated targets changed. As in full
builds, the file list is returned sorted by timestamp.


OTHER CHECKS

In both full and incremental mode, this tool looks at the timestamps of all
source files in the tree, and reports on files that have been touched. In the
output, these are labeled with the header "Source files touched after start of
build."

In addition, by default, this tool sets the OUT_DIR environment variable to
something other than "out" in order to find build rules that are not respecting
the OUT_DIR. If you see these, you should fix them, but if your build can not
complete for some reason because of this, you can pass the --no-check-out-dir
flag to suppress this check.


OTHER FLAGS

In full mode, the --detect-embedded-paths flag does the two builds in different
directories, to help in finding rules that embed the out directory path into
the targets.

The --hide-build-output flag hides the output of successful bulds, to make
script output cleaner. The output of builds that fail is still shown.

The --no-build flag is useful if you have already done a build and would
just like to re-run the analysis.

The --target flag lets you specify a build target other than the default
full build (droid). You can pass "nothing" as in the example below, or a
specific target, to reduce the scope of the checks performed.

The --touch flag lets you specify a list of source files to touch between
the builds, to examine the consequences of editing a particular file.


EXAMPLE COMMANDLINES

Please run build/make/tools/compare_builds.py --help for a full listing
of the commandline flags. Here are a sampling of useful combinations.

  1. Find files changed during an incremental build that doesn't build
     any targets.

       build/make/tools/compare_builds.py --incremental --target nothing

     Long incremental build times, or consecutive builds that re-run build actions
     are usually caused by files being touched as part of loading the makefiles.

     The nothing build (m nothing) loads the make and blueprint files, generates
     the dependency graph, but then doesn't actually build any targets. Checking
     against this build is the fastest and easiest way to find files that are
     modified while makefiles are read, for example with $(shell) invocations.

  2. Find packaging targets that are different, ignoring intermediate files.

       build/make/tools/compare_builds.py --subdirs --detect-embedded-paths

     These flags will compare the final staging directories for partitions,
     as well as the APKs, apexes, testcases, and the like (the full directory
     list is in the DEFAULT_DIRS variable below). Since these are the files
     that are ultimately released, it is more important that these files be
     replicable, even if the intermediates that went into them are not (for
     example, when debugging symbols are stripped).

  3. Check that all targets are repeatable.

       build/make/tools/compare_builds.py --detect-embedded-paths

     This check will list all of the differences in built targets that it can
     find. Be aware that the AOSP tree still has quite a few targets that
     are flagged by this check, so OEM changes might be lost in that list.
     That said, each file shown here is a potential blocker for a repeatable
     build.

  4. See what targets are rebuilt when a file is touched between builds.

       build/make/tools/compare_builds.py --incremental \
            --touch frameworks/base/core/java/android/app/Activity.java

     This check simulates the common engineer workflow of touching a single
     file and rebuilding the whole system. To see a restricted view, consider
     also passing a --target option for a common use case. For example:

       build/make/tools/compare_builds.py --incremental --target framework \
            --touch frameworks/base/core/java/android/app/Activity.java
"""

import argparse
import itertools
import os
import shutil
import stat
import subprocess
import sys


# Soong
SOONG_UI = "build/soong/soong_ui.bash"


# Which directories to use if no --subdirs is supplied without explicit directories.
DEFAULT_DIRS = (
    "apex",
    "data",
    "product",
    "ramdisk",
    "recovery",
    "root",
    "system",
    "system_ext",
    "system_other",
    "testcases",
    "vendor",
)


# Files to skip for incremental timestamp checking
BUILD_INTERNALS_PREFIX_SKIP = (
    "soong/.glob/",
    ".path/",
)


BUILD_INTERNALS_SUFFIX_SKIP = (
    "/soong/soong_build_metrics.pb",
    "/.installable_test_files",
    "/files.db",
    "/.blueprint.bootstrap",
    "/build_number.txt",
    "/build.ninja",
    "/.out-dir",
    "/build_fingerprint.txt",
    "/build_thumbprint.txt",
    "/.copied_headers_list",
    "/.installable_files",
)


class DiffType(object):
  def __init__(self, code, message):
    self.code = code
    self.message = message

DIFF_NONE = DiffType("DIFF_NONE", "Files are the same")
DIFF_MODE = DiffType("DIFF_MODE", "Stat mode bits differ")
DIFF_SIZE = DiffType("DIFF_SIZE", "File size differs")
DIFF_SYMLINK = DiffType("DIFF_SYMLINK", "Symlinks point to different locations")
DIFF_CONTENTS = DiffType("DIFF_CONTENTS", "File contents differ")


def main():
  argparser = argparse.ArgumentParser(description="Diff build outputs from two builds.",
                                      epilog="Run this command from the root of the tree."
                                        + " Before running this command, the build environment"
                                        + " must be set up, including sourcing build/envsetup.sh"
                                        + " and running lunch.")
  argparser.add_argument("--detect-embedded-paths", action="store_true",
      help="Use unique out dirs to detect paths embedded in binaries.")
  argparser.add_argument("--incremental", action="store_true",
      help="Compare which files are touched in two consecutive builds without a clean in between.")
  argparser.add_argument("--hide-build-output", action="store_true",
      help="Don't print the build output for successful builds")
  argparser.add_argument("--no-build", dest="run_build", action="store_false",
      help="Don't build or clean, but do everything else.")
  argparser.add_argument("--no-check-out-dir", dest="check_out_dir", action="store_false",
      help="Don't check for rules not honoring movable out directories.")
  argparser.add_argument("--subdirs", nargs="*",
      help="Only scan these subdirs of $PRODUCT_OUT instead of the whole out directory."
           + " The --subdirs argument with no listed directories will give a default list.")
  argparser.add_argument("--target", default="droid",
      help="Make target to run. The default is droid")
  argparser.add_argument("--touch", nargs="+", default=[],
      help="Files to touch between builds. Must pair with --incremental.")
  args = argparser.parse_args(sys.argv[1:])

  if args.detect_embedded_paths and args.incremental:
    sys.stderr.write("Can't pass --detect-embedded-paths and --incremental together.\n")
    sys.exit(1)
  if args.detect_embedded_paths and not args.check_out_dir:
    sys.stderr.write("Can't pass --detect-embedded-paths and --no-check-out-dir together.\n")
    sys.exit(1)
  if args.touch and not args.incremental:
    sys.stderr.write("The --incremental flag is required if the --touch flag is passed.")
    sys.exit(1)

  AssertAtTop()
  RequireEnvVar("TARGET_PRODUCT")
  RequireEnvVar("TARGET_BUILD_VARIANT")

  # Out dir file names:
  #   - dir_prefix - The directory we'll put everything in (except for maybe the top level
  #     out/ dir).
  #   - *work_dir - The directory that we will build directly into. This is in dir_prefix
  #     unless --no-check-out-dir is set.
  #   - *out_dir - After building, if work_dir is different from out_dir, we move the out
  #     directory to here so we can do the comparisions.
  #   - timestamp_* - Files we touch so we know the various phases between the builds, so we
  #     can compare timestamps of files.
  if args.incremental:
    dir_prefix = "out_incremental"
    if args.check_out_dir:
      first_work_dir = first_out_dir = dir_prefix + "/out"
      second_work_dir = second_out_dir = dir_prefix + "/out"
    else:
      first_work_dir = first_out_dir = "out"
      second_work_dir = second_out_dir = "out"
  else:
    dir_prefix = "out_full"
    first_out_dir = dir_prefix + "/out_1"
    second_out_dir = dir_prefix + "/out_2"
    if not args.check_out_dir:
      first_work_dir = second_work_dir = "out"
    elif args.detect_embedded_paths:
      first_work_dir = first_out_dir
      second_work_dir = second_out_dir
    else:
      first_work_dir = dir_prefix + "/work"
      second_work_dir = dir_prefix + "/work"
  timestamp_start = dir_prefix + "/timestamp_start"
  timestamp_between = dir_prefix + "/timestamp_between"
  timestamp_end = dir_prefix + "/timestamp_end"

  if args.run_build:
    # Initial clean, if necessary
    print("Cleaning " + dir_prefix + "/")
    Clean(dir_prefix)
    print("Cleaning out/")
    Clean("out")
    CreateEmptyFile(timestamp_start)
    print("Running the first build in " + first_work_dir)
    RunBuild(first_work_dir, first_out_dir, args.target, args.hide_build_output)
    for f in args.touch:
      print("Touching " + f)
      TouchFile(f)
    CreateEmptyFile(timestamp_between)
    print("Running the second build in " + second_work_dir)
    RunBuild(second_work_dir, second_out_dir, args.target, args.hide_build_output)
    CreateEmptyFile(timestamp_end)
    print("Done building")
    print()

  # Which out directories to scan
  if args.subdirs is not None:
    if args.subdirs:
      subdirs = args.subdirs
    else:
      subdirs = DEFAULT_DIRS
    first_files = ProductFiles(RequireBuildVar(first_out_dir, "PRODUCT_OUT"), subdirs)
    second_files = ProductFiles(RequireBuildVar(second_out_dir, "PRODUCT_OUT"), subdirs)
  else:
    first_files = OutFiles(first_out_dir)
    second_files = OutFiles(second_out_dir)

  printer = Printer()

  if args.incremental:
    # Find files that were rebuilt unnecessarily
    touched_incrementally = FindOutFilesTouchedAfter(first_files,
                                                     GetFileTimestamp(timestamp_between))
    printer.PrintList("Touched in incremental build", touched_incrementally)
  else:
    # Compare the two out dirs
    added, removed, changed = DiffFileList(first_files, second_files)
    printer.PrintList("Added", added)
    printer.PrintList("Removed", removed)
    printer.PrintList("Changed", changed, "%s %s")

  # Find files in the source tree that were touched
  touched_during = FindSourceFilesTouchedAfter(GetFileTimestamp(timestamp_start))
  printer.PrintList("Source files touched after start of build", touched_during)

  # Find files and dirs that were output to "out" and didn't respect $OUT_DIR
  if args.check_out_dir:
    bad_out_dir_contents = FindFilesAndDirectories("out")
    printer.PrintList("Files and directories created by rules that didn't respect $OUT_DIR",
                      bad_out_dir_contents)

  # If we didn't find anything, print success message
  if not printer.printed_anything:
    print("No bad behaviors found.")


def AssertAtTop():
  """If the current directory is not the top of an android source tree, print an error
     message and exit."""
  if not os.access(SOONG_UI, os.X_OK):
    sys.stderr.write("FAILED: Please run from the root of the tree.\n")
    sys.exit(1)


def RequireEnvVar(name):
  """Gets an environment variable. If that fails, then print an error message and exit."""
  result = os.environ.get(name)
  if not result:
    sys.stderr.write("error: Can't determine %s. Please run lunch first.\n" % name)
    sys.exit(1)
  return result


def RunSoong(out_dir, args, capture_output):
  env = dict(os.environ)
  env["OUT_DIR"] = out_dir
  args = [SOONG_UI,] + args
  if capture_output:
    proc = subprocess.Popen(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    combined_output, none = proc.communicate()
    return proc.returncode, combined_output
  else:
    result = subprocess.run(args, env=env)
    return result.returncode, None


def GetBuildVar(out_dir, name):
  """Gets a variable from the build system."""
  returncode, output = RunSoong(out_dir, ["--dumpvar-mode", name], True)
  if returncode != 0:
    return None
  else:
    return output.decode("utf-8").strip()


def RequireBuildVar(out_dir, name):
  """Gets a variable from the builds system. If that fails, then print an error
     message and exit."""
  value = GetBuildVar(out_dir, name)
  if not value:
    sys.stderr.write("error: Can't determine %s. Please run lunch first.\n" % name)
    sys.exit(1)
  return value


def Clean(directory):
  """"Deletes the supplied directory."""
  try:
    shutil.rmtree(directory)
  except FileNotFoundError:
    pass


def RunBuild(work_dir, out_dir, target, hide_build_output):
  """Runs a build. If the build fails, prints a message and exits."""
  returncode, output = RunSoong(work_dir,
                    ["--build-mode", "--all-modules", "--dir=" + os.getcwd(), target],
                    hide_build_output)
  if work_dir != out_dir:
    os.replace(work_dir, out_dir)
  if returncode != 0:
    if hide_build_output:
      # The build output was hidden, so print it now for debugging
      sys.stderr.buffer.write(output)
    sys.stderr.write("FAILED: Build failed. Stopping.\n")
    sys.exit(1)


def DiffFileList(first_files, second_files):
  """Examines the files.

  Returns:
    Filenames of files in first_filelist but not second_filelist (added files)
    Filenames of files in second_filelist but not first_filelist (removed files)
    2-Tuple of filenames for the files that are in both but are different (changed files)
  """
  # List of files, relative to their respective PRODUCT_OUT directories
  first_filelist = sorted([x for x in first_files], key=lambda x: x[1])
  second_filelist = sorted([x for x in second_files], key=lambda x: x[1])

  added = []
  removed = []
  changed = []

  first_index = 0
  second_index = 0

  while first_index < len(first_filelist) and second_index < len(second_filelist):
    # Path relative to source root and path relative to PRODUCT_OUT
    first_full_filename, first_relative_filename = first_filelist[first_index]
    second_full_filename, second_relative_filename = second_filelist[second_index]

    if first_relative_filename < second_relative_filename:
      # Removed
      removed.append(first_full_filename)
      first_index += 1
    elif first_relative_filename > second_relative_filename:
      # Added
      added.append(second_full_filename)
      second_index += 1
    else:
      # Both present
      diff_type = DiffFiles(first_full_filename, second_full_filename)
      if diff_type != DIFF_NONE:
        changed.append((first_full_filename, second_full_filename))
      first_index += 1
      second_index += 1

  while first_index < len(first_filelist):
    first_full_filename, first_relative_filename = first_filelist[first_index]
    removed.append(first_full_filename)
    first_index += 1

  while second_index < len(second_filelist):
    second_full_filename, second_relative_filename = second_filelist[second_index]
    added.append(second_full_filename)
    second_index += 1

  return (SortByTimestamp(added),
          SortByTimestamp(removed),
          SortByTimestamp(changed, key=lambda item: item[1]))


def FindOutFilesTouchedAfter(files, timestamp):
  """Find files in the given file iterator that were touched after timestamp."""
  result = []
  for full, relative in files:
    ts = GetFileTimestamp(full)
    if ts > timestamp:
      result.append(TouchedFile(full, ts))
  return [f.filename for f in sorted(result, key=lambda f: f.timestamp)]


def GetFileTimestamp(filename):
  """Get timestamp for a file (just wraps stat)."""
  st = os.stat(filename, follow_symlinks=False)
  return st.st_mtime


def SortByTimestamp(items, key=lambda item: item):
  """Sort the list by timestamp of files.
  Args:
    items - the list of items to sort
    key - a function to extract a filename from each element in items
  """
  return [x[0] for x in sorted([(item, GetFileTimestamp(key(item))) for item in items],
                               key=lambda y: y[1])]


def FindSourceFilesTouchedAfter(timestamp):
  """Find files in the source tree that have changed after timestamp. Ignores
  the out directory."""
  result = []
  for root, dirs, files in os.walk(".", followlinks=False):
    if root == ".":
      RemoveItemsFromList(dirs, (".repo", "out", "out_full", "out_incremental"))
    for f in files:
      full = os.path.sep.join((root, f))[2:]
      ts = GetFileTimestamp(full)
      if ts > timestamp:
        result.append(TouchedFile(full, ts))
  return [f.filename for f in sorted(result, key=lambda f: f.timestamp)]


def FindFilesAndDirectories(directory):
  """Finds all files and directories inside a directory."""
  result = []
  for root, dirs, files in os.walk(directory, followlinks=False):
    result += [os.path.sep.join((root, x, "")) for x in dirs]
    result += [os.path.sep.join((root, x)) for x in files]
  return result


def CreateEmptyFile(filename):
  """Create an empty file with now as the timestamp at filename."""
  try:
    os.makedirs(os.path.dirname(filename))
  except FileExistsError:
    pass
  open(filename, "w").close()
  os.utime(filename)


def TouchFile(filename):
  os.utime(filename)


def DiffFiles(first_filename, second_filename):
  def AreFileContentsSame(remaining, first_filename, second_filename):
    """Compare the file contents. They must be known to be the same size."""
    CHUNK_SIZE = 32*1024
    with open(first_filename, "rb") as first_file:
      with open(second_filename, "rb") as second_file:
        while remaining > 0:
          size = min(CHUNK_SIZE, remaining)
          if first_file.read(CHUNK_SIZE) != second_file.read(CHUNK_SIZE):
            return False
          remaining -= size
        return True

  first_stat = os.stat(first_filename, follow_symlinks=False)
  second_stat = os.stat(first_filename, follow_symlinks=False)

  # Mode bits
  if first_stat.st_mode != second_stat.st_mode:
    return DIFF_MODE

  # File size
  if first_stat.st_size != second_stat.st_size:
    return DIFF_SIZE

  # Contents
  if stat.S_ISLNK(first_stat.st_mode):
    if os.readlink(first_filename) != os.readlink(second_filename):
      return DIFF_SYMLINK
  elif stat.S_ISREG(first_stat.st_mode):
    if not AreFileContentsSame(first_stat.st_size, first_filename, second_filename):
      return DIFF_CONTENTS

  return DIFF_NONE


class FileIterator(object):
  """Object that produces an iterator containing all files in a given directory.

  Each iteration yields a tuple containing:

  [0] (full) Path to file relative to source tree.
  [1] (relative) Path to the file relative to the base directory given in the
      constructor.
  """

  def __init__(self, base_dir):
    self._base_dir = base_dir

  def __iter__(self):
    return self._Iterator(self, self._base_dir)

  def ShouldIncludeFile(self, root, path):
    return False

  class _Iterator(object):
    def __init__(self, parent, base_dir):
      self._parent = parent
      self._base_dir = base_dir
      self._walker = os.walk(base_dir, followlinks=False)
      self._current_index = 0
      self._current_dir = []

    def __iter__(self):
      return self

    def __next__(self):
      # os.walk's iterator will eventually terminate by raising StopIteration
      while True:
        if self._current_index >= len(self._current_dir):
          root, dirs, files = self._walker.__next__()
          full_paths = [os.path.sep.join((root, f)) for f in files]
          pairs = [(f, f[len(self._base_dir)+1:]) for f in full_paths]
          self._current_dir = [(full, relative) for full, relative in pairs
                               if self._parent.ShouldIncludeFile(root, relative)]
          self._current_index = 0
          if not self._current_dir:
            continue
        index = self._current_index
        self._current_index += 1
        return self._current_dir[index]


class OutFiles(FileIterator):
  """Object that produces an iterator containing all files in a given out directory,
  except for files which are known to be touched as part of build setup.
  """
  def __init__(self, out_dir):
    super().__init__(out_dir)
    self._out_dir = out_dir

  def ShouldIncludeFile(self, root, relative):
    # Skip files in root, although note that this could actually skip
    # files that are sadly generated directly into that directory.
    if root == self._out_dir:
      return False
    # Skiplist
    for skip in BUILD_INTERNALS_PREFIX_SKIP:
      if relative.startswith(skip):
        return False
    for skip in BUILD_INTERNALS_SUFFIX_SKIP:
      if relative.endswith(skip):
        return False
    return True


class ProductFiles(FileIterator):
  """Object that produces an iterator containing files in listed subdirectories of $PRODUCT_OUT.
  """
  def __init__(self, product_out, subdirs):
    super().__init__(product_out)
    self._subdirs = subdirs

  def ShouldIncludeFile(self, root, relative):
    for subdir in self._subdirs:
      if relative.startswith(subdir):
        return True
    return False


class TouchedFile(object):
  """A file in the out directory with a timestamp."""
  def __init__(self, filename, timestamp):
    self.filename = filename
    self.timestamp = timestamp


def RemoveItemsFromList(haystack, needles):
  for needle in needles:
    try:
      haystack.remove(needle)
    except ValueError:
      pass


class Printer(object):
  def __init__(self):
    self.printed_anything = False

  def PrintList(self, title, items, fmt="%s"):
    if items:
      if self.printed_anything:
        sys.stdout.write("\n")
      sys.stdout.write("%s:\n" % title)
      for item in items:
        sys.stdout.write("  %s\n" % fmt % item)
      self.printed_anything = True


if __name__ == "__main__":
  try:
    main()
  except KeyboardInterrupt:
    pass


# vim: ts=2 sw=2 sts=2 nocindent
