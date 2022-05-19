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

import ninja_tools
import ninja_syntax # Has to be after ninja_tools because of the path hack

def final_packaging(context):
    """Pull together all of the previously defined rules into the final build stems."""

    with open(context.out.outer_ninja_file(), "w") as ninja_file:
        ninja = ninja_tools.Ninja(context, ninja_file)

        # Add the api surfaces file
        ninja.add_subninja(ninja_syntax.Subninja(context.out.api_ninja_file(), chDir=None))

        # Finish writing the ninja file
        ninja.write()
