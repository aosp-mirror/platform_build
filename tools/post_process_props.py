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

import sys

# Usage: post_process_props.py file.prop [blacklist_key, ...]
# Blacklisted keys are removed from the property file, if present

# See PROP_VALUE_MAX in system_properties.h.
# The constant in system_properties.h includes the terminating NUL,
# so we decrease the value by 1 here.
PROP_VALUE_MAX = 91

# Put the modifications that you need to make into the */build.prop into this
# function.
def mangle_build_prop(prop_list):
  # If ro.debuggable is 1, then enable adb on USB by default
  # (this is for userdebug builds)
  if prop_list.get("ro.debuggable") == "1":
    val = prop_list.get("persist.sys.usb.config")
    if "adb" not in val:
      if val == "":
        val = "adb"
      else:
        val = val + ",adb"
      prop_list.put("persist.sys.usb.config", val)
  # UsbDeviceManager expects a value here.  If it doesn't get it, it will
  # default to "adb". That might not the right policy there, but it's better
  # to be explicit.
  if not prop_list.get("persist.sys.usb.config"):
    prop_list.put("persist.sys.usb.config", "none");

def validate(prop_list):
  """Validate the properties.

  Returns:
    True if nothing is wrong.
  """
  check_pass = True
  for p in prop_list.get_all():
    if len(p.value) > PROP_VALUE_MAX and not p.name.startswith("ro."):
      check_pass = False
      sys.stderr.write("error: %s cannot exceed %d bytes: " %
                       (p.name, PROP_VALUE_MAX))
      sys.stderr.write("%s (%d)\n" % (p.value, len(p.value)))
  return check_pass

class Prop:

  def __init__(self, name, value, comment=None):
    self.name = name.strip()
    self.value = value.strip()
    self.comment = comment

  @staticmethod
  def from_line(line):
    line = line.rstrip('\n')
    if line.startswith("#"):
      return Prop("", "", line)
    elif "=" in line:
      name, value = line.split("=", 1)
      return Prop(name, value)
    else:
      # don't fail on invalid line
      # TODO(jiyong) make this a hard error
      return Prop("", "", line)

  def is_comment(self):
    return self.comment != None

  def __str__(self):
    if self.is_comment():
      return self.comment
    else:
      return self.name + "=" + self.value

class PropList:

  def __init__(self, filename):
    with open(filename) as f:
      self.props = [Prop.from_line(l)
                    for l in f.readlines() if l.strip() != ""]

  def get_all(self):
    return [p for p in self.props if not p.is_comment()]

  def get(self, name):
    return next((p.value for p in self.props if p.name == name), "")

  def put(self, name, value):
    index = next((i for i,p in enumerate(self.props) if p.name == name), -1)
    if index == -1:
      self.props.append(Prop(name, value))
    else:
      self.props[index].value = value

  def delete(self, name):
    self.props = [p for p in self.props if p.name != name]

  def write(self, filename):
    with open(filename, 'w+') as f:
      for p in self.props:
        f.write(str(p) + "\n")

def main(argv):
  filename = argv[1]

  if not filename.endswith("/build.prop"):
    sys.stderr.write("bad command line: " + str(argv) + "\n")
    sys.exit(1)

  props = PropList(filename)
  mangle_build_prop(props)
  if not validate(props):
    sys.exit(1)

  # Drop any blacklisted keys
  for key in argv[2:]:
    props.delete(key)

  props.write(filename)

if __name__ == "__main__":
  main(sys.argv)
