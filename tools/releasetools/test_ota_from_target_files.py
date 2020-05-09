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
import os
import os.path
import zipfile

import common
import test_utils
from ota_from_target_files import (
    _LoadOemDicts, AbOtaPropertyFiles, FinalizeMetadata,
    GetPackageMetadata, GetTargetFilesZipForSecondaryImages,
    GetTargetFilesZipWithoutPostinstallConfig, NonAbOtaPropertyFiles,
    Payload, PayloadSigner, POSTINSTALL_CONFIG, PropertyFiles,
    StreamingPropertyFiles, WriteFingerprintAssertion)


def construct_target_files(secondary=False):
  """Returns a target-files.zip file for generating OTA packages."""
  target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
  with zipfile.ZipFile(target_files, 'w') as target_files_zip:
    # META/update_engine_config.txt
    target_files_zip.writestr(
        'META/update_engine_config.txt',
        "PAYLOAD_MAJOR_VERSION=2\nPAYLOAD_MINOR_VERSION=4\n")

    # META/postinstall_config.txt
    target_files_zip.writestr(
        POSTINSTALL_CONFIG,
        '\n'.join([
            "RUN_POSTINSTALL_system=true",
            "POSTINSTALL_PATH_system=system/bin/otapreopt_script",
            "FILESYSTEM_TYPE_system=ext4",
            "POSTINSTALL_OPTIONAL_system=true",
        ]))

    ab_partitions = [
        ('IMAGES', 'boot'),
        ('IMAGES', 'system'),
        ('IMAGES', 'vendor'),
        ('RADIO', 'bootloader'),
        ('RADIO', 'modem'),
    ]
    # META/ab_partitions.txt
    target_files_zip.writestr(
        'META/ab_partitions.txt',
        '\n'.join([partition[1] for partition in ab_partitions]))

    # Create dummy images for each of them.
    for path, partition in ab_partitions:
      target_files_zip.writestr(
          '{}/{}.img'.format(path, partition),
          os.urandom(len(partition)))

    # system_other shouldn't appear in META/ab_partitions.txt.
    if secondary:
      target_files_zip.writestr('IMAGES/system_other.img',
                                os.urandom(len("system_other")))

  return target_files


class LoadOemDictsTest(test_utils.ReleaseToolsTestCase):

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


