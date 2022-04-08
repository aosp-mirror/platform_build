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

"""Call -m warn.warn to process warning messages.

This script is used by Android continuous build bots for all branches.
Old frozen branches will continue to use the old warn.py, and active
branches will use this new version to call -m warn.warn.
"""

import os
import subprocess
import sys


def main():
  os.environ['PYTHONPATH'] = os.path.dirname(os.path.abspath(__file__))
  subprocess.check_call(['/usr/bin/python', '-m', 'warn.warn'] + sys.argv[1:])


if __name__ == '__main__':
  main()
