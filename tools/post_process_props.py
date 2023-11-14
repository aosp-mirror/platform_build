#!/usr/bin/env python3
#
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

import argparse
import sys

# Usage: post_process_props.py file.prop [disallowed_key, ...]
# Disallowed keys are removed from the property file, if present

# See PROP_VALUE_MAX in system_properties.h.
# The constant in system_properties.h includes the terminating NUL,
# so we decrease the value by 1 here.
PROP_VALUE_MAX = 91

# Put the modifications that you need to make into the */build.prop into this
# function.
def mangle_build_prop(prop_list):
  # If ro.debuggable is 1, then enable adb on USB by default
  # (this is for userdebug builds)
  if prop_list.get_value("ro.debuggable") == "1":
    val = prop_list.get_value("persist.sys.usb.config")
    if "adb" not in val:
      if val == "":
        val = "adb"
      else:
        val = val + ",adb"
      prop_list.put("persist.sys.usb.config", val)

def validate_grf_props(prop_list):
  """Validate GRF properties if exist.

  If ro.board.first_api_level is defined, check if its value is valid.

  Returns:
    True if the GRF properties are valid.
  """
  grf_api_level = prop_list.get_value("ro.board.first_api_level")
  board_api_level = prop_list.get_value("ro.board.api_level")

  if grf_api_level and board_api_level:
    grf_api_level = int(grf_api_level)
    board_api_level = int(board_api_level)
    if board_api_level < grf_api_level:
      sys.stderr.write("error: ro.board.api_level(%d) must not be less than "
                       "ro.board.first_api_level(%d)\n"
                       % (board_api_level, grf_api_level))
      return False

  return True

def validate(prop_list):
  """Validate the properties.

  If the value of a sysprop exceeds the max limit (91), it's an error, unless
  the sysprop is a read-only one.

  Checks if there is no optional prop assignments.

  Returns:
    True if nothing is wrong.
  """
  check_pass = True
  for p in prop_list.get_all_props():
    if len(p.value) > PROP_VALUE_MAX and not p.name.startswith("ro."):
      check_pass = False
      sys.stderr.write("error: %s cannot exceed %d bytes: " %
                       (p.name, PROP_VALUE_MAX))
      sys.stderr.write("%s (%d)\n" % (p.value, len(p.value)))

    if p.is_optional():
      check_pass = False
      sys.stderr.write("error: found unresolved optional prop assignment:\n")
      sys.stderr.write(str(p) + "\n")

  return check_pass

def override_optional_props(prop_list, allow_dup=False):
  """Override a?=b with a=c, if the latter exists

  Overriding is done by deleting a?=b
  When there are a?=b and a?=c, then only the last one survives
  When there are a=b and a=c, then it's an error.

  Returns:
    True if the override was successful
  """
  success = True
  for name in prop_list.get_all_names():
    props = prop_list.get_props(name)
    optional_props = [p for p in props if p.is_optional()]
    overriding_props = [p for p in props if not p.is_optional()]
    if len(overriding_props) > 1:
      # duplicated props are allowed when the all have the same value
      if all(overriding_props[0].value == p.value for p in overriding_props):
        for p in optional_props:
          p.delete("overridden by %s" % str(overriding_props[0]))
        continue
      # or if dup is explicitly allowed for compat reason
      if allow_dup:
        # this could left one or more optional props unresolved.
        # Convert them into non-optional because init doesn't understand ?=
        # syntax
        for p in optional_props:
          p.optional = False
        continue

      success = False
      sys.stderr.write("error: found duplicate sysprop assignments:\n")
      for p in overriding_props:
        sys.stderr.write("%s\n" % str(p))
    elif len(overriding_props) == 1:
      for p in optional_props:
        p.delete("overridden by %s" % str(overriding_props[0]))
    else:
      if len(optional_props) > 1:
        for p in optional_props[:-1]:
          p.delete("overridden by %s" % str(optional_props[-1]))
      # Make the last optional one as non-optional
      optional_props[-1].optional = False

  return success

