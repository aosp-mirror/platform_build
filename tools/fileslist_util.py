#!/usr/bin/env python3
#
# Copyright (C) 2016 The Android Open Source Project
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

import argparse
import json
import sys

def PrintFileNames(path):
  with open(path) as jf:
    data = json.load(jf)
  for line in data:
    print(line["Name"])

def PrintCanonicalList(path):
  with open(path) as jf:
    data = json.load(jf)
  for line in data:
    print(f"{line['Size']:12d}  {line['Name']}")

def main():
  parser = argparse.ArgumentParser()
  parser.add_argument("-n", action="store_true",
                      help="produces list of files only")
  parser.add_argument("-c", action="store_true",
                      help="produces classic installed-files.txt")
  parser.add_argument("json_files_list")
  args = parser.parse_args()

  if args.n and args.c:
    sys.exit("Cannot specify both -n and -c")
  elif args.n:
    PrintFileNames(args.json_files_list)
  elif args.c:
    PrintCanonicalList(args.json_files_list)
  else:
    sys.exit("No conversion option specified")

if __name__ == '__main__':
  main()
