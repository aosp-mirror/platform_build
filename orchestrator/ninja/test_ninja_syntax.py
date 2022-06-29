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

from ninja_syntax import Variable, Rule, RuleException, BuildAction, BuildActionException, Pool

class TestVariable(unittest.TestCase):

  def test_assignment(self):
    variable = Variable(name="key", value="value")
    self.assertEqual("key = value", next(variable.stream()))
    variable = Variable(name="key", value="value with spaces")
    self.assertEqual("key = value with spaces", next(variable.stream()))
    variable = Variable(name="key", value="$some_other_variable")
    self.assertEqual("key = $some_other_variable", next(variable.stream()))

  def test_indentation(self):
    variable = Variable(name="key", value="value", indent=0)
    self.assertEqual("key = value", next(variable.stream()))
    variable = Variable(name="key", value="value", indent=1)
    self.assertEqual("  key = value", next(variable.stream()))

class TestRule(unittest.TestCase):

  def test_rulename_comes_first(self):
    rule = Rule(name="myrule")
    rule.add_variable("command", "/bin/bash echo")
    self.assertEqual("rule myrule", next(rule.stream()))

  def test_command_is_a_required_variable(self):
    rule = Rule(name="myrule")
    with self.assertRaises(RuleException):
      next(rule.stream())

  def test_bad_rule_variable(self):
    rule = Rule(name="myrule")
    with self.assertRaises(RuleException):
      rule.add_variable(name="unrecognize_rule_variable", value="value")

  def test_rule_variables_are_indented(self):
    rule = Rule(name="myrule")
    rule.add_variable("command", "/bin/bash echo")
    stream = rule.stream()
    self.assertEqual("rule myrule", next(stream)) # top-level rule should not be indented
    self.assertEqual("  command = /bin/bash echo", next(stream))

  def test_rule_variables_are_sorted(self):
    rule = Rule(name="myrule")
    rule.add_variable("description", "Adding description before command")
    rule.add_variable("command", "/bin/bash echo")
    stream = rule.stream()
    self.assertEqual("rule myrule", next(stream)) # rule always comes first
    self.assertEqual("  command = /bin/bash echo", next(stream))
    self.assertEqual("  description = Adding description before command", next(stream))

class TestBuildAction(unittest.TestCase):

  def test_no_inputs(self):
    build = BuildAction(output="out", rule="phony")
    stream = build.stream()
    self.assertEqual("build out: phony", next(stream))
    # Empty output
    build = BuildAction(output="", rule="phony")
    with self.assertRaises(BuildActionException):
      next(build.stream())
    # Empty rule
    build = BuildAction(output="out", rule="")
    with self.assertRaises(BuildActionException):
      next(build.stream())

  def test_inputs(self):
    build = BuildAction(output="out", rule="cat", inputs=["input1", "input2"])
    self.assertEqual("build out: cat input1 input2", next(build.stream()))
    build = BuildAction(output="out", rule="cat", inputs=["input1", "input2"], implicits=["implicits1", "implicits2"], order_only=["order_only1", "order_only2"])
    self.assertEqual("build out: cat input1 input2 | implicits1 implicits2 || order_only1 order_only2", next(build.stream()))

  def test_variables(self):
    build = BuildAction(output="out", rule="cat", inputs=["input1", "input2"])
    build.add_variable(name="myvar", value="myval")
    stream = build.stream()
    next(stream)
    self.assertEqual("  myvar = myval", next(stream))

class TestPool(unittest.TestCase):

  def test_pool(self):
    pool = Pool(name="mypool", depth=10)
    stream = pool.stream()
    self.assertEqual("pool mypool", next(stream))
    self.assertEqual("  depth = 10", next(stream))

if __name__ == "__main__":
  unittest.main()
