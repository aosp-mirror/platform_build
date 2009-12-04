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
Usage: java-event-log-tags.py [-o output_file] <input_file>

Generate a java class containing constants for each of the event log
tags in the given input file.

-h to display this usage message and exit.
"""

import cStringIO
import getopt
import os
import sys

import event_log_tags

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

if len(args) != 1:
  print "need exactly one input file, not %d" % (len(args),)
  print __doc__
  sys.exit(1)

fn = args[0]
tagfile = event_log_tags.TagFile(fn)

if "java_package" not in tagfile.options:
  tagfile.AddError("java_package option not specified", linenum=0)

if tagfile.errors:
  for fn, ln, msg in tagfile.errors:
    print >> sys.stderr, "%s:%d: error: %s" % (fn, ln, msg)
  sys.exit(1)

buffer = cStringIO.StringIO()
buffer.write("/* This file is auto-generated.  DO NOT MODIFY.\n"
             " * Source file: %s\n"
             " */\n\n" % (fn,))

buffer.write("package %s;\n\n" % (tagfile.options["java_package"][0],))

basename, _ = os.path.splitext(os.path.basename(fn))
buffer.write("public class %s {\n" % (basename,))
buffer.write("  private %s() { }  // don't instantiate\n" % (basename,))

for t in tagfile.tags:
  if t.description:
    buffer.write("\n  /** %d %s %s */\n" % (t.tagnum, t.tagname, t.description))
  else:
    buffer.write("\n  /** %d %s */\n" % (t.tagnum, t.tagname))

  buffer.write("  public static final int %s = %d;\n" %
               (t.tagname.upper(), t.tagnum))
buffer.write("}\n");

event_log_tags.WriteOutput(output_file, buffer)
