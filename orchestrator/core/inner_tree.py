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

import json
import os
import subprocess
import sys
import textwrap


class InnerTreeKey(object):
    """Trees are identified uniquely by their root and the TARGET_PRODUCT they will use to build.
    If a single tree uses two different prdoucts, then we won't make assumptions about
    them sharing _anything_.
    TODO: This is true for soong. It's more likely that bazel could do analysis for two
    products at the same time in a single tree, so there's an optimization there to do
    eventually."""

    def __init__(self, root, product):
        if isinstance(root, list):
            self.melds = root[1:]
            root = root[0]
        else:
            self.melds = []
        self.root = root
        self.product = product

    def __str__(self):
        return (f"TreeKey(root={enquote(self.root)} "
                f"product={enquote(self.product)}")

    def __hash__(self):
        return hash((self.root, self.product))

    def _cmp(self, other):
        assert isinstance(other, InnerTreeKey)
        if self.root < other.root:
            return -1
        if self.root > other.root:
            return 1
        if self.melds < other.melds:
            return -1
        if self.melds > other.melds:
            return 1
        if self.product == other.product:
            return 0
        if self.product is None:
            return -1
        if other.product is None:
            return 1
        if self.product < other.product:
            return -1
        return 1

    def __eq__(self, other):
        return self._cmp(other) == 0

    def __ne__(self, other):
        return self._cmp(other) != 0

    def __lt__(self, other):
        return self._cmp(other) < 0

    def __le__(self, other):
        return self._cmp(other) <= 0

    def __gt__(self, other):
        return self._cmp(other) > 0

    def __ge__(self, other):
        return self._cmp(other) >= 0


class InnerTree(object):
    def __init__(self, context, paths, product):
        """Initialize with the inner tree root (relative to the workspace root)"""
        if not isinstance(paths, list):
            paths = [paths]
        self.root = paths[0]
        self.meld_dirs = paths[1:]
        self.product = product
        self.domains = {}
        # TODO: Base directory on OUT_DIR
        out_root = context.out.inner_tree_dir(self.root)
        if product:
            out_root += "_" + product
        else:
            out_root += "_unbundled"
        self.out = OutDirLayout(out_root)

    def __str__(self):
        return (f"InnerTree(root={enquote(self.root)} "
                f"product={enquote(self.product)} "
                f"domains={enquote(list(self.domains.keys()))} "
                f"meld={enquote(self.meld_dirs)})")

    def invoke(self, args):
        """Call the inner tree command for this inner tree. Exits on failure."""
        # TODO: Build time tracing

        # Validate that there is a .inner_build command to run at the root of the tree
        # so we can print a good error message
        inner_build_tool = os.path.join(self.root, ".inner_build")
        if not os.access(inner_build_tool, os.X_OK):
            sys.stderr.write(
                f"Unable to execute {inner_build_tool}. Is there an inner tree "
                "or lunch combo misconfiguration?\n")
            sys.exit(1)

        # TODO: This is where we should set up the shared trees

        # Build the command
        cmd = [inner_build_tool, "--out_dir", self.out.root()]
        for domain_name in sorted(self.domains.keys()):
            cmd.append("--api_domain")
            cmd.append(domain_name)
        cmd += args

        # Run the command
        process = subprocess.run(cmd, shell=False)

        # TODO: Probably want better handling of inner tree failures
        if process.returncode:
            sys.stderr.write(
                f"Build error in inner tree: {self.root}\nstopping "
                "multitree build.\n")
            sys.exit(1)


class InnerTrees(object):
    def __init__(self, trees, domains):
        self.trees = trees
        self.domains = domains

    def __str__(self):
        "Return a debugging dump of this object"

        def _vals(values):
            return ("\n" + " " * 16).join(sorted([str(t) for t in values]))

        return textwrap.dedent(f"""\
        InnerTrees {{
            trees: [
                {_vals(self.trees.values())}
            ]
            domains: [
                {_vals(self.domains.values())}
            ]
        }}""")

    def for_each_tree(self, func, cookie=None):
        """Call func for each of the inner trees once for each product that will be built in it.

        The calls will be in a stable order.

        Return a map of the InnerTreeKey to any results returned from func().
        """
        result = {}
        for key in sorted(self.trees.keys()):
            result[key] = func(key, self.trees[key], cookie)
        return result

    def get(self, tree_key):
        """Get an inner tree for tree_key"""
        return self.trees.get(tree_key)

    def keys(self):
        "Get the keys for the inner trees in name order."
        return [self.trees[k] for k in sorted(self.trees.keys())]


class OutDirLayout(object):
    """Encapsulates the logic about the layout of the inner tree out directories.
    See also context.OutDir for outer tree out dir contents."""

    def __init__(self, root):
        "Initialize with the root of the OUT_DIR for the inner tree."
        self._root = root

    def root(self):
        return self._root

    def tree_info_file(self):
        return os.path.join(self._root, "tree_info.json")

    def api_contributions_dir(self):
        return os.path.join(self._root, "api_contributions")

    def build_targets_file(self):
        return os.path.join(self._root, "build_targets.json")

    def main_ninja_file(self):
        return os.path.join(self._root, "inner_tree.ninja")


def enquote(s):
    return json.dumps(s)
