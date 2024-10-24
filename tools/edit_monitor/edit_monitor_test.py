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

"""Unittests for Edit Monitor."""

import logging
import multiprocessing
import os
import pathlib
import signal
import sys
import tempfile
import time
import unittest

from atest.proto import clientanalytics_pb2
from edit_monitor import edit_monitor
from proto import edit_event_pb2


class EditMonitorTest(unittest.TestCase):

  @classmethod
  def setUpClass(cls):
    super().setUpClass()
    # Configure to print logging to stdout.
    logging.basicConfig(filename=None, level=logging.DEBUG)
    console = logging.StreamHandler(sys.stdout)
    logging.getLogger('').addHandler(console)

  def setUp(self):
    super().setUp()
    self.working_dir = tempfile.TemporaryDirectory()
    self.root_monitoring_path = pathlib.Path(self.working_dir.name).joinpath(
        'files'
    )
    self.root_monitoring_path.mkdir()
    self.log_event_dir = pathlib.Path(self.working_dir.name).joinpath('logs')
    self.log_event_dir.mkdir()

  def tearDown(self):
    self.working_dir.cleanup()
    super().tearDown()

  def test_log_edit_event_success(self):
    # Create the .git file under the monitoring dir.
    self.root_monitoring_path.joinpath('.git').touch()
    fake_cclient = FakeClearcutClient(
        log_output_file=self.log_event_dir.joinpath('logs.output')
    )
    p = self._start_test_edit_monitor_process(fake_cclient)

    # Create and modify a file.
    test_file = self.root_monitoring_path.joinpath('test.txt')
    with open(test_file, 'w') as f:
      f.write('something')
    # Move the file.
    test_file_moved = self.root_monitoring_path.joinpath('new_test.txt')
    test_file.rename(test_file_moved)
    # Delete the file.
    test_file_moved.unlink()
    # Give some time for the edit monitor to receive the edit event.
    time.sleep(1)
    # Stop the edit monitor and flush all events.
    os.kill(p.pid, signal.SIGINT)
    p.join()

    logged_events = self._get_logged_events()
    self.assertEqual(len(logged_events), 4)
    expected_create_event = edit_event_pb2.EditEvent.SingleEditEvent(
        file_path=str(
            self.root_monitoring_path.joinpath('test.txt').resolve()
        ),
        edit_type=edit_event_pb2.EditEvent.CREATE,
    )
    expected_modify_event = edit_event_pb2.EditEvent.SingleEditEvent(
        file_path=str(
            self.root_monitoring_path.joinpath('test.txt').resolve()
        ),
        edit_type=edit_event_pb2.EditEvent.MODIFY,
    )
    expected_move_event = edit_event_pb2.EditEvent.SingleEditEvent(
        file_path=str(
            self.root_monitoring_path.joinpath('test.txt').resolve()
        ),
        edit_type=edit_event_pb2.EditEvent.MOVE,
    )
    expected_delete_event = edit_event_pb2.EditEvent.SingleEditEvent(
        file_path=str(
            self.root_monitoring_path.joinpath('new_test.txt').resolve()
        ),
        edit_type=edit_event_pb2.EditEvent.DELETE,
    )
    self.assertEqual(
        expected_create_event,
        edit_event_pb2.EditEvent.FromString(
            logged_events[0].source_extension
        ).single_edit_event,
    )
    self.assertEqual(
        expected_modify_event,
        edit_event_pb2.EditEvent.FromString(
            logged_events[1].source_extension
        ).single_edit_event,
    )
    self.assertEqual(
        expected_move_event,
        edit_event_pb2.EditEvent.FromString(
            logged_events[2].source_extension
        ).single_edit_event,
    )
    self.assertEqual(
        expected_delete_event,
        edit_event_pb2.EditEvent.FromString(
            logged_events[3].source_extension
        ).single_edit_event,
    )

  def test_do_not_log_edit_event_for_directory_change(self):
    # Create the .git file under the monitoring dir.
    self.root_monitoring_path.joinpath('.git').touch()
    fake_cclient = FakeClearcutClient(
        log_output_file=self.log_event_dir.joinpath('logs.output')
    )
    p = self._start_test_edit_monitor_process(fake_cclient)

    # Create a sub directory
    self.root_monitoring_path.joinpath('test_dir').mkdir()
    # Give some time for the edit monitor to receive the edit event.
    time.sleep(1)
    # Stop the edit monitor and flush all events.
    os.kill(p.pid, signal.SIGINT)
    p.join()

    logged_events = self._get_logged_events()
    self.assertEqual(len(logged_events), 0)

  def test_do_not_log_edit_event_for_hidden_file(self):
    # Create the .git file under the monitoring dir.
    self.root_monitoring_path.joinpath('.git').touch()
    fake_cclient = FakeClearcutClient(
        log_output_file=self.log_event_dir.joinpath('logs.output')
    )
    p = self._start_test_edit_monitor_process(fake_cclient)

    # Create a hidden file.
    self.root_monitoring_path.joinpath('.test.txt').touch()
    # Create a hidden dir.
    hidden_dir = self.root_monitoring_path.joinpath('.test')
    hidden_dir.mkdir()
    hidden_dir.joinpath('test.txt').touch()
    # Give some time for the edit monitor to receive the edit event.
    time.sleep(1)
    # Stop the edit monitor and flush all events.
    os.kill(p.pid, signal.SIGINT)
    p.join()

    logged_events = self._get_logged_events()
    self.assertEqual(len(logged_events), 0)

  def test_do_not_log_edit_event_for_non_git_project_file(self):
    fake_cclient = FakeClearcutClient(
        log_output_file=self.log_event_dir.joinpath('logs.output')
    )
    p = self._start_test_edit_monitor_process(fake_cclient)

    # Create a file.
    self.root_monitoring_path.joinpath('test.txt').touch()
    # Create a file under a sub dir.
    sub_dir = self.root_monitoring_path.joinpath('.test')
    sub_dir.mkdir()
    sub_dir.joinpath('test.txt').touch()
    # Give some time for the edit monitor to receive the edit event.
    time.sleep(1)
    # Stop the edit monitor and flush all events.
    os.kill(p.pid, signal.SIGINT)
    p.join()

    logged_events = self._get_logged_events()
    self.assertEqual(len(logged_events), 0)

  def test_log_edit_event_fail(self):
    # Create the .git file under the monitoring dir.
    self.root_monitoring_path.joinpath('.git').touch()
    fake_cclient = FakeClearcutClient(
        log_output_file=self.log_event_dir.joinpath('logs.output'),
        raise_log_exception=True,
    )
    p = self._start_test_edit_monitor_process(fake_cclient)

    # Create a file.
    self.root_monitoring_path.joinpath('test.txt').touch()
    # Give some time for the edit monitor to receive the edit event.
    time.sleep(1)
    # Stop the edit monitor and flush all events.
    os.kill(p.pid, signal.SIGINT)
    p.join()

    logged_events = self._get_logged_events()
    self.assertEqual(len(logged_events), 0)

  def _start_test_edit_monitor_process(
      self, cclient
  ) -> multiprocessing.Process:
    receiver, sender = multiprocessing.Pipe()
    # Start edit monitor in a subprocess.
    p = multiprocessing.Process(
        target=edit_monitor.start,
        args=(str(self.root_monitoring_path.resolve()), cclient, sender),
    )
    p.daemon = True
    p.start()

    # Wait until observer started.
    received_data = receiver.recv()
    self.assertEquals(received_data, 'Observer started.')

    receiver.close()
    return p

  def _get_logged_events(self):
    with open(self.log_event_dir.joinpath('logs.output'), 'rb') as f:
      data = f.read()

    return [
        clientanalytics_pb2.LogEvent.FromString(record)
        for record in data.split(b'\x00')
        if record
    ]


class FakeClearcutClient:

  def __init__(self, log_output_file, raise_log_exception=False):
    self.pending_log_events = []
    self.raise_log_exception = raise_log_exception
    self.log_output_file = log_output_file

  def log(self, log_event):
    if self.raise_log_exception:
      raise Exception('unknown exception')
    self.pending_log_events.append(log_event)

  def flush_events(self):
    delimiter = b'\x00'  # Use a null byte as the delimiter
    with open(self.log_output_file, 'wb') as f:
      for log_event in self.pending_log_events:
        f.write(log_event.SerializeToString() + delimiter)

    self.pending_log_events.clear()


if __name__ == '__main__':
  unittest.main()
