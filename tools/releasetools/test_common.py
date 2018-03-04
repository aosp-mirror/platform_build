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
import subprocess
import tempfile
import time
import unittest
import zipfile
from hashlib import sha1

import common
import test_utils
import validate_target_files
from rangelib import RangeSet


KiB = 1024
MiB = 1024 * KiB
GiB = 1024 * MiB


def get_2gb_string():
  size = int(2 * GiB + 1)
  block_size = 4 * KiB
  step_size = 4 * MiB
  # Generate a long string with holes, e.g. 'xyz\x00abc\x00...'.
  for _ in range(0, size, step_size):
    yield os.urandom(block_size)
    yield '\0' * (step_size - block_size)


class CommonZipTest(unittest.TestCase):
  def _verify(self, zip_file, zip_file_name, arcname, expected_hash,
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
    entry = zip_file.open(arcname)
    sha1_hash = sha1()
    for chunk in iter(lambda: entry.read(4 * MiB), ''):
      sha1_hash.update(chunk)
    self.assertEqual(expected_hash, sha1_hash.hexdigest())
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
      sha1_hash = sha1()
      for data in contents:
        sha1_hash.update(data)
        test_file.write(data)
      test_file.close()

      expected_stat = os.stat(test_file_name)
      expected_mode = extra_zipwrite_args.get("perms", 0o644)
      expected_compress_type = extra_zipwrite_args.get("compress_type",
                                                       zipfile.ZIP_STORED)
      time.sleep(5)  # Make sure the atime/mtime will change measurably.

      common.ZipWrite(zip_file, test_file_name, **extra_zipwrite_args)
      common.ZipClose(zip_file)

      self._verify(zip_file, zip_file_name, arcname, sha1_hash.hexdigest(),
                   test_file_name, expected_stat, expected_mode,
                   expected_compress_type)
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

      self._verify(zip_file, zip_file_name, arcname, sha1(contents).hexdigest(),
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
      sha1_hash = sha1()
      for data in large:
        sha1_hash.update(data)
        test_file.write(data)
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
      self._verify(zip_file, zip_file_name, arcname_large,
                   sha1_hash.hexdigest(), test_file_name, expected_stat,
                   expected_mode, expected_compress_type)

      # Verify the contents written by ZipWriteStr().
      self._verify(zip_file, zip_file_name, arcname_small,
                   sha1(small).hexdigest(),
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

      self._verify(zip_file, zip_file_name, "foo",
                   sha1(random_string).hexdigest(),
                   expected_mode=0o644)
      self._verify(zip_file, zip_file_name, "bar",
                   sha1(random_string).hexdigest(),
                   expected_mode=0o755)
      self._verify(zip_file, zip_file_name, "baz",
                   sha1(random_string).hexdigest(),
                   expected_mode=0o740)
      self._verify(zip_file, zip_file_name, "qux",
                   sha1(random_string).hexdigest(),
                   expected_mode=0o400)
    finally:
      os.remove(zip_file_name)

  def test_ZipDelete(self):
    zip_file = tempfile.NamedTemporaryFile(delete=False, suffix='.zip')
    output_zip = zipfile.ZipFile(zip_file.name, 'w',
                                 compression=zipfile.ZIP_DEFLATED)
    with tempfile.NamedTemporaryFile() as entry_file:
      entry_file.write(os.urandom(1024))
      common.ZipWrite(output_zip, entry_file.name, arcname='Test1')
      common.ZipWrite(output_zip, entry_file.name, arcname='Test2')
      common.ZipWrite(output_zip, entry_file.name, arcname='Test3')
      common.ZipClose(output_zip)
    zip_file.close()

    try:
      common.ZipDelete(zip_file.name, 'Test2')
      with zipfile.ZipFile(zip_file.name, 'r') as check_zip:
        entries = check_zip.namelist()
        self.assertTrue('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertTrue('Test3' in entries)

      self.assertRaises(AssertionError, common.ZipDelete, zip_file.name,
                        'Test2')
      with zipfile.ZipFile(zip_file.name, 'r') as check_zip:
        entries = check_zip.namelist()
        self.assertTrue('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertTrue('Test3' in entries)

      common.ZipDelete(zip_file.name, ['Test3'])
      with zipfile.ZipFile(zip_file.name, 'r') as check_zip:
        entries = check_zip.namelist()
        self.assertTrue('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertFalse('Test3' in entries)

      common.ZipDelete(zip_file.name, ['Test1', 'Test2'])
      with zipfile.ZipFile(zip_file.name, 'r') as check_zip:
        entries = check_zip.namelist()
        self.assertFalse('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertFalse('Test3' in entries)
    finally:
      os.remove(zip_file.name)


class CommonApkUtilsTest(unittest.TestCase):
  """Tests the APK utils related functions."""

  APKCERTS_TXT1 = (
      'name="RecoveryLocalizer.apk" certificate="certs/devkey.x509.pem"'
      ' private_key="certs/devkey.pk8"\n'
      'name="Settings.apk"'
      ' certificate="build/target/product/security/platform.x509.pem"'
      ' private_key="build/target/product/security/platform.pk8"\n'
      'name="TV.apk" certificate="PRESIGNED" private_key=""\n'
  )

  APKCERTS_CERTMAP1 = {
      'RecoveryLocalizer.apk' : 'certs/devkey',
      'Settings.apk' : 'build/target/product/security/platform',
      'TV.apk' : 'PRESIGNED',
  }

  APKCERTS_TXT2 = (
      'name="Compressed1.apk" certificate="certs/compressed1.x509.pem"'
      ' private_key="certs/compressed1.pk8" compressed="gz"\n'
      'name="Compressed2a.apk" certificate="certs/compressed2.x509.pem"'
      ' private_key="certs/compressed2.pk8" compressed="gz"\n'
      'name="Compressed2b.apk" certificate="certs/compressed2.x509.pem"'
      ' private_key="certs/compressed2.pk8" compressed="gz"\n'
      'name="Compressed3.apk" certificate="certs/compressed3.x509.pem"'
      ' private_key="certs/compressed3.pk8" compressed="gz"\n'
  )

  APKCERTS_CERTMAP2 = {
      'Compressed1.apk' : 'certs/compressed1',
      'Compressed2a.apk' : 'certs/compressed2',
      'Compressed2b.apk' : 'certs/compressed2',
      'Compressed3.apk' : 'certs/compressed3',
  }

  APKCERTS_TXT3 = (
      'name="Compressed4.apk" certificate="certs/compressed4.x509.pem"'
      ' private_key="certs/compressed4.pk8" compressed="xz"\n'
  )

  APKCERTS_CERTMAP3 = {
      'Compressed4.apk' : 'certs/compressed4',
  }

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  def tearDown(self):
    common.Cleanup()

  @staticmethod
  def _write_apkcerts_txt(apkcerts_txt, additional=None):
    if additional is None:
      additional = []
    target_files = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.writestr('META/apkcerts.txt', apkcerts_txt)
      for entry in additional:
        target_files_zip.writestr(entry, '')
    return target_files

  def test_ReadApkCerts_NoncompressedApks(self):
    target_files = self._write_apkcerts_txt(self.APKCERTS_TXT1)
    with zipfile.ZipFile(target_files, 'r') as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    self.assertDictEqual(self.APKCERTS_CERTMAP1, certmap)
    self.assertIsNone(ext)

  def test_ReadApkCerts_CompressedApks(self):
    # We have "installed" Compressed1.apk.gz only. Note that Compressed3.apk is
    # not stored in '.gz' format, so it shouldn't be considered as installed.
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT2,
        ['Compressed1.apk.gz', 'Compressed3.apk'])

    with zipfile.ZipFile(target_files, 'r') as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    self.assertDictEqual(self.APKCERTS_CERTMAP2, certmap)
    self.assertEqual('.gz', ext)

    # Alternative case with '.xz'.
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT3, ['Compressed4.apk.xz'])

    with zipfile.ZipFile(target_files, 'r') as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    self.assertDictEqual(self.APKCERTS_CERTMAP3, certmap)
    self.assertEqual('.xz', ext)

  def test_ReadApkCerts_CompressedAndNoncompressedApks(self):
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT1 + self.APKCERTS_TXT2,
        ['Compressed1.apk.gz', 'Compressed3.apk'])

    with zipfile.ZipFile(target_files, 'r') as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    certmap_merged = self.APKCERTS_CERTMAP1.copy()
    certmap_merged.update(self.APKCERTS_CERTMAP2)
    self.assertDictEqual(certmap_merged, certmap)
    self.assertEqual('.gz', ext)

  def test_ReadApkCerts_MultipleCompressionMethods(self):
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT2 + self.APKCERTS_TXT3,
        ['Compressed1.apk.gz', 'Compressed4.apk.xz'])

    with zipfile.ZipFile(target_files, 'r') as input_zip:
      self.assertRaises(ValueError, common.ReadApkCerts, input_zip)

  def test_ReadApkCerts_MismatchingKeys(self):
    malformed_apkcerts_txt = (
        'name="App1.apk" certificate="certs/cert1.x509.pem"'
        ' private_key="certs/cert2.pk8"\n'
    )
    target_files = self._write_apkcerts_txt(malformed_apkcerts_txt)

    with zipfile.ZipFile(target_files, 'r') as input_zip:
      self.assertRaises(ValueError, common.ReadApkCerts, input_zip)

  def test_ExtractPublicKey(self):
    cert = os.path.join(self.testdata_dir, 'testkey.x509.pem')
    pubkey = os.path.join(self.testdata_dir, 'testkey.pubkey.pem')
    with open(pubkey, 'rb') as pubkey_fp:
      self.assertEqual(pubkey_fp.read(), common.ExtractPublicKey(cert))

  def test_ExtractPublicKey_invalidInput(self):
    wrong_input = os.path.join(self.testdata_dir, 'testkey.pk8')
    self.assertRaises(AssertionError, common.ExtractPublicKey, wrong_input)

  def test_ParseCertificate(self):
    cert = os.path.join(self.testdata_dir, 'testkey.x509.pem')

    cmd = ['openssl', 'x509', '-in', cert, '-outform', 'DER']
    proc = common.Run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    expected, _ = proc.communicate()
    self.assertEqual(0, proc.returncode)

    with open(cert) as cert_fp:
      actual = common.ParseCertificate(cert_fp.read())
    self.assertEqual(expected, actual)


class CommonUtilsTest(unittest.TestCase):

  def tearDown(self):
    common.Cleanup()

  def test_GetSparseImage_emptyBlockMapFile(self):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([
              (0xCAC1, 6),
              (0xCAC3, 3),
              (0xCAC1, 4)]),
          arcname='IMAGES/system.img')
      target_files_zip.writestr('IMAGES/system.map', '')
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 8))
      target_files_zip.writestr('SYSTEM/file2', os.urandom(4096 * 3))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r') as input_zip:
      sparse_image = common.GetSparseImage('system', tempdir, input_zip, False)

    self.assertDictEqual(
        {
            '__COPY': RangeSet("0"),
            '__NONZERO-0': RangeSet("1-5 9-12"),
        },
        sparse_image.file_map)

  def test_GetSparseImage_invalidImageName(self):
    self.assertRaises(
        AssertionError, common.GetSparseImage, 'system2', None, None, False)
    self.assertRaises(
        AssertionError, common.GetSparseImage, 'unknown', None, None, False)

  def test_GetSparseImage_missingBlockMapFile(self):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([
              (0xCAC1, 6),
              (0xCAC3, 3),
              (0xCAC1, 4)]),
          arcname='IMAGES/system.img')
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 8))
      target_files_zip.writestr('SYSTEM/file2', os.urandom(4096 * 3))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r') as input_zip:
      self.assertRaises(
          AssertionError, common.GetSparseImage, 'system', tempdir, input_zip,
          False)

  def test_GetSparseImage_sharedBlocks_notAllowed(self):
    """Tests the case of having overlapping blocks but disallowed."""
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([(0xCAC2, 16)]),
          arcname='IMAGES/system.img')
      # Block 10 is shared between two files.
      target_files_zip.writestr(
          'IMAGES/system.map',
          '\n'.join([
              '/system/file1 1-5 9-10',
              '/system/file2 10-12']))
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 7))
      target_files_zip.writestr('SYSTEM/file2', os.urandom(4096 * 3))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r') as input_zip:
      self.assertRaises(
          AssertionError, common.GetSparseImage, 'system', tempdir, input_zip,
          False)

  def test_GetSparseImage_sharedBlocks_allowed(self):
    """Tests the case for target using BOARD_EXT4_SHARE_DUP_BLOCKS := true."""
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      # Construct an image with a care_map of "0-5 9-12".
      target_files_zip.write(
          test_utils.construct_sparse_image([(0xCAC2, 16)]),
          arcname='IMAGES/system.img')
      # Block 10 is shared between two files.
      target_files_zip.writestr(
          'IMAGES/system.map',
          '\n'.join([
              '/system/file1 1-5 9-10',
              '/system/file2 10-12']))
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 7))
      target_files_zip.writestr('SYSTEM/file2', os.urandom(4096 * 3))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r') as input_zip:
      sparse_image = common.GetSparseImage('system', tempdir, input_zip, True)

    self.assertDictEqual(
        {
            '__COPY': RangeSet("0"),
            '__NONZERO-0': RangeSet("6-8 13-15"),
            '/system/file1': RangeSet("1-5 9-10"),
            '/system/file2': RangeSet("11-12"),
        },
        sparse_image.file_map)

    # '/system/file2' should be marked with 'uses_shared_blocks', but not with
    # 'incomplete'.
    self.assertTrue(
        sparse_image.file_map['/system/file2'].extra['uses_shared_blocks'])
    self.assertNotIn(
        'incomplete', sparse_image.file_map['/system/file2'].extra)

    # All other entries should look normal without any tags.
    self.assertFalse(sparse_image.file_map['__COPY'].extra)
    self.assertFalse(sparse_image.file_map['__NONZERO-0'].extra)
    self.assertFalse(sparse_image.file_map['/system/file1'].extra)

  def test_GetSparseImage_incompleteRanges(self):
    """Tests the case of ext4 images with holes."""
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w') as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([(0xCAC2, 16)]),
          arcname='IMAGES/system.img')
      target_files_zip.writestr(
          'IMAGES/system.map',
          '\n'.join([
              '/system/file1 1-5 9-10',
              '/system/file2 11-12']))
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 7))
      # '/system/file2' has less blocks listed (2) than actual (3).
      target_files_zip.writestr('SYSTEM/file2', os.urandom(4096 * 3))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r') as input_zip:
      sparse_image = common.GetSparseImage('system', tempdir, input_zip, False)

    self.assertFalse(sparse_image.file_map['/system/file1'].extra)
    self.assertTrue(sparse_image.file_map['/system/file2'].extra['incomplete'])


