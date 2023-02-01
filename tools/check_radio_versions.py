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

import sys
import os

try:
  from hashlib import sha1
except ImportError:
  from sha import sha as sha1

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--board_info_txt", nargs="?", required=True)
parser.add_argument("--board_info_check", nargs="*", required=True)
args = parser.parse_args()

if not args.board_info_txt:
  sys.exit(0)

build_info = {}
f = open(args.board_info_txt)
for line in f:
  line = line.strip()
  if line.startswith("require"):
    key, value = line.split()[1].split("=", 1)
    build_info[key] = value
f.close()

bad = False

for item in args.board_info_check:
  key, fn = item.split(":", 1)

  values = build_info.get(key, None)
  if not values:
    continue
  values = values.split("|")

  f = open(fn, "rb")
  digest = sha1(f.read()).hexdigest()
  f.close()

  versions = {}
  try:
    f = open(fn + ".sha1")
  except IOError:
    if not bad: print()
    print("*** Error opening \"%s.sha1\"; can't verify %s" % (fn, key))
    bad = True
    continue
  for line in f:
    line = line.strip()
    if not line or line.startswith("#"): continue
    h, v = line.split()
    versions[h] = v

  if digest not in versions:
    if not bad: print()
    print("*** SHA-1 hash of \"%s\" doesn't appear in \"%s.sha1\"" % (fn, fn))
    bad = True
    continue

  if versions[digest] not in values:
    if not bad: print()
    print("*** \"%s\" is version %s; not any %s allowed by \"%s\"." % (
        fn, versions[digest], key, args.board_info_txt))
    bad = True

if bad:
  print()
  sys.exit(1)
