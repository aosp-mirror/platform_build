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
import subprocess
import sys

sys.dont_write_bytecode = True
import api_assembly
import api_domain
import api_export
import final_packaging
import inner_tree
import tree_analysis
import interrogate
import lunch
import ninja_runner
import utils

EXIT_STATUS_OK = 0
EXIT_STATUS_ERROR = 1

API_DOMAIN_SYSTEM = "system"
API_DOMAIN_VENDOR = "vendor"
API_DOMAIN_MODULE = "module"

def process_config(context, lunch_config):
    """Returns a InnerTrees object based on the configuration requested in the lunch config."""
    def add(domain_name, tree_root, product):
        tree_key = inner_tree.InnerTreeKey(tree_root, product)
        if tree_key in trees:
            tree = trees[tree_key]
        else:
            tree = inner_tree.InnerTree(context, tree_root, product)
            trees[tree_key] = tree
        domain = api_domain.ApiDomain(domain_name, tree, product)
        domains[domain_name] = domain
        tree.domains[domain_name] = domain

    trees = {}
    domains = {}

    system_entry = lunch_config.get("system")
    if system_entry:
        add(API_DOMAIN_SYSTEM, system_entry["inner-tree"],
            system_entry["product"])

    vendor_entry = lunch_config.get("vendor")
    if vendor_entry:
        add(API_DOMAIN_VENDOR, vendor_entry["inner-tree"],
            vendor_entry["product"])

    for module_name, module_entry in lunch_config.get("modules", []).items():
        add(module_name, module_entry["inner-tree"], None)

    return inner_tree.InnerTrees(trees, domains)


def build():
    # Choose the out directory, set up error handling, etc.
    context = utils.Context(utils.choose_out_dir(), utils.Errors(sys.stderr))

    # Read the lunch config file
    try:
        config_file, config, variant = lunch.load_current_config()
    except lunch.ConfigException as ex:
        sys.stderr.write("%s\n" % ex)
        return EXIT_STATUS_ERROR
    sys.stdout.write(lunch.make_config_header(config_file, config, variant))

    # Construct the trees and domains dicts
    inner_trees = process_config(context, config)

    # 1. Interrogate the trees
    inner_trees.for_each_tree(interrogate.interrogate_tree)
    # TODO: Detect bazel-only mode

    # 2a. API Export
    inner_trees.for_each_tree(api_export.export_apis_from_tree)

    # 2b. API Surface Assembly
    api_assembly.assemble_apis(context, inner_trees)

    # 3a. Inner tree analysis
    tree_analysis.analyze_trees(context, inner_trees)

    # 3b. Final Packaging Rules
    final_packaging.final_packaging(context, inner_trees)

    # 4. Build Execution
    # TODO: Decide what we want the UX for selecting targets to be across
    # branches... since there are very likely to be conflicting soong short
    # names.
    print("Running ninja...")
    targets = ["staging", "system"]
    ninja_runner.run_ninja(context, targets)

    # Success!
    return EXIT_STATUS_OK

def main(argv):
    return build()

if __name__ == "__main__":
    sys.exit(main(sys.argv))


# vim: sts=4:ts=4:sw=4
