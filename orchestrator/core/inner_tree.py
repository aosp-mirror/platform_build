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
import textwrap

class InnerTreeKey(object):
    """Trees are identified uniquely by their root and the TARGET_PRODUCT they will use to build.
    If a single tree uses two different prdoucts, then we won't make assumptions about
    them sharing _anything_.
    TODO: This is true for soong. It's more likely that bazel could do analysis for two
    products at the same time in a single tree, so there's an optimization there to do
    eventually."""
    def __init__(self, root, product):
        self.root = root
        self.product = product

    def __str__(self):
        return "TreeKey(root=%s product=%s)" % (enquote(self.root), enquote(self.product))

    def __hash__(self):
        return hash((self.root, self.product))

    def __eq__(self, other):
        return (self.root == other.root and self.product == other.product)

    def __ne__(self, other):
        return not self.__eq__(other)

    def __lt__(self, other):
        return (self.root, self.product) < (other.root, other.product)

    def __le__(self, other):
        return (self.root, self.product) <= (other.root, other.product)

    def __gt__(self, other):
        return (self.root, self.product) > (other.root, other.product)

    def __ge__(self, other):
        return (self.root, self.product) >= (other.root, other.product)


class InnerTree(object):
    def __init__(self, context, root, product):
        """Initialize with the inner tree root (relative to the workspace root)"""
        self.root = root
        self.product = product
        self.domains = {}
        # TODO: Base directory on OUT_DIR
        self.out = OutDirLayout(context.out.inner_tree_dir(root))

    def __str__(self):
        return "InnerTree(root=%s product=%s domains=[%s])" % (enquote(self.root),
                enquote(self.product),
                " ".join([enquote(d) for d in sorted(self.domains.keys())]))

    def invoke(self, args):
        """Call the inner tree command for this inner tree. Exits on failure."""
        # TODO: Build time tracing

        # Validate that there is a .inner_build command to run at the root of the tree
        # so we can print a good error message
        inner_build_tool = os.path.join(self.root, ".inner_build")
        if not os.access(inner_build_tool, os.X_OK):
            sys.stderr.write(("Unable to execute %s. Is there an inner tree or lunch combo"
                    + " misconfiguration?\n") % inner_build_tool)
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
            sys.stderr.write("Build error in inner tree: %s\nstopping multitree build.\n"
                    % self.root)
            sys.exit(1)


class InnerTrees(object):
    def __init__(self, trees, domains):
        self.trees = trees
        self.domains = domains

    def __str__(self):
        "Return a debugging dump of this object"
        return textwrap.dedent("""\
        InnerTrees {
            trees: [
                %(trees)s
            ]
            domains: [
                %(domains)s
            ]
        }""" % {
            "trees": "\n        ".join(sorted([str(t) for t in self.trees.values()])),
            "domains": "\n        ".join(sorted([str(d) for d in self.domains.values()])),
        })


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


def enquote(s):
    return "None" if s is None else "\"%s\"" % s


