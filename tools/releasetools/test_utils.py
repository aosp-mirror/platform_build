#
# Copyright (C) 2018 The Android Open Source Project
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
#

"""
Utils for running unittests.
"""

import logging
import os
import os.path
import struct
import sys
import unittest

import common

# Some test runner doesn't like outputs from stderr.
logging.basicConfig(stream=sys.stdout)


def get_testdata_dir():
  """Returns the testdata dir, in relative to the script dir."""
  # The script dir is the one we want, which could be different from pwd.
  current_dir = os.path.dirname(os.path.realpath(__file__))
  return os.path.join(current_dir, 'testdata')


def get_search_path():
  """Returns the search path that has 'framework/signapk.jar' under."""
  current_dir = os.path.dirname(os.path.realpath(__file__))
  for path in (
      # In relative to 'build/make/tools/releasetools' in the Android source.
      ['..'] * 4 + ['out', 'host', 'linux-x86'],
      # Or running the script unpacked from otatools.zip.
      ['..']):
    full_path = os.path.realpath(os.path.join(current_dir, *path))
    signapk_path = os.path.realpath(
        os.path.join(full_path, 'framework', 'signapk.jar'))
    if os.path.exists(signapk_path):
      return full_path
  return None


def construct_sparse_image(chunks):
  """Returns a sparse image file constructed from the given chunks.

  From system/core/libsparse/sparse_format.h.
  typedef struct sparse_header {
    __le32 magic;  // 0xed26ff3a
    __le16 major_version;  // (0x1) - reject images with higher major versions
    __le16 minor_version;  // (0x0) - allow images with higer minor versions
    __le16 file_hdr_sz;  // 28 bytes for first revision of the file format
    __le16 chunk_hdr_sz;  // 12 bytes for first revision of the file format
    __le32 blk_sz;  // block size in bytes, must be a multiple of 4 (4096)
    __le32 total_blks;  // total blocks in the non-sparse output image
    __le32 total_chunks;  // total chunks in the sparse input image
    __le32 image_checksum;  // CRC32 checksum of the original data, counting
                            // "don't care" as 0. Standard 802.3 polynomial,
                            // use a Public Domain table implementation
  } sparse_header_t;

  typedef struct chunk_header {
    __le16 chunk_type;  // 0xCAC1 -> raw; 0xCAC2 -> fill;
                        // 0xCAC3 -> don't care
    __le16 reserved1;
    __le32 chunk_sz;  // in blocks in output image
    __le32 total_sz;  // in bytes of chunk input file including chunk header
                      // and data
  } chunk_header_t;

  Args:
    chunks: A list of chunks to be written. Each entry should be a tuple of
        (chunk_type, block_number).

  Returns:
    Filename of the created sparse image.
  """
  SPARSE_HEADER_MAGIC = 0xED26FF3A
  SPARSE_HEADER_FORMAT = "<I4H4I"
  CHUNK_HEADER_FORMAT = "<2H2I"

  sparse_image = common.MakeTempFile(prefix='sparse-', suffix='.img')
  with open(sparse_image, 'wb') as fp:
    fp.write(struct.pack(
        SPARSE_HEADER_FORMAT, SPARSE_HEADER_MAGIC, 1, 0, 28, 12, 4096,
        sum(chunk[1] for chunk in chunks),
        len(chunks), 0))

    for chunk in chunks:
      data_size = 0
      if chunk[0] == 0xCAC1:
        data_size = 4096 * chunk[1]
      elif chunk[0] == 0xCAC2:
        data_size = 4
      elif chunk[0] == 0xCAC3:
        pass
      else:
        assert False, "Unsupported chunk type: {}".format(chunk[0])

      fp.write(struct.pack(
          CHUNK_HEADER_FORMAT, chunk[0], 0, chunk[1], data_size + 12))
      if data_size != 0:
        fp.write(os.urandom(data_size))

  return sparse_image


class ReleaseToolsTestCase(unittest.TestCase):
  """A common base class for all the releasetools unittests."""

  def tearDown(self):
    common.Cleanup()
