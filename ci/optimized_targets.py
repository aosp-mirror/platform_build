#
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

from abc import ABC
from typing import Self
import argparse
import functools


class OptimizedBuildTarget(ABC):
  """A representation of an optimized build target.

  This class will determine what targets to build given a given build_cotext and
  will have a packaging function to generate any necessary output zips for the
  build.
  """

  def __init__(
      self,
      target: str,
      build_context: dict[str, any],
      args: argparse.Namespace,
  ):
    self.target = target
    self.build_context = build_context
    self.args = args

  def get_build_targets(self) -> set[str]:
    features = self.build_context.get('enabledBuildFeatures', [])
    if self.get_enabled_flag() in features:
      return self.get_build_targets_impl()
    return {self.target}

  def package_outputs(self):
    features = self.build_context.get('enabledBuildFeatures', [])
    if self.get_enabled_flag() in features:
      return self.package_outputs_impl()

  def package_outputs_impl(self):
    raise NotImplementedError(
        f'package_outputs_impl not implemented in {type(self).__name__}'
    )

  def get_enabled_flag(self):
    raise NotImplementedError(
        f'get_enabled_flag not implemented in {type(self).__name__}'
    )

  def get_build_targets_impl(self) -> set[str]:
    raise NotImplementedError(
        f'get_build_targets_impl not implemented in {type(self).__name__}'
    )


class NullOptimizer(OptimizedBuildTarget):
  """No-op target optimizer.

  This will simply build the same target it was given and do nothing for the
  packaging step.
  """

  def __init__(self, target):
    self.target = target

  def get_build_targets(self):
    return {self.target}

  def package_outputs(self):
    pass


class GeneralTestsOptimizer(OptimizedBuildTarget):
  """general-tests optimizer

  TODO(b/358215235): Implement

  This optimizer reads in the list of changed files from the file located in
  env[CHANGE_INFO] and uses this list alongside the normal TEST MAPPING logic to
  determine what test mapping modules will run for the given changes. It then
  builds those modules and packages them in the same way general-tests.zip is
  normally built.
  """

  def get_enabled_flag(self):
    return 'general-tests-optimized'

  @classmethod
  def get_optimized_targets(cls) -> dict[str, OptimizedBuildTarget]:
    return {'general-tests': functools.partial(cls)}


OPTIMIZED_BUILD_TARGETS = {}
OPTIMIZED_BUILD_TARGETS.update(GeneralTestsOptimizer.get_optimized_targets())
