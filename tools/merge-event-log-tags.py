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
import sys

import event_log_tags

by_tagnum = {}
errors = []
warnings = []

output_file = None

try:
  opts, args = getopt.getopt(sys.argv[1:], "ho:")
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
  else:
    print >> sys.stderr, "unhandled option %s" % (o,)
    sys.exit(1)

for fn in args:
  tagfile = event_log_tags.TagFile(fn)

  for t in tagfile.tags:
    tagnum = t.tagnum
    tagname = t.tagname
    description = t.description

    if t.tagnum in by_tagnum:
      orig = by_tagnum[t.tagnum]

      if (t.tagname == orig.tagname and
          t.description == orig.description):
        # if the name and description are identical, issue a warning
        # instead of failing (to make it easier to move tags between
        # projects without breaking the build).
        tagfile.AddWarning("tag %d \"%s\" duplicated in %s:%d" %
                           (t.tagnum, t.tagname, orig.filename, orig.linenum),
                           linenum=t.linenum)
      else:
        tagfile.AddError("tag %d used by conflicting \"%s\" from %s:%d" %
                         (t.tagnum, orig.tagname, orig.filename, orig.linenum),
                         linenum=t.linenum)
      continue

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

buffer = cStringIO.StringIO()
for n in sorted(by_tagnum):
  t = by_tagnum[n]
  if t.description:
    buffer.write("%d %s %s\n" % (t.tagnum, t.tagname, t.description))
  else:
    buffer.write("%d %s\n" % (t.tagnum, t.tagname))

event_log_tags.WriteOutput(output_file, buffer)
