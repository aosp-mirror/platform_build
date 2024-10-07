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

"""Tests for build_test_suites.py"""

import argparse
import functools
from importlib import resources
import json
import multiprocessing
import os
import pathlib
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import textwrap
import time
from typing import Callable
import unittest
from unittest import mock
from build_context import BuildContext
import build_test_suites
import ci_test_lib
import optimized_targets
from pyfakefs import fake_filesystem_unittest


class BuildTestSuitesTest(fake_filesystem_unittest.TestCase):

  def setUp(self):
    self.setUpPyfakefs()

    os_environ_patcher = mock.patch.dict('os.environ', {})
    self.addCleanup(os_environ_patcher.stop)
    self.mock_os_environ = os_environ_patcher.start()

    subprocess_run_patcher = mock.patch('subprocess.run')
    self.addCleanup(subprocess_run_patcher.stop)
    self.mock_subprocess_run = subprocess_run_patcher.start()

    self._setup_working_build_env()

  def test_missing_target_release_env_var_raises(self):
    del os.environ['TARGET_RELEASE']

    with self.assert_raises_word(build_test_suites.Error, 'TARGET_RELEASE'):
      build_test_suites.main([])

  def test_missing_target_product_env_var_raises(self):
    del os.environ['TARGET_PRODUCT']

    with self.assert_raises_word(build_test_suites.Error, 'TARGET_PRODUCT'):
      build_test_suites.main([])

  def test_missing_top_env_var_raises(self):
    del os.environ['TOP']

    with self.assert_raises_word(build_test_suites.Error, 'TOP'):
      build_test_suites.main([])

  def test_invalid_arg_raises(self):
    invalid_args = ['--invalid_arg']

    with self.assertRaisesRegex(SystemExit, '2'):
      build_test_suites.main(invalid_args)

  def test_build_failure_returns(self):
    self.mock_subprocess_run.side_effect = subprocess.CalledProcessError(
        42, None
    )

    with self.assertRaisesRegex(SystemExit, '42'):
      build_test_suites.main([])

  def test_incorrectly_formatted_build_context_raises(self):
    build_context = self.fake_top.joinpath('build_context')
    build_context.touch()
    os.environ['BUILD_CONTEXT'] = str(build_context)

    with self.assert_raises_word(build_test_suites.Error, 'JSON'):
      build_test_suites.main([])

  def test_build_success_returns(self):
    with self.assertRaisesRegex(SystemExit, '0'):
      build_test_suites.main([])

  def assert_raises_word(self, cls, word):
    return self.assertRaisesRegex(cls, rf'\b{word}\b')

  def _setup_working_build_env(self):
    self.fake_top = pathlib.Path('/fake/top')
    self.fake_top.mkdir(parents=True)

    self.soong_ui_dir = self.fake_top.joinpath('build/soong')
    self.soong_ui_dir.mkdir(parents=True, exist_ok=True)

    self.soong_ui = self.soong_ui_dir.joinpath('soong_ui.bash')
    self.soong_ui.touch()

    self.mock_os_environ.update({
        'TARGET_RELEASE': 'release',
        'TARGET_PRODUCT': 'product',
        'TOP': str(self.fake_top),
    })

    self.mock_subprocess_run.return_value = 0


