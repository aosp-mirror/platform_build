#!/usr/bin/env python
#
# Copyright (C) 2009 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import os, sys

def main(argv):
  output = []
  roots = argv[1:]
  for root in roots:
    base = len(root[:root.rfind(os.path.sep)])
    for dir, dirs, files in os.walk(root):
      relative = dir[base:]
      for f in files:
        try:
          row = (
              os.path.getsize(os.path.sep.join((dir, f))),
              os.path.sep.join((relative, f)),
            )
          output.append(row)
        except os.error:
          pass
  for row in output:
    print "%12d  %s" % row

if __name__ == '__main__':
  main(sys.argv)

