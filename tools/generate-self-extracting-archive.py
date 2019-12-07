#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
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
Generates a self extracting archive with a license click through.

Usage:
  generate-self-extracting-archive.py $OUTPUT_FILE $INPUT_ARCHIVE $COMMENT $LICENSE_FILE

  The comment will be included at the beginning of the output archive file.

Output:
  The output of the script is a single executable file that when run will
  display the provided license and if the user accepts extract the wrapped
  archive.

  The layout of the output file is roughly:
   * Executable shell script that extracts the archive
   * Actual archive contents
   * Zip file containing the license
"""

import tempfile
import sys
import os
import zipfile

_HEADER_TEMPLATE = """#!/bin/bash
#
{comment_line}
#
# Usage is subject to the enclosed license agreement

echo
echo The license for this software will now be displayed.
echo You must agree to this license before using this software.
echo
echo -n Press Enter to view the license
read dummy
echo
more << EndOfLicense
{license}
EndOfLicense

if test $? != 0
then
  echo "ERROR: Couldn't display license file" 1>&2
  exit 1
fi
echo
echo -n 'Type "I ACCEPT" if you agree to the terms of the license: '
read typed
if test "$typed" != "I ACCEPT"
then
  echo
  echo "You didn't accept the license. Extraction aborted."
  exit 2
fi
echo
{extract_command}
if test $? != 0
then
  echo
  echo "ERROR: Couldn't extract files." 1>&2
  exit 3
else
  echo
  echo "Files extracted successfully."
fi
exit 0
"""

_PIPE_CHUNK_SIZE = 1048576
def _pipe_bytes(src, dst):
  while True:
    b = src.read(_PIPE_CHUNK_SIZE)
    if not b:
      break
    dst.write(b)

_MAX_OFFSET_WIDTH = 20
def _generate_extract_command(start, end, extract_name):
  """Generate the extract command.

  The length of this string must be constant no matter what the start and end
  offsets are so that its length can be computed before the actual command is
  generated.

  Args:
    start: offset in bytes of the start of the wrapped file
    end: offset in bytes of the end of the wrapped file
    extract_name: of the file to create when extracted

  """
  # start gets an extra character for the '+'
  # for tail +1 is the start of the file, not +0
  start_str = ('+%d' % (start + 1)).rjust(_MAX_OFFSET_WIDTH + 1)
  if len(start_str) != _MAX_OFFSET_WIDTH + 1:
    raise Exception('Start offset too large (%d)' % start)

  end_str = ('%d' % end).rjust(_MAX_OFFSET_WIDTH)
  if len(end_str) != _MAX_OFFSET_WIDTH:
    raise Exception('End offset too large (%d)' % end)

  return "tail -c %s $0 | head -c %s > %s\n" % (start_str, end_str, extract_name)


def main(argv):
  if len(argv) != 5:
    print 'generate-self-extracting-archive.py expects exactly 4 arguments'
    sys.exit(1)

  output_filename = argv[1]
  input_archive_filename = argv[2]
  comment = argv[3]
  license_filename = argv[4]

  input_archive_size = os.stat(input_archive_filename).st_size

  with open(license_filename, 'r') as license_file:
    license = license_file.read()

  if not license:
    print 'License file was empty'
    sys.exit(1)

  if 'SOFTWARE LICENSE AGREEMENT' not in license:
    print 'License does not look like a license'
    sys.exit(1)

  comment_line = '# %s\n' % comment
  extract_name = os.path.basename(input_archive_filename)

  # Compute the size of the header before writing the file out. This is required
  # so that the extract command, which uses the contents offset, can be created
  # and included inside the header.
  header_for_size = _HEADER_TEMPLATE.format(
      comment_line=comment_line,
      license=license,
      extract_command=_generate_extract_command(0, 0, extract_name),
  )
  header_size = len(header_for_size.encode('utf-8'))

  # write the final output
  with open(output_filename, 'wb') as output:
    output.write(_HEADER_TEMPLATE.format(
        comment_line=comment_line,
        license=license,
        extract_command=_generate_extract_command(header_size, input_archive_size, extract_name),
    ).encode('utf-8'))

    with open(input_archive_filename, 'rb') as input_file:
      _pipe_bytes(input_file, output)

    with tempfile.TemporaryFile() as trailing_zip:
      with zipfile.ZipFile(trailing_zip, 'w') as myzip:
        myzip.writestr('license.txt', license, compress_type=zipfile.ZIP_STORED)

      # append the trailing zip to the end of the file
      trailing_zip.seek(0)
      _pipe_bytes(trailing_zip, output)

  umask = os.umask(0)
  os.umask(umask)
  os.chmod(output_filename, 0o777 & ~umask)

if __name__ == "__main__":
  main(sys.argv)
