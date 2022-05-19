#!/usr/bin/python3
#
# Copyright (C) 2022 The Android Open Source Project
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

import os

def assemble_cc_api_library(context, ninja, build_file, stub_library):
    print("\nassembling cc_api_library %s-%s %s from:" % (stub_library.api_surface,
        stub_library.api_surface_version, stub_library.name))
    for contrib in stub_library.contributions:
        print("  %s %s" % (contrib.api_domain, contrib.library_contribution))

    staging_dir = context.out.api_library_dir(stub_library.api_surface,
            stub_library.api_surface_version, stub_library.name)
    work_dir = context.out.api_library_work_dir(stub_library.api_surface,
            stub_library.api_surface_version, stub_library.name)
    print("staging_dir=%s" % (staging_dir))
    print("work_dir=%s" % (work_dir))

    # Generate rules to copy headers
    includes = []
    include_dir = os.path.join(staging_dir, "include")
    for contrib in stub_library.contributions:
        for headers in contrib.library_contribution["headers"]:
            root = headers["root"]
            for file in headers["files"]:
                # TODO: Deal with collisions of the same name from multiple contributions
                include = os.path.join(include_dir, file)
                ninja.add_copy_file(include, os.path.join(contrib.inner_tree.root, root, file))
                includes.append(include)

    # Generate rule to run ndkstubgen


    # Generate rule to compile stubs to library

    # Generate phony rule to build the library
    # TODO: This name probably conflictgs with something
    ninja.add_phony("-".join((stub_library.api_surface, str(stub_library.api_surface_version),
            stub_library.name)), includes)

    # Generate build files

