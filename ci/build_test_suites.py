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

"""Script to build only the necessary modules for general-tests along

with whatever other targets are passed in.
"""

import argparse
from collections.abc import Sequence
import json
import os
import pathlib
import re
import subprocess
import sys
from typing import Any, Dict, Set, Text

import test_mapping_module_retriever


# List of modules that are always required to be in general-tests.zip
REQUIRED_MODULES = frozenset(
    ['cts-tradefed', 'vts-tradefed', 'compatibility-host-util', 'soong_zip']
)


def build_test_suites(argv):
  args = parse_args(argv)

  if not os.environ.get('BUILD_NUMBER')[0] == 'P':
    build_everything(args)
    return

  # Call the class to map changed files to modules to build.
  # TODO(lucafarsi): Move this into a replaceable class.
  build_affected_modules(args)


def parse_args(argv):
  argparser = argparse.ArgumentParser()
  argparser.add_argument(
      'extra_targets', nargs='*', help='Extra test suites to build.'
  )
  argparser.add_argument('--target_product')
  argparser.add_argument('--target_release')
  argparser.add_argument(
      '--with_dexpreopt_boot_img_and_system_server_only', action='store_true'
  )
  argparser.add_argument('--dist_dir')
  argparser.add_argument('--change_info', nargs='?')
  argparser.add_argument('--extra_required_modules', nargs='*')

  return argparser.parse_args()


def build_everything(args: argparse.Namespace):
  build_command = base_build_command(args)
  build_command.append('general-tests')

  run_command(build_command, print_output=True)


def build_affected_modules(args: argparse.Namespace):
  modules_to_build = find_modules_to_build(
      pathlib.Path(args.change_info), args.extra_required_modules
  )

  # Call the build command with everything.
  build_command = base_build_command(args)
  build_command.extend(modules_to_build)

  run_command(build_command, print_output=True)

  zip_build_outputs(modules_to_build, args.dist_dir, args.target_release)


def base_build_command(args: argparse.Namespace) -> list:
  build_command = []
  build_command.append('time')
  build_command.append('./build/soong/soong_ui.bash')
  build_command.append('--make-mode')
  build_command.append('dist')
  build_command.append('DIST_DIR=' + args.dist_dir)
  build_command.append('TARGET_PRODUCT=' + args.target_product)
  build_command.append('TARGET_RELEASE=' + args.target_release)
  if args.with_dexpreopt_boot_img_and_system_server_only:
    build_command.append('WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY=true')
  build_command.extend(args.extra_targets)

  return build_command


def run_command(
    args: list[str],
    env: Dict[Text, Text] = os.environ,
    print_output: bool = False,
) -> str:
  result = subprocess.run(
      args=args,
      text=True,
      capture_output=True,
      check=False,
      env=env,
  )
  # If the process failed, print its stdout and propagate the exception.
  if not result.returncode == 0:
    print('Build command failed! output:')
    print('stdout: ' + result.stdout)
    print('stderr: ' + result.stderr)

  result.check_returncode()

  if print_output:
    print(result.stdout)

  return result.stdout


def find_modules_to_build(
    change_info: pathlib.Path, extra_required_modules: list[Text]
) -> Set[Text]:
  changed_files = find_changed_files(change_info)

  test_mappings = test_mapping_module_retriever.GetTestMappings(
      changed_files, set()
  )

  # Soong_zip is required to generate the output zip so always build it.
  modules_to_build = set(REQUIRED_MODULES)
  if extra_required_modules:
    modules_to_build.update(extra_required_modules)

  modules_to_build.update(find_affected_modules(test_mappings, changed_files))

  return modules_to_build


def find_changed_files(change_info: pathlib.Path) -> Set[Text]:
  with open(change_info) as change_info_file:
    change_info_contents = json.load(change_info_file)

  changed_files = set()

  for change in change_info_contents['changes']:
    project_path = change.get('projectPath') + '/'

    for revision in change.get('revisions'):
      for file_info in revision.get('fileInfos'):
        changed_files.add(project_path + file_info.get('path'))

  return changed_files


