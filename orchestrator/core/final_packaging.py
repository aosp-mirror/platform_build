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

import json
import os
import sys

import ninja_tools
import ninja_syntax # Has to be after ninja_tools because of the path hack

def final_packaging(context, inner_trees):
    """Pull together all of the previously defined rules into the final build stems."""

    with open(context.out.outer_ninja_file(), "w") as ninja_file:
        ninja = ninja_tools.Ninja(context, ninja_file)

        # Add the api surfaces file
        ninja.add_subninja(ninja_syntax.Subninja(context.out.api_ninja_file(), chDir=None))

        # For each inner tree
        for tree in inner_trees.keys():
            # TODO: Verify that inner_tree.ninja was generated

            # Read and verify file
            build_targets = read_build_targets_json(context, tree)
            if not build_targets:
                continue

            # Generate the ninja and build files for this inner tree
            generate_cross_domain_build_rules(context, ninja, tree, build_targets)

        # Finish writing the ninja file
        ninja.write()


def read_build_targets_json(context, tree):
    """Read and validate the build_targets.json file for the given tree."""
    try:
        f = open(tree.out.build_targets_file())
    except FileNotFoundError:
        # It's allowed not to have any artifacts (e.g. if a tree is a light tree with only APIs)
        return None

    data = None
    with f:
        try:
            data = json.load(f)
        except json.decoder.JSONDecodeError as ex:
            sys.stderr.write("Error parsing file: %s\n" % tree.out.build_targets_file())
            # TODO: Error reporting
            raise ex

    # TODO: Better error handling
    # TODO: Validate json schema
    return data


def generate_cross_domain_build_rules(context, ninja, tree, build_targets):
    "Generate the ninja and build files for the inner tree."
    # Include the inner tree's inner_tree.ninja
    ninja.add_subninja(ninja_syntax.Subninja(tree.out.main_ninja_file(), chDir=tree.root))

    # Generate module rules and files
    for module in build_targets.get("modules", []):
        generate_shared_module(context, ninja, tree, module)

    # Generate staging rules
    staging_dir = context.out.staging_dir()
    for staged in build_targets.get("staging", []):
        # TODO: Enforce that dest isn't in disallowed subdir of out or absolute
        dest = staged["dest"]
        dest = os.path.join(staging_dir, dest)
        if "src" in staged and "obj" in staged:
            context.errors.error("Can't have both \"src\" and \"obj\" tags in \"staging\" entry."
                    ) # TODO: Filename and line if possible
        if "src" in staged:
            ninja.add_copy_file(dest, os.path.join(tree.root, staged["src"]))
        elif "obj" in staged:
            ninja.add_copy_file(dest, os.path.join(tree.out.root(), staged["obj"]))
        ninja.add_global_phony("staging", [dest])

    # Generate dist rules
    dist_dir = context.out.dist_dir()
    for disted in build_targets.get("dist", []):
        # TODO: Enforce that dest absolute
        dest = disted["dest"]
        dest = os.path.join(dist_dir, dest)
        ninja.add_copy_file(dest, os.path.join(tree.root, disted["src"]))
        ninja.add_global_phony("dist", [dest])


def generate_shared_module(context, ninja, tree, module):
    """Generate ninja rules for the given build_targets.json defined module."""
    module_name = module["name"]
    module_type = module["type"]
    share_dir = context.out.module_share_dir(module_type, module_name)
    src_file = os.path.join(tree.root, module["file"])

    if module_type == "apex":
        ninja.add_copy_file(os.path.join(share_dir, module_name + ".apex"), src_file)
        # TODO: Generate build file

    else:
        # TODO: Better error handling
        raise Exception("Invalid module type: %s" % module)