class OtaFromTargetFilesTest(test_utils.ReleaseToolsTestCase):

  TEST_TARGET_INFO_DICT = {
      'build.prop' : {
          'ro.product.device' : 'product-device',
          'ro.build.fingerprint' : 'build-fingerprint-target',
          'ro.build.version.incremental' : 'build-version-incremental-target',
          'ro.build.version.sdk' : '27',
          'ro.build.version.security_patch' : '2017-12-01',
          'ro.build.date.utc' : '1500000000',
      },
  }

  TEST_SOURCE_INFO_DICT = {
      'build.prop' : {
          'ro.product.device' : 'product-device',
          'ro.build.fingerprint' : 'build-fingerprint-source',
          'ro.build.version.incremental' : 'build-version-incremental-source',
          'ro.build.version.sdk' : '25',
          'ro.build.version.security_patch' : '2016-12-01',
          'ro.build.date.utc' : '1400000000',
      },
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

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    self.assertTrue(os.path.exists(self.testdata_dir))

    # Reset the global options as in ota_from_target_files.py.
    common.OPTIONS.incremental_source = None
    common.OPTIONS.downgrade = False
    common.OPTIONS.retrofit_dynamic_partitions = False
    common.OPTIONS.timestamp = False
    common.OPTIONS.wipe_user_data = False
    common.OPTIONS.no_signing = False
    common.OPTIONS.package_key = os.path.join(self.testdata_dir, 'testkey')
    common.OPTIONS.key_passwords = {
        common.OPTIONS.package_key : None,
    }

    common.OPTIONS.search_path = test_utils.get_search_path()

  def test_GetPackageMetadata_abOta_full(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info = common.BuildInfo(target_info_dict, None)
    metadata = GetPackageMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type' : 'AB',
            'ota-required-cache' : '0',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-sdk-level' : '27',
            'post-security-patch-level' : '2017-12-01',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
        },
        metadata)

  def test_GetPackageMetadata_abOta_incremental(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info = common.BuildInfo(target_info_dict, None)
    source_info = common.BuildInfo(self.TEST_SOURCE_INFO_DICT, None)
    common.OPTIONS.incremental_source = ''
    metadata = GetPackageMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-type' : 'AB',
            'ota-required-cache' : '0',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-sdk-level' : '27',
            'post-security-patch-level' : '2017-12-01',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
            'pre-build' : 'build-fingerprint-source',
            'pre-build-incremental' : 'build-version-incremental-source',
        },
        metadata)

  def test_GetPackageMetadata_nonAbOta_full(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    metadata = GetPackageMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type' : 'BLOCK',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-sdk-level' : '27',
            'post-security-patch-level' : '2017-12-01',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
        },
        metadata)

  def test_GetPackageMetadata_nonAbOta_incremental(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    source_info = common.BuildInfo(self.TEST_SOURCE_INFO_DICT, None)
    common.OPTIONS.incremental_source = ''
    metadata = GetPackageMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-type' : 'BLOCK',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-sdk-level' : '27',
            'post-security-patch-level' : '2017-12-01',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
            'pre-build' : 'build-fingerprint-source',
            'pre-build-incremental' : 'build-version-incremental-source',
        },
        metadata)

  def test_GetPackageMetadata_wipe(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    common.OPTIONS.wipe_user_data = True
    metadata = GetPackageMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type' : 'BLOCK',
            'ota-wipe' : 'yes',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-sdk-level' : '27',
            'post-security-patch-level' : '2017-12-01',
            'post-timestamp' : '1500000000',
            'pre-device' : 'product-device',
        },
        metadata)

  def test_GetPackageMetadata_retrofitDynamicPartitions(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    common.OPTIONS.retrofit_dynamic_partitions = True
    metadata = GetPackageMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-retrofit-dynamic-partitions' : 'yes',
            'ota-type' : 'BLOCK',
            'post-build' : 'build-fingerprint-target',
            'post-build-incremental' : 'build-version-incremental-target',
            'post-sdk-level' : '27',
            'post-security-patch-level' : '2017-12-01',
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

    target_info = common.BuildInfo(target_info_dict, None)
    source_info = common.BuildInfo(source_info_dict, None)
    common.OPTIONS.incremental_source = ''
    self.assertRaises(RuntimeError, GetPackageMetadata, target_info,
                      source_info)

  def test_GetPackageMetadata_downgrade(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    source_info_dict = copy.deepcopy(self.TEST_SOURCE_INFO_DICT)
    self._test_GetPackageMetadata_swapBuildTimestamps(
        target_info_dict, source_info_dict)

    target_info = common.BuildInfo(target_info_dict, None)
    source_info = common.BuildInfo(source_info_dict, None)
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
            'post-sdk-level' : '27',
            'post-security-patch-level' : '2017-12-01',
            'post-timestamp' : '1400000000',
            'pre-device' : 'product-device',
            'pre-build' : 'build-fingerprint-source',
            'pre-build-incremental' : 'build-version-incremental-source',
        },
        metadata)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForSecondaryImages(self):
    input_file = construct_target_files(secondary=True)
    target_file = GetTargetFilesZipForSecondaryImages(input_file)

    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()
      ab_partitions = verify_zip.read('META/ab_partitions.txt').decode()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertIn('IMAGES/system.img', namelist)
    self.assertIn('RADIO/bootloader.img', namelist)
    self.assertIn(POSTINSTALL_CONFIG, namelist)

    self.assertNotIn('IMAGES/boot.img', namelist)
    self.assertNotIn('IMAGES/system_other.img', namelist)
    self.assertNotIn('IMAGES/system.map', namelist)
    self.assertNotIn('RADIO/modem.img', namelist)

    expected_ab_partitions = ['system', 'bootloader']
    self.assertEqual('\n'.join(expected_ab_partitions), ab_partitions)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForSecondaryImages_skipPostinstall(self):
    input_file = construct_target_files(secondary=True)
    target_file = GetTargetFilesZipForSecondaryImages(
        input_file, skip_postinstall=True)

    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertIn('IMAGES/system.img', namelist)
    self.assertIn('RADIO/bootloader.img', namelist)

    self.assertNotIn('IMAGES/boot.img', namelist)
    self.assertNotIn('IMAGES/system_other.img', namelist)
    self.assertNotIn('IMAGES/system.map', namelist)
    self.assertNotIn('RADIO/modem.img', namelist)
    self.assertNotIn(POSTINSTALL_CONFIG, namelist)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForSecondaryImages_withoutRadioImages(self):
    input_file = construct_target_files(secondary=True)
    common.ZipDelete(input_file, 'RADIO/bootloader.img')
    common.ZipDelete(input_file, 'RADIO/modem.img')
    target_file = GetTargetFilesZipForSecondaryImages(input_file)

    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertIn('IMAGES/system.img', namelist)
    self.assertIn(POSTINSTALL_CONFIG, namelist)

    self.assertNotIn('IMAGES/boot.img', namelist)
    self.assertNotIn('IMAGES/system_other.img', namelist)
    self.assertNotIn('IMAGES/system.map', namelist)
    self.assertNotIn('RADIO/bootloader.img', namelist)
    self.assertNotIn('RADIO/modem.img', namelist)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForSecondaryImages_dynamicPartitions(self):
    input_file = construct_target_files(secondary=True)
    misc_info = '\n'.join([
        'use_dynamic_partition_size=true',
        'use_dynamic_partitions=true',
        'dynamic_partition_list=system vendor product',
        'super_partition_groups=google_dynamic_partitions',
        'super_google_dynamic_partitions_group_size=4873781248',
        'super_google_dynamic_partitions_partition_list=system vendor product',
    ])
    dynamic_partitions_info = '\n'.join([
        'super_partition_groups=google_dynamic_partitions',
        'super_google_dynamic_partitions_group_size=4873781248',
        'super_google_dynamic_partitions_partition_list=system vendor product',
    ])

    with zipfile.ZipFile(input_file, 'a') as append_zip:
      common.ZipWriteStr(append_zip, 'META/misc_info.txt', misc_info)
      common.ZipWriteStr(append_zip, 'META/dynamic_partitions_info.txt',
                         dynamic_partitions_info)

    target_file = GetTargetFilesZipForSecondaryImages(input_file)

    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()
      updated_misc_info = verify_zip.read('META/misc_info.txt').decode()
      updated_dynamic_partitions_info = verify_zip.read(
          'META/dynamic_partitions_info.txt').decode()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertIn('IMAGES/system.img', namelist)
    self.assertIn(POSTINSTALL_CONFIG, namelist)
    self.assertIn('META/misc_info.txt', namelist)
    self.assertIn('META/dynamic_partitions_info.txt', namelist)

    self.assertNotIn('IMAGES/boot.img', namelist)
    self.assertNotIn('IMAGES/system_other.img', namelist)
    self.assertNotIn('IMAGES/system.map', namelist)

    # Check the vendor & product are removed from the partitions list.
    expected_misc_info = misc_info.replace('system vendor product',
                                           'system')
    expected_dynamic_partitions_info = dynamic_partitions_info.replace(
        'system vendor product', 'system')
    self.assertEqual(expected_misc_info, updated_misc_info)
    self.assertEqual(expected_dynamic_partitions_info,
                     updated_dynamic_partitions_info)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipWithoutPostinstallConfig(self):
    input_file = construct_target_files()
    target_file = GetTargetFilesZipWithoutPostinstallConfig(input_file)
    with zipfile.ZipFile(target_file) as verify_zip:
      self.assertNotIn(POSTINSTALL_CONFIG, verify_zip.namelist())

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipWithoutPostinstallConfig_missingEntry(self):
    input_file = construct_target_files()
    common.ZipDelete(input_file, POSTINSTALL_CONFIG)
    target_file = GetTargetFilesZipWithoutPostinstallConfig(input_file)
    with zipfile.ZipFile(target_file) as verify_zip:
      self.assertNotIn(POSTINSTALL_CONFIG, verify_zip.namelist())

  def _test_FinalizeMetadata(self, large_entry=False):
    entries = [
        'required-entry1',
        'required-entry2',
    ]
    zip_file = PropertyFilesTest.construct_zip_package(entries)
    # Add a large entry of 1 GiB if requested.
    if large_entry:
      with zipfile.ZipFile(zip_file, 'a') as zip_fp:
        zip_fp.writestr(
            # Using 'zoo' so that the entry stays behind others after signing.
            'zoo',
            'A' * 1024 * 1024 * 1024,
            zipfile.ZIP_STORED)

    metadata = {}
    output_file = common.MakeTempFile(suffix='.zip')
    needed_property_files = (
        TestPropertyFiles(),
    )
    FinalizeMetadata(metadata, zip_file, output_file, needed_property_files)
    self.assertIn('ota-test-property-files', metadata)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_FinalizeMetadata(self):
    self._test_FinalizeMetadata()

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_FinalizeMetadata_withNoSigning(self):
    common.OPTIONS.no_signing = True
    self._test_FinalizeMetadata()

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_FinalizeMetadata_largeEntry(self):
    self._test_FinalizeMetadata(large_entry=True)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_FinalizeMetadata_largeEntry_withNoSigning(self):
    common.OPTIONS.no_signing = True
    self._test_FinalizeMetadata(large_entry=True)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_FinalizeMetadata_insufficientSpace(self):
    entries = [
        'required-entry1',
        'required-entry2',
        'optional-entry1',
        'optional-entry2',
    ]
    zip_file = PropertyFilesTest.construct_zip_package(entries)
    with zipfile.ZipFile(zip_file, 'a') as zip_fp:
      zip_fp.writestr(
          # 'foo-entry1' will appear ahead of all other entries (in alphabetical
          # order) after the signing, which will in turn trigger the
          # InsufficientSpaceException and an automatic retry.
          'foo-entry1',
          'A' * 1024 * 1024,
          zipfile.ZIP_STORED)

    metadata = {}
    needed_property_files = (
        TestPropertyFiles(),
    )
    output_file = common.MakeTempFile(suffix='.zip')
    FinalizeMetadata(metadata, zip_file, output_file, needed_property_files)
    self.assertIn('ota-test-property-files', metadata)

  def test_WriteFingerprintAssertion_without_oem_props(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    source_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    source_info_dict['build.prop']['ro.build.fingerprint'] = (
        'source-build-fingerprint')
    source_info = common.BuildInfo(source_info_dict, None)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertSomeFingerprint', 'source-build-fingerprint',
          'build-fingerprint-target')],
        script_writer.lines)

  def test_WriteFingerprintAssertion_with_source_oem_props(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    source_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertFingerprintOrThumbprint', 'build-fingerprint-target',
          'build-thumbprint')],
        script_writer.lines)

  def test_WriteFingerprintAssertion_with_target_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    source_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertFingerprintOrThumbprint', 'build-fingerprint-target',
          'build-thumbprint')],
        script_writer.lines)

  def test_WriteFingerprintAssertion_with_both_oem_props(self):
    target_info = common.BuildInfo(self.TEST_INFO_DICT_USES_OEM_PROPS,
                                   self.TEST_OEM_DICTS)
    source_info_dict = copy.deepcopy(self.TEST_INFO_DICT_USES_OEM_PROPS)
    source_info_dict['build.prop']['ro.build.thumbprint'] = (
        'source-build-thumbprint')
    source_info = common.BuildInfo(source_info_dict, self.TEST_OEM_DICTS)

    script_writer = test_utils.MockScriptWriter()
    WriteFingerprintAssertion(script_writer, target_info, source_info)
    self.assertEqual(
        [('AssertSomeThumbprint', 'build-thumbprint',
          'source-build-thumbprint')],
        script_writer.lines)


