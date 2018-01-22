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

import copy
import os.path
import unittest

import common
from ota_from_target_files import (
    _LoadOemDicts, BuildInfo, GetPackageMetadata, PayloadSigner,
    WriteFingerprintAssertion)


def get_testdata_dir():
  """Returns the testdata dir, in relative to the script dir."""
  # The script dir is the one we want, which could be different from pwd.
  current_dir = os.path.dirname(os.path.realpath(__file__))
  return os.path.join(current_dir, 'testdata')


class MockScriptWriter(object):
  """A class that mocks edify_generator.EdifyGenerator.

  It simply pushes the incoming arguments onto script stack, which is to assert
  the calls to EdifyGenerator functions.
  """

  def __init__(self):
    self.script = []

  def Mount(self, *args):
    self.script.append(('Mount',) + args)

  def AssertDevice(self, *args):
    self.script.append(('AssertDevice',) + args)

  def AssertOemProperty(self, *args):
    self.script.append(('AssertOemProperty',) + args)

  def AssertFingerprintOrThumbprint(self, *args):
    self.script.append(('AssertFingerprintOrThumbprint',) + args)

  def AssertSomeFingerprint(self, *args):
    self.script.append(('AssertSomeFingerprint',) + args)

  def AssertSomeThumbprint(self, *args):
    self.script.append(('AssertSomeThumbprint',) + args)


