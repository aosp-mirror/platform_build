#!/usr/bin/env python3

"""Tool to find static libraries that maybe should be shared libraries and shared libraries that maybe should be static libraries.

This tool only looks at the module-info.json for the current target.

Example of "class" types for each of the modules in module-info.json
  "EXECUTABLES": 2307,
  "ETC": 9094,
  "NATIVE_TESTS": 10461,
  "APPS": 2885,
  "JAVA_LIBRARIES": 5205,
  "EXECUTABLES/JAVA_LIBRARIES": 119,
  "FAKE": 553,
  "SHARED_LIBRARIES/STATIC_LIBRARIES": 7591,
  "STATIC_LIBRARIES": 11535,
  "SHARED_LIBRARIES": 10852,
  "HEADER_LIBRARIES": 1897,
  "DYLIB_LIBRARIES": 1262,
  "RLIB_LIBRARIES": 3413,
  "ROBOLECTRIC": 39,
  "PACKAGING": 5,
  "PROC_MACRO_LIBRARIES": 36,
  "RENDERSCRIPT_BITCODE": 17,
  "DYLIB_LIBRARIES/RLIB_LIBRARIES": 8,
  "ETC/FAKE": 1

None of the "SHARED_LIBRARIES/STATIC_LIBRARIES" are double counted in the
modules with one class
RLIB/

All of these classes have shared_libs and/or static_libs
    "EXECUTABLES",
    "SHARED_LIBRARIES",
    "STATIC_LIBRARIES",
    "SHARED_LIBRARIES/STATIC_LIBRARIES", # cc_library
    "HEADER_LIBRARIES",
    "NATIVE_TESTS", # test modules
    "DYLIB_LIBRARIES", # rust
    "RLIB_LIBRARIES", # rust
    "ETC", # rust_bindgen
"""

from collections import defaultdict

import json, os, argparse

ANDROID_PRODUCT_OUT = os.environ.get("ANDROID_PRODUCT_OUT")
# If a shared library is used less than MAX_SHARED_INCLUSIONS times in a target,
# then it will likely save memory by changing it to a static library
# This move will also use less storage
MAX_SHARED_INCLUSIONS = 2
# If a static library is used more than MAX_STATIC_INCLUSIONS times in a target,
# then it will likely save memory by changing it to a shared library
# This move will also likely use less storage
MIN_STATIC_INCLUSIONS = 3


def parse_args():
  parser = argparse.ArgumentParser(
      description=(
          "Parse module-info.jso and display information about static and"
          " shared library dependencies."
      )
  )
  parser.add_argument(
      "--module", dest="module", help="Print the info for the module."
  )
  parser.add_argument(
      "--shared",
      dest="print_shared",
      action=argparse.BooleanOptionalAction,
      help=(
          "Print the list of libraries that are shared_libs for fewer than {}"
          " modules.".format(MAX_SHARED_INCLUSIONS)
      ),
  )
  parser.add_argument(
      "--static",
      dest="print_static",
      action=argparse.BooleanOptionalAction,
      help=(
          "Print the list of libraries that are static_libs for more than {}"
          " modules.".format(MIN_STATIC_INCLUSIONS)
      ),
  )
  parser.add_argument(
      "--recursive",
      dest="recursive",
      action=argparse.BooleanOptionalAction,
      default=True,
      help=(
          "Gather all dependencies of EXECUTABLES recursvily before calculating"
          " the stats. This eliminates duplicates from multiple libraries"
          " including the same dependencies in a single binary."
      ),
  )
  parser.add_argument(
      "--both",
      dest="both",
      action=argparse.BooleanOptionalAction,
      default=False,
      help=(
          "Print a list of libraries that are including libraries as both"
          " static and shared"
      ),
  )
  return parser.parse_args()


