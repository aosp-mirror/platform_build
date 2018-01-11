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
import unittest

import common
from ota_from_target_files import (
    _LoadOemDicts, BuildInfo, WriteFingerprintAssertion)


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
