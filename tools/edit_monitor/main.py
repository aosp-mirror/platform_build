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
import logging
import os
import signal
import sys
import tempfile

from edit_monitor import daemon_manager
from edit_monitor import edit_monitor


def create_arg_parser():
  """Creates an instance of the default arg parser."""

  parser = argparse.ArgumentParser(
      description=(
          'Monitors edits in Android source code and uploads the edit logs.'
      ),
      add_help=True,
      formatter_class=argparse.RawDescriptionHelpFormatter,
  )

  parser.add_argument(
      '--path',
      type=str,
      required=True,
      help='Root path to monitor the edit events.',
  )

  parser.add_argument(
      '--dry_run',
      action='store_true',
      help='Dry run the edit monitor. This starts the edit monitor process without actually send the edit logs to clearcut.',
  )

  parser.add_argument(
      '--force_cleanup',
      action='store_true',
      help=(
          'Instead of start a new edit monitor, force stop all existing edit'
          ' monitors in the system. This option is only used in emergent cases'
          ' when we want to prevent user damage by the edit monitor.'
      ),
  )

  return parser


def configure_logging():
  root_logging_dir = tempfile.mkdtemp(prefix='edit_monitor_')
  _, log_path = tempfile.mkstemp(dir=root_logging_dir, suffix='.log')

  log_fmt = '%(asctime)s %(filename)s:%(lineno)s:%(levelname)s: %(message)s'
  date_fmt = '%Y-%m-%d %H:%M:%S'
  logging.basicConfig(
      filename=log_path, level=logging.DEBUG, format=log_fmt, datefmt=date_fmt
  )
  # Filter out logs from inotify_buff to prevent log pollution.
  logging.getLogger('watchdog.observers.inotify_buffer').addFilter(
      lambda record: record.filename != 'inotify_buffer.py')
  print(f'logging to file {log_path}')


def term_signal_handler(_signal_number, _frame):
  logging.info('Process %d received SIGTERM, Terminating...', os.getpid())
  sys.exit(0)


def main(argv: list[str]):
  args = create_arg_parser().parse_args(argv[1:])
  if args.dry_run:
    logging.info('This is a dry run.')
  dm = daemon_manager.DaemonManager(
      binary_path=argv[0],
      daemon_target=edit_monitor.start,
      daemon_args=(args.path, args.dry_run),
  )

  if args.force_cleanup:
    dm.cleanup()

  try:
    dm.start()
    dm.monitor_daemon()
  except Exception:
    logging.exception('Unexpected exception raised when run daemon.')
  finally:
    dm.stop()


if __name__ == '__main__':
  signal.signal(signal.SIGTERM, term_signal_handler)
  configure_logging()
  main(sys.argv)