class RunCommandIntegrationTest(ci_test_lib.TestCase):

  def setUp(self):
    self.temp_dir = ci_test_lib.TestTemporaryDirectory.create(self)

    # Copy the Python executable from 'non-code' resources and make it
    # executable for use by tests that launch a subprocess. Note that we don't
    # use Python's native `sys.executable` property since that is not set when
    # running via the embedded launcher.
    base_name = 'py3-cmd'
    dest_file = self.temp_dir.joinpath(base_name)
    with resources.as_file(
        resources.files('testdata').joinpath(base_name)
    ) as p:
      shutil.copy(p, dest_file)
    dest_file.chmod(dest_file.stat().st_mode | stat.S_IEXEC)
    self.python_executable = dest_file

    self._managed_processes = []

  def tearDown(self):
    self._terminate_managed_processes()

  def test_raises_on_nonzero_exit(self):
    with self.assertRaises(Exception):
      build_test_suites.run_command([
          self.python_executable,
          '-c',
          textwrap.dedent(f"""\
              import sys
              sys.exit(1)
              """),
      ])

  def test_streams_stdout(self):

    def run_slow_command(stdout_file, marker):
      with open(stdout_file, 'w') as f:
        build_test_suites.run_command(
            [
                self.python_executable,
                '-c',
                textwrap.dedent(f"""\
                  import time

                  print('{marker}', end='', flush=True)

                  # Keep process alive until we check stdout.
                  time.sleep(10)
                  """),
            ],
            stdout=f,
        )

    marker = 'Spinach'
    stdout_file = self.temp_dir.joinpath('stdout.txt')

    p = self.start_process(target=run_slow_command, args=[stdout_file, marker])

    self.assert_file_eventually_contains(stdout_file, marker)

  def test_propagates_interruptions(self):

    def run(pid_file):
      build_test_suites.run_command([
          self.python_executable,
          '-c',
          textwrap.dedent(f"""\
              import os
              import pathlib
              import time

              pathlib.Path('{pid_file}').write_text(str(os.getpid()))

              # Keep the process alive for us to explicitly interrupt it.
              time.sleep(10)
              """),
      ])

    pid_file = self.temp_dir.joinpath('pid.txt')
    p = self.start_process(target=run, args=[pid_file])
    subprocess_pid = int(read_eventual_file_contents(pid_file))

    os.kill(p.pid, signal.SIGINT)
    p.join()

    self.assert_process_eventually_dies(p.pid)
    self.assert_process_eventually_dies(subprocess_pid)

  def start_process(self, *args, **kwargs) -> multiprocessing.Process:
    p = multiprocessing.Process(*args, **kwargs)
    self._managed_processes.append(p)
    p.start()
    return p

  def assert_process_eventually_dies(self, pid: int):
    try:
      wait_until(lambda: not ci_test_lib.process_alive(pid))
    except TimeoutError as e:
      self.fail(f'Process {pid} did not die after a while: {e}')

  def assert_file_eventually_contains(self, file: pathlib.Path, substring: str):
    wait_until(lambda: file.is_file() and file.stat().st_size > 0)
    self.assertIn(substring, read_file_contents(file))

  def _terminate_managed_processes(self):
    for p in self._managed_processes:
      if not p.is_alive():
        continue

      # We terminate the process with `SIGINT` since using `terminate` or
      # `SIGKILL` doesn't kill any grandchild processes and we don't have
      # `psutil` available to easily query all children.
      os.kill(p.pid, signal.SIGINT)


