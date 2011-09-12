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

import operator, os, sys

def get_file_size(path):
  st = os.lstat(path)
  return st.st_size;

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
              get_file_size(os.path.sep.join((dir, f))),
              os.path.sep.join((relative, f)),
            )
          output.append(row)
        except os.error:
          pass
  output.sort(key=operator.itemgetter(0), reverse=True)
  for row in output:
    print "%12d  %s" % row

if __name__ == '__main__':
  main(sys.argv)
