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

"""
Usage: merge-event-log-tags.py [-o output_file] [input_files...]

Merge together zero or more event-logs-tags files to produce a single
output file, stripped of comments.  Checks that no tag numbers conflict
and fails if they do.

-h to display this usage message and exit.
"""

import cStringIO
import getopt
import md5
import struct
import sys

import event_log_tags

errors = []
warnings = []

output_file = None
pre_merged_file = None

# Tags with a tag number of ? are assigned a tag in the range
# [ASSIGN_START, ASSIGN_LIMIT).
ASSIGN_START = 900000
ASSIGN_LIMIT = 1000000

try:
  opts, args = getopt.getopt(sys.argv[1:], "ho:m:")
except getopt.GetoptError, err:
  print str(err)
  print __doc__
  sys.exit(2)

for o, a in opts:
  if o == "-h":
    print __doc__
    sys.exit(2)
  elif o == "-o":
    output_file = a
  elif o == "-m":
    pre_merged_file = a
  else:
    print >> sys.stderr, "unhandled option %s" % (o,)
    sys.exit(1)

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

pre_merged_tags = {}
if pre_merged_file:
  for t in event_log_tags.TagFile(pre_merged_file).tags:
    pre_merged_tags[t.tagname] = t

for fn in args:
  tagfile = event_log_tags.TagFile(fn)

  for t in tagfile.tags:
    tagnum = t.tagnum
    tagname = t.tagname
    description = t.description

    if t.tagname in by_tagname:
      orig = by_tagname[t.tagname]

      # Allow an explicit tag number to define an implicit tag number
      if orig.tagnum is None:
        orig.tagnum = t.tagnum
      elif t.tagnum is None:
        t.tagnum = orig.tagnum

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

    if t.tagnum is not None and t.tagnum in by_tagnum:
      orig = by_tagnum[t.tagnum]

      if t.tagname != orig.tagname:
        tagfile.AddError(
            "tag number %d used by conflicting tag \"%s\" from %s:%d" %
            (t.tagnum, orig.tagname, orig.filename, orig.linenum),
            linenum=t.linenum)
        continue

    by_tagname[t.tagname] = t
    if t.tagnum is not None:
      by_tagnum[t.tagnum] = t

  errors.extend(tagfile.errors)
  warnings.extend(tagfile.warnings)

if errors:
  for fn, ln, msg in errors:
    print >> sys.stderr, "%s:%d: error: %s" % (fn, ln, msg)
  sys.exit(1)

if warnings:
  for fn, ln, msg in warnings:
    print >> sys.stderr, "%s:%d: warning: %s" % (fn, ln, msg)

# Python's hash function (a) isn't great and (b) varies between
# versions of python.  Using md5 is overkill here but is the same from
# platform to platform and speed shouldn't matter in practice.
def hashname(str):
  d = md5.md5(str).digest()[:4]
  return struct.unpack("!I", d)[0]

# Assign a tag number to all the entries that say they want one
# assigned.  We do this based on a hash of the tag name so that the
# numbers should stay relatively stable as tags are added.

# If we were provided pre-merged tags (w/ the -m option), then don't
# ever try to allocate one, just fail if we don't have a number

for name, t in sorted(by_tagname.iteritems()):
  if t.tagnum is None:
    if pre_merged_tags:
      try:
        t.tagnum = pre_merged_tags[t.tagname]
      except KeyError:
        print >> sys.stderr, ("Error: Tag number not defined for tag `%s'."
            +" Have you done a full build?") % t.tagname
        sys.exit(1)
    else:
      while True:
        x = (hashname(name) % (ASSIGN_LIMIT - ASSIGN_START - 1)) + ASSIGN_START
        if x not in by_tagnum:
          t.tagnum = x
          by_tagnum[x] = t
          break
        name = "_" + name

# by_tagnum should be complete now; we've assigned numbers to all tags.

buffer = cStringIO.StringIO()
for n, t in sorted(by_tagnum.iteritems()):
  if t.description:
    buffer.write("%d %s %s\n" % (t.tagnum, t.tagname, t.description))
  else:
    buffer.write("%d %s\n" % (t.tagnum, t.tagname))

event_log_tags.WriteOutput(output_file, buffer)
