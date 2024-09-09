# Copyright 2024, The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Utilities for interacting with buildbot, with a simulation in a local environment"""

import os
import sys

# Check that the script is running from the root of the tree. Prevents subtle
# errors later, and CI always runs from the root of the tree.
if not os.path.exists("build/make/ci/buildbot.py"):
    raise Exception("CI script must be run from the root of the tree instead of: "
                    + os.getcwd())

# Check that we are using the hermetic interpreter
if "prebuilts/build-tools/" not in sys.executable:
    raise Exception("CI script must be run using the hermetic interpreter from "
                    + "prebuilts/build-tools instead of: " + sys.executable)


def OutDir():
    "Get the out directory. Will create it if needed."
    result = os.environ.get("OUT_DIR", "out")
    os.makedirs(result, exist_ok=True)
    return result

def DistDir():
    "Get the dist directory. Will create it if needed."
    result = os.environ.get("DIST_DIR", os.path.join(OutDir(), "dist"))
    os.makedirs(result, exist_ok=True)
    return result