class Prop:

  def __init__(self, name, value, optional=False, comment=None):
    self.name = name.strip()
    self.value = value.strip()
    if comment != None:
      self.comments = [comment]
    else:
      self.comments = []
    self.optional = optional

  @staticmethod
  def from_line(line):
    line = line.rstrip('\n')
    if line.startswith("#"):
      return Prop("", "", comment=line)
    elif "?=" in line:
      name, value = line.split("?=", 1)
      return Prop(name, value, optional=True)
    elif "=" in line:
      name, value = line.split("=", 1)
      return Prop(name, value, optional=False)
    else:
      # don't fail on invalid line
      # TODO(jiyong) make this a hard error
      return Prop("", "", comment=line)

  def is_comment(self):
    return bool(self.comments and not self.name)

  def is_optional(self):
    return (not self.is_comment()) and self.optional

  def make_as_comment(self):
    # Prepend "#" to the last line which is the prop assignment
    if not self.is_comment():
      assignment = str(self).rsplit("\n", 1)[-1]
      self.comments.append("#" + assignment)
      self.name = ""
      self.value = ""

  def delete(self, reason):
    self.comments.append("# Removed by post_process_props.py because " + reason)
    self.make_as_comment()

  def __str__(self):
    assignment = []
    if not self.is_comment():
      operator = "?=" if self.is_optional() else "="
      assignment.append(self.name + operator + self.value)
    return "\n".join(self.comments + assignment)

class PropList:

  def __init__(self, filename):
    with open(filename) as f:
      self.props = [Prop.from_line(l)
                    for l in f.readlines() if l.strip() != ""]

  def get_all_props(self):
    return [p for p in self.props if not p.is_comment()]

  def get_all_names(self):
    return set([p.name for p in self.get_all_props()])

  def get_props(self, name):
    return [p for p in self.get_all_props() if p.name == name]

  def get_value(self, name):
    # Caution: only the value of the first sysprop having the name is returned.
    return next((p.value for p in self.props if p.name == name), "")

  def put(self, name, value):
    # Note: when there is an optional prop for the name, its value isn't changed.
    # Instead a new non-optional prop is appended, which will override the
    # optional prop. Otherwise, the new value might be overridden by an existing
    # non-optional prop of the same name.
    index = next((i for i,p in enumerate(self.props)
                  if p.name == name and not p.is_optional()), -1)
    if index == -1:
      self.props.append(Prop(name, value,
                             comment="# Auto-added by post_process_props.py"))
    else:
      self.props[index].comments.append(
          "# Value overridden by post_process_props.py. Original value: %s" %
          self.props[index].value)
      self.props[index].value = value

  def write(self, filename):
    with open(filename, 'w+') as f:
      for p in self.props:
        f.write(str(p) + "\n")

def main(argv):
  parser = argparse.ArgumentParser(description="Post-process build.prop file")
  parser.add_argument("--allow-dup", dest="allow_dup", action="store_true",
                      default=False)
  parser.add_argument("filename")
  parser.add_argument("disallowed_keys", metavar="KEY", type=str, nargs="*")
  parser.add_argument("--sdk-version", type=int, required=True)
  args = parser.parse_args()

  if not args.filename.endswith("/build.prop"):
    sys.stderr.write("bad command line: " + str(argv) + "\n")
    sys.exit(1)

  props = PropList(args.filename)
  mangle_build_prop(props)
  if not override_optional_props(props, args.allow_dup):
    sys.exit(1)
  if not validate_grf_props(props):
    sys.exit(1)
  if not validate(props):
    sys.exit(1)

  # Drop any disallowed keys
  for key in args.disallowed_keys:
    for p in props.get_props(key):
      p.delete("%s is a disallowed key" % key)

  props.write(args.filename)

if __name__ == "__main__":
  main(sys.argv)
