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

import copy
import os
import subprocess
import tempfile
import unittest
import zipfile
from hashlib import sha1
from typing import BinaryIO

import common
import test_utils
import validate_target_files
from images import EmptyImage, DataImage
from rangelib import RangeSet


KiB = 1024
MiB = 1024 * KiB
GiB = 1024 * MiB


def get_2gb_file():
  size = int(2 * GiB + 1)
  block_size = 4 * KiB
  step_size = 4 * MiB
  tmpfile = tempfile.NamedTemporaryFile()
  tmpfile.truncate(size)
  for _ in range(0, size, step_size):
    tmpfile.write(os.urandom(block_size))
    tmpfile.seek(step_size - block_size, os.SEEK_CUR)
  return tmpfile


def hash_file(filename):
  sha1_hash = sha1()
  with open(filename, "rb") as fp:
    for data in iter(lambda: fp.read(4*MiB), b''):
      sha1_hash.update(data)
  return sha1_hash


class BuildInfoTest(test_utils.ReleaseToolsTestCase):

  TEST_INFO_FINGERPRINT_DICT = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.brand': 'product-brand',
              'ro.product.name': 'product-name',
              'ro.product.device': 'product-device',
              'ro.build.version.release': 'version-release',
              'ro.build.id': 'build-id',
              'ro.build.version.incremental': 'version-incremental',
              'ro.build.type': 'build-type',
              'ro.build.tags': 'build-tags',
              'ro.build.version.sdk': 30,
          }
      ),
  }

  TEST_INFO_DICT = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.device': 'product-device',
              'ro.product.name': 'product-name',
              'ro.build.fingerprint': 'build-fingerprint',
              'ro.build.foo': 'build-foo'}
      ),
      'system.build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.system.brand': 'product-brand',
              'ro.product.system.name': 'product-name',
              'ro.product.system.device': 'product-device',
              'ro.system.build.version.release': 'version-release',
              'ro.system.build.id': 'build-id',
              'ro.system.build.version.incremental': 'version-incremental',
              'ro.system.build.type': 'build-type',
              'ro.system.build.tags': 'build-tags',
              'ro.system.build.foo': 'build-foo'}
      ),
      'vendor.build.prop': common.PartitionBuildProps.FromDictionary(
          'vendor', {
              'ro.product.vendor.brand': 'vendor-product-brand',
              'ro.product.vendor.name': 'vendor-product-name',
              'ro.product.vendor.device': 'vendor-product-device',
              'ro.vendor.build.version.release': 'vendor-version-release',
              'ro.vendor.build.id': 'vendor-build-id',
              'ro.vendor.build.version.incremental':
              'vendor-version-incremental',
              'ro.vendor.build.type': 'vendor-build-type',
              'ro.vendor.build.tags': 'vendor-build-tags'}
      ),
      'property1': 'value1',
      'property2': 4096,
  }

  TEST_INFO_DICT_USES_OEM_PROPS = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.name': 'product-name',
              'ro.build.thumbprint': 'build-thumbprint',
              'ro.build.bar': 'build-bar'}
      ),
      'vendor.build.prop': common.PartitionBuildProps.FromDictionary(
          'vendor', {
              'ro.vendor.build.fingerprint': 'vendor-build-fingerprint'}
      ),
      'property1': 'value1',
      'property2': 4096,
      'oem_fingerprint_properties': 'ro.product.device ro.product.brand',
  }

  TEST_OEM_DICTS = [
      {
          'ro.product.brand': 'brand1',
          'ro.product.device': 'device1',
      },
      {
          'ro.product.brand': 'brand2',
          'ro.product.device': 'device2',
      },
      {
          'ro.product.brand': 'brand3',
          'ro.product.device': 'device3',
      },
  ]

  TEST_INFO_DICT_PROPERTY_SOURCE_ORDER = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.build.fingerprint': 'build-fingerprint',
              'ro.product.property_source_order':
                  'product,odm,vendor,system_ext,system'}
      ),
      'system.build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.system.device': 'system-product-device'}
      ),
      'vendor.build.prop': common.PartitionBuildProps.FromDictionary(
          'vendor', {
              'ro.product.vendor.device': 'vendor-product-device'}
      ),
  }

  TEST_INFO_DICT_PROPERTY_SOURCE_ORDER_ANDROID_10 = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.build.fingerprint': 'build-fingerprint',
              'ro.product.property_source_order':
                  'product,product_services,odm,vendor,system',
              'ro.build.version.release': '10',
              'ro.build.version.codename': 'REL'}
      ),
      'system.build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.system.device': 'system-product-device'}
      ),
      'vendor.build.prop': common.PartitionBuildProps.FromDictionary(
          'vendor', {
              'ro.product.vendor.device': 'vendor-product-device'}
      ),
  }

  TEST_INFO_DICT_PROPERTY_SOURCE_ORDER_ANDROID_9 = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.device': 'product-device',
              'ro.build.fingerprint': 'build-fingerprint',
              'ro.build.version.release': '9',
              'ro.build.version.codename': 'REL'}
      ),
      'system.build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.system.device': 'system-product-device'}
      ),
      'vendor.build.prop': common.PartitionBuildProps.FromDictionary(
          'vendor', {
              'ro.product.vendor.device': 'vendor-product-device'}
      ),
  }

  def test_init(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('product-device', target_info.device)
    self.assertEqual('build-fingerprint', target_info.fingerprint)
    self.assertFalse(target_info.is_ab)
    self.assertIsNone(target_info.oem_props)

  def test_init_with_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    self.assertEqual('device1', target_info.device)
    self.assertEqual('brand1/product-name/device1:build-thumbprint',
                     target_info.fingerprint)

    # Swap the order in oem_dicts, which would lead to different BuildInfo.
    oem_dicts = copy.copy(self.TEST_OEM_DICTS)
    oem_dicts[0], oem_dicts[2] = oem_dicts[2], oem_dicts[0]
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   oem_dicts)
    self.assertEqual('device3', target_info.device)
    self.assertEqual('brand3/product-name/device3:build-thumbprint',
                     target_info.fingerprint)

  def test_init_badFingerprint(self):
    info_dict = copy.deepcopy(self.TEST_INFO_DICT)
    info_dict['build.prop'].build_props[
        'ro.build.fingerprint'] = 'bad fingerprint'
    self.assertRaises(ValueError, common.BuildInfo, info_dict, None)

    info_dict['build.prop'].build_props[
        'ro.build.fingerprint'] = 'bad\x80fingerprint'
    self.assertRaises(ValueError, common.BuildInfo, info_dict, None)

  def test_init_goodFingerprint(self):
    info_dict = copy.deepcopy(self.TEST_INFO_FINGERPRINT_DICT)
    build_info = common.BuildInfo(info_dict)
    self.assertEqual(
        'product-brand/product-name/product-device:version-release/build-id/'
        'version-incremental:build-type/build-tags', build_info.fingerprint)

    build_props = info_dict['build.prop'].build_props
    del build_props['ro.build.id']
    build_props['ro.build.legacy.id'] = 'legacy-build-id'
    build_info = common.BuildInfo(info_dict, use_legacy_id=True)
    self.assertEqual(
        'product-brand/product-name/product-device:version-release/'
        'legacy-build-id/version-incremental:build-type/build-tags',
        build_info.fingerprint)

    self.assertRaises(common.ExternalError, common.BuildInfo, info_dict, None,
                      False)

    info_dict['avb_enable'] = 'true'
    info_dict['vbmeta_digest'] = 'abcde12345'
    build_info = common.BuildInfo(info_dict, use_legacy_id=False)
    self.assertEqual(
        'product-brand/product-name/product-device:version-release/'
        'legacy-build-id.abcde123/version-incremental:build-type/build-tags',
        build_info.fingerprint)

  def test___getitem__(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('value1', target_info['property1'])
    self.assertEqual(4096, target_info['property2'])
    self.assertEqual('build-foo',
                     target_info['build.prop'].GetProp('ro.build.foo'))

  def test___getitem__with_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    self.assertEqual('value1', target_info['property1'])
    self.assertEqual(4096, target_info['property2'])
    self.assertIsNone(target_info['build.prop'].GetProp('ro.build.foo'))

  def test___setitem__(self):
    target_info = common.BuildInfo(copy.deepcopy(self.TEST_INFO_DICT), None)
    self.assertEqual('value1', target_info['property1'])
    target_info['property1'] = 'value2'
    self.assertEqual('value2', target_info['property1'])

    self.assertEqual('build-foo',
                     target_info['build.prop'].GetProp('ro.build.foo'))
    target_info['build.prop'].build_props['ro.build.foo'] = 'build-bar'
    self.assertEqual('build-bar',
                     target_info['build.prop'].GetProp('ro.build.foo'))

  def test_get(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('value1', target_info.get('property1'))
    self.assertEqual(4096, target_info.get('property2'))
    self.assertEqual(4096, target_info.get('property2', 1024))
    self.assertEqual(1024, target_info.get('property-nonexistent', 1024))
    self.assertEqual('build-foo',
                     target_info.get('build.prop').GetProp('ro.build.foo'))

  def test_get_with_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    self.assertEqual('value1', target_info.get('property1'))
    self.assertEqual(4096, target_info.get('property2'))
    self.assertEqual(4096, target_info.get('property2', 1024))
    self.assertEqual(1024, target_info.get('property-nonexistent', 1024))
    self.assertIsNone(target_info.get('build.prop').GetProp('ro.build.foo'))

  def test_items(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    items = target_info.items()
    self.assertIn(('property1', 'value1'), items)
    self.assertIn(('property2', 4096), items)

  def test_GetBuildProp(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('build-foo', target_info.GetBuildProp('ro.build.foo'))
    self.assertRaises(common.ExternalError, target_info.GetBuildProp,
                      'ro.build.nonexistent')

  def test_GetBuildProp_with_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    self.assertEqual('build-bar', target_info.GetBuildProp('ro.build.bar'))
    self.assertRaises(common.ExternalError, target_info.GetBuildProp,
                      'ro.build.nonexistent')

  def test_GetPartitionFingerprint(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual(
        target_info.GetPartitionFingerprint('vendor'),
        'vendor-product-brand/vendor-product-name/vendor-product-device'
        ':vendor-version-release/vendor-build-id/vendor-version-incremental'
        ':vendor-build-type/vendor-build-tags')

  def test_GetPartitionFingerprint_system_other_uses_system(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual(
        target_info.GetPartitionFingerprint('system_other'),
        target_info.GetPartitionFingerprint('system'))

  def test_GetPartitionFingerprint_uses_fingerprint_prop_if_available(self):
    info_dict = copy.deepcopy(self.TEST_INFO_DICT)
    info_dict['vendor.build.prop'].build_props[
        'ro.vendor.build.fingerprint'] = 'vendor:fingerprint'
    target_info = common.BuildInfo(info_dict, None)
    self.assertEqual(
        target_info.GetPartitionFingerprint('vendor'),
        'vendor:fingerprint')

  def test_WriteMountOemScript(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    script_writer = test_utils.MockScriptWriter()
    target_info.WriteMountOemScript(script_writer)
    self.assertEqual([('Mount', '/oem', None)], script_writer.lines)

  def test_WriteDeviceAssertions(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT, None)
    script_writer = test_utils.MockScriptWriter()
    target_info.WriteDeviceAssertions(script_writer, False)
    self.assertEqual([('AssertDevice', 'product-device')], script_writer.lines)

  def test_WriteDeviceAssertions_with_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    script_writer = test_utils.MockScriptWriter()
    target_info.WriteDeviceAssertions(script_writer, False)
    self.assertEqual(
        [
            ('AssertOemProperty', 'ro.product.device',
             ['device1', 'device2', 'device3'], False),
            ('AssertOemProperty', 'ro.product.brand',
             ['brand1', 'brand2', 'brand3'], False),
        ],
        script_writer.lines)

  def test_ResolveRoProductProperty_FromVendor(self):
    info_dict = copy.deepcopy(self.TEST_INFO_DICT_PROPERTY_SOURCE_ORDER)
    info = common.BuildInfo(info_dict, None)
    self.assertEqual('vendor-product-device',
                     info.GetBuildProp('ro.product.device'))

  def test_ResolveRoProductProperty_FromSystem(self):
    info_dict = copy.deepcopy(self.TEST_INFO_DICT_PROPERTY_SOURCE_ORDER)
    del info_dict['vendor.build.prop'].build_props['ro.product.vendor.device']
    info = common.BuildInfo(info_dict, None)
    self.assertEqual('system-product-device',
                     info.GetBuildProp('ro.product.device'))

  def test_ResolveRoProductProperty_InvalidPropertySearchOrder(self):
    info_dict = copy.deepcopy(self.TEST_INFO_DICT_PROPERTY_SOURCE_ORDER)
    info_dict['build.prop'].build_props[
        'ro.product.property_source_order'] = 'bad-source'
    with self.assertRaisesRegexp(common.ExternalError,
                                 'Invalid ro.product.property_source_order'):
      info = common.BuildInfo(info_dict, None)
      info.GetBuildProp('ro.product.device')

  def test_ResolveRoProductProperty_Android10PropertySearchOrder(self):
    info_dict = copy.deepcopy(
        self.TEST_INFO_DICT_PROPERTY_SOURCE_ORDER_ANDROID_10)
    info = common.BuildInfo(info_dict, None)
    self.assertEqual('vendor-product-device',
                     info.GetBuildProp('ro.product.device'))

  def test_ResolveRoProductProperty_Android9PropertySearchOrder(self):
    info_dict = copy.deepcopy(
        self.TEST_INFO_DICT_PROPERTY_SOURCE_ORDER_ANDROID_9)
    info = common.BuildInfo(info_dict, None)
    self.assertEqual('product-device',
                     info.GetBuildProp('ro.product.device'))


class CommonZipTest(test_utils.ReleaseToolsTestCase):

  def _verify(self, zip_file, zip_file_name, arcname, expected_hash,
              test_file_name=None, expected_stat=None, expected_mode=0o644,
              expected_compress_type=zipfile.ZIP_STORED):
    # Verify the stat if present.
    if test_file_name is not None:
      new_stat = os.stat(test_file_name)
      self.assertEqual(int(expected_stat.st_mode), int(new_stat.st_mode))
      self.assertEqual(int(expected_stat.st_mtime), int(new_stat.st_mtime))

    # Reopen the zip file to verify.
    zip_file = zipfile.ZipFile(zip_file_name, "r", allowZip64=True)

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
    for chunk in iter(lambda: entry.read(4 * MiB), b''):
      sha1_hash.update(chunk)
    self.assertEqual(expected_hash, sha1_hash.hexdigest())
    self.assertIsNone(zip_file.testzip())

  def _test_ZipWrite(self, contents, extra_zipwrite_args=None):
    with tempfile.NamedTemporaryFile() as test_file:
      test_file_name = test_file.name
      for data in contents:
        test_file.write(bytes(data))
      return self._test_ZipWriteFile(test_file_name, extra_zipwrite_args)

  def _test_ZipWriteFile(self, test_file_name, extra_zipwrite_args=None):
    extra_zipwrite_args = dict(extra_zipwrite_args or {})

    test_file = tempfile.NamedTemporaryFile(delete=False)
    test_file_name = test_file.name

    zip_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file_name = zip_file.name

    # File names within an archive strip the leading slash.
    arcname = extra_zipwrite_args.get("arcname", test_file_name)
    if arcname[0] == "/":
      arcname = arcname[1:]
    sha1_hash = hash_file(test_file_name)

    zip_file.close()
    zip_file = zipfile.ZipFile(zip_file_name, "w", allowZip64=True)

    try:
      expected_mode = extra_zipwrite_args.get("perms", 0o644)
      expected_compress_type = extra_zipwrite_args.get("compress_type",
                                                       zipfile.ZIP_STORED)

      # Arbitrary timestamp, just to make sure common.ZipWrite() restores
      # the timestamp after writing.
      os.utime(test_file_name, (1234567, 1234567))
      expected_stat = os.stat(test_file_name)
      common.ZipWrite(zip_file, test_file_name, **extra_zipwrite_args)
      common.ZipClose(zip_file)

      self._verify(zip_file, zip_file_name, arcname, sha1_hash.hexdigest(),
                   test_file_name, expected_stat, expected_mode,
                   expected_compress_type)
    finally:
      os.remove(zip_file_name)

  def _test_ZipWriteStr(self, zinfo_or_arcname, contents, extra_args=None):
    extra_args = dict(extra_args or {})

    zip_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file_name = zip_file.name
    zip_file.close()

    zip_file = zipfile.ZipFile(zip_file_name, "w", allowZip64=True)

    try:
      expected_compress_type = extra_args.get("compress_type",
                                              zipfile.ZIP_STORED)
      if not isinstance(zinfo_or_arcname, zipfile.ZipInfo):
        arcname = zinfo_or_arcname
        expected_mode = extra_args.get("perms", 0o644)
      else:
        arcname = zinfo_or_arcname.filename
        if zinfo_or_arcname.external_attr:
          zinfo_perms = zinfo_or_arcname.external_attr >> 16
        else:
          zinfo_perms = 0o600
        expected_mode = extra_args.get("perms", zinfo_perms)

      common.ZipWriteStr(zip_file, zinfo_or_arcname, contents, **extra_args)
      common.ZipClose(zip_file)

      self._verify(zip_file, zip_file_name, arcname, sha1(contents).hexdigest(),
                   expected_mode=expected_mode,
                   expected_compress_type=expected_compress_type)
    finally:
      os.remove(zip_file_name)

  def _test_ZipWriteStr_large_file(self, large_file: BinaryIO, small, extra_args=None):
    extra_args = dict(extra_args or {})

    zip_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file_name = zip_file.name

    test_file_name = large_file.name

    arcname_large = test_file_name
    arcname_small = "bar"

    # File names within an archive strip the leading slash.
    if arcname_large[0] == "/":
      arcname_large = arcname_large[1:]

    zip_file.close()
    zip_file = zipfile.ZipFile(zip_file_name, "w", allowZip64=True)

    try:
      sha1_hash = hash_file(test_file_name)

      # Arbitrary timestamp, just to make sure common.ZipWrite() restores
      # the timestamp after writing.
      os.utime(test_file_name, (1234567, 1234567))
      expected_stat = os.stat(test_file_name)
      expected_mode = 0o644
      expected_compress_type = extra_args.get("compress_type",
                                              zipfile.ZIP_STORED)

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
    with get_2gb_file() as tmpfile:
      self._test_ZipWriteFile(tmpfile.name, {
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
    self._test_ZipWriteStr(zinfo, random_string, {
        "perms": 0o000,
        "compress_type": zipfile.ZIP_STORED,
    })

  def test_ZipWriteStr_large_file(self):
    # zipfile.writestr() doesn't work when the str size is over 2GiB even with
    # the workaround. We will only test the case of writing a string into a
    # large archive.
    short_string = os.urandom(1024)
    with get_2gb_file() as large_file:
      self._test_ZipWriteStr_large_file(large_file, short_string, {
          "compress_type": zipfile.ZIP_DEFLATED,
      })

  def test_ZipWriteStr_resets_ZIP64_LIMIT(self):
    self._test_reset_ZIP64_LIMIT(self._test_ZipWriteStr, 'foo', b'')
    zinfo = zipfile.ZipInfo(filename="foo")
    self._test_reset_ZIP64_LIMIT(self._test_ZipWriteStr, zinfo, b'')

  def test_bug21309935(self):
    zip_file = tempfile.NamedTemporaryFile(delete=False)
    zip_file_name = zip_file.name
    zip_file.close()

    try:
      random_string = os.urandom(1024)
      zip_file = zipfile.ZipFile(zip_file_name, "w", allowZip64=True)
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

  @test_utils.SkipIfExternalToolsUnavailable()
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
      with zipfile.ZipFile(zip_file.name, 'r', allowZip64=True) as check_zip:
        entries = check_zip.namelist()
        self.assertTrue('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertTrue('Test3' in entries)

      self.assertRaises(
          common.ExternalError, common.ZipDelete, zip_file.name, 'Test2')
      with zipfile.ZipFile(zip_file.name, 'r', allowZip64=True) as check_zip:
        entries = check_zip.namelist()
        self.assertTrue('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertTrue('Test3' in entries)

      common.ZipDelete(zip_file.name, ['Test3'])
      with zipfile.ZipFile(zip_file.name, 'r', allowZip64=True) as check_zip:
        entries = check_zip.namelist()
        self.assertTrue('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertFalse('Test3' in entries)

      common.ZipDelete(zip_file.name, ['Test1', 'Test2'])
      with zipfile.ZipFile(zip_file.name, 'r', allowZip64=True) as check_zip:
        entries = check_zip.namelist()
        self.assertFalse('Test1' in entries)
        self.assertFalse('Test2' in entries)
        self.assertFalse('Test3' in entries)
    finally:
      os.remove(zip_file.name)

  @staticmethod
  def _test_UnzipTemp_createZipFile():
    zip_file = common.MakeTempFile(suffix='.zip')
    output_zip = zipfile.ZipFile(
        zip_file, 'w', compression=zipfile.ZIP_DEFLATED)
    contents = os.urandom(1024)
    with tempfile.NamedTemporaryFile() as entry_file:
      entry_file.write(contents)
      common.ZipWrite(output_zip, entry_file.name, arcname='Test1')
      common.ZipWrite(output_zip, entry_file.name, arcname='Test2')
      common.ZipWrite(output_zip, entry_file.name, arcname='Foo3')
      common.ZipWrite(output_zip, entry_file.name, arcname='Bar4')
      common.ZipWrite(output_zip, entry_file.name, arcname='Dir5/Baz5')
      common.ZipClose(output_zip)
    common.ZipClose(output_zip)
    return zip_file

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_UnzipTemp(self):
    zip_file = self._test_UnzipTemp_createZipFile()
    unzipped_dir = common.UnzipTemp(zip_file)
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_UnzipTemp_withPatterns(self):
    zip_file = self._test_UnzipTemp_createZipFile()

    unzipped_dir = common.UnzipTemp(zip_file, ['Test1'])
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))

    unzipped_dir = common.UnzipTemp(zip_file, ['Test1', 'Foo3'])
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))

    unzipped_dir = common.UnzipTemp(zip_file, ['Test*', 'Foo3*'])
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))

    unzipped_dir = common.UnzipTemp(zip_file, ['*Test1', '*Baz*'])
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))

  def test_UnzipTemp_withEmptyPatterns(self):
    zip_file = self._test_UnzipTemp_createZipFile()
    unzipped_dir = common.UnzipTemp(zip_file, [])
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_UnzipTemp_withPartiallyMatchingPatterns(self):
    zip_file = self._test_UnzipTemp_createZipFile()
    unzipped_dir = common.UnzipTemp(zip_file, ['Test*', 'Nonexistent*'])
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertTrue(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))

  def test_UnzipTemp_withNoMatchingPatterns(self):
    zip_file = self._test_UnzipTemp_createZipFile()
    unzipped_dir = common.UnzipTemp(zip_file, ['Foo4', 'Nonexistent*'])
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Test1')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Test2')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Foo3')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Bar4')))
    self.assertFalse(os.path.exists(os.path.join(unzipped_dir, 'Dir5/Baz5')))


