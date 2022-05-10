#!/usr/bin/env python3
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
import struct
import sys

MD5_BLOCKSIZE = 1024 * 1024
HTML_ESCAPE_TABLE = {
    b"&": b"&amp;",
    b'"': b"&quot;",
    b"'": b"&apos;",
    b">": b"&gt;",
    b"<": b"&lt;",
    }

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
    return sum.hexdigest()


def html_escape(text):
    """Produce entities within text."""
    # Using for i in text doesn't work since i will be an int, not a byte.
    # There are multiple ways to solve this, but the most performant way
    # to iterate over a byte array is to use unpack. Using the
    # for i in range(len(text)) and using that to get a byte using array
    # slices is twice as slow as this method.
    return b"".join(HTML_ESCAPE_TABLE.get(i,i) for i in struct.unpack(str(len(text)) + 'c', text))

HTML_OUTPUT_CSS=b"""
<style type="text/css">
body { padding: 0; font-family: sans-serif; }
.same-license { background-color: #eeeeee; border-top: 20px solid white; padding: 10px; }
.label { font-weight: bold; }
.file-list { margin-left: 1em; color: blue; }
</style>

"""

def combine_notice_files_html(file_hash, input_dirs, output_filename):
    """Combine notice files in FILE_HASH and output a HTML version to OUTPUT_FILENAME."""

    SRC_DIR_STRIP_RE = re.compile("(?:" + "|".join(input_dirs) + ")(/.*).txt")

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

    output_file.write(b"<html><head>\n")
    output_file.write(HTML_OUTPUT_CSS)
    output_file.write(b'</head><body topmargin="0" leftmargin="0" rightmargin="0" bottommargin="0">\n')

    # Output our table of contents
    output_file.write(b'<div class="toc">\n')
    output_file.write(b"<ul>\n")

    # Flatten the list of lists into a single list of filenames
    sorted_filenames = sorted(itertools.chain.from_iterable(file_hash))

    # Print out a nice table of contents
    for filename in sorted_filenames:
        stripped_filename = SRC_DIR_STRIP_RE.sub(r"\1", filename)
        output_file.write(('<li><a href="#id%d">%s</a></li>\n' % (id_table.get(filename), stripped_filename)).encode())

    output_file.write(b"</ul>\n")
    output_file.write(b"</div><!-- table of contents -->\n")
    # Output the individual notice file lists
    output_file.write(b'<table cellpadding="0" cellspacing="0" border="0">\n')
    for value in file_hash:
        output_file.write(b'<tr id="id%d"><td class="same-license">\n' % id_table.get(value[0]))
        output_file.write(b'<div class="label">Notices for file(s):</div>\n')
        output_file.write(b'<div class="file-list">\n')
        for filename in value:
            output_file.write(("%s <br/>\n" % SRC_DIR_STRIP_RE.sub(r"\1", filename)).encode())
        output_file.write(b"</div><!-- file-list -->\n")
        output_file.write(b"\n")
        output_file.write(b'<pre class="license-text">\n')
        with open(value[0], "rb") as notice_file:
            output_file.write(html_escape(notice_file.read()))
        output_file.write(b"\n</pre><!-- license-text -->\n")
        output_file.write(b"</td></tr><!-- same-license -->\n\n\n\n")

    # Finish off the file output
    output_file.write(b"</table>\n")
    output_file.write(b"</body></html>\n")
    output_file.close()

def combine_notice_files_text(file_hash, input_dirs, output_filename, file_title):
    """Combine notice files in FILE_HASH and output a text version to OUTPUT_FILENAME."""

    SRC_DIR_STRIP_RE = re.compile("(?:" + "|".join(input_dirs) + ")(/.*).txt")
    output_file = open(output_filename, "wb")
    output_file.write(file_title.encode())
    output_file.write(b"\n")
    for value in file_hash:
        output_file.write(b"============================================================\n")
        output_file.write(b"Notices for file(s):\n")
        for filename in value:
            output_file.write(SRC_DIR_STRIP_RE.sub(r"\1", filename).encode())
            output_file.write(b"\n")
        output_file.write(b"------------------------------------------------------------\n")
        with open(value[0], "rb") as notice_file:
            output_file.write(notice_file.read())
            output_file.write(b"\n")
    output_file.close()

def combine_notice_files_xml(files_with_same_hash, input_dirs, output_filename):
    """Combine notice files in FILE_HASH and output a XML version to OUTPUT_FILENAME."""

    SRC_DIR_STRIP_RE = re.compile("(?:" + "|".join(input_dirs) + ")(/.*).txt")

    # Set up a filename to row id table (anchors inside tables don't work in
    # most browsers, but href's to table row ids do)
    id_table = {}
    for file_key, files in files_with_same_hash.items():
        for filename in files:
             id_table[filename] = file_key

    # Open the output file, and output the header pieces
    output_file = open(output_filename, "wb")

    output_file.write(b'<?xml version="1.0" encoding="utf-8"?>\n')
    output_file.write(b"<licenses>\n")

    # Flatten the list of lists into a single list of filenames
    sorted_filenames = sorted(id_table.keys())

    # Print out a nice table of contents
    for filename in sorted_filenames:
        stripped_filename = SRC_DIR_STRIP_RE.sub(r"\1", filename)
        output_file.write(('<file-name contentId="%s">%s</file-name>\n' % (id_table.get(filename), stripped_filename)).encode())
    output_file.write(b"\n\n")

    processed_file_keys = []
    # Output the individual notice file lists
    for filename in sorted_filenames:
        file_key = id_table.get(filename)
        if file_key in processed_file_keys:
            continue
        processed_file_keys.append(file_key)

        output_file.write(('<file-content contentId="%s"><![CDATA[' % file_key).encode())
        with open(filename, "rb") as notice_file:
            output_file.write(html_escape(notice_file.read()))
        output_file.write(b"]]></file-content>\n\n")

    # Finish off the file output
    output_file.write(b"</licenses>\n")
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
        '-s', '--source-dir', required=True, action='append',
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

    input_dirs = [os.path.normpath(source_dir) for source_dir in args.source_dir]
    # Find all the notice files and md5 them
    files_with_same_hash = defaultdict(list)
    for input_dir in input_dirs:
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

    filesets = [sorted(files_with_same_hash[md5]) for md5 in sorted(list(files_with_same_hash))]
    combine_notice_files_text(filesets, input_dirs, txt_output_file, file_title)

    if html_output_file is not None:
        combine_notice_files_html(filesets, input_dirs, html_output_file)

    if xml_output_file is not None:
        combine_notice_files_xml(files_with_same_hash, input_dirs, xml_output_file)

if __name__ == "__main__":
    main(sys.argv)