class BuildPlannerTest(unittest.TestCase):

  class TestOptimizedBuildTarget(optimized_targets.OptimizedBuildTarget):

    def __init__(
        self, target, build_context, args, output_targets, packaging_commands
    ):
      super().__init__(target, build_context, args)
      self.output_targets = output_targets
      self.packaging_commands = packaging_commands

    def get_build_targets_impl(self):
      return self.output_targets

    def get_package_outputs_commands_impl(self):
      return self.packaging_commands

    def get_enabled_flag(self):
      return f'{self.target}_enabled'

  def test_build_optimization_off_builds_everything(self):
    build_targets = {'target_1', 'target_2'}
    build_planner = self.create_build_planner(
        build_context=self.create_build_context(optimized_build_enabled=False),
        build_targets=build_targets,
    )

    build_plan = build_planner.create_build_plan()

    self.assertSetEqual(build_targets, build_plan.build_targets)

  def test_build_optimization_off_doesnt_package(self):
    build_targets = {'target_1', 'target_2'}
    build_planner = self.create_build_planner(
        build_context=self.create_build_context(optimized_build_enabled=False),
        build_targets=build_targets,
    )

    build_plan = build_planner.create_build_plan()

    for packaging_command in self.run_packaging_commands(build_plan):
      self.assertEqual(len(packaging_command), 0)

  def test_build_optimization_on_optimizes_target(self):
    build_targets = {'target_1', 'target_2'}
    build_planner = self.create_build_planner(
        build_targets=build_targets,
        build_context=self.create_build_context(
            enabled_build_features=[{'name': self.get_target_flag('target_1')}]
        ),
    )

    build_plan = build_planner.create_build_plan()

    expected_targets = {self.get_optimized_target_name('target_1'), 'target_2'}
    self.assertSetEqual(expected_targets, build_plan.build_targets)

  def test_build_optimization_on_packages_target(self):
    build_targets = {'target_1', 'target_2'}
    optimized_target_name = self.get_optimized_target_name('target_1')
    packaging_commands = [[f'packaging {optimized_target_name}']]
    build_planner = self.create_build_planner(
        build_targets=build_targets,
        build_context=self.create_build_context(
            enabled_build_features=[{'name': self.get_target_flag('target_1')}]
        ),
        packaging_commands=packaging_commands,
    )

    build_plan = build_planner.create_build_plan()

    self.assertIn(packaging_commands, self.run_packaging_commands(build_plan))

  def test_individual_build_optimization_off_doesnt_optimize(self):
    build_targets = {'target_1', 'target_2'}
    build_planner = self.create_build_planner(
        build_targets=build_targets,
    )

    build_plan = build_planner.create_build_plan()

    self.assertSetEqual(build_targets, build_plan.build_targets)

  def test_individual_build_optimization_off_doesnt_package(self):
    build_targets = {'target_1', 'target_2'}
    packaging_commands = [['packaging command']]
    build_planner = self.create_build_planner(
        build_targets=build_targets,
        packaging_commands=packaging_commands,
    )

    build_plan = build_planner.create_build_plan()

    for packaging_command in self.run_packaging_commands(build_plan):
      self.assertEqual(len(packaging_command), 0)

  def test_target_output_used_target_built(self):
    build_target = 'test_target'
    build_planner = self.create_build_planner(
        build_targets={build_target},
        build_context=self.create_build_context(
            test_context=self.get_test_context(build_target),
            enabled_build_features=[{'name': 'test_target_unused_exclusion'}],
        ),
    )

    build_plan = build_planner.create_build_plan()

    self.assertSetEqual(build_plan.build_targets, {build_target})

  def test_target_regex_used_target_built(self):
    build_target = 'test_target'
    test_context = self.get_test_context(build_target)
    test_context['testInfos'][0]['extraOptions'] = [{
        'key': 'additional-files-filter',
        'values': [f'.*{build_target}.*\.zip'],
    }]
    build_planner = self.create_build_planner(
        build_targets={build_target},
        build_context=self.create_build_context(
            test_context=test_context,
            enabled_build_features=[{'name': 'test_target_unused_exclusion'}],
        ),
    )

    build_plan = build_planner.create_build_plan()

    self.assertSetEqual(build_plan.build_targets, {build_target})

  def test_target_output_not_used_target_not_built(self):
    build_target = 'test_target'
    test_context = self.get_test_context(build_target)
    test_context['testInfos'][0]['extraOptions'] = []
    build_planner = self.create_build_planner(
        build_targets={build_target},
        build_context=self.create_build_context(
            test_context=test_context,
            enabled_build_features=[{'name': 'test_target_unused_exclusion'}],
        ),
    )

    build_plan = build_planner.create_build_plan()

    self.assertSetEqual(build_plan.build_targets, set())

  def test_target_regex_matching_not_too_broad(self):
    build_target = 'test_target'
    test_context = self.get_test_context(build_target)
    test_context['testInfos'][0]['extraOptions'] = [{
        'key': 'additional-files-filter',
        'values': [f'.*a{build_target}.*\.zip'],
    }]
    build_planner = self.create_build_planner(
        build_targets={build_target},
        build_context=self.create_build_context(
            test_context=test_context,
            enabled_build_features=[{'name': 'test_target_unused_exclusion'}],
        ),
    )

    build_plan = build_planner.create_build_plan()

    self.assertSetEqual(build_plan.build_targets, set())

  def create_build_planner(
      self,
      build_targets: set[str],
      build_context: BuildContext = None,
      args: argparse.Namespace = None,
      target_optimizations: dict[
          str, optimized_targets.OptimizedBuildTarget
      ] = None,
      packaging_commands: list[list[str]] = [],
  ) -> build_test_suites.BuildPlanner:
    if not build_context:
      build_context = self.create_build_context()
    if not args:
      args = self.create_args(extra_build_targets=build_targets)
    if not target_optimizations:
      target_optimizations = self.create_target_optimizations(
          build_context,
          build_targets,
          packaging_commands,
      )
    return build_test_suites.BuildPlanner(
        build_context, args, target_optimizations
    )

  def create_build_context(
      self,
      optimized_build_enabled: bool = True,
      enabled_build_features: list[dict[str, str]] = [],
      test_context: dict[str, any] = {},
  ) -> BuildContext:
    build_context_dict = {}
    build_context_dict['enabledBuildFeatures'] = enabled_build_features
    if optimized_build_enabled:
      build_context_dict['enabledBuildFeatures'].append(
          {'name': 'optimized_build'}
      )
    build_context_dict['testContext'] = test_context
    return BuildContext(build_context_dict)

  def create_args(
      self, extra_build_targets: set[str] = set()
  ) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('extra_targets', nargs='*')
    return parser.parse_args(extra_build_targets)

  def create_target_optimizations(
      self,
      build_context: BuildContext,
      build_targets: set[str],
      packaging_commands: list[list[str]] = [],
  ):
    target_optimizations = dict()
    for target in build_targets:
      target_optimizations[target] = functools.partial(
          self.TestOptimizedBuildTarget,
          output_targets={self.get_optimized_target_name(target)},
          packaging_commands=packaging_commands,
      )

    return target_optimizations

  def get_target_flag(self, target: str):
    return f'{target}_enabled'

  def get_optimized_target_name(self, target: str):
    return f'{target}_optimized'

  def get_test_context(self, target: str):
    return {
        'testInfos': [
            {
                'name': 'atp_test',
                'target': 'test_target',
                'branch': 'branch',
                'extraOptions': [{
                    'key': 'additional-files-filter',
                    'values': [f'{target}.zip'],
                }],
                'command': '/tf/command',
                'extraBuildTargets': [
                    'extra_build_target',
                ],
            },
        ],
    }

  def run_packaging_commands(self, build_plan: build_test_suites.BuildPlan):
    return [
        packaging_command_getter()
        for packaging_command_getter in build_plan.packaging_commands_getters
    ]


def wait_until(
    condition_function: Callable[[], bool],
    timeout_secs: float = 3.0,
    polling_interval_secs: float = 0.1,
):
  """Waits until a condition function returns True."""

  start_time_secs = time.time()

  while not condition_function():
    if time.time() - start_time_secs > timeout_secs:
      raise TimeoutError(
          f'Condition not met within timeout: {timeout_secs} seconds'
      )

    time.sleep(polling_interval_secs)


def read_file_contents(file: pathlib.Path) -> str:
  with open(file, 'r') as f:
    return f.read()


def read_eventual_file_contents(file: pathlib.Path) -> str:
  wait_until(lambda: file.is_file() and file.stat().st_size > 0)
  return read_file_contents(file)


if __name__ == '__main__':
  ci_test_lib.main()
