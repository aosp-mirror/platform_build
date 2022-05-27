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
import sys

# Workaround for python include path
_ninja_dir = os.path.realpath(os.path.join(os.path.dirname(__file__), "..", "ninja"))
if _ninja_dir not in sys.path:
    sys.path.append(_ninja_dir)
import ninja_writer
from ninja_syntax import Variable, BuildAction, Rule, Pool, Subninja, Line


class Ninja(ninja_writer.Writer):
    """Some higher level constructs on top of raw ninja writing.
    TODO: Not sure where these should be."""
    def __init__(self, context, file):
        super(Ninja, self).__init__(file)
        self._context = context
        self._did_copy_file = False

    def add_copy_file(self, copy_to, copy_from):
        if not self._did_copy_file:
            self._did_copy_file = True
            rule = Rule("copy_file")
            rule.add_variable("command", "mkdir -p ${out_dir} && " + self._context.tools.acp()
                    + " -f ${in} ${out}")
            self.add_rule(rule)
        build_action = BuildAction(copy_to, "copy_file", inputs=[copy_from,],
                implicits=[self._context.tools.acp()])
        build_action.add_variable("out_dir", os.path.dirname(copy_to))
        self.add_build_action(build_action)