class BuildInfoTest(unittest.TestCase):

  TEST_INFO_DICT = {
      'build.prop' : {
          'ro.product.device' : 'product-device',
          'ro.product.name' : 'product-name',
          'ro.build.fingerprint' : 'build-fingerprint',
          'ro.build.foo' : 'build-foo',
      },
      'vendor.build.prop' : {
          'ro.vendor.build.fingerprint' : 'vendor-build-fingerprint',
      },
      'property1' : 'value1',
      'property2' : 4096,
  }

  TEST_INFO_DICT_USES_OEM_PROPS = {
      'build.prop' : {
          'ro.product.name' : 'product-name',
          'ro.build.thumbprint' : 'build-thumbprint',
          'ro.build.bar' : 'build-bar',
      },
      'vendor.build.prop' : {
          'ro.vendor.build.fingerprint' : 'vendor-build-fingerprint',
      },
      'property1' : 'value1',
      'property2' : 4096,
      'oem_fingerprint_properties' : 'ro.product.device ro.product.brand',
  }

  TEST_OEM_DICTS = [
      {
          'ro.product.brand' : 'brand1',
          'ro.product.device' : 'device1',
      },
      {
          'ro.product.brand' : 'brand2',
          'ro.product.device' : 'device2',
      },
      {
          'ro.product.brand' : 'brand3',
          'ro.product.device' : 'device3',
      },
  ]

  def test_init(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('product-device', target_info.device)
    self.assertEqual('build-fingerprint', target_info.fingerprint)
    self.assertFalse(target_info.is_ab)
    self.assertIsNone(target_info.oem_props)

  def test_init_with_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    self.assertEqual('device1', target_info.device)
    self.assertEqual('brand1/product-name/device1:build-thumbprint',
                     target_info.fingerprint)

    # Swap the order in oem_dicts, which would lead to different BuildInfo.
    oem_dicts = copy.copy(self.TEST_OEM_DICTS)
    oem_dicts[0], oem_dicts[2] = oem_dicts[2], oem_dicts[0]
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS, oem_dicts)
    self.assertEqual('device3', target_info.device)
    self.assertEqual('brand3/product-name/device3:build-thumbprint',
                     target_info.fingerprint)

    # Missing oem_dict should be rejected.
    self.assertRaises(AssertionError, BuildInfo,
                      self.TEST_INFO_DICT_USES_OEM_PROPS, None)

  def test___getitem__(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('value1', target_info['property1'])
    self.assertEqual(4096, target_info['property2'])
    self.assertEqual('build-foo', target_info['build.prop']['ro.build.foo'])

  def test___getitem__with_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    self.assertEqual('value1', target_info['property1'])
    self.assertEqual(4096, target_info['property2'])
    self.assertRaises(KeyError,
                      lambda: target_info['build.prop']['ro.build.foo'])

  def test_get(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('value1', target_info.get('property1'))
    self.assertEqual(4096, target_info.get('property2'))
    self.assertEqual(4096, target_info.get('property2', 1024))
    self.assertEqual(1024, target_info.get('property-nonexistent', 1024))
    self.assertEqual('build-foo', target_info.get('build.prop')['ro.build.foo'])

  def test_get_with_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    self.assertEqual('value1', target_info.get('property1'))
    self.assertEqual(4096, target_info.get('property2'))
    self.assertEqual(4096, target_info.get('property2', 1024))
    self.assertEqual(1024, target_info.get('property-nonexistent', 1024))
    self.assertIsNone(target_info.get('build.prop').get('ro.build.foo'))
    self.assertRaises(KeyError,
                      lambda: target_info.get('build.prop')['ro.build.foo'])

  def test_GetBuildProp(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('build-foo', target_info.GetBuildProp('ro.build.foo'))
    self.assertRaises(common.ExternalError, target_info.GetBuildProp,
                      'ro.build.nonexistent')

  def test_GetBuildProp_with_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    self.assertEqual('build-bar', target_info.GetBuildProp('ro.build.bar'))
    self.assertRaises(common.ExternalError, target_info.GetBuildProp,
                      'ro.build.nonexistent')

  def test_GetVendorBuildProp(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    self.assertEqual('vendor-build-fingerprint',
                     target_info.GetVendorBuildProp(
                         'ro.vendor.build.fingerprint'))
    self.assertRaises(common.ExternalError, target_info.GetVendorBuildProp,
                      'ro.build.nonexistent')

  def test_GetVendorBuildProp_with_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    self.assertEqual('vendor-build-fingerprint',
                     target_info.GetVendorBuildProp(
                         'ro.vendor.build.fingerprint'))
    self.assertRaises(common.ExternalError, target_info.GetVendorBuildProp,
                      'ro.build.nonexistent')

  def test_WriteMountOemScript(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    script_writer = MockScriptWriter()
    target_info.WriteMountOemScript(script_writer)
    self.assertEqual([('Mount', '/oem', None)], script_writer.script)

  def test_WriteDeviceAssertions(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    script_writer = MockScriptWriter()
    target_info.WriteDeviceAssertions(script_writer, False)
    self.assertEqual([('AssertDevice', 'product-device')], script_writer.script)

  def test_WriteDeviceAssertions_with_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    script_writer = MockScriptWriter()
    target_info.WriteDeviceAssertions(script_writer, False)
    self.assertEqual(
        [
            ('AssertOemProperty', 'ro.product.device',
             ['device1', 'device2', 'device3'], False),
            ('AssertOemProperty', 'ro.product.brand',
             ['brand1', 'brand2', 'brand3'], False),
        ],
        script_writer.script)

  def test_WriteFingerprintAssertion_without_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    source_info_dict = copy.deepcopy(self.TEST_INFO_DICT)
    source_info_dict['build.prop']['ro.build.fingerprint'] = (
        'source-build-fingerprint')
    source_info = BuildInfo(source_info_dict, None)

    script_writer = MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertSomeFingerprint', 'source-build-fingerprint',
          'build-fingerprint')],
        script_writer.script)

  def test_WriteFingerprintAssertion_with_source_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT, None)
    source_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)

    script_writer = MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertFingerprintOrThumbprint', 'build-fingerprint',
          'build-thumbprint')],
        script_writer.script)

  def test_WriteFingerprintAssertion_with_target_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    source_info = BuildInfo(self.TEST_INFO_DICT, None)

    script_writer = MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertFingerprintOrThumbprint', 'build-fingerprint',
          'build-thumbprint')],
        script_writer.script)

  def test_WriteFingerprintAssertion_with_both_oem_props(self):
    target_info = BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                            self.TEST_OEM_DICTS)
    source_info_dict = copy.deepcopy(self.TEST_INFO_DICT_USES_OEM_PROPS)
    source_info_dict['build.prop']['ro.build.thumbprint'] = (
        'source-build-thumbprint')
    source_info = BuildInfo(source_info_dict, self.TEST_OEM_DICTS)

    script_writer = MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertSomeThumbprint', 'build-thumbprint',
          'source-build-thumbprint')],
        script_writer.script)