class TransitiveHelper:

  def __init__(self):
    # keep a list of already expanded libraries so we don't end up in a cycle
    self.visited = defaultdict(lambda: defaultdict(set))

  # module is an object from the module-info dictionary
  # module_info is the dictionary from module-info.json
  # modify the module's shared_libs and static_libs with all of the transient
  # dependencies required from all of the explicit dependencies
  def flattenDeps(self, module, module_info):
    libs_snapshot = dict(shared_libs = set(module.get("shared_libs",{})), static_libs = set(module.get("static_libs",{})))

    for lib_class in ["shared_libs", "static_libs"]:
      for lib in libs_snapshot[lib_class]:
        if not lib or lib not in module_info or lib_class not in module:
          continue
        if lib in self.visited:
          module[lib_class].update(self.visited[lib][lib_class])
        else:
          res = self.flattenDeps(module_info[lib], module_info)
          module[lib_class].update(res.get(lib_class, {}))
          self.visited[lib][lib_class].update(res.get(lib_class, {}))

    return module

def main():
  module_info = json.load(open(ANDROID_PRODUCT_OUT + "/module-info.json"))

  args = parse_args()

  if args.module:
    if args.module not in module_info:
      print("Module {} does not exist".format(args.module))
      exit(1)

  # turn all of the static_libs and shared_libs lists into sets to make them
  # easier to update
  for _, module in module_info.items():
    module["shared_libs"] = set(module.get("shared_libs", {}))
    module["static_libs"] = set(module.get("static_libs", {}))

  includedStatically = defaultdict(set)
  includedSharedly = defaultdict(set)
  includedBothly = defaultdict(set)
  transitive = TransitiveHelper()
  for name, module in module_info.items():
    if args.recursive:
      # in this recursive mode we only want to see what is included by the executables
      if "EXECUTABLES" not in module["class"]:
        continue
      module = transitive.flattenDeps(module, module_info)
      # filter out fuzzers by their dependency on clang
      if "static_libs" in module:
        if "libclang_rt.fuzzer" in module["static_libs"]:
          continue
    else:
      if "NATIVE_TESTS" in module["class"]:
        # We don't care about how tests are including libraries
        continue

    # count all of the shared and static libs included in this module
    if "shared_libs" in module:
      for lib in module["shared_libs"]:
        includedSharedly[lib].add(name)
    if "static_libs" in module:
      for lib in module["static_libs"]:
        includedStatically[lib].add(name)

    if "shared_libs" in module and  "static_libs" in module:
      intersection = set(module["shared_libs"]).intersection(
          module["static_libs"]
      )
      if intersection:
        includedBothly[name] = intersection

  if args.print_shared:
    print(
        "Shared libraries that are included by fewer than {} modules on a"
        " device:".format(MAX_SHARED_INCLUSIONS)
    )
    for name, libs in includedSharedly.items():
      if len(libs) < MAX_SHARED_INCLUSIONS:
        print("{}: {} included by: {}".format(name, len(libs), libs))

  if args.print_static:
    print(
        "Libraries that are included statically by more than {} modules on a"
        " device:".format(MIN_STATIC_INCLUSIONS)
    )
    for name, libs in includedStatically.items():
      if len(libs) > MIN_STATIC_INCLUSIONS:
        print("{}: {} included by: {}".format(name, len(libs), libs))

  if args.both:
    allIncludedBothly = set()
    for name, libs in includedBothly.items():
      allIncludedBothly.update(libs)

    print(
        "List of libraries used both statically and shared in the same"
        " processes:\n {}\n\n".format("\n".join(sorted(allIncludedBothly)))
    )
    print(
        "List of libraries used both statically and shared in any processes:\n {}".format("\n".join(sorted(includedStatically.keys() & includedSharedly.keys()))))

  if args.module:
    print(json.dumps(module_info[args.module], default=list, indent=2))
    print(
        "{} is included in shared_libs {} times by these modules: {}".format(
            args.module, len(includedSharedly[args.module]),
            includedSharedly[args.module]
        )
    )
    print(
        "{} is included in static_libs {} times by these modules: {}".format(
            args.module, len(includedStatically[args.module]),
            includedStatically[args.module]
        )
    )
    print("Shared libs included by this module that are used in fewer than {} processes:\n{}".format(
        MAX_SHARED_INCLUSIONS, [x for x in module_info[args.module]["shared_libs"] if len(includedSharedly[x]) < MAX_SHARED_INCLUSIONS]))



if __name__ == "__main__":
  main()
