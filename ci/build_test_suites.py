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

"""Build script for the CI `test_suites` target."""

import argparse
from dataclasses import dataclass
import json
import logging
import os
import pathlib
import subprocess
import sys
from typing import Callable
from build_context import BuildContext
import optimized_targets


REQUIRED_ENV_VARS = frozenset(['TARGET_PRODUCT', 'TARGET_RELEASE', 'TOP'])
SOONG_UI_EXE_REL_PATH = 'build/soong/soong_ui.bash'
LOG_PATH = 'logs/build_test_suites.log'


class Error(Exception):

  def __init__(self, message):
    super().__init__(message)


class BuildFailureError(Error):

  def __init__(self, return_code):
    super().__init__(f'Build command failed with return code: f{return_code}')
    self.return_code = return_code


class BuildPlanner:
  """Class in charge of determining how to optimize build targets.

  Given the build context and targets to build it will determine a final list of
  targets to build along with getting a set of packaging functions to package up
  any output zip files needed by the build.
  """

  def __init__(
      self,
      build_context: BuildContext,
      args: argparse.Namespace,
      target_optimizations: dict[str, optimized_targets.OptimizedBuildTarget],
  ):
    self.build_context = build_context
    self.args = args
    self.target_optimizations = target_optimizations

  def create_build_plan(self):

    if 'optimized_build' not in self.build_context.enabled_build_features:
      return BuildPlan(set(self.args.extra_targets), set())

    build_targets = set()
    packaging_commands_getters = []
    for target in self.args.extra_targets:
      if self._unused_target_exclusion_enabled(
          target
      ) and not self.build_context.build_target_used(target):
        continue

      target_optimizer_getter = self.target_optimizations.get(target, None)
      if not target_optimizer_getter:
        build_targets.add(target)
        continue

      target_optimizer = target_optimizer_getter(
          target, self.build_context, self.args
      )
      build_targets.update(target_optimizer.get_build_targets())
      packaging_commands_getters.append(
          target_optimizer.get_package_outputs_commands
      )

    return BuildPlan(build_targets, packaging_commands_getters)

  def _unused_target_exclusion_enabled(self, target: str) -> bool:
    return (
        f'{target}_unused_exclusion'
        in self.build_context.enabled_build_features
    )


@dataclass(frozen=True)
class BuildPlan:
  build_targets: set[str]
  packaging_commands_getters: list[Callable[[], list[list[str]]]]


def build_test_suites(argv: list[str]) -> int:
  """Builds all test suites passed in, optimizing based on the build_context content.

  Args:
    argv: The command line arguments passed in.

  Returns:
    The exit code of the build.
  """
  args = parse_args(argv)
  check_required_env()
  build_context = BuildContext(load_build_context())
  build_planner = BuildPlanner(
      build_context, args, optimized_targets.OPTIMIZED_BUILD_TARGETS
  )
  build_plan = build_planner.create_build_plan()

  try:
    execute_build_plan(build_plan)
  except BuildFailureError as e:
    logging.error('Build command failed! Check build_log for details.')
    return e.return_code

  return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
  argparser = argparse.ArgumentParser()

  argparser.add_argument(
      'extra_targets', nargs='*', help='Extra test suites to build.'
  )

  return argparser.parse_args(argv)


def check_required_env():
  """Check for required env vars.

  Raises:
    RuntimeError: If any required env vars are not found.
  """
  missing_env_vars = sorted(v for v in REQUIRED_ENV_VARS if v not in os.environ)

  if not missing_env_vars:
    return

  t = ','.join(missing_env_vars)
  raise Error(f'Missing required environment variables: {t}')


def load_build_context():
  build_context_path = pathlib.Path(os.environ.get('BUILD_CONTEXT', ''))
  if build_context_path.is_file():
    try:
      with open(build_context_path, 'r') as f:
        return json.load(f)
    except json.decoder.JSONDecodeError as e:
      raise Error(f'Failed to load JSON file: {build_context_path}')

  logging.info('No BUILD_CONTEXT found, skipping optimizations.')
  return empty_build_context()


def empty_build_context():
  return {'enabledBuildFeatures': []}


def execute_build_plan(build_plan: BuildPlan):
  build_command = []
  build_command.append(get_top().joinpath(SOONG_UI_EXE_REL_PATH))
  build_command.append('--make-mode')
  build_command.extend(build_plan.build_targets)

  try:
    run_command(build_command)
  except subprocess.CalledProcessError as e:
    raise BuildFailureError(e.returncode) from e

  for packaging_commands_getter in build_plan.packaging_commands_getters:
    try:
      for packaging_command in packaging_commands_getter():
        run_command(packaging_command)
    except subprocess.CalledProcessError as e:
      raise BuildFailureError(e.returncode) from e


def get_top() -> pathlib.Path:
  return pathlib.Path(os.environ['TOP'])


def run_command(args: list[str], stdout=None):
  subprocess.run(args=args, check=True, stdout=stdout)


def main(argv):
  dist_dir = os.environ.get('DIST_DIR')
  if dist_dir:
    log_file = pathlib.Path(dist_dir) / LOG_PATH
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s %(levelname)s %(message)s',
        filename=log_file,
    )
  sys.exit(build_test_suites(argv))
