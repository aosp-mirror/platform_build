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

"""Testing utilities for tests in the CI package."""

import logging
import os
import unittest
import subprocess
import pathlib
import shutil
import tempfile


# Export the TestCase class to reduce the number of imports tests have to list.
TestCase = unittest.TestCase


def process_alive(pid):
  """Check For the existence of a pid."""

  try:
    os.kill(pid, 0)
  except OSError:
    return False

  return True


class TemporaryProcessSession:

  def __init__(self, test_case: TestCase):
    self._created_processes = []
    test_case.addCleanup(self.cleanup)

  def create(self, args, kwargs):
    p = subprocess.Popen(*args, **kwargs, start_new_session=True)
    self._created_processes.append(p)
    return p

  def cleanup(self):
    for p in self._created_processes:
      if not process_alive(p.pid):
        return
      os.killpg(os.getpgid(p.pid), signal.SIGKILL)


class TestTemporaryDirectory:

  def __init__(self, delete: bool, ):
    self._delete = delete

  @classmethod
  def create(cls, test_case: TestCase, delete: bool = True):
    temp_dir = TestTemporaryDirectory(delete)
    temp_dir._dir = pathlib.Path(tempfile.mkdtemp())
    test_case.addCleanup(temp_dir.cleanup)
    return temp_dir._dir

  def get_dir(self):
    return self._dir

  def cleanup(self):
    if not self._delete:
      return
    shutil.rmtree(self._dir, ignore_errors=True)


def main():

  # Disable logging since it breaks the TF Python test output parser.
  # TODO(hzalek): Use TF's `test-output-file` option to re-enable logging.
  logging.getLogger().disabled = True

  unittest.main()
