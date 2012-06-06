#!/usr/bin/env python
#
# Copyright (C) 2012 The Android Open Source Project
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

"""
Prints to stdout the package names that have overlay changes between
current_overlays.txt and previous_overlays.txt.

Usage: diff_package_overlays.py <current_packages.txt> <current_overlays.txt> <previous_overlays.txt>
current_packages.txt contains all package names separated by space in the current build.
This script modfies current_packages.txt if necessary: if there is a package in
previous_overlays.txt but absent from current_packages.txt, we copy that line
from previous_overlays.txt over to current_packages.txt. Usually that means we
just don't care that package in the current build (for example we are switching
from a full build to a partial build with mm/mmm), and we should carry on the
previous overlay config so current_overlays.txt always reflects the current
status of the entire tree.

Format of current_overlays.txt and previous_overlays.txt:
  <package_name> <resource_overlay> [resource_overlay ...]
  <package_name> <resource_overlay> [resource_overlay ...]
  ...
"""

import sys

def main(argv):
  if len(argv) != 4:
    print >> sys.stderr, __doc__
    sys.exit(1)

  f = open(argv[1])
  all_packages = set(f.read().split())
  f.close()

  def load_overlay_config(filename):
    f = open(filename)
    result = {}
    for line in f:
      line = line.strip()
      if not line or line.startswith("#"):
        continue
      words = line.split()
      result[words[0]] = " ".join(words[1:])
    f.close()
    return result

  current_overlays = load_overlay_config(argv[2])
  previous_overlays = load_overlay_config(argv[3])

  result = []
  carryon = []
  for p in current_overlays:
    if p not in previous_overlays:
      result.append(p)
    elif current_overlays[p] != previous_overlays[p]:
      result.append(p)
  for p in previous_overlays:
    if p not in current_overlays:
      if p in all_packages:
        # overlay changed
        result.append(p)
      else:
        # we don't build p in the current build.
        carryon.append(p)

  # Add carryon to the current overlay config file.
  if carryon:
    f = open(argv[2], "a")
    for p in carryon:
      f.write(p + " " + previous_overlays[p] + "\n")
    f.close()

  # Print out the package names that have overlay change.
  for r in result:
    print r

if __name__ == "__main__":
  main(sys.argv)
