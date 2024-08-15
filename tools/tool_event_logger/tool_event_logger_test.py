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

"""Unittests for ToolEventLogger."""

import datetime
import logging
import unittest
from unittest import mock

from atest.metrics import clearcut_client
from proto import tool_event_pb2
from tool_event_logger import tool_event_logger

TEST_INVOCATION_ID = 'test_invocation_id'
TEST_USER_NAME = 'test_user'
TEST_HOST_NAME = 'test_host_name'
TEST_TOOL_TAG = 'test_tool'
TEST_SOURCE_ROOT = 'test_source_root'
TEST_PLATFORM_VERSION = 'test_platform_version'
TEST_PYTHON_VERSION = 'test_python_version'
TEST_EVENT_TIMESTAMP = datetime.datetime.now()


class ToolEventLoggerTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    self.clearcut_client = FakeClearcutClient()
    self.logger = tool_event_logger.ToolEventLogger(
        TEST_TOOL_TAG,
        TEST_INVOCATION_ID,
        TEST_USER_NAME,
        TEST_HOST_NAME,
        TEST_SOURCE_ROOT,
        TEST_PLATFORM_VERSION,
        TEST_PYTHON_VERSION,
        client=self.clearcut_client,
    )

  def test_log_event_timestamp(self):
    with self.logger:
      self.logger.log_invocation_started(
          datetime.datetime.fromtimestamp(100.101), 'test_command'
      )

    self.assertEqual(
        self.clearcut_client.get_last_sent_event().event_time_ms, 100101
    )

  def test_log_event_basic_information(self):
    with self.logger:
      self.logger.log_invocation_started(TEST_EVENT_TIMESTAMP, 'test_command')

    sent_event = self.clearcut_client.get_last_sent_event()
    log_event = tool_event_pb2.ToolEvent.FromString(sent_event.source_extension)
    self.assertEqual(log_event.invocation_id, TEST_INVOCATION_ID)
    self.assertEqual(log_event.user_name, TEST_USER_NAME)
    self.assertEqual(log_event.host_name, TEST_HOST_NAME)
    self.assertEqual(log_event.tool_tag, TEST_TOOL_TAG)
    self.assertEqual(log_event.source_root, TEST_SOURCE_ROOT)

  def test_log_invocation_started(self):
    expected_invocation_started = tool_event_pb2.ToolEvent.InvocationStarted(
        command_args='test_command',
        os=TEST_PLATFORM_VERSION + ':' + TEST_PYTHON_VERSION,
    )

    with self.logger:
      self.logger.log_invocation_started(TEST_EVENT_TIMESTAMP, 'test_command')

    self.assertEqual(self.clearcut_client.get_number_of_sent_events(), 1)
    sent_event = self.clearcut_client.get_last_sent_event()
    self.assertEqual(
        expected_invocation_started,
        tool_event_pb2.ToolEvent.FromString(
            sent_event.source_extension
        ).invocation_started,
    )

  def test_log_invocation_stopped(self):
    expected_invocation_stopped = tool_event_pb2.ToolEvent.InvocationStopped(
        exit_code=0,
        exit_log='exit_log',
    )

    with self.logger:
      self.logger.log_invocation_stopped(TEST_EVENT_TIMESTAMP, 0, 'exit_log')

    self.assertEqual(self.clearcut_client.get_number_of_sent_events(), 1)
    sent_event = self.clearcut_client.get_last_sent_event()
    self.assertEqual(
        expected_invocation_stopped,
        tool_event_pb2.ToolEvent.FromString(
            sent_event.source_extension
        ).invocation_stopped,
    )

  def test_log_multiple_events(self):
    with self.logger:
      self.logger.log_invocation_started(TEST_EVENT_TIMESTAMP, 'test_command')
      self.logger.log_invocation_stopped(TEST_EVENT_TIMESTAMP, 0, 'exit_log')

    self.assertEqual(self.clearcut_client.get_number_of_sent_events(), 2)


class MainTest(unittest.TestCase):

  REQUIRED_ARGS = [
      '',
      '--tool_tag',
      'test_tool',
      '--start_timestamp',
      '1',
      '--end_timestamp',
      '2',
      '--exit_code',
      '0',
  ]

  def test_log_and_exit_with_missing_required_args(self):
    with self.assertLogs() as logs:
      with self.assertRaises(SystemExit) as ex:
        tool_event_logger.main(['', '--tool_tag', 'test_tool'])

    with self.subTest('Verify exception code'):
      self.assertEqual(ex.exception.code, 2)

    with self.subTest('Verify log messages'):
      self.assertIn(
          'the following arguments are required',
          '\n'.join(logs.output),
      )

  def test_log_and_exit_with_invalid_args(self):
    with self.assertLogs() as logs:
      with self.assertRaises(SystemExit) as ex:
        tool_event_logger.main(['', '--start_timestamp', 'test'])

    with self.subTest('Verify exception code'):
      self.assertEqual(ex.exception.code, 2)

    with self.subTest('Verify log messages'):
      self.assertIn(
          '--start_timestamp: invalid',
          '\n'.join(logs.output),
      )

  def test_log_and_exit_with_dry_run(self):
    with self.assertLogs(level=logging.DEBUG) as logs:
      tool_event_logger.main(self.REQUIRED_ARGS + ['--dry_run'])

    with self.subTest('Verify log messages'):
      self.assertIn('dry run', '\n'.join(logs.output))

  @mock.patch.object(clearcut_client, 'Clearcut')
  def test_log_and_exit_with_unexpected_exception(self, mock_cc):
    mock_cc.return_value = FakeClearcutClient(raise_log_exception=True)

    with self.assertLogs() as logs:
      with self.assertRaises(Exception) as ex:
        tool_event_logger.main(self.REQUIRED_ARGS)

    with self.subTest('Verify log messages'):
      self.assertIn('unexpected error', '\n'.join(logs.output))

  @mock.patch.object(clearcut_client, 'Clearcut')
  def test_success(self, mock_cc):
    mock_clear_cut_client = FakeClearcutClient()
    mock_cc.return_value = mock_clear_cut_client

    tool_event_logger.main(self.REQUIRED_ARGS)

    self.assertEqual(mock_clear_cut_client.get_number_of_sent_events(), 2)


class FakeClearcutClient:

  def __init__(self, raise_log_exception=False):
    self.pending_log_events = []
    self.sent_log_events = []
    self.raise_log_exception = raise_log_exception

  def log(self, log_event):
    if self.raise_log_exception:
      raise Exception('unknown exception')
    self.pending_log_events.append(log_event)

  def flush_events(self):
    self.sent_log_events.extend(self.pending_log_events)
    self.pending_log_events.clear()

  def get_number_of_sent_events(self):
    return len(self.sent_log_events)

  def get_last_sent_event(self):
    return self.sent_log_events[-1]


if __name__ == '__main__':
  unittest.main()
