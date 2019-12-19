#!/usr/bin/python
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

# pylint:disable=relative-beyond-top-level
from .warn_common import common_main


# This parallel_process could be changed depending on platform
# and availability of multi-process library functions.
def parallel_process(num_cpu, classify_warnings, groups):
  pool = multiprocessing.Pool(num_cpu)
  return pool.map(classify_warnings, groups)


def main():
  common_main(parallel_process)


if __name__ == '__main__':
  main()
