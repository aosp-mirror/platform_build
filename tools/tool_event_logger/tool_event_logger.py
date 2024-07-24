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


import argparse
import datetime
import getpass
import logging
import os
import platform
import sys
import tempfile
import uuid

from atest.metrics import clearcut_client
from atest.proto import clientanalytics_pb2
from proto import tool_event_pb2

LOG_SOURCE = 2395


class ToolEventLogger:
  """Logs tool events to Sawmill through Clearcut."""

  def __init__(
      self,
      tool_tag: str,
      invocation_id: str,
      user_name: str,
      host_name: str,
      source_root: str,
      platform_version: str,
      python_version: str,
      client: clearcut_client.Clearcut,
  ):
    self.tool_tag = tool_tag
    self.invocation_id = invocation_id
    self.user_name = user_name
    self.host_name = host_name
    self.source_root = source_root
    self.platform_version = platform_version
    self.python_version = python_version
    self._clearcut_client = client

  @classmethod
  def create(cls, tool_tag: str):
    return ToolEventLogger(
        tool_tag=tool_tag,
        invocation_id=str(uuid.uuid4()),
        user_name=getpass.getuser(),
        host_name=platform.node(),
        source_root=os.environ.get('ANDROID_BUILD_TOP', ''),
        platform_version=platform.platform(),
        python_version=platform.python_version(),
        client=clearcut_client.Clearcut(LOG_SOURCE),
    )

  def __enter__(self):
    return self

  def __exit__(self, exc_type, exc_val, exc_tb):
    self.flush()

  def log_invocation_started(self, event_time: datetime, command_args: str):
    """Creates an event log with invocation started info."""
    event = self._create_tool_event()
    event.invocation_started.CopyFrom(
        tool_event_pb2.ToolEvent.InvocationStarted(
            command_args=command_args,
            os=f'{self.platform_version}:{self.python_version}',
        )
    )

    logging.debug('Log invocation_started: %s', event)
    self._log_clearcut_event(event, event_time)

  def log_invocation_stopped(
      self,
      event_time: datetime,
      exit_code: int,
      exit_log: str,
  ):
    """Creates an event log with invocation stopped info."""
    event = self._create_tool_event()
    event.invocation_stopped.CopyFrom(
        tool_event_pb2.ToolEvent.InvocationStopped(
            exit_code=exit_code,
            exit_log=exit_log,
        )
    )

    logging.debug('Log invocation_stopped: %s', event)
    self._log_clearcut_event(event, event_time)

  def flush(self):
    """Sends all batched events to Clearcut."""
    logging.debug('Sending events to Clearcut.')
    self._clearcut_client.flush_events()

  def _create_tool_event(self):
    return tool_event_pb2.ToolEvent(
        tool_tag=self.tool_tag,
        invocation_id=self.invocation_id,
        user_name=self.user_name,
        host_name=self.host_name,
        source_root=self.source_root,
    )

  def _log_clearcut_event(
      self, tool_event: tool_event_pb2.ToolEvent, event_time: datetime
  ):
    log_event = clientanalytics_pb2.LogEvent(
        event_time_ms=int(event_time.timestamp() * 1000),
        source_extension=tool_event.SerializeToString(),
    )
    self._clearcut_client.log(log_event)


class ArgumentParserWithLogging(argparse.ArgumentParser):

  def error(self, message):
    logging.error('Failed to parse args with error: %s', message)
    super().error(message)


def create_arg_parser():
  """Creates an instance of the default ToolEventLogger arg parser."""

  parser = ArgumentParserWithLogging(
      description='Build and upload logs for Android dev tools',
      add_help=True,
      formatter_class=argparse.RawDescriptionHelpFormatter,
  )

  parser.add_argument(
      '--tool_tag',
      type=str,
      required=True,
      help='Name of the tool.',
  )

  parser.add_argument(
      '--start_timestamp',
      type=lambda ts: datetime.datetime.fromtimestamp(float(ts)),
      required=True,
      help=(
          'Timestamp when the tool starts. The timestamp should have the format'
          '%s.%N which represents the seconds elapses since epoch.'
      ),
  )

  parser.add_argument(
      '--end_timestamp',
      type=lambda ts: datetime.datetime.fromtimestamp(float(ts)),
      required=True,
      help=(
          'Timestamp when the tool exits. The timestamp should have the format'
          '%s.%N which represents the seconds elapses since epoch.'
      ),
  )

  parser.add_argument(
      '--tool_args',
      type=str,
      help='Parameters that are passed to the tool.',
  )

  parser.add_argument(
      '--exit_code',
      type=int,
      required=True,
      help='Tool exit code.',
  )

  parser.add_argument(
      '--exit_log',
      type=str,
      help='Logs when tool exits.',
  )

  parser.add_argument(
      '--dry_run',
      action='store_true',
      help='Dry run the tool event logger if set.',
  )

  return parser


def configure_logging():
  root_logging_dir = tempfile.mkdtemp(prefix='tool_event_logger_')

  log_fmt = '%(asctime)s %(filename)s:%(lineno)s:%(levelname)s: %(message)s'
  date_fmt = '%Y-%m-%d %H:%M:%S'
  _, log_path = tempfile.mkstemp(dir=root_logging_dir, suffix='.log')

  logging.basicConfig(
      filename=log_path, level=logging.DEBUG, format=log_fmt, datefmt=date_fmt
  )


def main(argv: list[str]):
  args = create_arg_parser().parse_args(argv[1:])

  if args.dry_run:
    logging.debug('This is a dry run.')
    return

  try:
    with ToolEventLogger.create(args.tool_tag) as logger:
      logger.log_invocation_started(args.start_timestamp, args.tool_args)
      logger.log_invocation_stopped(
          args.end_timestamp, args.exit_code, args.exit_log
      )
  except Exception as e:
    logging.error('Log failed with unexpected error: %s', e)
    raise


if __name__ == '__main__':
  configure_logging()
  main(sys.argv)
