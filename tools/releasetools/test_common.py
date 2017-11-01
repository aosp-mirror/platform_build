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
import shutil
import tempfile
import time
import unittest
import zipfile

import common
import validate_target_files


def random_string_with_holes(size, block_size, step_size):
  data = ["\0"] * size
  for begin in range(0, size, step_size):
    end = begin + block_size
    data[begin:end] = os.urandom(block_size)
  return "".join(data)

def get_2gb_string():
  kilobytes = 1024
  megabytes = 1024 * kilobytes
  gigabytes = 1024 * megabytes

  size = int(2 * gigabytes + 1)
  block_size = 4 * kilobytes
  step_size = 4 * megabytes
  two_gb_string = random_string_with_holes(
        size, block_size, step_size)
  return two_gb_string


class CommonZipTest(unittest.TestCase):
  def _verify(self, zip_file, zip_file_name, arcname, contents,
              test_file_name=None, expected_stat=None, expected_mode=0o644,
              expected_compress_type=zipfile.ZIP_STORED):
    # Verify the stat if present.
    if test_file_name is not None:
      new_stat = os.stat(test_file_name)
      self.assertEqual(int(expected_stat.st_mode), int(new_stat.st_mode))
      self.assertEqual(int(expected_stat.st_mtime), int(new_stat.st_mtime))

    # Reopen the zip file to verify.
    zip_file = zipfile.ZipFile(zip_file_name, "r")

    # Verify the timestamp.
    info = zip_file.getinfo(arcname)
    self.assertEqual(info.date_time, (2009, 1, 1, 0, 0, 0))

    # Verify the file mode.
    mode = (info.external_attr >> 16) & 0o777
    self.assertEqual(mode, expected_mode)

    # Verify the compress type.
    self.assertEqual(info.compress_type, expected_compress_type)

    # Verify the zip contents.
    self.assertEqual(zip_file.read(arcname), contents)
    self.assertIsNone(zip_file.testzip())

  def _test_ZipWrite(self, contents, extra_zipwrite_args=None):
    extra_zipwrite_args = dict(extra_zipwrite_args or {})

    test_file = tempfile.NamedTemporaryFile(delete=False)
    test_file_name = test_file.name

    zip_file = tempfile.NamedTemporaryFile(delete=False)
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

      expected_stat = os.stat(test_file_name)
      expected_mode = extra_zipwrite_args.get("perms", 0o644)
      expected_compress_type = extra_zipwrite_args.get("compress_type",
                                                       zipfile.ZIP_STORED)
      time.sleep(5)  # Make sure the atime/mtime will change measurably.

      common.ZipWrite(zip_file, test_file_name, **extra_zipwrite_args)
      common.ZipClose(zip_file)

      self._verify(zip_file, zip_file_name, arcname, contents, test_file_name,
                   expected_stat, expected_mode, expected_compress_type)
    finally:
      os.remove(test_file_name)
      os.remove(zip_file_name)

  def _test_ZipWriteStr(self, zinfo_or_arcname, contents, extra_args=None):
    extra_args = dict(extra_args or {})

    zip_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file_name = zip_file.name
    zip_file.close()

    zip_file = zipfile.ZipFile(zip_file_name, "w")

    try:
      expected_compress_type = extra_args.get("compress_type",
                                              zipfile.ZIP_STORED)
      time.sleep(5)  # Make sure the atime/mtime will change measurably.

      if not isinstance(zinfo_or_arcname, zipfile.ZipInfo):
        arcname = zinfo_or_arcname
        expected_mode = extra_args.get("perms", 0o644)
      else:
        arcname = zinfo_or_arcname.filename
        expected_mode = extra_args.get("perms",
                                       zinfo_or_arcname.external_attr >> 16)

      common.ZipWriteStr(zip_file, zinfo_or_arcname, contents, **extra_args)
      common.ZipClose(zip_file)

      self._verify(zip_file, zip_file_name, arcname, contents,
                   expected_mode=expected_mode,
                   expected_compress_type=expected_compress_type)
    finally:
      os.remove(zip_file_name)

  def _test_ZipWriteStr_large_file(self, large, small, extra_args=None):
    extra_args = dict(extra_args or {})

    zip_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file_name = zip_file.name

    test_file = tempfile.NamedTemporaryFile(delete=False)
    test_file_name = test_file.name

    arcname_large = test_file_name
    arcname_small = "bar"

    # File names within an archive strip the leading slash.
    if arcname_large[0] == "/":
      arcname_large = arcname_large[1:]

    zip_file.close()
    zip_file = zipfile.ZipFile(zip_file_name, "w")

    try:
      test_file.write(large)
      test_file.close()

      expected_stat = os.stat(test_file_name)
      expected_mode = 0o644
      expected_compress_type = extra_args.get("compress_type",
                                              zipfile.ZIP_STORED)
      time.sleep(5)  # Make sure the atime/mtime will change measurably.

      common.ZipWrite(zip_file, test_file_name, **extra_args)
      common.ZipWriteStr(zip_file, arcname_small, small, **extra_args)
      common.ZipClose(zip_file)

      # Verify the contents written by ZipWrite().
      self._verify(zip_file, zip_file_name, arcname_large, large,
                   test_file_name, expected_stat, expected_mode,
                   expected_compress_type)

      # Verify the contents written by ZipWriteStr().
      self._verify(zip_file, zip_file_name, arcname_small, small,
                   expected_compress_type=expected_compress_type)
    finally:
      os.remove(zip_file_name)
      os.remove(test_file_name)

  def _test_reset_ZIP64_LIMIT(self, func, *args):
    default_limit = (1 << 31) - 1
    self.assertEqual(default_limit, zipfile.ZIP64_LIMIT)
    func(*args)
    self.assertEqual(default_limit, zipfile.ZIP64_LIMIT)

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
    self._test_ZipWrite(file_contents, {
        "arcname": "foobar",
        "perms": 0o700,
        "compress_type": zipfile.ZIP_STORED,
    })

  def test_ZipWrite_large_file(self):
    file_contents = get_2gb_string()
    self._test_ZipWrite(file_contents, {
        "compress_type": zipfile.ZIP_DEFLATED,
    })

  def test_ZipWrite_resets_ZIP64_LIMIT(self):
    self._test_reset_ZIP64_LIMIT(self._test_ZipWrite, "")

  def test_ZipWriteStr(self):
    random_string = os.urandom(1024)
    # Passing arcname
    self._test_ZipWriteStr("foo", random_string)

    # Passing zinfo
    zinfo = zipfile.ZipInfo(filename="foo")
    self._test_ZipWriteStr(zinfo, random_string)

    # Timestamp in the zinfo should be overwritten.
    zinfo.date_time = (2015, 3, 1, 15, 30, 0)
    self._test_ZipWriteStr(zinfo, random_string)

  def test_ZipWriteStr_with_opts(self):
    random_string = os.urandom(1024)
    # Passing arcname
    self._test_ZipWriteStr("foo", random_string, {
        "perms": 0o700,
        "compress_type": zipfile.ZIP_DEFLATED,
    })
    self._test_ZipWriteStr("bar", random_string, {
        "compress_type": zipfile.ZIP_STORED,
    })

    # Passing zinfo
    zinfo = zipfile.ZipInfo(filename="foo")
    self._test_ZipWriteStr(zinfo, random_string, {
        "compress_type": zipfile.ZIP_DEFLATED,
    })
    self._test_ZipWriteStr(zinfo, random_string, {
        "perms": 0o600,
        "compress_type": zipfile.ZIP_STORED,
    })

  def test_ZipWriteStr_large_file(self):
    # zipfile.writestr() doesn't work when the str size is over 2GiB even with
    # the workaround. We will only test the case of writing a string into a
    # large archive.
    long_string = get_2gb_string()
    short_string = os.urandom(1024)
    self._test_ZipWriteStr_large_file(long_string, short_string, {
        "compress_type": zipfile.ZIP_DEFLATED,
    })

  def test_ZipWriteStr_resets_ZIP64_LIMIT(self):
    self._test_reset_ZIP64_LIMIT(self._test_ZipWriteStr, "foo", "")
    zinfo = zipfile.ZipInfo(filename="foo")
    self._test_reset_ZIP64_LIMIT(self._test_ZipWriteStr, zinfo, "")

  def test_bug21309935(self):
    zip_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file_name = zip_file.name
    zip_file.close()

    try:
      random_string = os.urandom(1024)
      zip_file = zipfile.ZipFile(zip_file_name, "w")
      # Default perms should be 0o644 when passing the filename.
      common.ZipWriteStr(zip_file, "foo", random_string)
      # Honor the specified perms.
      common.ZipWriteStr(zip_file, "bar", random_string, perms=0o755)
      # The perms in zinfo should be untouched.
      zinfo = zipfile.ZipInfo(filename="baz")
      zinfo.external_attr = 0o740 << 16
      common.ZipWriteStr(zip_file, zinfo, random_string)
      # Explicitly specified perms has the priority.
      zinfo = zipfile.ZipInfo(filename="qux")
      zinfo.external_attr = 0o700 << 16
      common.ZipWriteStr(zip_file, zinfo, random_string, perms=0o400)
      common.ZipClose(zip_file)

      self._verify(zip_file, zip_file_name, "foo", random_string,
                   expected_mode=0o644)
      self._verify(zip_file, zip_file_name, "bar", random_string,
                   expected_mode=0o755)
      self._verify(zip_file, zip_file_name, "baz", random_string,
                   expected_mode=0o740)
      self._verify(zip_file, zip_file_name, "qux", random_string,
                   expected_mode=0o400)
    finally:
      os.remove(zip_file_name)