class CommonApkUtilsTest(test_utils.ReleaseToolsTestCase):
  """Tests the APK utils related functions."""

  APKCERTS_TXT1 = (
      'name="RecoveryLocalizer.apk" certificate="certs/devkey.x509.pem"'
      ' private_key="certs/devkey.pk8"\n'
      'name="Settings.apk"'
      ' certificate="build/make/target/product/security/platform.x509.pem"'
      ' private_key="build/make/target/product/security/platform.pk8"\n'
      'name="TV.apk" certificate="PRESIGNED" private_key=""\n'
  )

  APKCERTS_CERTMAP1 = {
      'RecoveryLocalizer.apk': 'certs/devkey',
      'Settings.apk': 'build/make/target/product/security/platform',
      'TV.apk': 'PRESIGNED',
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
      'Compressed1.apk': 'certs/compressed1',
      'Compressed2a.apk': 'certs/compressed2',
      'Compressed2b.apk': 'certs/compressed2',
      'Compressed3.apk': 'certs/compressed3',
  }

  APKCERTS_TXT3 = (
      'name="Compressed4.apk" certificate="certs/compressed4.x509.pem"'
      ' private_key="certs/compressed4.pk8" compressed="xz"\n'
  )

  APKCERTS_CERTMAP3 = {
      'Compressed4.apk': 'certs/compressed4',
  }

  # Test parsing with no optional fields, both optional fields, and only the
  # partition optional field.
  APKCERTS_TXT4 = (
      'name="RecoveryLocalizer.apk" certificate="certs/devkey.x509.pem"'
      ' private_key="certs/devkey.pk8"\n'
      'name="Settings.apk"'
      ' certificate="build/make/target/product/security/platform.x509.pem"'
      ' private_key="build/make/target/product/security/platform.pk8"'
      ' compressed="gz" partition="system"\n'
      'name="TV.apk" certificate="PRESIGNED" private_key=""'
      ' partition="product"\n'
  )

  APKCERTS_CERTMAP4 = {
      'RecoveryLocalizer.apk': 'certs/devkey',
      'Settings.apk': 'build/make/target/product/security/platform',
      'TV.apk': 'PRESIGNED',
  }

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  @staticmethod
  def _write_apkcerts_txt(apkcerts_txt, additional=None):
    if additional is None:
      additional = []
    target_files = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
      target_files_zip.writestr('META/apkcerts.txt', apkcerts_txt)
      for entry in additional:
        target_files_zip.writestr(entry, '')
    return target_files

  def test_ReadApkCerts_NoncompressedApks(self):
    target_files = self._write_apkcerts_txt(self.APKCERTS_TXT1)
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    self.assertDictEqual(self.APKCERTS_CERTMAP1, certmap)
    self.assertIsNone(ext)

  def test_ReadApkCerts_CompressedApks(self):
    # We have "installed" Compressed1.apk.gz only. Note that Compressed3.apk is
    # not stored in '.gz' format, so it shouldn't be considered as installed.
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT2,
        ['Compressed1.apk.gz', 'Compressed3.apk'])

    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    self.assertDictEqual(self.APKCERTS_CERTMAP2, certmap)
    self.assertEqual('.gz', ext)

    # Alternative case with '.xz'.
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT3, ['Compressed4.apk.xz'])

    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    self.assertDictEqual(self.APKCERTS_CERTMAP3, certmap)
    self.assertEqual('.xz', ext)

  def test_ReadApkCerts_CompressedAndNoncompressedApks(self):
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT1 + self.APKCERTS_TXT2,
        ['Compressed1.apk.gz', 'Compressed3.apk'])

    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    certmap_merged = self.APKCERTS_CERTMAP1.copy()
    certmap_merged.update(self.APKCERTS_CERTMAP2)
    self.assertDictEqual(certmap_merged, certmap)
    self.assertEqual('.gz', ext)

  def test_ReadApkCerts_MultipleCompressionMethods(self):
    target_files = self._write_apkcerts_txt(
        self.APKCERTS_TXT2 + self.APKCERTS_TXT3,
        ['Compressed1.apk.gz', 'Compressed4.apk.xz'])

    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      self.assertRaises(ValueError, common.ReadApkCerts, input_zip)

  def test_ReadApkCerts_MismatchingKeys(self):
    malformed_apkcerts_txt = (
        'name="App1.apk" certificate="certs/cert1.x509.pem"'
        ' private_key="certs/cert2.pk8"\n'
    )
    target_files = self._write_apkcerts_txt(malformed_apkcerts_txt)

    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      self.assertRaises(ValueError, common.ReadApkCerts, input_zip)

  def test_ReadApkCerts_WithWithoutOptionalFields(self):
    target_files = self._write_apkcerts_txt(self.APKCERTS_TXT4)
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      certmap, ext = common.ReadApkCerts(input_zip)

    self.assertDictEqual(self.APKCERTS_CERTMAP4, certmap)
    self.assertIsNone(ext)

  def test_ExtractPublicKey(self):
    cert = os.path.join(self.testdata_dir, 'testkey.x509.pem')
    pubkey = os.path.join(self.testdata_dir, 'testkey.pubkey.pem')
    with open(pubkey) as pubkey_fp:
      self.assertEqual(pubkey_fp.read(), common.ExtractPublicKey(cert))

  def test_ExtractPublicKey_invalidInput(self):
    wrong_input = os.path.join(self.testdata_dir, 'testkey.pk8')
    self.assertRaises(AssertionError, common.ExtractPublicKey, wrong_input)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_ExtractAvbPublicKey(self):
    privkey = os.path.join(self.testdata_dir, 'testkey.key')
    pubkey = os.path.join(self.testdata_dir, 'testkey.pubkey.pem')
    extracted_from_privkey = common.ExtractAvbPublicKey('avbtool', privkey)
    extracted_from_pubkey = common.ExtractAvbPublicKey('avbtool', pubkey)
    with open(extracted_from_privkey, 'rb') as privkey_fp, \
            open(extracted_from_pubkey, 'rb') as pubkey_fp:
      self.assertEqual(privkey_fp.read(), pubkey_fp.read())

  def test_ParseCertificate(self):
    cert = os.path.join(self.testdata_dir, 'testkey.x509.pem')

    cmd = ['openssl', 'x509', '-in', cert, '-outform', 'DER']
    proc = common.Run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                      universal_newlines=False)
    expected, _ = proc.communicate()
    self.assertEqual(0, proc.returncode)

    with open(cert) as cert_fp:
      actual = common.ParseCertificate(cert_fp.read())
    self.assertEqual(expected, actual)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetMinSdkVersion(self):
    test_app = os.path.join(self.testdata_dir, 'TestApp.apk')
    self.assertEqual('24', common.GetMinSdkVersion(test_app))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetMinSdkVersion_invalidInput(self):
    self.assertRaises(
        common.ExternalError, common.GetMinSdkVersion, 'does-not-exist.apk')

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetMinSdkVersionInt(self):
    test_app = os.path.join(self.testdata_dir, 'TestApp.apk')
    self.assertEqual(24, common.GetMinSdkVersionInt(test_app, {}))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetMinSdkVersionInt_invalidInput(self):
    self.assertRaises(
        common.ExternalError, common.GetMinSdkVersionInt, 'does-not-exist.apk',
        {})


class CommonUtilsTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_emptyBlockMapFile(self):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
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
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      sparse_image = common.GetSparseImage('system', tempdir, input_zip, False)

    self.assertDictEqual(
        {
            '__COPY': RangeSet("0"),
            '__NONZERO-0': RangeSet("1-5 9-12"),
        },
        sparse_image.file_map)

  def test_PartitionMapFromTargetFiles(self):
    target_files_dir = common.MakeTempDir()
    os.makedirs(os.path.join(target_files_dir, 'SYSTEM'))
    os.makedirs(os.path.join(target_files_dir, 'SYSTEM', 'vendor'))
    os.makedirs(os.path.join(target_files_dir, 'PRODUCT'))
    os.makedirs(os.path.join(target_files_dir, 'SYSTEM', 'product'))
    os.makedirs(os.path.join(target_files_dir, 'SYSTEM', 'vendor', 'odm'))
    os.makedirs(os.path.join(target_files_dir, 'VENDOR_DLKM'))
    partition_map = common.PartitionMapFromTargetFiles(target_files_dir)
    self.assertDictEqual(
        partition_map,
        {
            'system': 'SYSTEM',
            'vendor': 'SYSTEM/vendor',
            # Prefer PRODUCT over SYSTEM/product
            'product': 'PRODUCT',
            'odm': 'SYSTEM/vendor/odm',
            'vendor_dlkm': 'VENDOR_DLKM',
            # No system_ext or odm_dlkm
        })

  def test_SharedUidPartitionViolations(self):
    uid_dict = {
        'android.uid.phone': {
            'system': ['system_phone.apk'],
            'system_ext': ['system_ext_phone.apk'],
        },
        'android.uid.wifi': {
            'vendor': ['vendor_wifi.apk'],
            'odm': ['odm_wifi.apk'],
        },
    }
    errors = common.SharedUidPartitionViolations(
        uid_dict, [('system', 'system_ext'), ('vendor', 'odm')])
    self.assertEqual(errors, [])

  def test_SharedUidPartitionViolations_Violation(self):
    uid_dict = {
        'android.uid.phone': {
            'system': ['system_phone.apk'],
            'vendor': ['vendor_phone.apk'],
        },
    }
    errors = common.SharedUidPartitionViolations(
        uid_dict, [('system', 'system_ext'), ('vendor', 'odm')])
    self.assertIn(
        ('APK sharedUserId "android.uid.phone" found across partition groups '
         'in partitions "system,vendor"'), errors)

  def test_GetSparseImage_missingImageFile(self):
    self.assertRaises(
        AssertionError, common.GetSparseImage, 'system2', self.testdata_dir,
        None, False)
    self.assertRaises(
        AssertionError, common.GetSparseImage, 'unknown', self.testdata_dir,
        None, False)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_missingBlockMapFile(self):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([
              (0xCAC1, 6),
              (0xCAC3, 3),
              (0xCAC1, 4)]),
          arcname='IMAGES/system.img')
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 8))
      target_files_zip.writestr('SYSTEM/file2', os.urandom(4096 * 3))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      self.assertRaises(
          AssertionError, common.GetSparseImage, 'system', tempdir, input_zip,
          False)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_sharedBlocks_notAllowed(self):
    """Tests the case of having overlapping blocks but disallowed."""
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
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
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      self.assertRaises(
          AssertionError, common.GetSparseImage, 'system', tempdir, input_zip,
          False)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_sharedBlocks_allowed(self):
    """Tests the case for target using BOARD_EXT4_SHARE_DUP_BLOCKS := true."""
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
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
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
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

    # '/system/file1' will only contain one field -- a copy of the input text.
    self.assertEqual(1, len(sparse_image.file_map['/system/file1'].extra))

    # Meta entries should not have any extra tag.
    self.assertFalse(sparse_image.file_map['__COPY'].extra)
    self.assertFalse(sparse_image.file_map['__NONZERO-0'].extra)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_incompleteRanges(self):
    """Tests the case of ext4 images with holes."""
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
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
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      sparse_image = common.GetSparseImage('system', tempdir, input_zip, False)

    self.assertEqual(
        '1-5 9-10',
        sparse_image.file_map['/system/file1'].extra['text_str'])
    self.assertTrue(sparse_image.file_map['/system/file2'].extra['incomplete'])

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_systemRootImage_filenameWithExtraLeadingSlash(self):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([(0xCAC2, 16)]),
          arcname='IMAGES/system.img')
      target_files_zip.writestr(
          'IMAGES/system.map',
          '\n'.join([
              '//system/file1 1-5 9-10',
              '//system/file2 11-12',
              '/system/app/file3 13-15']))
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 7))
      # '/system/file2' has less blocks listed (2) than actual (3).
      target_files_zip.writestr('SYSTEM/file2', os.urandom(4096 * 3))
      # '/system/app/file3' has less blocks listed (3) than actual (4).
      target_files_zip.writestr('SYSTEM/app/file3', os.urandom(4096 * 4))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      sparse_image = common.GetSparseImage('system', tempdir, input_zip, False)

    self.assertEqual(
        '1-5 9-10',
        sparse_image.file_map['//system/file1'].extra['text_str'])
    self.assertTrue(
        sparse_image.file_map['//system/file2'].extra['incomplete'])
    self.assertTrue(
        sparse_image.file_map['/system/app/file3'].extra['incomplete'])

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_systemRootImage_nonSystemFiles(self):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([(0xCAC2, 16)]),
          arcname='IMAGES/system.img')
      target_files_zip.writestr(
          'IMAGES/system.map',
          '\n'.join([
              '//system/file1 1-5 9-10',
              '//init.rc 13-15']))
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 7))
      # '/init.rc' has less blocks listed (3) than actual (4).
      target_files_zip.writestr('ROOT/init.rc', os.urandom(4096 * 4))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      sparse_image = common.GetSparseImage('system', tempdir, input_zip, False)

    self.assertEqual(
        '1-5 9-10',
        sparse_image.file_map['//system/file1'].extra['text_str'])
    self.assertTrue(sparse_image.file_map['//init.rc'].extra['incomplete'])

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetSparseImage_fileNotFound(self):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
      target_files_zip.write(
          test_utils.construct_sparse_image([(0xCAC2, 16)]),
          arcname='IMAGES/system.img')
      target_files_zip.writestr(
          'IMAGES/system.map',
          '\n'.join([
              '//system/file1 1-5 9-10',
              '//system/file2 11-12']))
      target_files_zip.writestr('SYSTEM/file1', os.urandom(4096 * 7))

    tempdir = common.UnzipTemp(target_files)
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as input_zip:
      self.assertRaises(
          AssertionError, common.GetSparseImage, 'system', tempdir, input_zip,
          False)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetAvbChainedPartitionArg(self):
    pubkey = os.path.join(self.testdata_dir, 'testkey.pubkey.pem')
    info_dict = {
        'avb_avbtool': 'avbtool',
        'avb_system_key_path': pubkey,
        'avb_system_rollback_index_location': 2,
    }
    chained_partition_args = common.GetAvbChainedPartitionArg(
        'system', info_dict)
    self.assertEqual('system', chained_partition_args.partition)
    self.assertEqual(2, chained_partition_args.rollback_index_location)
    self.assertTrue(os.path.exists(chained_partition_args.pubkey_path))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetAvbChainedPartitionArg_withPrivateKey(self):
    key = os.path.join(self.testdata_dir, 'testkey.key')
    info_dict = {
        'avb_avbtool': 'avbtool',
        'avb_product_key_path': key,
        'avb_product_rollback_index_location': 2,
    }
    chained_partition_args = common.GetAvbChainedPartitionArg(
        'product', info_dict)
    self.assertEqual('product', chained_partition_args.partition)
    self.assertEqual(2, chained_partition_args.rollback_index_location)
    self.assertTrue(os.path.exists(chained_partition_args.pubkey_path))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetAvbChainedPartitionArg_withSpecifiedKey(self):
    info_dict = {
        'avb_avbtool': 'avbtool',
        'avb_system_key_path': 'does-not-exist',
        'avb_system_rollback_index_location': 2,
    }
    pubkey = os.path.join(self.testdata_dir, 'testkey.pubkey.pem')
    chained_partition_args = common.GetAvbChainedPartitionArg(
        'system', info_dict, pubkey)
    self.assertEqual('system', chained_partition_args.partition)
    self.assertEqual(2, chained_partition_args.rollback_index_location)
    self.assertTrue(os.path.exists(chained_partition_args.pubkey_path))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetAvbChainedPartitionArg_invalidKey(self):
    pubkey = os.path.join(self.testdata_dir, 'testkey_with_passwd.x509.pem')
    info_dict = {
        'avb_avbtool': 'avbtool',
        'avb_system_key_path': pubkey,
        'avb_system_rollback_index_location': 2,
    }
    self.assertRaises(
        common.ExternalError, common.GetAvbChainedPartitionArg, 'system',
        info_dict)

  INFO_DICT_DEFAULT = {
      'recovery_api_version': 3,
      'fstab_version': 2,
      'no_recovery': 'true',
      'recovery_as_boot': 'true',
  }

  def test_LoadListFromFile(self):
    file_path = os.path.join(self.testdata_dir,
                             'merge_config_framework_item_list')
    contents = common.LoadListFromFile(file_path)
    expected_contents = [
        'META/apkcerts.txt',
        'META/filesystem_config.txt',
        'META/root_filesystem_config.txt',
        'META/system_manifest.xml',
        'META/system_matrix.xml',
        'META/update_engine_config.txt',
        'PRODUCT/*',
        'ROOT/*',
        'SYSTEM/*',
    ]
    self.assertEqual(sorted(contents), sorted(expected_contents))

  @staticmethod
  def _test_LoadInfoDict_createTargetFiles(info_dict, fstab_path):
    target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
      info_values = ''.join(
          ['{}={}\n'.format(k, v) for k, v in sorted(info_dict.items())])
      common.ZipWriteStr(target_files_zip, 'META/misc_info.txt', info_values)
      common.ZipWriteStr(target_files_zip, fstab_path,
                         "/dev/block/system /system ext4 ro,barrier=1 defaults")
      common.ZipWriteStr(
          target_files_zip, 'META/file_contexts', 'file-contexts')
    return target_files

  def test_LoadInfoDict(self):
    target_files = self._test_LoadInfoDict_createTargetFiles(
        self.INFO_DICT_DEFAULT,
        'BOOT/RAMDISK/system/etc/recovery.fstab')
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as target_files_zip:
      loaded_dict = common.LoadInfoDict(target_files_zip)
      self.assertEqual(3, loaded_dict['recovery_api_version'])
      self.assertEqual(2, loaded_dict['fstab_version'])
      self.assertIn('/system', loaded_dict['fstab'])

  def test_LoadInfoDict_legacyRecoveryFstabPath(self):
    target_files = self._test_LoadInfoDict_createTargetFiles(
        self.INFO_DICT_DEFAULT,
        'BOOT/RAMDISK/etc/recovery.fstab')
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as target_files_zip:
      loaded_dict = common.LoadInfoDict(target_files_zip)
      self.assertEqual(3, loaded_dict['recovery_api_version'])
      self.assertEqual(2, loaded_dict['fstab_version'])
      self.assertIn('/system', loaded_dict['fstab'])

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_LoadInfoDict_dirInput(self):
    target_files = self._test_LoadInfoDict_createTargetFiles(
        self.INFO_DICT_DEFAULT,
        'BOOT/RAMDISK/system/etc/recovery.fstab')
    unzipped = common.UnzipTemp(target_files)
    loaded_dict = common.LoadInfoDict(unzipped)
    self.assertEqual(3, loaded_dict['recovery_api_version'])
    self.assertEqual(2, loaded_dict['fstab_version'])
    self.assertIn('/system', loaded_dict['fstab'])

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_LoadInfoDict_dirInput_legacyRecoveryFstabPath(self):
    target_files = self._test_LoadInfoDict_createTargetFiles(
        self.INFO_DICT_DEFAULT,
        'BOOT/RAMDISK/system/etc/recovery.fstab')
    unzipped = common.UnzipTemp(target_files)
    loaded_dict = common.LoadInfoDict(unzipped)
    self.assertEqual(3, loaded_dict['recovery_api_version'])
    self.assertEqual(2, loaded_dict['fstab_version'])
    self.assertIn('/system', loaded_dict['fstab'])

  def test_LoadInfoDict_recoveryAsBootFalse(self):
    info_dict = copy.copy(self.INFO_DICT_DEFAULT)
    del info_dict['no_recovery']
    del info_dict['recovery_as_boot']
    target_files = self._test_LoadInfoDict_createTargetFiles(
        info_dict,
        'RECOVERY/RAMDISK/system/etc/recovery.fstab')
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as target_files_zip:
      loaded_dict = common.LoadInfoDict(target_files_zip)
      self.assertEqual(3, loaded_dict['recovery_api_version'])
      self.assertEqual(2, loaded_dict['fstab_version'])
      self.assertNotIn('/', loaded_dict['fstab'])
      self.assertIn('/system', loaded_dict['fstab'])

  def test_LoadInfoDict_noRecoveryTrue(self):
    # Device doesn't have a recovery partition at all.
    info_dict = copy.copy(self.INFO_DICT_DEFAULT)
    del info_dict['recovery_as_boot']
    target_files = self._test_LoadInfoDict_createTargetFiles(
        info_dict,
        'RECOVERY/RAMDISK/system/etc/recovery.fstab')
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as target_files_zip:
      loaded_dict = common.LoadInfoDict(target_files_zip)
      self.assertEqual(3, loaded_dict['recovery_api_version'])
      self.assertEqual(2, loaded_dict['fstab_version'])
      self.assertIsNone(loaded_dict['fstab'])

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_LoadInfoDict_missingMetaMiscInfoTxt(self):
    target_files = self._test_LoadInfoDict_createTargetFiles(
        self.INFO_DICT_DEFAULT,
        'BOOT/RAMDISK/system/etc/recovery.fstab')
    common.ZipDelete(target_files, 'META/misc_info.txt')
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as target_files_zip:
      self.assertRaises(ValueError, common.LoadInfoDict, target_files_zip)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_LoadInfoDict_repacking(self):
    target_files = self._test_LoadInfoDict_createTargetFiles(
        self.INFO_DICT_DEFAULT,
        'BOOT/RAMDISK/system/etc/recovery.fstab')
    unzipped = common.UnzipTemp(target_files)
    loaded_dict = common.LoadInfoDict(unzipped, True)
    self.assertEqual(3, loaded_dict['recovery_api_version'])
    self.assertEqual(2, loaded_dict['fstab_version'])
    self.assertIn('/system', loaded_dict['fstab'])
    self.assertEqual(
        os.path.join(unzipped, 'ROOT'), loaded_dict['root_dir'])
    self.assertEqual(
        os.path.join(unzipped, 'META', 'root_filesystem_config.txt'),
        loaded_dict['root_fs_config'])

  def test_LoadInfoDict_repackingWithZipFileInput(self):
    target_files = self._test_LoadInfoDict_createTargetFiles(
        self.INFO_DICT_DEFAULT,
        'BOOT/RAMDISK/system/etc/recovery.fstab')
    with zipfile.ZipFile(target_files, 'r', allowZip64=True) as target_files_zip:
      self.assertRaises(
          AssertionError, common.LoadInfoDict, target_files_zip, True)

  def test_MergeDynamicPartitionInfoDicts_ReturnsMergedDict(self):
    framework_dict = {
        'use_dynamic_partitions': 'true',
        'super_partition_groups': 'group_a',
        'dynamic_partition_list': 'system',
        'super_group_a_partition_list': 'system',
    }
    vendor_dict = {
        'use_dynamic_partitions': 'true',
        'super_partition_groups': 'group_a group_b',
        'dynamic_partition_list': 'vendor product',
        'super_block_devices': 'super',
        'super_super_device_size': '3000',
        'super_group_a_partition_list': 'vendor',
        'super_group_a_group_size': '1000',
        'super_group_b_partition_list': 'product',
        'super_group_b_group_size': '2000',
    }
    merged_dict = common.MergeDynamicPartitionInfoDicts(
        framework_dict=framework_dict,
        vendor_dict=vendor_dict)
    expected_merged_dict = {
        'use_dynamic_partitions': 'true',
        'super_partition_groups': 'group_a group_b',
        'dynamic_partition_list': 'product system vendor',
        'super_block_devices': 'super',
        'super_super_device_size': '3000',
        'super_group_a_partition_list': 'system vendor',
        'super_group_a_group_size': '1000',
        'super_group_b_partition_list': 'product',
        'super_group_b_group_size': '2000',
        'vabc_cow_version': '2',
    }
    self.assertEqual(merged_dict, expected_merged_dict)

  def test_MergeDynamicPartitionInfoDicts_IgnoringFrameworkGroupSize(self):
    framework_dict = {
        'use_dynamic_partitions': 'true',
        'super_partition_groups': 'group_a',
        'dynamic_partition_list': 'system',
        'super_group_a_partition_list': 'system',
        'super_group_a_group_size': '5000',
        'vabc_cow_version': '3',
    }
    vendor_dict = {
        'use_dynamic_partitions': 'true',
        'super_partition_groups': 'group_a group_b',
        'dynamic_partition_list': 'vendor product',
        'super_group_a_partition_list': 'vendor',
        'super_group_a_group_size': '1000',
        'super_group_b_partition_list': 'product',
        'super_group_b_group_size': '2000',
    }
    merged_dict = common.MergeDynamicPartitionInfoDicts(
        framework_dict=framework_dict,
        vendor_dict=vendor_dict)
    expected_merged_dict = {
        'use_dynamic_partitions': 'true',
        'super_partition_groups': 'group_a group_b',
        'dynamic_partition_list': 'product system vendor',
        'super_group_a_partition_list': 'system vendor',
        'super_group_a_group_size': '1000',
        'super_group_b_partition_list': 'product',
        'super_group_b_group_size': '2000',
        'vabc_cow_version': '2',
    }
    self.assertEqual(merged_dict, expected_merged_dict)

  def test_GetAvbPartitionArg(self):
    info_dict = {}
    cmd = common.GetAvbPartitionArg('system', '/path/to/system.img', info_dict)
    self.assertEqual(
        [common.AVB_ARG_NAME_INCLUDE_DESC_FROM_IMG, '/path/to/system.img'],
        cmd)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AppendVBMetaArgsForPartition_vendorAsChainedPartition(self):
    testdata_dir = test_utils.get_testdata_dir()
    pubkey = os.path.join(testdata_dir, 'testkey.pubkey.pem')
    info_dict = {
        'avb_avbtool': 'avbtool',
        'avb_vendor_key_path': pubkey,
        'avb_vendor_rollback_index_location': 5,
    }
    cmd = common.GetAvbPartitionArg('vendor', '/path/to/vendor.img', info_dict)
    self.assertEqual(2, len(cmd))
    self.assertEqual(common.AVB_ARG_NAME_CHAIN_PARTITION, cmd[0])
    chained_partition_args = cmd[1]
    self.assertEqual('vendor', chained_partition_args.partition)
    self.assertEqual(5, chained_partition_args.rollback_index_location)
    self.assertTrue(os.path.exists(chained_partition_args.pubkey_path))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AppendVBMetaArgsForPartition_recoveryAsChainedPartition_nonAb(self):
    testdata_dir = test_utils.get_testdata_dir()
    pubkey = os.path.join(testdata_dir, 'testkey.pubkey.pem')
    info_dict = {
        'avb_avbtool': 'avbtool',
        'avb_recovery_key_path': pubkey,
        'avb_recovery_rollback_index_location': 3,
    }
    cmd = common.GetAvbPartitionArg(
        'recovery', '/path/to/recovery.img', info_dict)
    self.assertFalse(cmd)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AppendVBMetaArgsForPartition_recoveryAsChainedPartition_ab(self):
    testdata_dir = test_utils.get_testdata_dir()
    pubkey = os.path.join(testdata_dir, 'testkey.pubkey.pem')
    info_dict = {
        'ab_update': 'true',
        'avb_avbtool': 'avbtool',
        'avb_recovery_key_path': pubkey,
        'avb_recovery_rollback_index_location': 3,
    }
    cmd = common.GetAvbPartitionArg(
        'recovery', '/path/to/recovery.img', info_dict)
    self.assertEqual(2, len(cmd))
    self.assertEqual(common.AVB_ARG_NAME_CHAIN_PARTITION, cmd[0])
    chained_partition_args = cmd[1]
    self.assertEqual('recovery', chained_partition_args.partition)
    self.assertEqual(3, chained_partition_args.rollback_index_location)
    self.assertTrue(os.path.exists(chained_partition_args.pubkey_path))


