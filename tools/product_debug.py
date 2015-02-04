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

import os
import re
import sys

def break_lines(key, val):
  # these don't get split
  if key in ("PRODUCT_MODEL"):
    return (key,val)
  return (key, "\n".join(val.split()))

def split_line(line):
  words = line.split("=", 1)
  if len(words) == 1:
    return (words[0], "")
  else:
    return (words[0], words[1])

def sort_lines(text):
  lines = text.split()
  lines.sort()
  return "\n".join(lines)

def parse_variables(lines):
  return [split_line(line) for line in lines if line.strip()]

def render_variables(variables):
  variables = dict(variables)
  del variables["FILE"]
  variables = list(variables.iteritems())
  variables.sort(lambda a, b: cmp(a[0], b[0]))
  return ("<table id='variables'>"
      + "\n".join([ "<tr><th>%(key)s</th><td>%(val)s</td></tr>" % { "key": key, "val": val }
        for key,val in variables])
      +"</table>")

def linkify_inherit(variables, text, func_name):
  groups = re.split("(\\$\\(call " + func_name + ",.*\\))", text)
  result = ""
  for i in range(0,len(groups)/2):
    i = i * 2
    result = result + groups[i]
    s = groups[i+1]
    href = s.split(",", 1)[1].strip()[:-1]
    href = href.replace("$(SRC_TARGET_DIR)", "build/target")
    href = ("../" * variables["FILE"].count("/")) + href + ".html"
    result = result + "<a href=\"%s\">%s</a>" % (href,s)
  result = result + groups[-1]
  return result

def render_original(variables, text):
  text = linkify_inherit(variables, text, "inherit-product")
  text = linkify_inherit(variables, text, "inherit-product-if-exists")
  return text

def read_file(fn):
  f = file(fn)
  text = f.read()
  f.close()
  return text

def main(argv):
  # read the variables
  lines = sys.stdin.readlines()
  variables = parse_variables(lines)

  # format the variables
  variables = [break_lines(key,val) for key,val in variables]

  # now it's a dict
  variables = dict(variables)

  sorted_vars = (
      "PRODUCT_COPY_FILES",
      "PRODUCT_PACKAGES",
      "PRODUCT_LOCALES",
      "PRODUCT_PROPERTY_OVERRIDES",
    )

  for key in sorted_vars:
    variables[key] = sort_lines(variables[key])

  # the original file
  original = read_file(variables["FILE"])

  # formatting
  values = dict(variables)
  values.update({
    "variables": render_variables(variables),
    "original": render_original(variables, original),
  })
  print """<html>


<head>
  <title>%(FILE)s</title>
  <style type="text/css">
    body {
      font-family: Helvetica, Arial, sans-serif;
      padding-bottom: 20px;
    }
    #variables {
      border-collapse: collapse;
    }
    #variables th, #variables td {
      vertical-align: top;
      text-align: left;
      border-top: 1px solid #c5cdde;
      border-bottom: 1px solid #c5cdde;
      padding: 2px 10px 2px 10px;
    }
    #variables th {
      font-size: 10pt;
      background-color: #e2ecff
    }
    #variables td {
      background-color: #ebf2ff;
      white-space: pre;
      font-size: 10pt;
    }
    #original {
      background-color: #ebf2ff;
      border-top: 1px solid #c5cdde;
      border-bottom: 1px solid #c5cdde;
      padding: 2px 10px 2px 10px;
      white-space: pre;
      font-size: 10pt;
    }
  </style>
</head>
<body>
<h1>%(FILE)s</h1>
<a href="#Original">Original</a>
<a href="#Variables">Variables</a>
<h2><a name="Original"></a>Original</h2>
<div id="original">%(original)s</div>
<h2><a name="Variables"></a>Variables</h2>
%(variables)s
</body>
</html>
""" % values

if __name__ == "__main__":
  main(sys.argv)