class InstallRecoveryScriptFormatTest(unittest.TestCase):
  """Check the format of install-recovery.sh

  Its format should match between common.py and validate_target_files.py."""

  def setUp(self):
    self._tempdir = tempfile.mkdtemp()
    # Create a dummy dict that contains the fstab info for boot&recovery.
    self._info = {"fstab" : {}}
    dummy_fstab = \
        ["/dev/soc.0/by-name/boot /boot emmc defaults defaults",
         "/dev/soc.0/by-name/recovery /recovery emmc defaults defaults"]
    self._info["fstab"] = common.LoadRecoveryFSTab(lambda x : "\n".join(x),
                                                   2, dummy_fstab)

  def _out_tmp_sink(self, name, data, prefix="SYSTEM"):
    loc = os.path.join(self._tempdir, prefix, name)
    if not os.path.exists(os.path.dirname(loc)):
      os.makedirs(os.path.dirname(loc))
    with open(loc, "w+") as f:
      f.write(data)

  def test_full_recovery(self):
    recovery_image = common.File("recovery.img", "recovery");
    boot_image = common.File("boot.img", "boot");
    self._info["full_recovery_image"] = "true"

    common.MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)

  def test_recovery_from_boot(self):
    recovery_image = common.File("recovery.img", "recovery");
    self._out_tmp_sink("recovery.img", recovery_image.data, "IMAGES")
    boot_image = common.File("boot.img", "boot");
    self._out_tmp_sink("boot.img", boot_image.data, "IMAGES")

    common.MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)
    # Validate 'recovery-from-boot' with bonus argument.
    self._out_tmp_sink("etc/recovery-resource.dat", "bonus", "SYSTEM")
    common.MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)

  def tearDown(self):
    shutil.rmtree(self._tempdir)
