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
import platform

class Context(object):
    """Mockable container for global state."""
    def __init__(self, out_root, errors):
        self.out = OutDir(out_root)
        self.errors = errors
        self.tools = HostTools()

class TestContext(Context):
    "Context for testing. The real Context is manually constructed in orchestrator.py."

    def __init__(self, test_work_dir, test_name):
        super(TestContext, self).__init__(os.path.join(test_work_dir, test_name),
                Errors(None))


class OutDir(object):
    """Encapsulates the logic about the out directory at the outer-tree level.
    See also inner_tree.OutDirLayout for inner tree out dir contents."""

    def __init__(self, root):
        "Initialize with the root of the OUT_DIR for the outer tree."
        self._out_root = root
        self._intermediates = "intermediates"

    def root(self):
        return self._out_root

    def inner_tree_dir(self, tree_root):
        """Root directory for inner tree inside the out dir."""
        return os.path.join(self._out_root, "trees", tree_root)

    def api_ninja_file(self):
        """The ninja file that assembles API surfaces."""
        return os.path.join(self._out_root, "api_surfaces.ninja")

    def api_library_dir(self, surface, version, library):
        """Directory for all the contents of a library inside an API surface, including
        the build files.  Any intermediates should go in api_library_work_dir."""
        return os.path.join(self._out_root, "api_surfaces", surface, str(version), library)

    def api_library_work_dir(self, surface, version, library):
        """Intermediates / scratch directory for library inside an API surface."""
        return os.path.join(self._out_root, self._intermediates, "api_surfaces", surface,
                str(version), library)

    def outer_ninja_file(self):
        return os.path.join(self._out_root, "multitree.ninja")

    def module_share_dir(self, module_type, module_name):
        return os.path.join(self._out_root, "shared", module_type, module_name)

    def staging_dir(self):
        return os.path.join(self._out_root, "staging")

    def dist_dir(self):
        "The DIST_DIR provided or out/dist" # TODO: Look at DIST_DIR
        return os.path.join(self._out_root, "dist")

class Errors(object):
    """Class for reporting and tracking errors."""
    def __init__(self, stream):
        """Initialize Error reporter with a file-like object."""
        self._stream = stream
        self._all = []

    def error(self, message, file=None, line=None, col=None):
        """Record the error message."""
        s = ""
        if file:
            s += str(file)
            s += ":"
        if line:
            s += str(line)
            s += ":"
        if col:
            s += str(col)
            s += ":"
        if s:
            s += " "
        s += str(message)
        if s[-1] != "\n":
            s += "\n"
        self._all.append(s)
        if self._stream:
            self._stream.write(s)

    def had_error(self):
        """Return if there were any errors reported."""
        return len(self._all)

    def get_errors(self):
        """Get all errors that were reported."""
        return self._all


class HostTools(object):
    def __init__(self):
        if platform.system() == "Linux":
            self._arch = "linux-x86"
        else:
            raise Exception("Orchestrator running on an unknown system: %s" % platform.system())

        # Some of these are called a lot, so pre-compute the strings to save memory
        self._prebuilts = os.path.join("build", "prebuilts", "build-tools", self._arch, "bin")
        self._acp = os.path.join(self._prebuilts, "acp")
        self._ninja = os.path.join(self._prebuilts, "ninja")

    def acp(self):
        return self._acp

    def ninja(self):
        return self._ninja


def choose_out_dir():
    """Get the root of the out dir, either from the environment or by picking
    a default."""
    result = os.environ.get("OUT_DIR")
    if result:
        return result
    else:
        return "out"
