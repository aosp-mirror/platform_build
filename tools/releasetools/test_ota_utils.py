# Copyright (C) 2021 The Android Open Source Project
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


import unittest
import io
import ota_utils
import zipfile


class TestZipEntryOffset(unittest.TestCase):
  def test_extra_length_differ(self):
      # This is a magic zip file such that:
      # 1. It has 1 entry, `file.txt'`
      # 2. The central directory entry for the entry contains an extra field of#
      # length 24, while the local file header for the entry contains an extra#
      # field of length 28.
      # It is key that the entry contains extra field of different length.
      # The sole purpose of this test case is make sure our offset computing
      # logic works in this scenario.

      # This is created by:
      # touch file.txt
      # zip -0 test.zip file.txt
      # Above command may or may not work on all platforms.
      # Some zip implementation will keep the extra field size consistent.
      # Some don't
    magic_zip = b'PK\x03\x04\n\x00\x00\x00\x00\x00nY\xfcR\x00\x00\x00\x00\x00\x00\x00' +\
        b'\x00\x00\x00\x00\x00\x08\x00\x1c\x00file.txtUT\t\x00\x03' +\
        b'\xa0s\x01a\xa0s\x01aux\x0b\x00\x01\x04\x88\xc4\t\x00\x04S_\x01\x00' +\
        b'PK\x01\x02\x1e\x03\n\x00\x00\x00\x00\x00nY\xfcR\x00\x00\x00\x00' +\
        b'\x00\x00\x00\x00\x00\x00\x00\x00\x08\x00\x18\x00\x00\x00\x00\x00' +\
        b'\x00\x00\x00\x00\x80\x81\x00\x00\x00\x00file.txt' +\
        b'UT\x05\x00\x03\xa0s\x01aux\x0b\x00\x01\x04\x88\xc4\t\x00\x04' +\
        b'S_\x01\x00PK\x05\x06\x00\x00\x00\x00\x01\x00\x01\x00N\x00\x00' +\
        b'\x00B\x00\x00\x00\x00\x00'
    # Just making sure we concatenated the bytes correctly
    self.assertEqual(len(magic_zip), 166)
    fp = io.BytesIO(magic_zip)
    with zipfile.ZipFile(fp, 'r') as zfp:
      self.assertGreater(len(zfp.infolist()), 0)
      zinfo = zfp.getinfo("file.txt")
      (offset, size) = ota_utils.GetZipEntryOffset(zfp, zinfo)
      self.assertEqual(size, zinfo.file_size)
      self.assertEqual(offset, zipfile.sizeFileHeader+len(zinfo.filename) + 28)