class InstallRecoveryScriptFormatTest(unittest.TestCase):
  """Checks the format of install-recovery.sh.

  Its format should match between common.py and validate_target_files.py.
  """

  def setUp(self):
    self._tempdir = common.MakeTempDir()
    # Create a dummy dict that contains the fstab info for boot&recovery.
    self._info = {"fstab" : {}}
    dummy_fstab = [
        "/dev/soc.0/by-name/boot /boot emmc defaults defaults",
        "/dev/soc.0/by-name/recovery /recovery emmc defaults defaults"]
    self._info["fstab"] = common.LoadRecoveryFSTab("\n".join, 2, dummy_fstab)
    # Construct the gzipped recovery.img and boot.img
    self.recovery_data = bytearray([
        0x1f, 0x8b, 0x08, 0x00, 0x81, 0x11, 0x02, 0x5a, 0x00, 0x03, 0x2b, 0x4a,
        0x4d, 0xce, 0x2f, 0x4b, 0x2d, 0xaa, 0x04, 0x00, 0xc9, 0x93, 0x43, 0xf3,
        0x08, 0x00, 0x00, 0x00
    ])
    # echo -n "boot" | gzip -f | hd
    self.boot_data = bytearray([
        0x1f, 0x8b, 0x08, 0x00, 0x8c, 0x12, 0x02, 0x5a, 0x00, 0x03, 0x4b, 0xca,
        0xcf, 0x2f, 0x01, 0x00, 0xc4, 0xae, 0xed, 0x46, 0x04, 0x00, 0x00, 0x00
    ])

  def _out_tmp_sink(self, name, data, prefix="SYSTEM"):
    loc = os.path.join(self._tempdir, prefix, name)
    if not os.path.exists(os.path.dirname(loc)):
      os.makedirs(os.path.dirname(loc))
    with open(loc, "w+") as f:
      f.write(data)

  def test_full_recovery(self):
    recovery_image = common.File("recovery.img", self.recovery_data)
    boot_image = common.File("boot.img", self.boot_data)
    self._info["full_recovery_image"] = "true"

    common.MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)

  def test_recovery_from_boot(self):
    recovery_image = common.File("recovery.img", self.recovery_data)
    self._out_tmp_sink("recovery.img", recovery_image.data, "IMAGES")
    boot_image = common.File("boot.img", self.boot_data)
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
    common.Cleanup()
