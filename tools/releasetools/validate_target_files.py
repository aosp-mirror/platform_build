#!/usr/bin/env python

# Copyright (C) 2017 The Android Open Source Project
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
Validate a given (signed) target_files.zip.

It performs checks to ensure the integrity of the input zip.
 - It verifies the file consistency between the ones in IMAGES/system.img (read
   via IMAGES/system.map) and the ones under unpacked folder of SYSTEM/. The
   same check also applies to the vendor image if present.
"""

import common
import logging
import os.path
import sparse_img
import sys


def _GetImage(which, tmpdir):
  assert which in ('system', 'vendor')

  path = os.path.join(tmpdir, 'IMAGES', which + '.img')
  mappath = os.path.join(tmpdir, 'IMAGES', which + '.map')

  # Map file must exist (allowed to be empty).
  assert os.path.exists(path) and os.path.exists(mappath)

  clobbered_blocks = '0'
  return sparse_img.SparseImage(path, mappath, clobbered_blocks)


def ValidateFileConsistency(input_zip, input_tmp):
  """Compare the files from image files and unpacked folders."""

  def RoundUpTo4K(value):
    rounded_up = value + 4095
    return rounded_up - (rounded_up % 4096)

  def CheckAllFiles(which):
    logging.info('Checking %s image.', which)
    image = _GetImage(which, input_tmp)
    prefix = '/' + which
    for entry in image.file_map:
      if not entry.startswith(prefix):
        continue

      # Read the blocks that the file resides. Note that it will contain the
      # bytes past the file length, which is expected to be padded with '\0's.
      ranges = image.file_map[entry]
      blocks_sha1 = image.RangeSha1(ranges)

      # The filename under unpacked directory, such as SYSTEM/bin/sh.
      unpacked_name = os.path.join(
          input_tmp, which.upper(), entry[(len(prefix) + 1):])
      with open(unpacked_name) as f:
        file_data = f.read()
      file_size = len(file_data)
      file_size_rounded_up = RoundUpTo4K(file_size)
      file_data += '\0' * (file_size_rounded_up - file_size)
      file_sha1 = common.File(entry, file_data).sha1

      assert blocks_sha1 == file_sha1, \
          'file: %s, range: %s, blocks_sha1: %s, file_sha1: %s' % (
              entry, ranges, blocks_sha1, file_sha1)

  logging.info('Validating file consistency.')

  # Verify IMAGES/system.img.
  CheckAllFiles('system')

  # Verify IMAGES/vendor.img if applicable.
  if 'VENDOR/' in input_zip.namelist():
    CheckAllFiles('vendor')

  # Not checking IMAGES/system_other.img since it doesn't have the map file.


def main(argv):
  def option_handler():
    return True

  args = common.ParseOptions(
      argv, __doc__, extra_opts="",
      extra_long_opts=[],
      extra_option_handler=option_handler)

  if len(args) != 1:
    common.Usage(__doc__)
    sys.exit(1)

  logging_format = '%(asctime)s - %(filename)s - %(levelname)-8s: %(message)s'
  date_format = '%Y/%m/%d %H:%M:%S'
  logging.basicConfig(level=logging.INFO, format=logging_format,
                      datefmt=date_format)

  logging.info("Unzipping the input target_files.zip: %s", args[0])
  input_tmp, input_zip = common.UnzipTemp(args[0])

  ValidateFileConsistency(input_zip, input_tmp)

  # TODO: Check if the OTA keys have been properly updated (the ones on /system,
  # in recovery image).

  # TODO(b/35411009): Verify the contents in /system/bin/install-recovery.sh.

  logging.info("Done.")


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  finally:
    common.Cleanup()
