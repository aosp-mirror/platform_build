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
import re
import subprocess
import sys
from typing import Callable
from build_context import BuildContext
import optimized_targets
import metrics_agent
import test_discovery_agent


REQUIRED_ENV_VARS = frozenset(['TARGET_PRODUCT', 'TARGET_RELEASE', 'TOP', 'DIST_DIR'])
SOONG_UI_EXE_REL_PATH = 'build/soong/soong_ui.bash'
LOG_PATH = 'logs/build_test_suites.log'
# Currently, this prevents the removal of those tags when they exist. In the future we likely
# want the script to supply 'dist directly
REQUIRED_BUILD_TARGETS = frozenset(['dist', 'droid', 'checkbuild'])


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

    if not self.build_context.test_infos:
      logging.warning('Build context has no test infos, skipping optimizations.')
      for target in self.args.extra_targets:
        get_metrics_agent().report_unoptimized_target(target, 'BUILD_CONTEXT has no test infos.')
      return BuildPlan(set(self.args.extra_targets), set())

    build_targets = set()
    packaging_commands_getters = []
    # In order to roll optimizations out differently between test suites and
    # device builds, we have separate flags.
    enable_discovery = (('test_suites_zip_test_discovery'
        in self.build_context.enabled_build_features
        and not self.args.device_build
    ) or (
        'device_zip_test_discovery'
        in self.build_context.enabled_build_features
        and self.args.device_build
    )) and not self.args.test_discovery_info_mode
    logging.info(f'Discovery mode is enabled= {enable_discovery}')
    preliminary_build_targets = self._collect_preliminary_build_targets(enable_discovery)

    for target in preliminary_build_targets:
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

  def _collect_preliminary_build_targets(self, enable_discovery: bool):
    build_targets = set()
    try:
      test_discovery_zip_regexes = self._get_test_discovery_zip_regexes()
      logging.info(f'Discovered test discovery regexes: {test_discovery_zip_regexes}')
    except test_discovery_agent.TestDiscoveryError as e:
      optimization_rationale = e.message
      logging.warning(f'Unable to perform test discovery: {optimization_rationale}')

      for target in self.args.extra_targets:
        get_metrics_agent().report_unoptimized_target(target, optimization_rationale)
      return self._legacy_collect_preliminary_build_targets()

    for target in self.args.extra_targets:
      if target in REQUIRED_BUILD_TARGETS:
        build_targets.add(target)
        get_metrics_agent().report_unoptimized_target(target, 'Required build target.')
        continue
      # If nothing is discovered without error, that means nothing is needed.
      if not test_discovery_zip_regexes:
        get_metrics_agent().report_optimized_target(target)
        continue

      regex = r'\b(%s.*)\b' % re.escape(target)
      for opt in test_discovery_zip_regexes:
        try:
          if re.search(regex, opt):
            get_metrics_agent().report_unoptimized_target(target, 'Test artifact used.')
            build_targets.add(target)
            # proceed to next target evaluation
            break
          get_metrics_agent().report_optimized_target(target)
        except Exception as e:
          # In case of exception report as unoptimized
          build_targets.add(target)
          get_metrics_agent().report_unoptimized_target(target, f'Error in parsing test discovery output for {target}: {repr(e)}')
          logging.error(f'unable to parse test discovery output: {repr(e)}')
          break
    # If discovery is not enabled, return the original list
    if not enable_discovery:
      return self._legacy_collect_preliminary_build_targets()

    return build_targets

  def _legacy_collect_preliminary_build_targets(self):
    build_targets = set()
    for target in self.args.extra_targets:
      if self._unused_target_exclusion_enabled(
          target
      ) and not self.build_context.build_target_used(target):
        continue

      build_targets.add(target)
    return build_targets

  def _unused_target_exclusion_enabled(self, target: str) -> bool:
    return (
        f'{target}_unused_exclusion'
        in self.build_context.enabled_build_features
    )

  def _get_test_discovery_zip_regexes(self) -> set[str]:
    build_target_regexes = set()
    for test_info in self.build_context.test_infos:
      tf_command = self._build_tf_command(test_info)
      discovery_agent = test_discovery_agent.TestDiscoveryAgent(tradefed_args=tf_command)
      for regex in discovery_agent.discover_test_zip_regexes():
        build_target_regexes.add(regex)
    return build_target_regexes


  def _build_tf_command(self, test_info) -> list[str]:
    command = [test_info.command]
    for extra_option in test_info.extra_options:
      if not extra_option.get('key'):
        continue
      arg_key = '--' + extra_option.get('key')
      if arg_key == '--build-id':
        command.append(arg_key)
        command.append(os.environ.get('BUILD_NUMBER'))
        continue
      if extra_option.get('values'):
        for value in extra_option.get('values'):
          command.append(arg_key)
          command.append(value)
      else:
        command.append(arg_key)

    return command

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
  get_metrics_agent().analysis_start()
  try:
    args = parse_args(argv)
    check_required_env()
    build_context = BuildContext(load_build_context())
    build_planner = BuildPlanner(
        build_context, args, optimized_targets.OPTIMIZED_BUILD_TARGETS
    )
    build_plan = build_planner.create_build_plan()
  except:
    raise
  finally:
    get_metrics_agent().analysis_end()

  try:
    execute_build_plan(build_plan)
  except BuildFailureError as e:
    logging.error('Build command failed! Check build_log for details.')
    return e.return_code
  finally:
    get_metrics_agent().end_reporting()

  return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
  argparser = argparse.ArgumentParser()

  argparser.add_argument(
      'extra_targets', nargs='*', help='Extra test suites to build.'
  )
  argparser.add_argument(
      '--device-build',
      action='store_true',
      help='Flag to indicate running a device build.',
  )
  argparser.add_argument(
      '--test_discovery_info_mode',
      action='store_true',
      help='Flag to enable running test discovery in info only mode.',
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

  get_metrics_agent().packaging_start()
  try:
    for packaging_commands_getter in build_plan.packaging_commands_getters:
      for packaging_command in packaging_commands_getter():
        run_command(packaging_command)
  except subprocess.CalledProcessError as e:
    raise BuildFailureError(e.returncode) from e
  finally:
    get_metrics_agent().packaging_end()


def get_top() -> pathlib.Path:
  return pathlib.Path(os.environ['TOP'])


def run_command(args: list[str], stdout=None):
  subprocess.run(args=args, check=True, stdout=stdout)


def get_metrics_agent():
  return metrics_agent.MetricsAgent.instance()


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


if __name__ == '__main__':
  main(sys.argv[1:])
