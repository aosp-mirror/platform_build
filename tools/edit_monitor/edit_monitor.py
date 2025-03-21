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


import getpass
import logging
import multiprocessing.connection
import os
import pathlib
import platform
import threading
import time

from atest.metrics import clearcut_client
from atest.proto import clientanalytics_pb2
from proto import edit_event_pb2
from watchdog.events import FileSystemEvent
from watchdog.events import PatternMatchingEventHandler
from watchdog.observers import Observer

# Enum of the Clearcut log source defined under
# /google3/wireless/android/play/playlog/proto/log_source_enum.proto
LOG_SOURCE = 2524
DEFAULT_FLUSH_INTERVAL_SECONDS = 5
DEFAULT_SINGLE_EVENTS_SIZE_THRESHOLD = 100


class ClearcutEventHandler(PatternMatchingEventHandler):

  def __init__(
      self,
      path: str,
      flush_interval_sec: int,
      single_events_size_threshold: int,
      is_dry_run: bool = False,
      cclient: clearcut_client.Clearcut | None = None,
  ):

    super().__init__(patterns=["*"], ignore_directories=True)
    self.root_monitoring_path = path
    self.flush_interval_sec = flush_interval_sec
    self.single_events_size_threshold = single_events_size_threshold
    self.is_dry_run = is_dry_run
    self.cclient = cclient or clearcut_client.Clearcut(LOG_SOURCE)

    self.user_name = getpass.getuser()
    self.host_name = platform.node()
    self.source_root = os.environ.get("ANDROID_BUILD_TOP", "")

    self.pending_events = []
    self._scheduled_log_thread = None
    self._pending_events_lock = threading.Lock()

  def on_moved(self, event: FileSystemEvent):
    self._log_edit_event(event, edit_event_pb2.EditEvent.MOVE)

  def on_created(self, event: FileSystemEvent):
    self._log_edit_event(event, edit_event_pb2.EditEvent.CREATE)

  def on_deleted(self, event: FileSystemEvent):
    self._log_edit_event(event, edit_event_pb2.EditEvent.DELETE)

  def on_modified(self, event: FileSystemEvent):
    self._log_edit_event(event, edit_event_pb2.EditEvent.MODIFY)

  def flushall(self):
    logging.info("flushing all pending events.")
    if self._scheduled_log_thread:
      logging.info("canceling log thread")
      self._scheduled_log_thread.cancel()
      self._scheduled_log_thread = None

    self._log_clearcut_events()
    self.cclient.flush_events()

  def _log_edit_event(
      self, event: FileSystemEvent, edit_type: edit_event_pb2.EditEvent.EditType
  ):
    try:
      event_time = time.time()

      if self._is_hidden_file(pathlib.Path(event.src_path)):
        logging.debug("ignore hidden file: %s.", event.src_path)
        return

      if not self._is_under_git_project(pathlib.Path(event.src_path)):
        logging.debug(
            "ignore file %s which does not belong to a git project",
            event.src_path,
        )
        return

      logging.info("%s: %s", event.event_type, event.src_path)

      event_proto = edit_event_pb2.EditEvent(
          user_name=self.user_name,
          host_name=self.host_name,
          source_root=self.source_root,
      )
      event_proto.single_edit_event.CopyFrom(
          edit_event_pb2.EditEvent.SingleEditEvent(
              file_path=event.src_path, edit_type=edit_type
          )
      )
      with self._pending_events_lock:
        self.pending_events.append((event_proto, event_time))
        if not self._scheduled_log_thread:
          logging.debug(
              "Scheduling thread to run in %d seconds", self.flush_interval_sec
          )
          self._scheduled_log_thread = threading.Timer(
              self.flush_interval_sec, self._log_clearcut_events
          )
          self._scheduled_log_thread.start()

    except Exception:
      logging.exception("Failed to log edit event.")

  def _is_hidden_file(self, file_path: pathlib.Path) -> bool:
    return any(
        part.startswith(".")
        for part in file_path.relative_to(self.root_monitoring_path).parts
    )

  def _is_under_git_project(self, file_path: pathlib.Path) -> bool:
    root_path = pathlib.Path(self.root_monitoring_path).resolve()
    return any(
        root_path.joinpath(dir).joinpath('.git').exists()
        for dir in file_path.relative_to(root_path).parents
    )

  def _log_clearcut_events(self):
    with self._pending_events_lock:
      self._scheduled_log_thread = None
      edit_events = self.pending_events
      self.pending_events = []

    pending_events_size = len(edit_events)
    if pending_events_size > self.single_events_size_threshold:
      logging.info(
          "got %d events in %d seconds, sending aggregated events instead",
          pending_events_size,
          self.flush_interval_sec,
      )
      aggregated_event_time = edit_events[0][1]
      aggregated_event_proto = edit_event_pb2.EditEvent(
          user_name=self.user_name,
          host_name=self.host_name,
          source_root=self.source_root,
      )
      aggregated_event_proto.aggregated_edit_event.CopyFrom(
          edit_event_pb2.EditEvent.AggregatedEditEvent(
              num_edits=pending_events_size
          )
      )
      edit_events = [(aggregated_event_proto, aggregated_event_time)]

    if self.is_dry_run:
      logging.info("Sent %d edit events in dry run.", len(edit_events))
      return

    for event_proto, event_time in edit_events:
      log_event = clientanalytics_pb2.LogEvent(
          event_time_ms=int(event_time * 1000),
          source_extension=event_proto.SerializeToString(),
      )
      self.cclient.log(log_event)

    logging.info("sent %d edit events", len(edit_events))


def start(
    path: str,
    is_dry_run: bool = False,
    flush_interval_sec: int = DEFAULT_FLUSH_INTERVAL_SECONDS,
    single_events_size_threshold: int = DEFAULT_SINGLE_EVENTS_SIZE_THRESHOLD,
    cclient: clearcut_client.Clearcut | None = None,
    pipe_sender: multiprocessing.connection.Connection | None = None,
):
  """Method to start the edit monitor.

  This is the entry point to start the edit monitor as a subprocess of
  the daemon manager.

  params:
    path: The root path to monitor
    cclient: The clearcut client to send the edit logs.
    conn: the sender of the pipe to communicate with the deamon manager.
  """
  event_handler = ClearcutEventHandler(
      path, flush_interval_sec, single_events_size_threshold, is_dry_run, cclient)
  observer = Observer()

  logging.info("Starting observer on path %s.", path)
  observer.schedule(event_handler, path, recursive=True)
  observer.start()
  logging.info("Observer started.")
  if pipe_sender:
    pipe_sender.send("Observer started.")

  try:
    while True:
      time.sleep(1)
  finally:
    event_handler.flushall()
    observer.stop()
    observer.join()
    if pipe_sender:
      pipe_sender.close()
