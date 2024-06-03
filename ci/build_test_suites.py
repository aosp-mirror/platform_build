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
import logging
import os
import pathlib
import subprocess
import sys


class Error(Exception):

  def __init__(self, message):
    super().__init__(message)


class BuildFailureError(Error):

  def __init__(self, return_code):
    super().__init__(f'Build command failed with return code: f{return_code}')
    self.return_code = return_code


REQUIRED_ENV_VARS = frozenset(['TARGET_PRODUCT', 'TARGET_RELEASE', 'TOP'])
SOONG_UI_EXE_REL_PATH = 'build/soong/soong_ui.bash'


def get_top() -> pathlib.Path:
  return pathlib.Path(os.environ['TOP'])


def build_test_suites(argv: list[str]) -> int:
  """Builds the general-tests and any other test suites passed in.

  Args:
    argv: The command line arguments passed in.

  Returns:
    The exit code of the build.
  """
  args = parse_args(argv)
  check_required_env()

  try:
    build_everything(args)
  except BuildFailureError as e:
    logging.error('Build command failed! Check build_log for details.')
    return e.return_code

  return 0


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


def parse_args(argv):
  argparser = argparse.ArgumentParser()

  argparser.add_argument(
      'extra_targets', nargs='*', help='Extra test suites to build.'
  )

  return argparser.parse_args(argv)


def build_everything(args: argparse.Namespace):
  """Builds all tests (regardless of whether they are needed).

  Args:
    args: The parsed arguments.

  Raises:
    BuildFailure: If the build command fails.
  """
  build_command = base_build_command(args, args.extra_targets)

  try:
    run_command(build_command)
  except subprocess.CalledProcessError as e:
    raise BuildFailureError(e.returncode) from e


def base_build_command(
    args: argparse.Namespace, extra_targets: set[str]
) -> list[str]:

  build_command = []
  build_command.append(get_top().joinpath(SOONG_UI_EXE_REL_PATH))
  build_command.append('--make-mode')
  build_command.extend(extra_targets)

  return build_command


def run_command(args: list[str], stdout=None):
  subprocess.run(args=args, check=True, stdout=stdout)


def main(argv):
  sys.exit(build_test_suites(argv))