class InstallRecoveryScriptFormatTest(test_utils.ReleaseToolsTestCase):
  """Checks the format of install-recovery.sh.

  Its format should match between common.py and validate_target_files.py.
  """

  def setUp(self):
    self._tempdir = common.MakeTempDir()
    # Create a fake dict that contains the fstab info for boot&recovery.
    self._info = {"fstab": {}}
    fake_fstab = [
        "/dev/soc.0/by-name/boot /boot emmc defaults defaults",
        "/dev/soc.0/by-name/recovery /recovery emmc defaults defaults"]
    self._info["fstab"] = common.LoadRecoveryFSTab("\n".join, 2, fake_fstab)
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
    with open(loc, "wb") as f:
      f.write(data)

  def test_full_recovery(self):
    recovery_image = common.File("recovery.img", self.recovery_data)
    boot_image = common.File("boot.img", self.boot_data)
    self._info["full_recovery_image"] = "true"

    common.MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)

  @test_utils.SkipIfExternalToolsUnavailable()
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
    self._out_tmp_sink("etc/recovery-resource.dat", b"bonus", "SYSTEM")
    common.MakeRecoveryPatch(self._tempdir, self._out_tmp_sink,
                             recovery_image, boot_image, self._info)
    validate_target_files.ValidateInstallRecoveryScript(self._tempdir,
                                                        self._info)


