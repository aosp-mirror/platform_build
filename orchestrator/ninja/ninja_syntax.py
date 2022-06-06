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

from abc import ABC, abstractmethod

from collections.abc import Iterator
from typing import List

TAB = "  "

class Node(ABC):
  '''An abstract class that can be serialized to a ninja file
  All other ninja-serializable classes inherit from this class'''

  @abstractmethod
  def stream(self) -> Iterator[str]:
    pass

class Variable(Node):
  '''A ninja variable that can be reused across build actions
  https://ninja-build.org/manual.html#_variables'''

  def __init__(self, name:str, value:str, indent=0):
    self.name = name
    self.value = value
    self.indent = indent

  def stream(self) -> Iterator[str]:
    indent = TAB * self.indent
    yield f"{indent}{self.name} = {self.value}"

class RuleException(Exception):
  pass

# Ninja rules recognize a limited set of variables
# https://ninja-build.org/manual.html#ref_rule
# Keep this list sorted
RULE_VARIABLES = ["command",
                  "depfile",
                  "deps",
                  "description",
                  "dyndep",
                  "generator",
                  "msvc_deps_prefix",
                  "restat",
                  "rspfile",
                  "rspfile_content"]

class Rule(Node):
  '''A shorthand for a command line that can be reused
  https://ninja-build.org/manual.html#_rules'''

  def __init__(self, name:str):
    self.name = name
    self.variables = []

  def add_variable(self, name: str, value: str):
    if name not in RULE_VARIABLES:
      raise RuleException(f"{name} is not a recognized variable in a ninja rule")

    self.variables.append(Variable(name=name, value=value, indent=1))

  def stream(self) -> Iterator[str]:
    self._validate_rule()

    yield f"rule {self.name}"
    # Yield rule variables sorted by `name`
    for var in sorted(self.variables, key=lambda x: x.name):
      # variables yield a single item, next() is sufficient
      yield next(var.stream())

  def _validate_rule(self):
    # command is a required variable in a ninja rule
    self._assert_variable_is_not_empty(variable_name="command")

  def _assert_variable_is_not_empty(self, variable_name: str):
    if not any(var.name == variable_name for var in self.variables):
      raise RuleException(f"{variable_name} is required in a ninja rule")

class BuildActionException(Exception):
  pass

class BuildAction(Node):
  '''Describes the dependency edge between inputs and output
  https://ninja-build.org/manual.html#_build_statements'''

  def __init__(self, output: str, rule: str, inputs: List[str]=None, implicits: List[str]=None, order_only: List[str]=None):
    self.output = output
    self.rule = rule
    self.inputs = self._as_list(inputs)
    self.implicits = self._as_list(implicits)
    self.order_only = self._as_list(order_only)
    self.variables = []

  def add_variable(self, name: str, value: str):
    '''Variables limited to the scope of this build action'''
    self.variables.append(Variable(name=name, value=value, indent=1))

  def stream(self) -> Iterator[str]:
    self._validate()

    build_statement = f"build {self.output}: {self.rule}"
    if len(self.inputs) > 0:
      build_statement += " "
      build_statement += " ".join(self.inputs)
    if len(self.implicits) > 0:
      build_statement += " | "
      build_statement += " ".join(self.implicits)
    if len(self.order_only) > 0:
      build_statement += " || "
      build_statement += " ".join(self.order_only)
    yield build_statement
    # Yield variables sorted by `name`
    for var in sorted(self.variables, key=lambda x: x.name):
      # variables yield a single item, next() is sufficient
      yield next(var.stream())

  def _validate(self):
    if not self.output:
      raise BuildActionException("Output is required in a ninja build statement")
    if not self.rule:
      raise BuildActionException("Rule is required in a ninja build statement")

  def _as_list(self, list_like):
    if list_like is None:
      return []
    if isinstance(list_like, list):
      return list_like
    return [list_like]

class Pool(Node):
  '''https://ninja-build.org/manual.html#ref_pool'''

  def __init__(self, name: str, depth: int):
    self.name = name
    self.depth = Variable(name="depth", value=depth, indent=1)

  def stream(self) -> Iterator[str]:
    yield f"pool {self.name}"
    yield next(self.depth.stream())

class Subninja(Node):

  def __init__(self, subninja: str, chDir: str):
    self.subninja = subninja
    self.chDir = chDir

  # TODO(spandandas): Update the syntax when aosp/2064612 lands
  def stream(self) -> Iterator[str]:
    yield f"subninja {self.subninja}"

class Line(Node):
  '''Generic class that can be used for comments/newlines/default_target etc'''

  def __init__(self, value:str):
    self.value = value

  def stream(self) -> Iterator[str]:
    yield self.value
