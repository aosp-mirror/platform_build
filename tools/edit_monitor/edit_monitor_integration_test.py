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

"""Integration tests for Edit Monitor."""

import glob
from importlib import resources
import logging
import os
import pathlib
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


class EditMonitorIntegrationTest(unittest.TestCase):

  @classmethod
  def setUpClass(cls):
    super().setUpClass()
    # Configure to print logging to stdout.
    logging.basicConfig(filename=None, level=logging.DEBUG)
    console = logging.StreamHandler(sys.stdout)
    logging.getLogger("").addHandler(console)

  def setUp(self):
    super().setUp()
    self.working_dir = tempfile.TemporaryDirectory()
    self.root_monitoring_path = pathlib.Path(self.working_dir.name).joinpath(
        "files"
    )
    self.root_monitoring_path.mkdir()
    self.edit_monitor_binary_path = self._import_executable("edit_monitor")

  def tearDown(self):
    self.working_dir.cleanup()
    super().tearDown()

  def test_log_single_edit_event_success(self):
    p = self._start_edit_monitor_process()

    # Create the .git file under the monitoring dir.
    self.root_monitoring_path.joinpath(".git").touch()

    # Create and modify a file.
    test_file = self.root_monitoring_path.joinpath("test.txt")
    with open(test_file, "w") as f:
      f.write("something")

    # Move the file.
    test_file_moved = self.root_monitoring_path.joinpath("new_test.txt")
    test_file.rename(test_file_moved)

    # Delete the file.
    test_file_moved.unlink()

    # Give some time for the edit monitor to receive the edit event.
    time.sleep(1)
    # Stop the edit monitor and flush all events.
    os.kill(p.pid, signal.SIGINT)
    p.communicate()

    self.assertEqual(self._get_logged_events_num(), 4)

  def _start_edit_monitor_process(self):
    command = f"""
    export TMPDIR="{self.working_dir.name}"
    {self.edit_monitor_binary_path} --path={self.root_monitoring_path} --dry_run"""
    p = subprocess.Popen(
        command,
        shell=True,
        text=True,
        start_new_session=True,
        executable="/bin/bash",
    )
    self._wait_for_observer_start(time_out=5)
    return p

  def _wait_for_observer_start(self, time_out):
    start_time = time.time()

    while time.time() < start_time + time_out:
      log_files = glob.glob(self.working_dir.name + "/edit_monitor_*/*.log")
      if log_files:
        with open(log_files[0], "r") as f:
          for line in f:
            logging.debug("initial log: %s", line)
            if line.rstrip("\n").endswith("Observer started."):
              return
      else:
        time.sleep(1)

    self.fail(f"Observer not started in {time_out} seconds.")

  def _get_logged_events_num(self):
    log_files = glob.glob(self.working_dir.name + "/edit_monitor_*/*.log")
    self.assertEqual(len(log_files), 1)

    with open(log_files[0], "r") as f:
      for line in f:
        logging.debug("complete log: %s", line)
        if line.rstrip("\n").endswith("in dry run."):
          return int(line.split(":")[-1].split(" ")[2])

    return 0

  def _import_executable(self, executable_name: str) -> pathlib.Path:
    binary_dir = pathlib.Path(self.working_dir.name).joinpath("binary")
    binary_dir.mkdir()
    executable_path = binary_dir.joinpath(executable_name)
    with resources.as_file(
        resources.files("testdata").joinpath(executable_name)
    ) as binary:
      shutil.copy(binary, executable_path)
    executable_path.chmod(0o755)
    return executable_path


if __name__ == "__main__":
  unittest.main()
