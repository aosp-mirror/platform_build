# Copyright (C) 2009 The Android Open Source Project
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

"""A module for reading and parsing event-log-tags files."""

import dataclasses
import re
import sys
from typing import Optional

@dataclasses.dataclass
class Tag:
  tagnum: int
  tagname: str
  description: Optional[str]
  filename: str
  linenum: int


class TagFile:
  """Read an input event-log-tags file."""
  def AddError(self, msg, linenum=None):
    if linenum is None:
      linenum = self.linenum
    self.errors.append((self.filename, linenum, msg))

  def AddWarning(self, msg, linenum=None):
    if linenum is None:
      linenum = self.linenum
    self.warnings.append((self.filename, linenum, msg))

  def __init__(self, filename, file_object=None):
    """'filename' is the name of the file (included in any error
    messages).  If 'file_object' is None, 'filename' will be opened
    for reading."""
    self.errors = []
    self.warnings = []
    self.tags = []
    self.options = {}

    self.filename = filename
    self.linenum = 0

    if file_object is None:
      try:
        file_object = open(filename, "rb")
      except (IOError, OSError) as e:
        self.AddError(str(e))
        return

    try:
      for self.linenum, line in enumerate(file_object):
        line = line.decode('utf-8')
        self.linenum += 1
        line = re.sub('#.*$', '', line) # strip trailing comments
        line = line.strip()
        if not line: continue
        parts = re.split(r"\s+", line, 2)

        if len(parts) < 2:
          self.AddError("failed to parse \"%s\"" % (line,))
          continue

        if parts[0] == "option":
          self.options[parts[1]] = parts[2:]
          continue

        try:
          tag = int(parts[0])
        except ValueError:
          self.AddError("\"%s\" isn't an integer tag" % (parts[0],))
          continue

        tagname = parts[1]
        if len(parts) == 3:
          description = parts[2]
        else:
          description = None

        if description:
          # EventLog.java checks that the description field is
          # surrounded by parens, so we should too (to avoid a runtime
          # crash from badly-formatted descriptions).
          if not re.match(r"\(.*\)\s*$", description):
            self.AddError("tag \"%s\" has unparseable description" % (tagname,))
            continue

        self.tags.append(Tag(tag, tagname, description,
                             self.filename, self.linenum))
    except (IOError, OSError) as e:
      self.AddError(str(e))


def BooleanFromString(s):
  """Interpret 's' as a boolean and return its value.  Raise
  ValueError if it's not something we can interpret as true or
  false."""
  s = s.lower()
  if s in ("true", "t", "1", "on", "yes", "y"):
    return True
  if s in ("false", "f", "0", "off", "no", "n"):
    return False
  raise ValueError("'%s' not a valid boolean" % (s,))


def WriteOutput(output_file, data):
  """Write 'data' to the given output filename (which may be None to
  indicate stdout).  Emit an error message and die on any failure.
  'data' may be a string or a StringIO object."""
  if not isinstance(data, str):
    data = data.getvalue()
  try:
    if output_file is None:
      out = sys.stdout
      output_file = "<stdout>"
    else:
      out = open(output_file, "w")
    out.write(data)
    out.close()
  except (IOError, OSError) as e:
    print("failed to write %s: %s" % (output_file, e), file=sys.stderr)
    sys.exit(1)
