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

"""
Merge together zero or more event-logs-tags files to produce a single
output file, stripped of comments.  Checks that no tag numbers conflict
and fails if they do.
"""

from io import StringIO
import argparse
import sys

import event_log_tags

errors = []
warnings = []

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('-o', dest='output_file')
parser.add_argument('files', nargs='*')
args = parser.parse_args()

# Restrictions on tags:
#
#   Tag names must be unique.  (If the tag number and description are
#   also the same, a warning is issued instead of an error.)
#
#   Explicit tag numbers must be unique.  (If the tag name is also the
#   same, no error is issued because the above rule will issue a
#   warning or error.)

by_tagname = {}
by_tagnum = {}

for fn in args.files:
  tagfile = event_log_tags.TagFile(fn)

  for t in tagfile.tags:
    tagnum = t.tagnum
    tagname = t.tagname
    description = t.description

    if t.tagname in by_tagname:
      orig = by_tagname[t.tagname]

      if (t.tagnum == orig.tagnum and
          t.description == orig.description):
        # if the name and description are identical, issue a warning
        # instead of failing (to make it easier to move tags between
        # projects without breaking the build).
        tagfile.AddWarning("tag \"%s\" (%s) duplicated in %s:%d" %
                           (t.tagname, t.tagnum, orig.filename, orig.linenum),
                           linenum=t.linenum)
      else:
        tagfile.AddError(
            "tag name \"%s\" used by conflicting tag %s from %s:%d" %
            (t.tagname, orig.tagnum, orig.filename, orig.linenum),
            linenum=t.linenum)
      continue

    if t.tagnum in by_tagnum:
      orig = by_tagnum[t.tagnum]

      if t.tagname != orig.tagname:
        tagfile.AddError(
            "tag number %d used by conflicting tag \"%s\" from %s:%d" %
            (t.tagnum, orig.tagname, orig.filename, orig.linenum),
            linenum=t.linenum)
        continue

    by_tagname[t.tagname] = t
    by_tagnum[t.tagnum] = t

  errors.extend(tagfile.errors)
  warnings.extend(tagfile.warnings)

if errors:
  for fn, ln, msg in errors:
    print("%s:%d: error: %s" % (fn, ln, msg), file=sys.stderr)
  sys.exit(1)

if warnings:
  for fn, ln, msg in warnings:
    print("%s:%d: warning: %s" % (fn, ln, msg), file=sys.stderr)

# by_tagnum should be complete now; we've assigned numbers to all tags.

buffer = StringIO()
for n, t in sorted(by_tagnum.items()):
  if t.description:
    buffer.write("%d %s %s\n" % (t.tagnum, t.tagname, t.description))
  else:
    buffer.write("%d %s\n" % (t.tagnum, t.tagname))

event_log_tags.WriteOutput(args.output_file, buffer)