class MockBlockDifference(object):

  def __init__(self, partition, tgt, src=None):
    self.partition = partition
    self.tgt = tgt
    self.src = src

  def WriteScript(self, script, _, progress=None,
                  write_verify_script=False):
    if progress:
      script.AppendExtra("progress({})".format(progress))
    script.AppendExtra("patch({});".format(self.partition))
    if write_verify_script:
      self.WritePostInstallVerifyScript(script)

  def WritePostInstallVerifyScript(self, script):
    script.AppendExtra("verify({});".format(self.partition))


class FakeSparseImage(object):

  def __init__(self, size):
    self.blocksize = 4096
    self.total_blocks = size // 4096
    assert size % 4096 == 0, "{} is not a multiple of 4096".format(size)


class DynamicPartitionsDifferenceTest(test_utils.ReleaseToolsTestCase):

  @staticmethod
  def get_op_list(output_path):
    with zipfile.ZipFile(output_path, allowZip64=True) as output_zip:
      with output_zip.open('dynamic_partitions_op_list') as op_list:
        return [line.decode().strip() for line in op_list.readlines()
                if not line.startswith(b'#')]

  def setUp(self):
    self.script = test_utils.MockScriptWriter()
    self.output_path = common.MakeTempFile(suffix='.zip')

  def test_full(self):
    target_info = common.LoadDictionaryFromLines("""
dynamic_partition_list=system vendor
super_partition_groups=group_foo
super_group_foo_group_size={group_size}
super_group_foo_partition_list=system vendor
""".format(group_size=4 * GiB).split("\n"))
    block_diffs = [MockBlockDifference("system", FakeSparseImage(3 * GiB)),
                   MockBlockDifference("vendor", FakeSparseImage(1 * GiB))]

    dp_diff = common.DynamicPartitionsDifference(target_info, block_diffs)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    self.assertEqual(str(self.script).strip(), """
assert(update_dynamic_partitions(package_extract_file("dynamic_partitions_op_list")));
patch(system);
verify(system);
unmap_partition("system");
patch(vendor);
verify(vendor);
unmap_partition("vendor");
""".strip())

    lines = self.get_op_list(self.output_path)

    remove_all_groups = lines.index("remove_all_groups")
    add_group = lines.index("add_group group_foo 4294967296")
    add_vendor = lines.index("add vendor group_foo")
    add_system = lines.index("add system group_foo")
    resize_vendor = lines.index("resize vendor 1073741824")
    resize_system = lines.index("resize system 3221225472")

    self.assertLess(remove_all_groups, add_group,
                    "Should add groups after removing all groups")
    self.assertLess(add_group, min(add_vendor, add_system),
                    "Should add partitions after adding group")
    self.assertLess(add_system, resize_system,
                    "Should resize system after adding it")
    self.assertLess(add_vendor, resize_vendor,
                    "Should resize vendor after adding it")

  def test_inc_groups(self):
    source_info = common.LoadDictionaryFromLines("""
super_partition_groups=group_foo group_bar group_baz
super_group_foo_group_size={group_foo_size}
super_group_bar_group_size={group_bar_size}
""".format(group_foo_size=4 * GiB, group_bar_size=3 * GiB).split("\n"))
    target_info = common.LoadDictionaryFromLines("""
super_partition_groups=group_foo group_baz group_qux
super_group_foo_group_size={group_foo_size}
super_group_baz_group_size={group_baz_size}
super_group_qux_group_size={group_qux_size}
""".format(group_foo_size=3 * GiB, group_baz_size=4 * GiB,
           group_qux_size=1 * GiB).split("\n"))

    dp_diff = common.DynamicPartitionsDifference(target_info,
                                                 block_diffs=[],
                                                 source_info_dict=source_info)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    lines = self.get_op_list(self.output_path)

    removed = lines.index("remove_group group_bar")
    shrunk = lines.index("resize_group group_foo 3221225472")
    grown = lines.index("resize_group group_baz 4294967296")
    added = lines.index("add_group group_qux 1073741824")

    self.assertLess(max(removed, shrunk),
                    min(grown, added),
                    "ops that remove / shrink partitions must precede ops that "
                    "grow / add partitions")

  def test_incremental(self):
    source_info = common.LoadDictionaryFromLines("""
dynamic_partition_list=system vendor product system_ext
super_partition_groups=group_foo
super_group_foo_group_size={group_foo_size}
super_group_foo_partition_list=system vendor product system_ext
""".format(group_foo_size=4 * GiB).split("\n"))
    target_info = common.LoadDictionaryFromLines("""
dynamic_partition_list=system vendor product odm
super_partition_groups=group_foo group_bar
super_group_foo_group_size={group_foo_size}
super_group_foo_partition_list=system vendor odm
super_group_bar_group_size={group_bar_size}
super_group_bar_partition_list=product
""".format(group_foo_size=3 * GiB, group_bar_size=1 * GiB).split("\n"))

    block_diffs = [MockBlockDifference("system", FakeSparseImage(1536 * MiB),
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("vendor", FakeSparseImage(512 * MiB),
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("product", FakeSparseImage(1024 * MiB),
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("system_ext", None,
                                       src=FakeSparseImage(1024 * MiB)),
                   MockBlockDifference("odm", FakeSparseImage(1024 * MiB),
                                       src=None)]

    dp_diff = common.DynamicPartitionsDifference(target_info, block_diffs,
                                                 source_info_dict=source_info)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    metadata_idx = self.script.lines.index(
        'assert(update_dynamic_partitions(package_extract_file('
        '"dynamic_partitions_op_list")));')
    self.assertLess(self.script.lines.index('patch(vendor);'), metadata_idx)
    self.assertLess(metadata_idx, self.script.lines.index('verify(vendor);'))
    for p in ("product", "system", "odm"):
      patch_idx = self.script.lines.index("patch({});".format(p))
      verify_idx = self.script.lines.index("verify({});".format(p))
      self.assertLess(metadata_idx, patch_idx,
                      "Should patch {} after updating metadata".format(p))
      self.assertLess(patch_idx, verify_idx,
                      "Should verify {} after patching".format(p))

    self.assertNotIn("patch(system_ext);", self.script.lines)

    lines = self.get_op_list(self.output_path)

    remove = lines.index("remove system_ext")
    move_product_out = lines.index("move product default")
    shrink = lines.index("resize vendor 536870912")
    shrink_group = lines.index("resize_group group_foo 3221225472")
    add_group_bar = lines.index("add_group group_bar 1073741824")
    add_odm = lines.index("add odm group_foo")
    grow_existing = lines.index("resize system 1610612736")
    grow_added = lines.index("resize odm 1073741824")
    move_product_in = lines.index("move product group_bar")

    max_idx_move_partition_out_foo = max(remove, move_product_out, shrink)
    min_idx_move_partition_in_foo = min(add_odm, grow_existing, grow_added)

    self.assertLess(max_idx_move_partition_out_foo, shrink_group,
                    "Must shrink group after partitions inside group are shrunk"
                    " / removed")

    self.assertLess(add_group_bar, move_product_in,
                    "Must add partitions to group after group is added")

    self.assertLess(max_idx_move_partition_out_foo,
                    min_idx_move_partition_in_foo,
                    "Must shrink partitions / remove partitions from group"
                    "before adding / moving partitions into group")

  def test_remove_partition(self):
    source_info = common.LoadDictionaryFromLines("""
blockimgdiff_versions=3,4
use_dynamic_partitions=true
dynamic_partition_list=foo
super_partition_groups=group_foo
super_group_foo_group_size={group_foo_size}
super_group_foo_partition_list=foo
""".format(group_foo_size=4 * GiB).split("\n"))
    target_info = common.LoadDictionaryFromLines("""
blockimgdiff_versions=3,4
use_dynamic_partitions=true
super_partition_groups=group_foo
super_group_foo_group_size={group_foo_size}
""".format(group_foo_size=4 * GiB).split("\n"))

    common.OPTIONS.info_dict = target_info
    common.OPTIONS.target_info_dict = target_info
    common.OPTIONS.source_info_dict = source_info
    common.OPTIONS.cache_size = 4 * 4096

    block_diffs = [common.BlockDifference("foo", EmptyImage(),
                                          src=DataImage("source", pad=True))]

    dp_diff = common.DynamicPartitionsDifference(target_info, block_diffs,
                                                 source_info_dict=source_info)
    with zipfile.ZipFile(self.output_path, 'w', allowZip64=True) as output_zip:
      dp_diff.WriteScript(self.script, output_zip, write_verify_script=True)

    self.assertNotIn("block_image_update", str(self.script),
                     "Removed partition should not be patched.")

    lines = self.get_op_list(self.output_path)
    self.assertEqual(lines, ["remove foo"])


class PartitionBuildPropsTest(test_utils.ReleaseToolsTestCase):
  def setUp(self):
    self.odm_build_prop = [
        'ro.odm.build.date.utc=1578430045',
        'ro.odm.build.fingerprint='
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device=coral',
        'import /odm/etc/build_${ro.boot.product.device_name}.prop',
    ]

  @staticmethod
  def _BuildZipFile(entries):
    input_file = common.MakeTempFile(prefix='target_files-', suffix='.zip')
    with zipfile.ZipFile(input_file, 'w', allowZip64=True) as input_zip:
      for name, content in entries.items():
        input_zip.writestr(name, content)

    return input_file

  def test_parseBuildProps_noImportStatement(self):
    build_prop = [
        'ro.odm.build.date.utc=1578430045',
        'ro.odm.build.fingerprint='
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device=coral',
    ]
    input_file = self._BuildZipFile({
        'ODM/etc/build.prop': '\n'.join(build_prop),
    })

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': ['std', 'pro']
      }
      partition_props = common.PartitionBuildProps.FromInputFile(
          input_zip, 'odm', placeholder_values)

    self.assertEqual({
        'ro.odm.build.date.utc': '1578430045',
        'ro.odm.build.fingerprint':
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device': 'coral',
    }, partition_props.build_props)

    self.assertEqual(set(), partition_props.prop_overrides)

  def test_parseBuildProps_singleImportStatement(self):
    build_std_prop = [
        'ro.product.odm.device=coral',
        'ro.product.odm.name=product1',
    ]
    build_pro_prop = [
        'ro.product.odm.device=coralpro',
        'ro.product.odm.name=product2',
    ]

    input_file = self._BuildZipFile({
        'ODM/etc/build.prop': '\n'.join(self.odm_build_prop),
        'ODM/etc/build_std.prop': '\n'.join(build_std_prop),
        'ODM/etc/build_pro.prop': '\n'.join(build_pro_prop),
    })

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': 'std'
      }
      partition_props = common.PartitionBuildProps.FromInputFile(
          input_zip, 'odm', placeholder_values)

    self.assertEqual({
        'ro.odm.build.date.utc': '1578430045',
        'ro.odm.build.fingerprint':
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device': 'coral',
        'ro.product.odm.name': 'product1',
    }, partition_props.build_props)

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': 'pro'
      }
      partition_props = common.PartitionBuildProps.FromInputFile(
          input_zip, 'odm', placeholder_values)

    self.assertEqual({
        'ro.odm.build.date.utc': '1578430045',
        'ro.odm.build.fingerprint':
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device': 'coralpro',
        'ro.product.odm.name': 'product2',
    }, partition_props.build_props)

  def test_parseBuildProps_noPlaceHolders(self):
    build_prop = copy.copy(self.odm_build_prop)
    input_file = self._BuildZipFile({
        'ODM/etc/build.prop': '\n'.join(build_prop),
    })

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      partition_props = common.PartitionBuildProps.FromInputFile(
          input_zip, 'odm')

    self.assertEqual({
        'ro.odm.build.date.utc': '1578430045',
        'ro.odm.build.fingerprint':
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device': 'coral',
    }, partition_props.build_props)

    self.assertEqual(set(), partition_props.prop_overrides)

  def test_parseBuildProps_multipleImportStatements(self):
    build_prop = copy.deepcopy(self.odm_build_prop)
    build_prop.append(
        'import /odm/etc/build_${ro.boot.product.product_name}.prop')

    build_std_prop = [
        'ro.product.odm.device=coral',
    ]
    build_pro_prop = [
        'ro.product.odm.device=coralpro',
    ]

    product1_prop = [
        'ro.product.odm.name=product1',
        'ro.product.not_care=not_care',
    ]

    product2_prop = [
        'ro.product.odm.name=product2',
        'ro.product.not_care=not_care',
    ]

    input_file = self._BuildZipFile({
        'ODM/etc/build.prop': '\n'.join(build_prop),
        'ODM/etc/build_std.prop': '\n'.join(build_std_prop),
        'ODM/etc/build_pro.prop': '\n'.join(build_pro_prop),
        'ODM/etc/build_product1.prop': '\n'.join(product1_prop),
        'ODM/etc/build_product2.prop': '\n'.join(product2_prop),
    })

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': 'std',
          'ro.boot.product.product_name': 'product1',
          'ro.boot.product.not_care': 'not_care',
      }
      partition_props = common.PartitionBuildProps.FromInputFile(
          input_zip, 'odm', placeholder_values)

    self.assertEqual({
        'ro.odm.build.date.utc': '1578430045',
        'ro.odm.build.fingerprint':
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device': 'coral',
        'ro.product.odm.name': 'product1'
    }, partition_props.build_props)

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': 'pro',
          'ro.boot.product.product_name': 'product2',
          'ro.boot.product.not_care': 'not_care',
      }
      partition_props = common.PartitionBuildProps.FromInputFile(
          input_zip, 'odm', placeholder_values)

    self.assertEqual({
        'ro.odm.build.date.utc': '1578430045',
        'ro.odm.build.fingerprint':
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device': 'coralpro',
        'ro.product.odm.name': 'product2'
    }, partition_props.build_props)

  def test_parseBuildProps_defineAfterOverride(self):
    build_prop = copy.deepcopy(self.odm_build_prop)
    build_prop.append('ro.product.odm.device=coral')

    build_std_prop = [
        'ro.product.odm.device=coral',
    ]
    build_pro_prop = [
        'ro.product.odm.device=coralpro',
    ]

    input_file = self._BuildZipFile({
        'ODM/etc/build.prop': '\n'.join(build_prop),
        'ODM/etc/build_std.prop': '\n'.join(build_std_prop),
        'ODM/etc/build_pro.prop': '\n'.join(build_pro_prop),
    })

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': 'std',
      }

      self.assertRaises(ValueError, common.PartitionBuildProps.FromInputFile,
                        input_zip, 'odm', placeholder_values)

  def test_parseBuildProps_duplicateOverride(self):
    build_prop = copy.deepcopy(self.odm_build_prop)
    build_prop.append(
        'import /odm/etc/build_${ro.boot.product.product_name}.prop')

    build_std_prop = [
        'ro.product.odm.device=coral',
        'ro.product.odm.name=product1',
    ]
    build_pro_prop = [
        'ro.product.odm.device=coralpro',
    ]

    product1_prop = [
        'ro.product.odm.name=product1',
    ]

    product2_prop = [
        'ro.product.odm.name=product2',
    ]

    input_file = self._BuildZipFile({
        'ODM/etc/build.prop': '\n'.join(build_prop),
        'ODM/etc/build_std.prop': '\n'.join(build_std_prop),
        'ODM/etc/build_pro.prop': '\n'.join(build_pro_prop),
        'ODM/etc/build_product1.prop': '\n'.join(product1_prop),
        'ODM/etc/build_product2.prop': '\n'.join(product2_prop),
    })

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': 'std',
          'ro.boot.product.product_name': 'product1',
      }
      self.assertRaises(ValueError, common.PartitionBuildProps.FromInputFile,
                        input_zip, 'odm', placeholder_values)

  def test_partitionBuildProps_fromInputFile_deepcopy(self):
    build_prop = [
        'ro.odm.build.date.utc=1578430045',
        'ro.odm.build.fingerprint='
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device=coral',
    ]
    input_file = self._BuildZipFile({
        'ODM/etc/build.prop': '\n'.join(build_prop),
    })

    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      placeholder_values = {
          'ro.boot.product.device_name': ['std', 'pro']
      }
      partition_props = common.PartitionBuildProps.FromInputFile(
          input_zip, 'odm', placeholder_values)

    copied_props = copy.deepcopy(partition_props)
    self.assertEqual({
        'ro.odm.build.date.utc': '1578430045',
        'ro.odm.build.fingerprint':
        'google/coral/coral:10/RP1A.200325.001/6337676:user/dev-keys',
        'ro.product.odm.device': 'coral',
    }, copied_props.build_props)


class DeviceSpecificParamsTest(test_utils.ReleaseToolsTestCase):

  def test_missingSource(self):
    common.OPTIONS.device_specific = '/does_not_exist'
    ds = DeviceSpecificParams()
    self.assertIsNone(ds.module)
