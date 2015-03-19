#
# Copyright (C) 2015 The Android Open Source Project
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
import os
import tempfile
import time
import unittest
import zipfile

import common


def random_string_with_holes(size, block_size, step_size):
  data = ["\0"] * size
  for begin in range(0, size, step_size):
    end = begin + block_size
    data[begin:end] = os.urandom(block_size)
  return "".join(data)


class CommonZipTest(unittest.TestCase):
  def _test_ZipWrite(self, contents, extra_zipwrite_args=None):
    extra_zipwrite_args = dict(extra_zipwrite_args or {})

    test_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file = tempfile.NamedTemporaryFile(delete=False)

    test_file_name = test_file.name
    zip_file_name = zip_file.name

    # File names within an archive strip the leading slash.
    arcname = extra_zipwrite_args.get("arcname", test_file_name)
    if arcname[0] == "/":
      arcname = arcname[1:]

    zip_file.close()
    zip_file = zipfile.ZipFile(zip_file_name, "w")

    try:
      test_file.write(contents)
      test_file.close()

      old_stat = os.stat(test_file_name)
      expected_mode = extra_zipwrite_args.get("perms", 0o644)

      time.sleep(5)  # Make sure the atime/mtime will change measurably.

      common.ZipWrite(zip_file, test_file_name, **extra_zipwrite_args)

      new_stat = os.stat(test_file_name)
      self.assertEqual(int(old_stat.st_mode), int(new_stat.st_mode))
      self.assertEqual(int(old_stat.st_mtime), int(new_stat.st_mtime))

      zip_file.close()
      zip_file = zipfile.ZipFile(zip_file_name, "r")
      info = zip_file.getinfo(arcname)

      self.assertEqual(info.date_time, (2009, 1, 1, 0, 0, 0))
      mode = (info.external_attr >> 16) & 0o777
      self.assertEqual(mode, expected_mode)
      self.assertEqual(zip_file.read(arcname), contents)
    finally:
      os.remove(test_file_name)
      os.remove(zip_file_name)

  def test_ZipWrite(self):
    file_contents = os.urandom(1024)
    self._test_ZipWrite(file_contents)

  def test_ZipWrite_with_opts(self):
    file_contents = os.urandom(1024)
    self._test_ZipWrite(file_contents, {
        "arcname": "foobar",
        "perms": 0o777,
        "compress_type": zipfile.ZIP_DEFLATED,
    })

  def test_ZipWrite_large_file(self):
    kilobytes = 1024
    megabytes = 1024 * kilobytes
    gigabytes = 1024 * megabytes

    size = int(2 * gigabytes + 1)
    block_size = 4 * kilobytes
    step_size = 4 * megabytes
    file_contents = random_string_with_holes(
        size, block_size, step_size)
    self._test_ZipWrite(file_contents, {
        "compress_type": zipfile.ZIP_DEFLATED,
    })

  def test_ZipWrite_resets_ZIP64_LIMIT(self):
    default_limit = (1 << 31) - 1
    self.assertEqual(default_limit, zipfile.ZIP64_LIMIT)
    self._test_ZipWrite('')
    self.assertEqual(default_limit, zipfile.ZIP64_LIMIT)
