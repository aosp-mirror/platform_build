#!/usr/bin/env python3
#
# Copyright (C) 2019 The Android Open Source Project
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

"""Simple wrapper to run warn_common with Python standard Pool."""

import multiprocessing
import signal
import sys

# pylint:disable=relative-beyond-top-level,no-name-in-module
# suppress false positive of no-name-in-module warnings
from . import warn_common as common


def classify_warnings(args):
  """Classify a list of warning lines.

  Args:
    args: dictionary {
        'group': list of (warning, link),
        'project_patterns': re.compile(project_list[p][1]),
        'warn_patterns': list of warn_pattern,
        'num_processes': number of processes being used for multiprocessing }
  Returns:
    results: a list of the classified warnings.
  """
  results = []
  for line, link in args['group']:
    common.classify_one_warning(line, link, results, args['project_patterns'],
                                args['warn_patterns'])

  # After the main work, ignore all other signals to a child process,
  # to avoid bad warning/error messages from the exit clean-up process.
  if args['num_processes'] > 1:
    signal.signal(signal.SIGTERM, lambda *args: sys.exit(-signal.SIGTERM))
  return results


def create_and_launch_subprocesses(num_cpu, classify_warnings_fn, arg_groups,
                                   group_results):
  """Fork num_cpu processes to classify warnings."""
  pool = multiprocessing.Pool(num_cpu)
  for cpu in range(num_cpu):
    proc_result = pool.map(classify_warnings_fn, arg_groups[cpu])
    if proc_result is not None:
      group_results.append(proc_result)
  return group_results


def main():
  """Old main() calls new common_main."""
  use_google3 = False
  common.common_main(use_google3, create_and_launch_subprocesses,
                     classify_warnings)


if __name__ == '__main__':
  main()
