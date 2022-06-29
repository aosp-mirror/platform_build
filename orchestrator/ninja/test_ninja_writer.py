#!/usr/bin/env python
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

import unittest

from io import StringIO

from ninja_writer import Writer
from ninja_syntax import Variable, Rule, BuildAction

class TestWriter(unittest.TestCase):

  def test_simple_writer(self):
    with StringIO() as f:
      writer = Writer(f)
      writer.add_variable(Variable(name="cflags", value="-Wall"))
      writer.add_newline()
      cc = Rule(name="cc")
      cc.add_variable(name="command", value="gcc $cflags -c $in -o $out")
      writer.add_rule(cc)
      writer.add_newline()
      build_action = BuildAction(output="foo.o", rule="cc", inputs=["foo.c"])
      writer.add_build_action(build_action)
      writer.write()
      self.assertEqual('''cflags = -Wall

rule cc
  command = gcc $cflags -c $in -o $out

build foo.o: cc foo.c
''', f.getvalue())

  def test_comment(self):
    with StringIO() as f:
      writer = Writer(f)
      writer.add_comment("This is a comment in a ninja file")
      writer.write()
      self.assertEqual("# This is a comment in a ninja file\n", f.getvalue())

if __name__ == "__main__":
  unittest.main()