class LoadOemDictsTest(unittest.TestCase):

  def tearDown(self):
    common.Cleanup()

  def test_NoneDict(self):
    self.assertIsNone(_LoadOemDicts(None))

  def test_SingleDict(self):
    dict_file = common.MakeTempFile()
    with open(dict_file, 'w') as dict_fp:
      dict_fp.write('abc=1\ndef=2\nxyz=foo\na.b.c=bar\n')

    oem_dicts = _LoadOemDicts([dict_file])
    self.assertEqual(1, len(oem_dicts))
    self.assertEqual('foo', oem_dicts[0]['xyz'])
    self.assertEqual('bar', oem_dicts[0]['a.b.c'])

  def test_MultipleDicts(self):
    oem_source = []
    for i in range(3):
      dict_file = common.MakeTempFile()
      with open(dict_file, 'w') as dict_fp:
        dict_fp.write(
            'ro.build.index={}\ndef=2\nxyz=foo\na.b.c=bar\n'.format(i))
      oem_source.append(dict_file)

    oem_dicts = _LoadOemDicts(oem_source)
    self.assertEqual(3, len(oem_dicts))
    for i, oem_dict in enumerate(oem_dicts):
      self.assertEqual('2', oem_dict['def'])
      self.assertEqual('foo', oem_dict['xyz'])
      self.assertEqual('bar', oem_dict['a.b.c'])
      self.assertEqual('{}'.format(i), oem_dict['ro.build.index'])


class OtaFromTargetFilesTest(unittest.TestCase):

  TEST_TARGET_INFO_DICT = {
      'build.prop' : {
          'ro.product.device' : 'product-device',
          'ro.build.fingerprint' : 'build-fingerprint-target',
          'ro.build.version.incremental' : 'build-version-incremental-target',
          'ro.build.date.utc' : '1500000000',
      },
  }

  TEST_SOURCE_INFO_DICT = {
      'build.prop' : {
          'ro.product.device' : 'product-device',
          'ro.build.fingerprint' : 'build-fingerprint-source',
          'ro.build.version.incremental' : 'build-version-incremental-source',
          'ro.build.date.utc' : '1400000000',
      },
  }

  def setUp(self):
    # Reset the global options as in ota_from_target_files.py.
    common.OPTIONS.incremental_source = None
    common.OPTIONS.downgrade = False
    common.OPTIONS.timestamp = False
    common.OPTIONS.wipe_user_data = False

  def test_GetPackageMetadata_abOta_full(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info = BuildInfo(target_info_dict, None)
    metadata = GetPackageMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type' : 'AB',
            'ota-required-cache' : '0',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
        },
        metadata)

  def test_GetPackageMetadata_abOta_incremental(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info = BuildInfo(target_info_dict, None)
    source_info = BuildInfo(self.TEST_SOURCE_INFO_DICT, None)
    common.OPTIONS.incremental_source = ''
    metadata = GetPackageMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-type' : 'AB',
            'ota-required-cache' : '0',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
            'pre-build' : 'build-fingerprint-source',
            'pre-build-incremental' : 'build-version-incremental-source',
        },
        metadata)

  def test_GetPackageMetadata_nonAbOta_full(self):
    target_info = BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    metadata = GetPackageMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type' : 'BLOCK',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
        },
        metadata)

  def test_GetPackageMetadata_nonAbOta_incremental(self):
    target_info = BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    source_info = BuildInfo(self.TEST_SOURCE_INFO_DICT, None)
    common.OPTIONS.incremental_source = ''
    metadata = GetPackageMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-type' : 'BLOCK',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
            'pre-build' : 'build-fingerprint-source',
            'pre-build-incremental' : 'build-version-incremental-source',
        },
        metadata)

  def test_GetPackageMetadata_wipe(self):
    target_info = BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    common.OPTIONS.wipe_user_data = True
    metadata = GetPackageMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type' : 'BLOCK',
            'ota-wipe' : 'yes',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
        },
        metadata)

  @staticmethod
  def _test_GetPackageMetadata_swapBuildTimestamps(target_info, source_info):
    (target_info['build.prop']['ro.build.date.utc'],
     source_info['build.prop']['ro.build.date.utc']) = (
         source_info['build.prop']['ro.build.date.utc'],
         target_info['build.prop']['ro.build.date.utc'])

  def test_GetPackageMetadata_unintentionalDowngradeDetected(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    source_info_dict = copy.deepcopy(self.TEST_SOURCE_INFO_DICT)
    self._test_GetPackageMetadata_swapBuildTimestamps(
        target_info_dict, source_info_dict)

    target_info = BuildInfo(target_info_dict, None)
    source_info = BuildInfo(source_info_dict, None)
    common.OPTIONS.incremental_source = ''
    self.assertRaises(RuntimeError, GetPackageMetadata, target_info,
                      source_info)

  def test_GetPackageMetadata_downgrade(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    source_info_dict = copy.deepcopy(self.TEST_SOURCE_INFO_DICT)
    self._test_GetPackageMetadata_swapBuildTimestamps(
        target_info_dict, source_info_dict)

    target_info = BuildInfo(target_info_dict, None)
    source_info = BuildInfo(source_info_dict, None)
    common.OPTIONS.incremental_source = ''
    common.OPTIONS.downgrade = True
    common.OPTIONS.wipe_user_data = True
    metadata = GetPackageMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-downgrade' : 'yes',
            'ota-type' : 'BLOCK',
            'ota-wipe' : 'yes',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'pre-device' : 'product-device',
            'pre-build' : 'build-fingerprint-source',
            'pre-build-incremental' : 'build-version-incremental-source',
        },
        metadata)

  def test_GetPackageMetadata_overrideTimestamp(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    source_info_dict = copy.deepcopy(self.TEST_SOURCE_INFO_DICT)
    self._test_GetPackageMetadata_swapBuildTimestamps(
        target_info_dict, source_info_dict)

    target_info = BuildInfo(target_info_dict, None)
    source_info = BuildInfo(source_info_dict, None)
    common.OPTIONS.incremental_source = ''
    common.OPTIONS.timestamp = True
    metadata = GetPackageMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-type' : 'BLOCK',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-timestamp' : '1500000001',
            'pre-device' : 'product-device',
            'pre-build' : 'build-fingerprint-source',
            'pre-build-incremental' : 'build-version-incremental-source',
        },
        metadata)


