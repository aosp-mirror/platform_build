#!/usr/bin/env python
#
# Copyright (C) 2016 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Tool to prioritize which modules to convert to Soong.

Generally, you'd use this through the make integration, which automatically
generates the CSV input file that this tool expects:

  $ m $OUT/soong_to_convert.txt
  $ less $OUT/soong_to_convert.txt

The output is a list of modules that are probably ready to convert to Soong:

  # Blocked on Module (potential problems)
           283 libEGL (srcs_dotarm)
           246 libicuuc (dotdot_incs dotdot_srcs)
           221 libspeexresampler
           215 libcamera_metadata
               ...
             0 zram-perf (dotdot_incs)

The number at the beginning of the line shows how many native modules depend
on that module.

All of their dependencies have been satisfied, and any potential problems
that Make can detect are listed in parenthesis after the module:

  dotdot_srcs: LOCAL_SRC_FILES contains paths outside $(LOCAL_PATH)
  dotdot_incs: LOCAL_C_INCLUDES contains paths include '..'
  srcs_dotarm: LOCAL_SRC_FILES contains source files like <...>.c.arm
  aidl: LOCAL_SRC_FILES contains .aidl sources
  objc: LOCAL_SRC_FILES contains Objective-C sources
  proto: LOCAL_SRC_FILES contains .proto sources
  rs: LOCAL_SRC_FILES contains renderscript sources
  vts: LOCAL_SRC_FILES contains .vts sources

Not all problems can be discovered, but this is a starting point.

"""

from __future__ import print_function

import csv
import sys

def count_deps(depsdb, module, seen):
    """Based on the depsdb, count the number of transitive dependencies.

    You can pass in an reversed dependency graph to conut the number of
    modules that depend on the module."""
    count = 0
    seen.append(module)
    if module in depsdb:
        for dep in depsdb[module]:
            if dep in seen:
                continue
            count += 1 + count_deps(depsdb, dep, seen)
    return count

def process(reader):
    """Read the input file and produce a list of modules ready to move to Soong
    """
    problems = dict()
    deps = dict()
    reverse_deps = dict()
    module_types = dict()

    for (module, module_type, problem, dependencies) in reader:
        module_types[module] = module_type
        problems[module] = problem
        deps[module] = [d for d in dependencies.strip().split(' ') if d != ""]
        for dep in deps[module]:
            if not dep in reverse_deps:
                reverse_deps[dep] = []
            reverse_deps[dep].append(module)

    results = []
    for module in problems:
        # Only display actionable conversions, ones without missing dependencies
        if len(deps[module]) != 0:
            continue

        extra = ""
        if len(problems[module]) > 0:
            extra = " ({})".format(problems[module])
        results.append((count_deps(reverse_deps, module, []), module + extra, module_types[module]))

    return sorted(results, key=lambda result: (-result[0], result[1]))

def filter(results, module_type):
    return [x for x in results if x[2] == module_type]

def display(results):
    """Displays the results"""
    count_header = "# Blocked on"
    count_width = len(count_header)
    print("{} Module (potential problems)".format(count_header))
    for (count, module, module_type) in results:
        print("{:>{}} {}".format(count, count_width, module))

def main(filename):
    """Read the CSV file, print the results"""
    with open(filename, 'rb') as csvfile:
        results = process(csv.reader(csvfile))

    native_results = filter(results, "native")
    java_results = filter(results, "java")

    print("native modules ready to convert")
    display(native_results)

    print("")
    print("java modules ready to convert")
    display(java_results)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: soong_conversion.py <file>", file=sys.stderr)
        sys.exit(1)

    main(sys.argv[1])
