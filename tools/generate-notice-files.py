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
Usage: generate-notice-files --text-output [plain text output file] \
               --html-output [html output file] \
               --xml-output [xml output file] \
               -t [file title] -s [directory of notices]

Generate the Android notice files, including both text and html files.

-h to display this usage message and exit.
"""
from collections import defaultdict
import argparse
import hashlib
import itertools
import os
import os.path
import re
import sys

MD5_BLOCKSIZE = 1024 * 1024
HTML_ESCAPE_TABLE = {
    "&": "&amp;",
    '"': "&quot;",
    "'": "&apos;",
    ">": "&gt;",
    "<": "&lt;",
    }

def hexify(s):
    return ("%02x"*len(s)) % tuple(map(ord, s))

def md5sum(filename):
    """Calculate an MD5 of the file given by FILENAME,
    and return hex digest as a string.
    Output should be compatible with md5sum command"""

    f = open(filename, "rb")
    sum = hashlib.md5()
    while 1:
        block = f.read(MD5_BLOCKSIZE)
        if not block:
            break
        sum.update(block)
    f.close()
    return hexify(sum.digest())


def html_escape(text):
    """Produce entities within text."""
    return "".join(HTML_ESCAPE_TABLE.get(c,c) for c in text)

HTML_OUTPUT_CSS="""
<style type="text/css">
body { padding: 0; font-family: sans-serif; }
.same-license { background-color: #eeeeee; border-top: 20px solid white; padding: 10px; }
.label { font-weight: bold; }
.file-list { margin-left: 1em; color: blue; }
</style>
"""

def combine_notice_files_html(file_hash, input_dir, output_filename):
    """Combine notice files in FILE_HASH and output a HTML version to OUTPUT_FILENAME."""

    SRC_DIR_STRIP_RE = re.compile(input_dir + "(/.*).txt")

    # Set up a filename to row id table (anchors inside tables don't work in
    # most browsers, but href's to table row ids do)
    id_table = {}
    id_count = 0
    for value in file_hash:
        for filename in value:
             id_table[filename] = id_count
        id_count += 1

    # Open the output file, and output the header pieces
    output_file = open(output_filename, "wb")

    print >> output_file, "<html><head>"
    print >> output_file, HTML_OUTPUT_CSS
    print >> output_file, '</head><body topmargin="0" leftmargin="0" rightmargin="0" bottommargin="0">'

    # Output our table of contents
    print >> output_file, '<div class="toc">'
    print >> output_file, "<ul>"

    # Flatten the list of lists into a single list of filenames
    sorted_filenames = sorted(itertools.chain.from_iterable(file_hash))

    # Print out a nice table of contents
    for filename in sorted_filenames:
        stripped_filename = SRC_DIR_STRIP_RE.sub(r"\1", filename)
        print >> output_file, '<li><a href="#id%d">%s</a></li>' % (id_table.get(filename), stripped_filename)

    print >> output_file, "</ul>"
    print >> output_file, "</div><!-- table of contents -->"
    # Output the individual notice file lists
    print >>output_file, '<table cellpadding="0" cellspacing="0" border="0">'
    for value in file_hash:
        print >> output_file, '<tr id="id%d"><td class="same-license">' % id_table.get(value[0])
        print >> output_file, '<div class="label">Notices for file(s):</div>'
        print >> output_file, '<div class="file-list">'
        for filename in value:
            print >> output_file, "%s <br/>" % (SRC_DIR_STRIP_RE.sub(r"\1", filename))
        print >> output_file, "</div><!-- file-list -->"
        print >> output_file
        print >> output_file, '<pre class="license-text">'
        print >> output_file, html_escape(open(value[0]).read())
        print >> output_file, "</pre><!-- license-text -->"
        print >> output_file, "</td></tr><!-- same-license -->"
        print >> output_file
        print >> output_file
        print >> output_file

    # Finish off the file output
    print >> output_file, "</table>"
    print >> output_file, "</body></html>"
    output_file.close()

def combine_notice_files_text(file_hash, input_dir, output_filename, file_title):
    """Combine notice files in FILE_HASH and output a text version to OUTPUT_FILENAME."""

    SRC_DIR_STRIP_RE = re.compile(input_dir + "(/.*).txt")
    output_file = open(output_filename, "wb")
    print >> output_file, file_title
    for value in file_hash:
      print >> output_file, "============================================================"
      print >> output_file, "Notices for file(s):"
      for filename in value:
        print >> output_file, SRC_DIR_STRIP_RE.sub(r"\1", filename)
      print >> output_file, "------------------------------------------------------------"
      print >> output_file, open(value[0]).read()
    output_file.close()

def combine_notice_files_xml(files_with_same_hash, input_dir, output_filename):
    """Combine notice files in FILE_HASH and output a XML version to OUTPUT_FILENAME."""

    SRC_DIR_STRIP_RE = re.compile(input_dir + "(/.*).txt")

    # Set up a filename to row id table (anchors inside tables don't work in
    # most browsers, but href's to table row ids do)
    id_table = {}
    for file_key in files_with_same_hash.keys():
        for filename in files_with_same_hash[file_key]:
             id_table[filename] = file_key

    # Open the output file, and output the header pieces
    output_file = open(output_filename, "wb")

    print >> output_file, '<?xml version="1.0" encoding="utf-8"?>'
    print >> output_file, "<licenses>"

    # Flatten the list of lists into a single list of filenames
    sorted_filenames = sorted(id_table.keys())

    # Print out a nice table of contents
    for filename in sorted_filenames:
        stripped_filename = SRC_DIR_STRIP_RE.sub(r"\1", filename)
        print >> output_file, '<file-name contentId="%s">%s</file-name>' % (id_table.get(filename), stripped_filename)

    print >> output_file
    print >> output_file

    processed_file_keys = []
    # Output the individual notice file lists
    for filename in sorted_filenames:
        file_key = id_table.get(filename)
        if file_key in processed_file_keys:
            continue
        processed_file_keys.append(file_key)

        print >> output_file, '<file-content contentId="%s"><![CDATA[%s]]></file-content>' % (file_key, html_escape(open(filename).read()))
        print >> output_file

    # Finish off the file output
    print >> output_file, "</licenses>"
    output_file.close()

def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--text-output', required=True,
        help='The text output file path.')
    parser.add_argument(
        '--html-output',
        help='The html output file path.')
    parser.add_argument(
        '--xml-output',
        help='The xml output file path.')
    parser.add_argument(
        '-t', '--title', required=True,
        help='The file title.')
    parser.add_argument(
        '-s', '--source-dir', required=True,
        help='The directory containing notices.')
    parser.add_argument(
        '-i', '--included-subdirs', action='append',
        help='The sub directories which should be included.')
    parser.add_argument(
        '-e', '--excluded-subdirs', action='append',
        help='The sub directories which should be excluded.')
    return parser.parse_args()

def main(argv):
    args = get_args()

    txt_output_file = args.text_output
    html_output_file = args.html_output
    xml_output_file = args.xml_output
    file_title = args.title
    included_subdirs = []
    excluded_subdirs = []
    if args.included_subdirs is not None:
        included_subdirs = args.included_subdirs
    if args.excluded_subdirs is not None:
        excluded_subdirs = args.excluded_subdirs

    # Find all the notice files and md5 them
    input_dir = os.path.normpath(args.source_dir)
    files_with_same_hash = defaultdict(list)
    for root, dir, files in os.walk(input_dir):
        for file in files:
            matched = True
            if len(included_subdirs) > 0:
                matched = False
                for subdir in included_subdirs:
                    if (root == (input_dir + '/' + subdir) or
                        root.startswith(input_dir + '/' + subdir + '/')):
                        matched = True
                        break
            elif len(excluded_subdirs) > 0:
                for subdir in excluded_subdirs:
                    if (root == (input_dir + '/' + subdir) or
                        root.startswith(input_dir + '/' + subdir + '/')):
                        matched = False
                        break
            if matched and file.endswith(".txt"):
                filename = os.path.join(root, file)
                file_md5sum = md5sum(filename)
                files_with_same_hash[file_md5sum].append(filename)

    filesets = [sorted(files_with_same_hash[md5]) for md5 in sorted(files_with_same_hash.keys())]

    combine_notice_files_text(filesets, input_dir, txt_output_file, file_title)

    if html_output_file is not None:
        combine_notice_files_html(filesets, input_dir, html_output_file)

    if xml_output_file is not None:
        combine_notice_files_xml(files_with_same_hash, input_dir, xml_output_file)

if __name__ == "__main__":
    main(sys.argv)
