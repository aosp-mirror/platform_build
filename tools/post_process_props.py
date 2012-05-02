#!/usr/bin/env python
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

# Put the modifications that you need to make into the /system/build.prop into this
# function. The prop object has get(name) and put(name,value) methods.
def mangle_build_prop(prop):
  pass

# Put the modifications that you need to make into the /system/build.prop into this
# function. The prop object has get(name) and put(name,value) methods.
def mangle_default_prop(prop):
  # If ro.debuggable is 1, then enable adb on USB by default
  # (this is for userdebug builds)
  if prop.get("ro.debuggable") == "1":
    val = prop.get("persist.sys.usb.config")
    if val == "":
      val = "adb"
    else:
      val = val + ",adb"
    prop.put("persist.sys.usb.config", val)
  # UsbDeviceManager expects a value here.  If it doesn't get it, it will
  # default to "adb". That might not the right policy there, but it's better
  # to be explicit.
  if not prop.get("persist.sys.usb.config"):
    prop.put("persist.sys.usb.config", "none");

class PropFile:
  def __init__(self, lines):
    self.lines = [s[:-1] for s in lines]

  def get(self, name):
    key = name + "="
    for line in self.lines:
      if line.startswith(key):
        return line[len(key):]
    return ""

  def put(self, name, value):
    key = name + "="
    for i in range(0,len(self.lines)):
      if self.lines[i].startswith(key):
        self.lines[i] = key + value
        return
    self.lines.append(key + value)

  def write(self, f):
    f.write("\n".join(self.lines))
    f.write("\n")

def main(argv):
  filename = argv[1]
  f = open(filename)
  lines = f.readlines()
  f.close()

  properties = PropFile(lines)
  if filename.endswith("/build.prop"):
    mangle_build_prop(properties)
  elif filename.endswith("/default.prop"):
    mangle_default_prop(properties)
  else:
    sys.stderr.write("bad command line: " + str(argv) + "\n")
    sys.exit(1)

  f = open(filename, 'w+')
  properties.write(f)
  f.close()

if __name__ == "__main__":
  main(sys.argv)
