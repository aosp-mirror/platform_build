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
Generate a java class containing constants for each of the event log
tags in the given input file.
"""

from io import StringIO
import argparse
import os
import os.path
import re
import sys

import event_log_tags

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('-o', dest='output_file')
parser.add_argument('file')
args = parser.parse_args()

fn = args.file
tagfile = event_log_tags.TagFile(fn)

if "java_package" not in tagfile.options:
  tagfile.AddError("java_package option not specified", linenum=0)

hide = True
if "javadoc_hide" in tagfile.options:
  hide = event_log_tags.BooleanFromString(tagfile.options["javadoc_hide"][0])

if tagfile.errors:
  for fn, ln, msg in tagfile.errors:
    print("%s:%d: error: %s" % (fn, ln, msg), file=sys.stderr)
  sys.exit(1)

buffer = StringIO()
buffer.write("/* This file is auto-generated.  DO NOT MODIFY.\n"
             " * Source file: %s\n"
             " */\n\n" % (fn,))

# .rstrip(";") to avoid an empty top-level statement errorprone error
buffer.write("package %s;\n\n" % (tagfile.options["java_package"][0].rstrip(";"),))

basename, _ = os.path.splitext(os.path.basename(fn))

if hide:
  buffer.write("/**\n"
               " * @hide\n"
               " */\n")
buffer.write("public class %s {\n" % (basename,))
buffer.write("  private %s() { }  // don't instantiate\n" % (basename,))

for t in tagfile.tags:
  if t.description:
    buffer.write("\n  /** %d %s %s */\n" % (t.tagnum, t.tagname, t.description))
  else:
    buffer.write("\n  /** %d %s */\n" % (t.tagnum, t.tagname))

  buffer.write("  public static final int %s = %d;\n" %
               (t.tagname.upper(), t.tagnum))

keywords = frozenset(["abstract", "continue", "for", "new", "switch", "assert",
                      "default", "goto", "package", "synchronized", "boolean",
                      "do", "if", "private", "this", "break", "double",
                      "implements", "protected", "throw", "byte", "else",
                      "import", "public", "throws", "case", "enum",
                      "instanceof", "return", "transient", "catch", "extends",
                      "int", "short", "try", "char", "final", "interface",
                      "static", "void", "class", "finally", "long", "strictfp",
                      "volatile", "const", "float", "native", "super", "while"])

def javaName(name):
  out = name[0].lower() + re.sub(r"[^A-Za-z0-9]", "", name.title())[1:]
  if out in keywords:
    out += "_"
  return out

javaTypes = ["ERROR", "int", "long", "String", "Object[]", "float"]
for t in tagfile.tags:
  methodName = javaName("write_" + t.tagname)
  if t.description:
    fn_args = [arg.strip("() ").split("|") for arg in t.description.split(",")]
  else:
    fn_args = []
  argTypesNames = ", ".join([javaTypes[int(arg[1])] + " " + javaName(arg[0]) for arg in fn_args])
  argNames = "".join([", " + javaName(arg[0]) for arg in fn_args])
  buffer.write("\n  public static void %s(%s) {" % (methodName, argTypesNames))
  buffer.write("\n    android.util.EventLog.writeEvent(%s%s);" % (t.tagname.upper(), argNames))
  buffer.write("\n  }\n")


buffer.write("}\n");

output_dir = os.path.dirname(args.output_file)
if not os.path.exists(output_dir):
  os.makedirs(output_dir)

event_log_tags.WriteOutput(args.output_file, buffer)