class TestPropertyFiles(PropertyFiles):
  """A class that extends PropertyFiles for testing purpose."""

  def __init__(self):
    super(TestPropertyFiles, self).__init__()
    self.name = 'ota-test-property-files'
    self.required = (
        'required-entry1',
        'required-entry2',
    )
    self.optional = (
        'optional-entry1',
        'optional-entry2',
    )


class PropertyFilesTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    common.OPTIONS.no_signing = False

  @staticmethod
  def construct_zip_package(entries):
    zip_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(zip_file, 'w') as zip_fp:
      for entry in entries:
        zip_fp.writestr(
            entry,
            entry.replace('.', '-').upper(),
            zipfile.ZIP_STORED)
    return zip_file

  @staticmethod
  def _parse_property_files_string(data):
    result = {}
    for token in data.split(','):
      name, info = token.split(':', 1)
      result[name] = info
    return result

  def _verify_entries(self, input_file, tokens, entries):
    for entry in entries:
      offset, size = map(int, tokens[entry].split(':'))
      with open(input_file, 'rb') as input_fp:
        input_fp.seek(offset)
        if entry == 'metadata':
          expected = b'META-INF/COM/ANDROID/METADATA'
        else:
          expected = entry.replace('.', '-').upper().encode()
        self.assertEqual(expected, input_fp.read(size))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Compute(self):
    entries = (
        'required-entry1',
        'required-entry2',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(3, len(tokens))
    self._verify_entries(zip_file, tokens, entries)

  def test_Compute_withOptionalEntries(self):
    entries = (
        'required-entry1',
        'required-entry2',
        'optional-entry1',
        'optional-entry2',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(5, len(tokens))
    self._verify_entries(zip_file, tokens, entries)

  def test_Compute_missingRequiredEntry(self):
    entries = (
        'required-entry2',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      self.assertRaises(KeyError, property_files.Compute, zip_fp)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Finalize(self):
    entries = [
        'required-entry1',
        'required-entry2',
        'META-INF/com/android/metadata',
    ]
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      streaming_metadata = property_files.Finalize(zip_fp, len(raw_metadata))
    tokens = self._parse_property_files_string(streaming_metadata)

    self.assertEqual(3, len(tokens))
    # 'META-INF/com/android/metadata' will be key'd as 'metadata' in the
    # streaming metadata.
    entries[2] = 'metadata'
    self._verify_entries(zip_file, tokens, entries)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Finalize_assertReservedLength(self):
    entries = (
        'required-entry1',
        'required-entry2',
        'optional-entry1',
        'optional-entry2',
        'META-INF/com/android/metadata',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      # First get the raw metadata string (i.e. without padding space).
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      raw_length = len(raw_metadata)

      # Now pass in the exact expected length.
      streaming_metadata = property_files.Finalize(zip_fp, raw_length)
      self.assertEqual(raw_length, len(streaming_metadata))

      # Or pass in insufficient length.
      self.assertRaises(
          PropertyFiles.InsufficientSpaceException,
          property_files.Finalize,
          zip_fp,
          raw_length - 1)

      # Or pass in a much larger size.
      streaming_metadata = property_files.Finalize(
          zip_fp,
          raw_length + 20)
      self.assertEqual(raw_length + 20, len(streaming_metadata))
      self.assertEqual(' ' * 20, streaming_metadata[raw_length:])

  def test_Verify(self):
    entries = (
        'required-entry1',
        'required-entry2',
        'optional-entry1',
        'optional-entry2',
        'META-INF/com/android/metadata',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      # First get the raw metadata string (i.e. without padding space).
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)

      # Should pass the test if verification passes.
      property_files.Verify(zip_fp, raw_metadata)

      # Or raise on verification failure.
      self.assertRaises(
          AssertionError, property_files.Verify, zip_fp, raw_metadata + 'x')


class StreamingPropertyFilesTest(PropertyFilesTest):
  """Additional sanity checks specialized for StreamingPropertyFiles."""

  def test_init(self):
    property_files = StreamingPropertyFiles()
    self.assertEqual('ota-streaming-property-files', property_files.name)
    self.assertEqual(
        (
            'payload.bin',
            'payload_properties.txt',
        ),
        property_files.required)
    self.assertEqual(
        (
            'care_map.pb',
            'care_map.txt',
            'compatibility.zip',
        ),
        property_files.optional)

  def test_Compute(self):
    entries = (
        'payload.bin',
        'payload_properties.txt',
        'care_map.txt',
        'compatibility.zip',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = StreamingPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(5, len(tokens))
    self._verify_entries(zip_file, tokens, entries)

  def test_Finalize(self):
    entries = [
        'payload.bin',
        'payload_properties.txt',
        'care_map.txt',
        'compatibility.zip',
        'META-INF/com/android/metadata',
    ]
    zip_file = self.construct_zip_package(entries)
    property_files = StreamingPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      streaming_metadata = property_files.Finalize(zip_fp, len(raw_metadata))
    tokens = self._parse_property_files_string(streaming_metadata)

    self.assertEqual(5, len(tokens))
    # 'META-INF/com/android/metadata' will be key'd as 'metadata' in the
    # streaming metadata.
    entries[4] = 'metadata'
    self._verify_entries(zip_file, tokens, entries)

  def test_Verify(self):
    entries = (
        'payload.bin',
        'payload_properties.txt',
        'care_map.txt',
        'compatibility.zip',
        'META-INF/com/android/metadata',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = StreamingPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      # First get the raw metadata string (i.e. without padding space).
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)

      # Should pass the test if verification passes.
      property_files.Verify(zip_fp, raw_metadata)

      # Or raise on verification failure.
      self.assertRaises(
          AssertionError, property_files.Verify, zip_fp, raw_metadata + 'x')


class AbOtaPropertyFilesTest(PropertyFilesTest):
  """Additional sanity checks specialized for AbOtaPropertyFiles."""

  # The size for payload and metadata signature size.
  SIGNATURE_SIZE = 256

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    self.assertTrue(os.path.exists(self.testdata_dir))

    common.OPTIONS.wipe_user_data = False
    common.OPTIONS.payload_signer = None
    common.OPTIONS.payload_signer_args = None
    common.OPTIONS.package_key = os.path.join(self.testdata_dir, 'testkey')
    common.OPTIONS.key_passwords = {
        common.OPTIONS.package_key : None,
    }

  def test_init(self):
    property_files = AbOtaPropertyFiles()
    self.assertEqual('ota-property-files', property_files.name)
    self.assertEqual(
        (
            'payload.bin',
            'payload_properties.txt',
        ),
        property_files.required)
    self.assertEqual(
        (
            'care_map.pb',
            'care_map.txt',
            'compatibility.zip',
        ),
        property_files.optional)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetPayloadMetadataOffsetAndSize(self):
    target_file = construct_target_files()
    payload = Payload()
    payload.Generate(target_file)

    payload_signer = PayloadSigner()
    payload.Sign(payload_signer)

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      payload.WriteToZip(output_zip)

    # Find out the payload metadata offset and size.
    property_files = AbOtaPropertyFiles()
    with zipfile.ZipFile(output_file) as input_zip:
      # pylint: disable=protected-access
      payload_offset, metadata_total = (
          property_files._GetPayloadMetadataOffsetAndSize(input_zip))

    # The signature proto has the following format (details in
    #  /platform/system/update_engine/update_metadata.proto):
    #  message Signature {
    #    optional uint32 version = 1;
    #    optional bytes data = 2;
    #    optional fixed32 unpadded_signature_size = 3;
    #  }
    #
    # According to the protobuf encoding, the tail of the signature message will
    # be [signature string(256 bytes) + encoding of the fixed32 number 256]. And
    # 256 is encoded as 'x1d\x00\x01\x00\x00':
    # [3 (field number) << 3 | 5 (type) + byte reverse of 0x100 (256)].
    # Details in (https://developers.google.com/protocol-buffers/docs/encoding)
    signature_tail_length = self.SIGNATURE_SIZE + 5
    self.assertGreater(metadata_total, signature_tail_length)
    with open(output_file, 'rb') as verify_fp:
      verify_fp.seek(payload_offset + metadata_total - signature_tail_length)
      metadata_signature_proto_tail = verify_fp.read(signature_tail_length)

    self.assertEqual(b'\x1d\x00\x01\x00\x00',
                     metadata_signature_proto_tail[-5:])
    metadata_signature = metadata_signature_proto_tail[:-5]

    # Now we extract the metadata hash via brillo_update_payload script, which
    # will serve as the oracle result.
    payload_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
    metadata_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
    cmd = ['brillo_update_payload', 'hash',
           '--unsigned_payload', payload.payload_file,
           '--signature_size', str(self.SIGNATURE_SIZE),
           '--metadata_hash_file', metadata_sig_file,
           '--payload_hash_file', payload_sig_file]
    proc = common.Run(cmd)
    stdoutdata, _ = proc.communicate()
    self.assertEqual(
        0, proc.returncode,
        'Failed to run brillo_update_payload:\n{}'.format(stdoutdata))

    signed_metadata_sig_file = payload_signer.Sign(metadata_sig_file)

    # Finally we can compare the two signatures.
    with open(signed_metadata_sig_file, 'rb') as verify_fp:
      self.assertEqual(verify_fp.read(), metadata_signature)

  @staticmethod
  def construct_zip_package_withValidPayload(with_metadata=False):
    # Cannot use construct_zip_package() since we need a "valid" payload.bin.
    target_file = construct_target_files()
    payload = Payload()
    payload.Generate(target_file)

    payload_signer = PayloadSigner()
    payload.Sign(payload_signer)

    zip_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(zip_file, 'w') as zip_fp:
      # 'payload.bin',
      payload.WriteToZip(zip_fp)

      # Other entries.
      entries = ['care_map.txt', 'compatibility.zip']

      # Put META-INF/com/android/metadata if needed.
      if with_metadata:
        entries.append('META-INF/com/android/metadata')

      for entry in entries:
        zip_fp.writestr(
            entry, entry.replace('.', '-').upper(), zipfile.ZIP_STORED)

    return zip_file

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Compute(self):
    zip_file = self.construct_zip_package_withValidPayload()
    property_files = AbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    # "6" indcludes the four entries above, one metadata entry, and one entry
    # for payload-metadata.bin.
    self.assertEqual(6, len(tokens))
    self._verify_entries(
        zip_file, tokens, ('care_map.txt', 'compatibility.zip'))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Finalize(self):
    zip_file = self.construct_zip_package_withValidPayload(with_metadata=True)
    property_files = AbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      property_files_string = property_files.Finalize(zip_fp, len(raw_metadata))

    tokens = self._parse_property_files_string(property_files_string)
    # "6" indcludes the four entries above, one metadata entry, and one entry
    # for payload-metadata.bin.
    self.assertEqual(6, len(tokens))
    self._verify_entries(
        zip_file, tokens, ('care_map.txt', 'compatibility.zip'))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Verify(self):
    zip_file = self.construct_zip_package_withValidPayload(with_metadata=True)
    property_files = AbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r') as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)

      property_files.Verify(zip_fp, raw_metadata)


class NonAbOtaPropertyFilesTest(PropertyFilesTest):
  """Additional sanity checks specialized for NonAbOtaPropertyFiles."""

  def test_init(self):
    property_files = NonAbOtaPropertyFiles()
    self.assertEqual('ota-property-files', property_files.name)
    self.assertEqual((), property_files.required)
    self.assertEqual((), property_files.optional)

  def test_Compute(self):
    entries = ()
    zip_file = self.construct_zip_package(entries)
    property_files = NonAbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file) as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(1, len(tokens))
    self._verify_entries(zip_file, tokens, entries)

  def test_Finalize(self):
    entries = [
        'META-INF/com/android/metadata',
    ]
    zip_file = self.construct_zip_package(entries)
    property_files = NonAbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file) as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      property_files_string = property_files.Finalize(zip_fp, len(raw_metadata))
    tokens = self._parse_property_files_string(property_files_string)

    self.assertEqual(1, len(tokens))
    # 'META-INF/com/android/metadata' will be key'd as 'metadata'.
    entries[0] = 'metadata'
    self._verify_entries(zip_file, tokens, entries)

  def test_Verify(self):
    entries = (
        'META-INF/com/android/metadata',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = NonAbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file) as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)

      property_files.Verify(zip_fp, raw_metadata)


class PayloadSignerTest(test_utils.ReleaseToolsTestCase):

  SIGFILE = 'sigfile.bin'
  SIGNED_SIGFILE = 'signed-sigfile.bin'

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    self.assertTrue(os.path.exists(self.testdata_dir))

    common.OPTIONS.payload_signer = None
    common.OPTIONS.payload_signer_args = []
    common.OPTIONS.package_key = os.path.join(self.testdata_dir, 'testkey')
    common.OPTIONS.key_passwords = {
        common.OPTIONS.package_key : None,
    }

  def _assertFilesEqual(self, file1, file2):
    with open(file1, 'rb') as fp1, open(file2, 'rb') as fp2:
      self.assertEqual(fp1.read(), fp2.read())

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_init(self):
    payload_signer = PayloadSigner()
    self.assertEqual('openssl', payload_signer.signer)
    self.assertEqual(256, payload_signer.maximum_signature_size)

  @test_utils.SkipIfExternalToolsUnavailable()
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
    common.OPTIONS.payload_signer_maximum_signature_size = '512'
    payload_signer = PayloadSigner()
    self.assertEqual('abc', payload_signer.signer)
    self.assertEqual(['arg1', 'arg2'], payload_signer.signer_args)
    self.assertEqual(512, payload_signer.maximum_signature_size)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetMaximumSignatureSizeInBytes_512Bytes(self):
    signing_key = os.path.join(self.testdata_dir, 'testkey_RSA4096.key')
    # pylint: disable=protected-access
    signature_size = PayloadSigner._GetMaximumSignatureSizeInBytes(signing_key)
    self.assertEqual(512, signature_size)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetMaximumSignatureSizeInBytes_ECKey(self):
    signing_key = os.path.join(self.testdata_dir, 'testkey_EC.key')
    # pylint: disable=protected-access
    signature_size = PayloadSigner._GetMaximumSignatureSizeInBytes(signing_key)
    self.assertEqual(72, signature_size)

  @test_utils.SkipIfExternalToolsUnavailable()
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
    os.chmod(common.OPTIONS.payload_signer, 0o700)
    common.OPTIONS.payload_signer_args = [
        os.path.join(self.testdata_dir, 'testkey.pk8')]
    payload_signer = PayloadSigner()
    input_file = os.path.join(self.testdata_dir, self.SIGFILE)
    signed_file = payload_signer.Sign(input_file)

    verify_file = os.path.join(self.testdata_dir, self.SIGNED_SIGFILE)
    self._assertFilesEqual(verify_file, signed_file)


class PayloadTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()
    self.assertTrue(os.path.exists(self.testdata_dir))

    common.OPTIONS.wipe_user_data = False
    common.OPTIONS.payload_signer = None
    common.OPTIONS.payload_signer_args = None
    common.OPTIONS.package_key = os.path.join(self.testdata_dir, 'testkey')
    common.OPTIONS.key_passwords = {
        common.OPTIONS.package_key : None,
    }

  @staticmethod
  def _create_payload_full(secondary=False):
    target_file = construct_target_files(secondary)
    payload = Payload(secondary)
    payload.Generate(target_file)
    return payload

  @staticmethod
  def _create_payload_incremental():
    target_file = construct_target_files()
    source_file = construct_target_files()
    payload = Payload()
    payload.Generate(target_file, source_file)
    return payload

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Generate_full(self):
    payload = self._create_payload_full()
    self.assertTrue(os.path.exists(payload.payload_file))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Generate_incremental(self):
    payload = self._create_payload_incremental()
    self.assertTrue(os.path.exists(payload.payload_file))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Generate_additionalArgs(self):
    target_file = construct_target_files()
    source_file = construct_target_files()
    payload = Payload()
    # This should work the same as calling payload.Generate(target_file,
    # source_file).
    payload.Generate(
        target_file, additional_args=["--source_image", source_file])
    self.assertTrue(os.path.exists(payload.payload_file))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Generate_invalidInput(self):
    target_file = construct_target_files()
    common.ZipDelete(target_file, 'IMAGES/vendor.img')
    payload = Payload()
    self.assertRaises(common.ExternalError, payload.Generate, target_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Sign_full(self):
    payload = self._create_payload_full()
    payload.Sign(PayloadSigner())

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      payload.WriteToZip(output_zip)

    import check_ota_package_signature
    check_ota_package_signature.VerifyAbOtaPayload(
        os.path.join(self.testdata_dir, 'testkey.x509.pem'),
        output_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Sign_incremental(self):
    payload = self._create_payload_incremental()
    payload.Sign(PayloadSigner())

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      payload.WriteToZip(output_zip)

    import check_ota_package_signature
    check_ota_package_signature.VerifyAbOtaPayload(
        os.path.join(self.testdata_dir, 'testkey.x509.pem'),
        output_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Sign_withDataWipe(self):
    common.OPTIONS.wipe_user_data = True
    payload = self._create_payload_full()
    payload.Sign(PayloadSigner())

    with open(payload.payload_properties) as properties_fp:
      self.assertIn("POWERWASH=1", properties_fp.read())

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Sign_secondary(self):
    payload = self._create_payload_full(secondary=True)
    payload.Sign(PayloadSigner())

    with open(payload.payload_properties) as properties_fp:
      self.assertIn("SWITCH_SLOT_ON_REBOOT=0", properties_fp.read())

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Sign_badSigner(self):
    """Tests that signing failure can be captured."""
    payload = self._create_payload_full()
    payload_signer = PayloadSigner()
    payload_signer.signer_args.append('bad-option')
    self.assertRaises(common.ExternalError, payload.Sign, payload_signer)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_WriteToZip(self):
    payload = self._create_payload_full()
    payload.Sign(PayloadSigner())

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      payload.WriteToZip(output_zip)

    with zipfile.ZipFile(output_file) as verify_zip:
      # First make sure we have the essential entries.
      namelist = verify_zip.namelist()
      self.assertIn(Payload.PAYLOAD_BIN, namelist)
      self.assertIn(Payload.PAYLOAD_PROPERTIES_TXT, namelist)

      # Then assert these entries are stored.
      for entry_info in verify_zip.infolist():
        if entry_info.filename not in (Payload.PAYLOAD_BIN,
                                       Payload.PAYLOAD_PROPERTIES_TXT):
          continue
        self.assertEqual(zipfile.ZIP_STORED, entry_info.compress_type)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_WriteToZip_unsignedPayload(self):
    """Unsigned payloads should not be allowed to be written to zip."""
    payload = self._create_payload_full()

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      self.assertRaises(AssertionError, payload.WriteToZip, output_zip)

    # Also test with incremental payload.
    payload = self._create_payload_incremental()

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      self.assertRaises(AssertionError, payload.WriteToZip, output_zip)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_WriteToZip_secondary(self):
    payload = self._create_payload_full(secondary=True)
    payload.Sign(PayloadSigner())

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      payload.WriteToZip(output_zip)

    with zipfile.ZipFile(output_file) as verify_zip:
      # First make sure we have the essential entries.
      namelist = verify_zip.namelist()
      self.assertIn(Payload.SECONDARY_PAYLOAD_BIN, namelist)
      self.assertIn(Payload.SECONDARY_PAYLOAD_PROPERTIES_TXT, namelist)

      # Then assert these entries are stored.
      for entry_info in verify_zip.infolist():
        if entry_info.filename not in (
            Payload.SECONDARY_PAYLOAD_BIN,
            Payload.SECONDARY_PAYLOAD_PROPERTIES_TXT):
          continue
        self.assertEqual(zipfile.ZIP_STORED, entry_info.compress_type)