class PayloadSignerTest(unittest.TestCase):

  SIGFILE = 'sigfile.bin'
  SIGNED_SIGFILE = 'signed-sigfile.bin'

  def setUp(self):
    self.testdata_dir = get_testdata_dir()
    self.assertTrue(os.path.exists(self.testdata_dir))

    common.OPTIONS.payload_signer = None
    common.OPTIONS.payload_signer_args = []
    common.OPTIONS.package_key = os.path.join(self.testdata_dir, 'testkey')
    common.OPTIONS.key_passwords = {
        common.OPTIONS.package_key : None,
    }

  def tearDown(self):
    common.Cleanup()

  def _assertFilesEqual(self, file1, file2):
    with open(file1, 'rb') as fp1, open(file2, 'rb') as fp2:
      self.assertEqual(fp1.read(), fp2.read())

  def test_init(self):
    payload_signer = PayloadSigner()
    self.assertEqual('openssl', payload_signer.signer)

  def test_init_withPassword(self):
    common.OPTIONS.package_key = os.path.join(
        self.testdata_dir, 'testkey_with_passwd')
    common.OPTIONS.key_passwords = {
        common.OPTIONS.package_key : 'foo',
    }
    payload_signer = PayloadSigner()
    self.assertEqual('openssl', payload_signer.signer)

  def test_init_withExternalSigner(self):
    common.OPTIONS.payload_signer = 'abc'
    common.OPTIONS.payload_signer_args = ['arg1', 'arg2']
    payload_signer = PayloadSigner()
    self.assertEqual('abc', payload_signer.signer)
    self.assertEqual(['arg1', 'arg2'], payload_signer.signer_args)

  def test_Sign(self):
    payload_signer = PayloadSigner()
    input_file = os.path.join(self.testdata_dir, self.SIGFILE)
    signed_file = payload_signer.Sign(input_file)

    verify_file = os.path.join(self.testdata_dir, self.SIGNED_SIGFILE)
    self._assertFilesEqual(verify_file, signed_file)

  def test_Sign_withExternalSigner_openssl(self):
    """Uses openssl as the external payload signer."""
    common.OPTIONS.payload_signer = 'openssl'
    common.OPTIONS.payload_signer_args = [
        'pkeyutl', '-sign', '-keyform', 'DER', '-inkey',
        os.path.join(self.testdata_dir, 'testkey.pk8'),
        '-pkeyopt', 'digest:sha256']
    payload_signer = PayloadSigner()
    input_file = os.path.join(self.testdata_dir, self.SIGFILE)
    signed_file = payload_signer.Sign(input_file)

    verify_file = os.path.join(self.testdata_dir, self.SIGNED_SIGFILE)
    self._assertFilesEqual(verify_file, signed_file)

  def test_Sign_withExternalSigner_script(self):
    """Uses testdata/payload_signer.sh as the external payload signer."""
    common.OPTIONS.payload_signer = os.path.join(
        self.testdata_dir, 'payload_signer.sh')
    common.OPTIONS.payload_signer_args = [
        os.path.join(self.testdata_dir, 'testkey.pk8')]
    payload_signer = PayloadSigner()
    input_file = os.path.join(self.testdata_dir, self.SIGFILE)
    signed_file = payload_signer.Sign(input_file)

    verify_file = os.path.join(self.testdata_dir, self.SIGNED_SIGFILE)
    self._assertFilesEqual(verify_file, signed_file)
