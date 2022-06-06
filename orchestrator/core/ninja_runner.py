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

import subprocess
import sys

def run_ninja(context, targets):
    """Run ninja.
    """

    # Construct the command
    cmd = [
            context.tools.ninja(),
            "-f",
            context.out.outer_ninja_file(),
        ] + targets

    # Run the command
    process = subprocess.run(cmd, shell=False)

    # TODO: Probably want better handling of inner tree failures
    if process.returncode:
        sys.stderr.write("Build error in outer tree.\nstopping multitree build.\n")
        sys.exit(1)