def find_affected_modules(
    test_mappings: Dict[str, Any], changed_files: Set[Text]
) -> Set[Text]:
  modules = set()

  # The test_mappings object returned by GetTestMappings is organized as
  # follows:
  # {
  #   'test_mapping_file_path': {
  #     'group_name' : [
  #       'name': 'module_name',
  #     ],
  #   }
  # }
  for test_mapping in test_mappings.values():
    for group in test_mapping.values():
      for entry in group:
        module_name = entry.get('name', None)

        if not module_name:
          continue

        file_patterns = entry.get('file_patterns')
        if not file_patterns:
          modules.add(module_name)
          continue

        if matches_file_patterns(file_patterns, changed_files):
          modules.add(module_name)
          continue

  return modules


# TODO(lucafarsi): Share this logic with the original logic in
# test_mapping_test_retriever.py
def matches_file_patterns(
    file_patterns: list[Text], changed_files: Set[Text]
) -> bool:
  for changed_file in changed_files:
    for pattern in file_patterns:
      if re.search(pattern, changed_file):
        return True

  return False


def zip_build_outputs(
    modules_to_build: Set[Text], dist_dir: Text, target_release: Text
):
  src_top = os.environ.get('TOP', os.getcwd())

  # Call dumpvars to get the necessary things.
  # TODO(lucafarsi): Don't call soong_ui 4 times for this, --dumpvars-mode can
  # do it but it requires parsing.
  host_out_testcases = get_soong_var('HOST_OUT_TESTCASES', target_release)
  target_out_testcases = get_soong_var('TARGET_OUT_TESTCASES', target_release)
  product_out = get_soong_var('PRODUCT_OUT', target_release)
  soong_host_out = get_soong_var('SOONG_HOST_OUT', target_release)
  host_out = get_soong_var('HOST_OUT', target_release)

  # Call the class to package the outputs.
  # TODO(lucafarsi): Move this code into a replaceable class.
  host_paths = []
  target_paths = []
  for module in modules_to_build:
    host_path = os.path.join(host_out_testcases, module)
    if os.path.exists(host_path):
      host_paths.append(host_path)

    target_path = os.path.join(target_out_testcases, module)
    if os.path.exists(target_path):
      target_paths.append(target_path)

  zip_command = ['time', os.path.join(host_out, 'bin', 'soong_zip')]

  # Add host testcases.
  zip_command.append('-C')
  zip_command.append(os.path.join(src_top, soong_host_out))
  zip_command.append('-P')
  zip_command.append('host/')
  for path in host_paths:
    zip_command.append('-D')
    zip_command.append(path)

  # Add target testcases.
  zip_command.append('-C')
  zip_command.append(os.path.join(src_top, product_out))
  zip_command.append('-P')
  zip_command.append('target')
  for path in target_paths:
    zip_command.append('-D')
    zip_command.append(path)

  # TODO(lucafarsi): Push this logic into a general-tests-minimal build command
  # Add necessary tools. These are also hardcoded in general-tests.mk.
  framework_path = os.path.join(soong_host_out, 'framework')

  zip_command.append('-C')
  zip_command.append(framework_path)
  zip_command.append('-P')
  zip_command.append('host/tools')
  zip_command.append('-f')
  zip_command.append(os.path.join(framework_path, 'cts-tradefed.jar'))
  zip_command.append('-f')
  zip_command.append(
      os.path.join(framework_path, 'compatibility-host-util.jar')
  )
  zip_command.append('-f')
  zip_command.append(os.path.join(framework_path, 'vts-tradefed.jar'))

  # Zip to the DIST dir.
  zip_command.append('-o')
  zip_command.append(os.path.join(dist_dir, 'general-tests.zip'))

  run_command(zip_command, print_output=True)


def get_soong_var(var: str, target_release: str) -> str:
  new_env = os.environ.copy()
  new_env['TARGET_RELEASE'] = target_release

  value = run_command(
      ['./build/soong/soong_ui.bash', '--dumpvar-mode', '--abs', var],
      env=new_env,
  ).strip()
  if not value:
    raise RuntimeError('Necessary soong variable ' + var + ' not found.')

  return value


def main(argv):
  build_test_suites(sys.argv)
