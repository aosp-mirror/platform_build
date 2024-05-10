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
import tempfile
import zipfile

import common
import ota_metadata_pb2
import test_utils
from ota_utils import (
    BuildLegacyOtaMetadata, CalculateRuntimeDevicesAndFingerprints,
    ConstructOtaApexInfo, FinalizeMetadata, GetPackageMetadata, PropertyFiles, AbOtaPropertyFiles, PayloadGenerator, StreamingPropertyFiles)
from ota_from_target_files import (
    _LoadOemDicts,
    GetTargetFilesZipForCustomImagesUpdates,
    GetTargetFilesZipForPartialUpdates,
    GetTargetFilesZipForSecondaryImages,
    GetTargetFilesZipWithoutPostinstallConfig,
    POSTINSTALL_CONFIG, AB_PARTITIONS)
from apex_utils import GetApexInfoFromTargetFiles
from test_utils import PropertyFilesTestCase
from common import OPTIONS
from payload_signer import PayloadSigner


def construct_target_files(secondary=False, compressedApex=False):
  """Returns a target-files.zip file for generating OTA packages."""
  target_files = common.MakeTempFile(prefix='target_files-', suffix='.zip')
  with zipfile.ZipFile(target_files, 'w', allowZip64=True) as target_files_zip:
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

    # Create fake images for each of them.
    for path, partition in ab_partitions:
      target_files_zip.writestr(
          '{}/{}.img'.format(path, partition),
          os.urandom(len(partition)))

    # system_other shouldn't appear in META/ab_partitions.txt.
    if secondary:
      target_files_zip.writestr('IMAGES/system_other.img',
                                os.urandom(len("system_other")))

    if compressedApex:
      apex_file_name = 'com.android.apex.compressed.v1.capex'
      apex_file = os.path.join(test_utils.get_current_dir(), apex_file_name)
      target_files_zip.write(apex_file, 'SYSTEM/apex/' + apex_file_name)

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
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.device': 'product-device',
              'ro.build.fingerprint': 'build-fingerprint-target',
              'ro.build.version.incremental': 'build-version-incremental-target',
              'ro.build.version.sdk': '27',
              'ro.build.version.security_patch': '2017-12-01',
              'ro.build.date.utc': '1500000000'}
      )
  }

  TEST_SOURCE_INFO_DICT = {
      'build.prop': common.PartitionBuildProps.FromDictionary(
          'system', {
              'ro.product.device': 'product-device',
              'ro.build.fingerprint': 'build-fingerprint-source',
              'ro.build.version.incremental': 'build-version-incremental-source',
              'ro.build.version.sdk': '25',
              'ro.build.version.security_patch': '2016-12-01',
              'ro.build.date.utc': '1400000000'}
      )
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

  TEST_TARGET_VENDOR_INFO_DICT = common.PartitionBuildProps.FromDictionary(
    'vendor', {
      'ro.vendor.build.date.utc' : '87654321',
      'ro.product.vendor.device':'vendor-device',
      'ro.vendor.build.fingerprint': 'build-fingerprint-vendor'}
  )

  TEST_SOURCE_VENDOR_INFO_DICT = common.PartitionBuildProps.FromDictionary(
    'vendor', {
      'ro.vendor.build.date.utc' : '12345678',
      'ro.product.vendor.device':'vendor-device',
      'ro.vendor.build.fingerprint': 'build-fingerprint-vendor'}
  )

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
        common.OPTIONS.package_key: None,
    }

    common.OPTIONS.search_path = test_utils.get_search_path()

  @staticmethod
  def GetLegacyOtaMetadata(target_info, source_info=None):
    metadata_proto = GetPackageMetadata(target_info, source_info)
    return BuildLegacyOtaMetadata(metadata_proto)

  def test_GetPackageMetadata_abOta_full(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info_dict['ab_partitions'] = []
    target_info = common.BuildInfo(target_info_dict, None)
    metadata = self.GetLegacyOtaMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type': 'AB',
            'ota-required-cache': '0',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1500000000',
            'pre-device': 'product-device',
        },
        metadata)

  def test_GetPackageMetadata_abOta_incremental(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info_dict['ab_partitions'] = []
    target_info = common.BuildInfo(target_info_dict, None)
    source_info = common.BuildInfo(self.TEST_SOURCE_INFO_DICT, None)
    common.OPTIONS.incremental_source = ''
    metadata = self.GetLegacyOtaMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-type': 'AB',
            'ota-required-cache': '0',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1500000000',
            'pre-device': 'product-device',
            'pre-build': 'build-fingerprint-source',
            'pre-build-incremental': 'build-version-incremental-source',
        },
        metadata)

  def test_GetPackageMetadata_nonAbOta_full(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    metadata = self.GetLegacyOtaMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type': 'BLOCK',
            'ota-required-cache': '0',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1500000000',
            'pre-device': 'product-device',
        },
        metadata)

  def test_GetPackageMetadata_nonAbOta_incremental(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    source_info = common.BuildInfo(self.TEST_SOURCE_INFO_DICT, None)
    common.OPTIONS.incremental_source = ''
    metadata = self.GetLegacyOtaMetadata(target_info, source_info)
    self.assertDictEqual(
        {
            'ota-type': 'BLOCK',
            'ota-required-cache': '0',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1500000000',
            'pre-device': 'product-device',
            'pre-build': 'build-fingerprint-source',
            'pre-build-incremental': 'build-version-incremental-source',
        },
        metadata)

  def test_GetPackageMetadata_wipe(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    common.OPTIONS.wipe_user_data = True
    metadata = self.GetLegacyOtaMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-type': 'BLOCK',
            'ota-required-cache': '0',
            'ota-wipe': 'yes',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1500000000',
            'pre-device': 'product-device',
        },
        metadata)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetApexInfoFromTargetFiles(self):
    target_files = construct_target_files(compressedApex=True)
    apex_infos = GetApexInfoFromTargetFiles(target_files)
    self.assertEqual(len(apex_infos), 1)
    self.assertEqual(apex_infos[0].package_name, "com.android.apex.compressed")
    self.assertEqual(apex_infos[0].version, 1)
    self.assertEqual(apex_infos[0].is_compressed, True)
    # Compare the decompressed APEX size with the original uncompressed APEX
    original_apex_name = 'com.android.apex.compressed.v1_original.apex'
    original_apex_filepath = os.path.join(
        test_utils.get_current_dir(), original_apex_name)
    uncompressed_apex_size = os.path.getsize(original_apex_filepath)
    self.assertEqual(apex_infos[0].decompressed_size, uncompressed_apex_size)

  @staticmethod
  def construct_tf_with_apex_info(infos):
    apex_metadata_proto = ota_metadata_pb2.ApexMetadata()
    apex_metadata_proto.apex_info.extend(infos)

    output = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output, 'w') as zfp:
      common.ZipWriteStr(zfp, "META/apex_info.pb",
                         apex_metadata_proto.SerializeToString())
    return output

  def test_ConstructOtaApexInfo_incremental_package(self):
    infos = [ota_metadata_pb2.ApexInfo(package_name='com.android.apex.1',
                                       version=1000, is_compressed=False),
             ota_metadata_pb2.ApexInfo(package_name='com.android.apex.2',
                                       version=2000, is_compressed=True)]
    target_file = self.construct_tf_with_apex_info(infos)

    with zipfile.ZipFile(target_file) as target_zip:
      info_bytes = ConstructOtaApexInfo(target_zip, source_file=target_file)
    apex_metadata_proto = ota_metadata_pb2.ApexMetadata()
    apex_metadata_proto.ParseFromString(info_bytes)

    info_list = apex_metadata_proto.apex_info
    self.assertEqual(2, len(info_list))
    self.assertEqual('com.android.apex.1', info_list[0].package_name)
    self.assertEqual(1000, info_list[0].version)
    self.assertEqual(1000, info_list[0].source_version)

  def test_GetPackageMetadata_retrofitDynamicPartitions(self):
    target_info = common.BuildInfo(self.TEST_TARGET_INFO_DICT, None)
    common.OPTIONS.retrofit_dynamic_partitions = True
    metadata = self.GetLegacyOtaMetadata(target_info)
    self.assertDictEqual(
        {
            'ota-retrofit-dynamic-partitions': 'yes',
            'ota-type': 'BLOCK',
            'ota-required-cache': '0',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1500000000',
            'pre-device': 'product-device',
        },
        metadata)

  @staticmethod
  def _test_GetPackageMetadata_swapBuildTimestamps(target_info, source_info):
    (target_info['build.prop'].build_props['ro.build.date.utc'],
     source_info['build.prop'].build_props['ro.build.date.utc']) = (
         source_info['build.prop'].build_props['ro.build.date.utc'],
         target_info['build.prop'].build_props['ro.build.date.utc'])

  @staticmethod
  def _test_GetPackageMetadata_swapVendorBuildTimestamps(target_info, source_info):
    (target_info['vendor.build.prop'].build_props['ro.vendor.build.date.utc'],
     source_info['vendor.build.prop'].build_props['ro.vendor.build.date.utc']) = (
         source_info['vendor.build.prop'].build_props['ro.vendor.build.date.utc'],
         target_info['vendor.build.prop'].build_props['ro.vendor.build.date.utc'])

  def test_GetPackageMetadata_unintentionalDowngradeDetected(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    source_info_dict = copy.deepcopy(self.TEST_SOURCE_INFO_DICT)
    self._test_GetPackageMetadata_swapBuildTimestamps(
        target_info_dict, source_info_dict)

    target_info = common.BuildInfo(target_info_dict, None)
    source_info = common.BuildInfo(source_info_dict, None)
    common.OPTIONS.incremental_source = ''
    self.assertRaises(RuntimeError, self.GetLegacyOtaMetadata, target_info,
                      source_info)

  def test_GetPackageMetadata_unintentionalVendorDowngradeDetected(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info_dict['ab_partitions'] = ['vendor']
    target_info_dict["vendor.build.prop"] = copy.deepcopy(self.TEST_TARGET_VENDOR_INFO_DICT)
    source_info_dict = copy.deepcopy(self.TEST_SOURCE_INFO_DICT)
    source_info_dict['ab_update'] = 'true'
    source_info_dict['ab_partitions'] = ['vendor']
    source_info_dict["vendor.build.prop"] = copy.deepcopy(self.TEST_SOURCE_VENDOR_INFO_DICT)
    self._test_GetPackageMetadata_swapVendorBuildTimestamps(
        target_info_dict, source_info_dict)

    target_info = common.BuildInfo(target_info_dict, None)
    source_info = common.BuildInfo(source_info_dict, None)
    common.OPTIONS.incremental_source = ''
    self.assertRaises(RuntimeError, self.GetLegacyOtaMetadata, target_info,
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
    common.OPTIONS.spl_downgrade = True
    metadata = self.GetLegacyOtaMetadata(target_info, source_info)
    # Reset spl_downgrade so other tests are unaffected
    common.OPTIONS.spl_downgrade = False

    self.assertDictEqual(
        {
            'ota-downgrade': 'yes',
            'ota-type': 'BLOCK',
            'ota-required-cache': '0',
            'ota-wipe': 'yes',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1400000000',
            'pre-device': 'product-device',
            'pre-build': 'build-fingerprint-source',
            'pre-build-incremental': 'build-version-incremental-source',
            'spl-downgrade': 'yes',
        },
        metadata)

  def test_GetPackageMetadata_vendorDowngrade(self):
    target_info_dict = copy.deepcopy(self.TEST_TARGET_INFO_DICT)
    target_info_dict['ab_update'] = 'true'
    target_info_dict['ab_partitions'] = ['vendor']
    target_info_dict["vendor.build.prop"] = copy.deepcopy(self.TEST_TARGET_VENDOR_INFO_DICT)
    source_info_dict = copy.deepcopy(self.TEST_SOURCE_INFO_DICT)
    source_info_dict['ab_update'] = 'true'
    source_info_dict['ab_partitions'] = ['vendor']
    source_info_dict["vendor.build.prop"] = copy.deepcopy(self.TEST_SOURCE_VENDOR_INFO_DICT)
    self._test_GetPackageMetadata_swapVendorBuildTimestamps(
        target_info_dict, source_info_dict)

    target_info = common.BuildInfo(target_info_dict, None)
    source_info = common.BuildInfo(source_info_dict, None)
    common.OPTIONS.incremental_source = ''
    common.OPTIONS.downgrade = True
    common.OPTIONS.wipe_user_data = True
    common.OPTIONS.spl_downgrade = True
    metadata = self.GetLegacyOtaMetadata(target_info, source_info)
    # Reset spl_downgrade so other tests are unaffected
    common.OPTIONS.spl_downgrade = False

    self.assertDictEqual(
        {
            'ota-downgrade': 'yes',
            'ota-type': 'AB',
            'ota-required-cache': '0',
            'ota-wipe': 'yes',
            'post-build': 'build-fingerprint-target',
            'post-build-incremental': 'build-version-incremental-target',
            'post-sdk-level': '27',
            'post-security-patch-level': '2017-12-01',
            'post-timestamp': '1500000000',
            'pre-device': 'product-device',
            'pre-build': 'build-fingerprint-source',
            'pre-build-incremental': 'build-version-incremental-source',
            'spl-downgrade': 'yes',
        },
        metadata)

    post_build = GetPackageMetadata(target_info, source_info).postcondition
    self.assertEqual('vendor', post_build.partition_state[0].partition_name)
    self.assertEqual('12345678', post_build.partition_state[0].version)

    pre_build = GetPackageMetadata(target_info, source_info).precondition
    self.assertEqual('vendor', pre_build.partition_state[0].partition_name)
    self.assertEqual('87654321', pre_build.partition_state[0].version)


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

    with zipfile.ZipFile(input_file, 'a', allowZip64=True) as append_zip:
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
  def test_GetTargetFilesZipForPartialUpdates_singlePartition(self):
    input_file = construct_target_files()
    with zipfile.ZipFile(input_file, 'a', allowZip64=True) as append_zip:
      common.ZipWriteStr(append_zip, 'IMAGES/system.map', 'fake map')

    target_file = GetTargetFilesZipForPartialUpdates(input_file, ['system'])
    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()
      ab_partitions = verify_zip.read('META/ab_partitions.txt').decode()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertIn('META/update_engine_config.txt', namelist)
    self.assertIn('IMAGES/system.img', namelist)
    self.assertIn('IMAGES/system.map', namelist)

    self.assertNotIn('IMAGES/boot.img', namelist)
    self.assertNotIn('IMAGES/system_other.img', namelist)
    self.assertNotIn('RADIO/bootloader.img', namelist)
    self.assertNotIn('RADIO/modem.img', namelist)

    self.assertEqual('system', ab_partitions)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForPartialUpdates_unrecognizedPartition(self):
    input_file = construct_target_files()
    self.assertRaises(ValueError, GetTargetFilesZipForPartialUpdates,
                      input_file, ['product'])

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForPartialUpdates_dynamicPartitions(self):
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

    with zipfile.ZipFile(input_file, 'a', allowZip64=True) as append_zip:
      common.ZipWriteStr(append_zip, 'META/misc_info.txt', misc_info)
      common.ZipWriteStr(append_zip, 'META/dynamic_partitions_info.txt',
                         dynamic_partitions_info)

    target_file = GetTargetFilesZipForPartialUpdates(input_file,
                                                     ['boot', 'system'])
    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()
      ab_partitions = verify_zip.read('META/ab_partitions.txt').decode()
      updated_misc_info = verify_zip.read('META/misc_info.txt').decode()
      updated_dynamic_partitions_info = verify_zip.read(
          'META/dynamic_partitions_info.txt').decode()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertIn('IMAGES/boot.img', namelist)
    self.assertIn('IMAGES/system.img', namelist)
    self.assertIn('META/misc_info.txt', namelist)
    self.assertIn('META/dynamic_partitions_info.txt', namelist)

    self.assertNotIn('IMAGES/system_other.img', namelist)
    self.assertNotIn('RADIO/bootloader.img', namelist)
    self.assertNotIn('RADIO/modem.img', namelist)

    # Check the vendor & product are removed from the partitions list.
    expected_misc_info = misc_info.replace('system vendor product',
                                           'system')
    expected_dynamic_partitions_info = dynamic_partitions_info.replace(
        'system vendor product', 'system')
    self.assertEqual(expected_misc_info, updated_misc_info)
    self.assertEqual(expected_dynamic_partitions_info,
                     updated_dynamic_partitions_info)
    self.assertEqual('boot\nsystem', ab_partitions)

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

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForCustomImagesUpdates_oemDefaultImage(self):
    input_file = construct_target_files()
    with zipfile.ZipFile(input_file, 'a', allowZip64=True) as append_zip:
      common.ZipWriteStr(append_zip, 'IMAGES/oem.img', 'oem')
      common.ZipWriteStr(append_zip, 'IMAGES/oem_test.img', 'oem_test')

    target_file = GetTargetFilesZipForCustomImagesUpdates(
        input_file, {'oem': 'oem.img'})

    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()
      ab_partitions = verify_zip.read('META/ab_partitions.txt').decode()
      oem_image = verify_zip.read('IMAGES/oem.img').decode()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertEqual('boot\nsystem\nvendor\nbootloader\nmodem', ab_partitions)
    self.assertIn('IMAGES/oem.img', namelist)
    self.assertEqual('oem', oem_image)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetTargetFilesZipForCustomImagesUpdates_oemTestImage(self):
    input_file = construct_target_files()
    with zipfile.ZipFile(input_file, 'a', allowZip64=True) as append_zip:
      common.ZipWriteStr(append_zip, 'IMAGES/oem.img', 'oem')
      common.ZipWriteStr(append_zip, 'IMAGES/oem_test.img', 'oem_test')

    target_file = GetTargetFilesZipForCustomImagesUpdates(
        input_file, {'oem': 'oem_test.img'})

    with zipfile.ZipFile(target_file) as verify_zip:
      namelist = verify_zip.namelist()
      ab_partitions = verify_zip.read('META/ab_partitions.txt').decode()
      oem_image = verify_zip.read('IMAGES/oem.img').decode()

    self.assertIn('META/ab_partitions.txt', namelist)
    self.assertEqual('boot\nsystem\nvendor\nbootloader\nmodem', ab_partitions)
    self.assertIn('IMAGES/oem.img', namelist)
    self.assertEqual('oem_test', oem_image)

  def _test_FinalizeMetadata(self, large_entry=False):
    entries = [
        'required-entry1',
        'required-entry2',
    ]
    zip_file = PropertyFilesTest.construct_zip_package(entries)
    # Add a large entry of 1 GiB if requested.
    if large_entry:
      with zipfile.ZipFile(zip_file, 'a', allowZip64=True) as zip_fp:
        zip_fp.writestr(
            # Using 'zoo' so that the entry stays behind others after signing.
            'zoo',
            'A' * 1024 * 1024 * 1024,
            zipfile.ZIP_STORED)

    metadata = ota_metadata_pb2.OtaMetadata()
    output_file = common.MakeTempFile(suffix='.zip')
    needed_property_files = (
        TestPropertyFiles(),
    )
    FinalizeMetadata(metadata, zip_file, output_file, needed_property_files)
    self.assertIn('ota-test-property-files', metadata.property_files)

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
    with zipfile.ZipFile(zip_file, 'a', allowZip64=True) as zip_fp:
      zip_fp.writestr(
          # 'foo-entry1' will appear ahead of all other entries (in alphabetical
          # order) after the signing, which will in turn trigger the
          # InsufficientSpaceException and an automatic retry.
          'foo-entry1',
          'A' * 1024 * 1024,
          zipfile.ZIP_STORED)

    metadata = ota_metadata_pb2.OtaMetadata()
    needed_property_files = (
        TestPropertyFiles(),
    )
    output_file = common.MakeTempFile(suffix='.zip')
    FinalizeMetadata(metadata, zip_file, output_file, needed_property_files)
    self.assertIn('ota-test-property-files', metadata.property_files)


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


class PropertyFilesTest(PropertyFilesTestCase):

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Compute(self):
    entries = (
        'required-entry1',
        'required-entry2',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(4, len(tokens))
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
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(6, len(tokens))
    self._verify_entries(zip_file, tokens, entries)

  def test_Compute_missingRequiredEntry(self):
    entries = (
        'required-entry2',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      self.assertRaises(KeyError, property_files.Compute, zip_fp)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Finalize(self):
    entries = [
        'required-entry1',
        'required-entry2',
        'META-INF/com/android/metadata',
        'META-INF/com/android/metadata.pb',
    ]
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      streaming_metadata = property_files.Finalize(zip_fp, len(raw_metadata))
    tokens = self._parse_property_files_string(streaming_metadata)

    self.assertEqual(4, len(tokens))
    # 'META-INF/com/android/metadata' will be key'd as 'metadata' in the
    # streaming metadata.
    entries[2] = 'metadata'
    entries[3] = 'metadata.pb'
    self._verify_entries(zip_file, tokens, entries)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Finalize_assertReservedLength(self):
    entries = (
        'required-entry1',
        'required-entry2',
        'optional-entry1',
        'optional-entry2',
        'META-INF/com/android/metadata',
        'META-INF/com/android/metadata.pb',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
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
        'META-INF/com/android/metadata.pb',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = TestPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      # First get the raw metadata string (i.e. without padding space).
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)

      # Should pass the test if verification passes.
      property_files.Verify(zip_fp, raw_metadata)

      # Or raise on verification failure.
      self.assertRaises(
          AssertionError, property_files.Verify, zip_fp, raw_metadata + 'x')


class StreamingPropertyFilesTest(PropertyFilesTestCase):
  """Additional validity checks specialized for StreamingPropertyFiles."""

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
            'apex_info.pb',
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
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    self.assertEqual(6, len(tokens))
    self._verify_entries(zip_file, tokens, entries)

  def test_Finalize(self):
    entries = [
        'payload.bin',
        'payload_properties.txt',
        'care_map.txt',
        'compatibility.zip',
        'META-INF/com/android/metadata',
        'META-INF/com/android/metadata.pb',
    ]
    zip_file = self.construct_zip_package(entries)
    property_files = StreamingPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      streaming_metadata = property_files.Finalize(zip_fp, len(raw_metadata))
    tokens = self._parse_property_files_string(streaming_metadata)

    self.assertEqual(6, len(tokens))
    # 'META-INF/com/android/metadata' will be key'd as 'metadata' in the
    # streaming metadata.
    entries[4] = 'metadata'
    entries[5] = 'metadata.pb'
    self._verify_entries(zip_file, tokens, entries)

  def test_Verify(self):
    entries = (
        'payload.bin',
        'payload_properties.txt',
        'care_map.txt',
        'compatibility.zip',
        'META-INF/com/android/metadata',
        'META-INF/com/android/metadata.pb',
    )
    zip_file = self.construct_zip_package(entries)
    property_files = StreamingPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      # First get the raw metadata string (i.e. without padding space).
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)

      # Should pass the test if verification passes.
      property_files.Verify(zip_fp, raw_metadata)

      # Or raise on verification failure.
      self.assertRaises(
          AssertionError, property_files.Verify, zip_fp, raw_metadata + 'x')


class AbOtaPropertyFilesTest(PropertyFilesTestCase):
  """Additional validity checks specialized for AbOtaPropertyFiles."""

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
        common.OPTIONS.package_key: None,
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
            'apex_info.pb',
            'care_map.pb',
            'care_map.txt',
            'compatibility.zip',
        ),
        property_files.optional)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_GetPayloadMetadataOffsetAndSize(self):
    target_file = construct_target_files()
    payload = PayloadGenerator()
    payload.Generate(target_file)

    payload_signer = PayloadSigner()
    payload.Sign(payload_signer)

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w', allowZip64=True) as output_zip:
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

    signed_metadata_sig_file = payload_signer.SignHashFile(metadata_sig_file)

    # Finally we can compare the two signatures.
    with open(signed_metadata_sig_file, 'rb') as verify_fp:
      self.assertEqual(verify_fp.read(), metadata_signature)

  @staticmethod
  def construct_zip_package_withValidPayload(with_metadata=False):
    # Cannot use construct_zip_package() since we need a "valid" payload.bin.
    target_file = construct_target_files()
    payload = PayloadGenerator()
    payload.Generate(target_file)

    payload_signer = PayloadSigner()
    payload.Sign(payload_signer)

    zip_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(zip_file, 'w', allowZip64=True) as zip_fp:
      # 'payload.bin',
      payload.WriteToZip(zip_fp)

      # Other entries.
      entries = ['care_map.txt', 'compatibility.zip']

      # Put META-INF/com/android/metadata if needed.
      if with_metadata:
        entries.append('META-INF/com/android/metadata')
        entries.append('META-INF/com/android/metadata.pb')

      for entry in entries:
        zip_fp.writestr(
            entry, entry.replace('.', '-').upper(), zipfile.ZIP_STORED)

    return zip_file

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Compute(self):
    zip_file = self.construct_zip_package_withValidPayload()
    property_files = AbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      property_files_string = property_files.Compute(zip_fp)

    tokens = self._parse_property_files_string(property_files_string)
    # "7" indcludes the four entries above, two metadata entries, and one entry
    # for payload-metadata.bin.
    self.assertEqual(7, len(tokens))
    self._verify_entries(
        zip_file, tokens, ('care_map.txt', 'compatibility.zip'))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Finalize(self):
    zip_file = self.construct_zip_package_withValidPayload(with_metadata=True)
    property_files = AbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
      raw_metadata = property_files.GetPropertyFilesString(
          zip_fp, reserve_space=False)
      property_files_string = property_files.Finalize(
          zip_fp, len(raw_metadata))

    tokens = self._parse_property_files_string(property_files_string)
    # "7" includes the four entries above, two metadata entries, and one entry
    # for payload-metadata.bin.
    self.assertEqual(7, len(tokens))
    self._verify_entries(
        zip_file, tokens, ('care_map.txt', 'compatibility.zip'))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Verify(self):
    zip_file = self.construct_zip_package_withValidPayload(with_metadata=True)
    property_files = AbOtaPropertyFiles()
    with zipfile.ZipFile(zip_file, 'r', allowZip64=True) as zip_fp:
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
        common.OPTIONS.package_key: None,
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
        common.OPTIONS.package_key: 'foo',
    }
    payload_signer = PayloadSigner()
    self.assertEqual('openssl', payload_signer.signer)

  def test_init_withExternalSigner(self):
    common.OPTIONS.payload_signer_args = ['arg1', 'arg2']
    common.OPTIONS.payload_signer_maximum_signature_size = '512'
    payload_signer = PayloadSigner(
        OPTIONS.package_key, OPTIONS.private_key_suffix, payload_signer='abc')
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
    signed_file = payload_signer.SignHashFile(input_file)

    verify_file = os.path.join(self.testdata_dir, self.SIGNED_SIGFILE)
    self._assertFilesEqual(verify_file, signed_file)

  def test_Sign_withExternalSigner_openssl(self):
    """Uses openssl as the external payload signer."""
    common.OPTIONS.payload_signer_args = [
        'pkeyutl', '-sign', '-keyform', 'DER', '-inkey',
        os.path.join(self.testdata_dir, 'testkey.pk8'),
        '-pkeyopt', 'digest:sha256']
    payload_signer = PayloadSigner(
        OPTIONS.package_key, OPTIONS.private_key_suffix, payload_signer="openssl")
    input_file = os.path.join(self.testdata_dir, self.SIGFILE)
    signed_file = payload_signer.SignHashFile(input_file)

    verify_file = os.path.join(self.testdata_dir, self.SIGNED_SIGFILE)
    self._assertFilesEqual(verify_file, signed_file)

  def test_Sign_withExternalSigner_script(self):
    """Uses testdata/payload_signer.sh as the external payload signer."""
    external_signer = os.path.join(
        self.testdata_dir, 'payload_signer.sh')
    os.chmod(external_signer, 0o700)
    common.OPTIONS.payload_signer_args = [
        os.path.join(self.testdata_dir, 'testkey.pk8')]
    payload_signer = PayloadSigner(
        OPTIONS.package_key, OPTIONS.private_key_suffix, payload_signer=external_signer)
    input_file = os.path.join(self.testdata_dir, self.SIGFILE)
    signed_file = payload_signer.SignHashFile(input_file)

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
        common.OPTIONS.package_key: None,
    }

  @staticmethod
  def _create_payload_full(secondary=False):
    target_file = construct_target_files(secondary)
    payload = PayloadGenerator(secondary, OPTIONS.wipe_user_data)
    payload.Generate(target_file)
    return payload

  @staticmethod
  def _create_payload_incremental():
    target_file = construct_target_files()
    source_file = construct_target_files()
    payload = PayloadGenerator()
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
    payload = PayloadGenerator()
    # This should work the same as calling payload.Generate(target_file,
    # source_file).
    payload.Generate(
        target_file, additional_args=["--source_image", source_file])
    self.assertTrue(os.path.exists(payload.payload_file))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Generate_invalidInput(self):
    target_file = construct_target_files()
    common.ZipDelete(target_file, 'IMAGES/vendor.img')
    payload = PayloadGenerator()
    self.assertRaises(common.ExternalError, payload.Generate, target_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Sign_full(self):
    payload = self._create_payload_full()
    payload.Sign(PayloadSigner())

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w', allowZip64=True) as output_zip:
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
    with zipfile.ZipFile(output_file, 'w', allowZip64=True) as output_zip:
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
    with tempfile.NamedTemporaryFile() as fp:
      with zipfile.ZipFile(fp, "w") as zfp:
        payload.WriteToZip(zfp)

    with open(payload.payload_properties) as properties_fp:
      self.assertIn("POWERWASH=1", properties_fp.read())

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_Sign_secondary(self):
    payload = self._create_payload_full(secondary=True)
    payload.Sign(PayloadSigner())
    with tempfile.NamedTemporaryFile() as fp:
      with zipfile.ZipFile(fp, "w") as zfp:
        payload.WriteToZip(zfp)

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
    with zipfile.ZipFile(output_file, 'w', allowZip64=True) as output_zip:
      payload.WriteToZip(output_zip)

    with zipfile.ZipFile(output_file) as verify_zip:
      # First make sure we have the essential entries.
      namelist = verify_zip.namelist()
      self.assertIn(PayloadGenerator.PAYLOAD_BIN, namelist)
      self.assertIn(PayloadGenerator.PAYLOAD_PROPERTIES_TXT, namelist)

      # Then assert these entries are stored.
      for entry_info in verify_zip.infolist():
        if entry_info.filename not in (PayloadGenerator.PAYLOAD_BIN,
                                       PayloadGenerator.PAYLOAD_PROPERTIES_TXT):
          continue
        self.assertEqual(zipfile.ZIP_STORED, entry_info.compress_type)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_WriteToZip_secondary(self):
    payload = self._create_payload_full(secondary=True)
    payload.Sign(PayloadSigner())

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w', allowZip64=True) as output_zip:
      payload.WriteToZip(output_zip)

    with zipfile.ZipFile(output_file) as verify_zip:
      # First make sure we have the essential entries.
      namelist = verify_zip.namelist()
      self.assertIn(PayloadGenerator.SECONDARY_PAYLOAD_BIN, namelist)
      self.assertIn(PayloadGenerator.SECONDARY_PAYLOAD_PROPERTIES_TXT, namelist)

      # Then assert these entries are stored.
      for entry_info in verify_zip.infolist():
        if entry_info.filename not in (
                PayloadGenerator.SECONDARY_PAYLOAD_BIN,
                PayloadGenerator.SECONDARY_PAYLOAD_PROPERTIES_TXT):
          continue
        self.assertEqual(zipfile.ZIP_STORED, entry_info.compress_type)


class RuntimeFingerprintTest(test_utils.ReleaseToolsTestCase):
  MISC_INFO = [
      'recovery_api_version=3',
      'fstab_version=2',
      'recovery_as_boot=true',
      'ab_update=true',
  ]

  BUILD_PROP = [
      'ro.build.id=build-id',
      'ro.build.version.incremental=version-incremental',
      'ro.build.type=build-type',
      'ro.build.tags=build-tags',
      'ro.build.version.release=version-release',
      'ro.build.version.release_or_codename=version-release',
      'ro.build.version.sdk=30',
      'ro.build.version.security_patch=2020',
      'ro.build.date.utc=12345678',
      'ro.system.build.version.release=version-release',
      'ro.system.build.id=build-id',
      'ro.system.build.version.incremental=version-incremental',
      'ro.system.build.type=build-type',
      'ro.system.build.tags=build-tags',
      'ro.system.build.version.sdk=30',
      'ro.system.build.version.security_patch=2020',
      'ro.system.build.date.utc=12345678',
      'ro.product.system.brand=generic',
      'ro.product.system.name=generic',
      'ro.product.system.device=generic',
  ]

  VENDOR_BUILD_PROP = [
      'ro.vendor.build.version.release=version-release',
      'ro.vendor.build.id=build-id',
      'ro.vendor.build.version.incremental=version-incremental',
      'ro.vendor.build.type=build-type',
      'ro.vendor.build.tags=build-tags',
      'ro.vendor.build.version.sdk=30',
      'ro.vendor.build.version.security_patch=2020',
      'ro.vendor.build.date.utc=12345678',
      'ro.product.vendor.brand=vendor-product-brand',
      'ro.product.vendor.name=vendor-product-name',
      'ro.product.vendor.device=vendor-product-device'
  ]

  def setUp(self):
    common.OPTIONS.oem_dicts = None
    self.test_dir = common.MakeTempDir()
    self.writeFiles({'META/misc_info.txt': '\n'.join(self.MISC_INFO)},
                    self.test_dir)

  def writeFiles(self, contents_dict, out_dir):
    for path, content in contents_dict.items():
      abs_path = os.path.join(out_dir, path)
      dir_name = os.path.dirname(abs_path)
      if not os.path.exists(dir_name):
        os.makedirs(dir_name)
      with open(abs_path, 'w') as f:
        f.write(content)

  @staticmethod
  def constructFingerprint(prefix):
    return '{}:version-release/build-id/version-incremental:' \
           'build-type/build-tags'.format(prefix)

  def test_CalculatePossibleFingerprints_no_dynamic_fingerprint(self):
    build_prop = copy.deepcopy(self.BUILD_PROP)
    build_prop.extend([
        'ro.product.brand=product-brand',
        'ro.product.name=product-name',
        'ro.product.device=product-device',
    ])
    self.writeFiles({
        'SYSTEM/build.prop': '\n'.join(build_prop),
        'VENDOR/build.prop': '\n'.join(self.VENDOR_BUILD_PROP),
    }, self.test_dir)

    build_info = common.BuildInfo(common.LoadInfoDict(self.test_dir))
    expected = ({'product-device'},
                {self.constructFingerprint(
                    'product-brand/product-name/product-device')})
    self.assertEqual(expected,
                     CalculateRuntimeDevicesAndFingerprints(build_info, {}))

  def test_CalculatePossibleFingerprints_single_override(self):
    vendor_build_prop = copy.deepcopy(self.VENDOR_BUILD_PROP)
    vendor_build_prop.extend([
        'import /vendor/etc/build_${ro.boot.sku_name}.prop',
    ])
    self.writeFiles({
        'SYSTEM/build.prop': '\n'.join(self.BUILD_PROP),
        'VENDOR/build.prop': '\n'.join(vendor_build_prop),
        'VENDOR/etc/build_std.prop':
        'ro.product.vendor.name=vendor-product-std',
        'VENDOR/etc/build_pro.prop':
        'ro.product.vendor.name=vendor-product-pro',
    }, self.test_dir)

    build_info = common.BuildInfo(common.LoadInfoDict(self.test_dir))
    boot_variable_values = {'ro.boot.sku_name': ['std', 'pro']}

    expected = ({'vendor-product-device'}, {
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-name/vendor-product-device'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-std/vendor-product-device'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-pro/vendor-product-device'),
    })
    self.assertEqual(
        expected, CalculateRuntimeDevicesAndFingerprints(
            build_info, boot_variable_values))

  def test_CalculatePossibleFingerprints_multiple_overrides(self):
    vendor_build_prop = copy.deepcopy(self.VENDOR_BUILD_PROP)
    vendor_build_prop.extend([
        'import /vendor/etc/build_${ro.boot.sku_name}.prop',
        'import /vendor/etc/build_${ro.boot.device_name}.prop',
    ])
    self.writeFiles({
        'SYSTEM/build.prop': '\n'.join(self.BUILD_PROP),
        'VENDOR/build.prop': '\n'.join(vendor_build_prop),
        'VENDOR/etc/build_std.prop':
        'ro.product.vendor.name=vendor-product-std',
        'VENDOR/etc/build_product1.prop':
        'ro.product.vendor.device=vendor-device-product1',
        'VENDOR/etc/build_pro.prop':
        'ro.product.vendor.name=vendor-product-pro',
        'VENDOR/etc/build_product2.prop':
        'ro.product.vendor.device=vendor-device-product2',
    }, self.test_dir)

    build_info = common.BuildInfo(common.LoadInfoDict(self.test_dir))
    boot_variable_values = {
        'ro.boot.sku_name': ['std', 'pro'],
        'ro.boot.device_name': ['product1', 'product2'],
    }

    expected_devices = {'vendor-product-device', 'vendor-device-product1',
                        'vendor-device-product2'}
    expected_fingerprints = {
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-name/vendor-product-device'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-std/vendor-device-product1'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-pro/vendor-device-product1'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-std/vendor-device-product2'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-pro/vendor-device-product2')
    }
    self.assertEqual((expected_devices, expected_fingerprints),
                     CalculateRuntimeDevicesAndFingerprints(
                         build_info, boot_variable_values))

  def test_GetPackageMetadata_full_package(self):
    vendor_build_prop = copy.deepcopy(self.VENDOR_BUILD_PROP)
    vendor_build_prop.extend([
        'import /vendor/etc/build_${ro.boot.sku_name}.prop',
    ])
    self.writeFiles({
        'SYSTEM/build.prop': '\n'.join(self.BUILD_PROP),
        'VENDOR/build.prop': '\n'.join(vendor_build_prop),
        'VENDOR/etc/build_std.prop':
        'ro.product.vendor.name=vendor-product-std',
        'VENDOR/etc/build_pro.prop':
        'ro.product.vendor.name=vendor-product-pro',
        AB_PARTITIONS: '\n'.join(['system', 'vendor']),
    }, self.test_dir)

    common.OPTIONS.boot_variable_file = common.MakeTempFile()
    with open(common.OPTIONS.boot_variable_file, 'w') as f:
      f.write('ro.boot.sku_name=std,pro')

    build_info = common.BuildInfo(common.LoadInfoDict(self.test_dir))
    metadata_dict = BuildLegacyOtaMetadata(GetPackageMetadata(build_info))
    self.assertEqual('vendor-product-device', metadata_dict['pre-device'])
    fingerprints = [
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-name/vendor-product-device'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-pro/vendor-product-device'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-std/vendor-product-device'),
    ]
    self.assertEqual('|'.join(fingerprints), metadata_dict['post-build'])

  def CheckMetadataEqual(self, metadata_dict, metadata_proto):
    post_build = metadata_proto.postcondition
    self.assertEqual('|'.join(post_build.build),
                     metadata_dict['post-build'])
    self.assertEqual(post_build.build_incremental,
                     metadata_dict['post-build-incremental'])
    self.assertEqual(post_build.sdk_level,
                     metadata_dict['post-sdk-level'])
    self.assertEqual(post_build.security_patch_level,
                     metadata_dict['post-security-patch-level'])

    if metadata_proto.type == ota_metadata_pb2.OtaMetadata.AB:
      ota_type = 'AB'
    elif metadata_proto.type == ota_metadata_pb2.OtaMetadata.BLOCK:
      ota_type = 'BLOCK'
    else:
      ota_type = ''
    self.assertEqual(ota_type, metadata_dict['ota-type'])
    self.assertEqual(metadata_proto.wipe,
                     metadata_dict.get('ota-wipe') == 'yes')
    self.assertEqual(metadata_proto.required_cache,
                     int(metadata_dict.get('ota-required-cache', 0)))
    self.assertEqual(metadata_proto.retrofit_dynamic_partitions,
                     metadata_dict.get(
                         'ota-retrofit-dynamic-partitions') == 'yes')

  def test_GetPackageMetadata_incremental_package(self):
    vendor_build_prop = copy.deepcopy(self.VENDOR_BUILD_PROP)
    vendor_build_prop.extend([
        'import /vendor/etc/build_${ro.boot.sku_name}.prop',
    ])
    self.writeFiles({
        'META/misc_info.txt': '\n'.join(self.MISC_INFO),
        'META/ab_partitions.txt': '\n'.join(['system', 'vendor', 'product']),
        'SYSTEM/build.prop': '\n'.join(self.BUILD_PROP),
        'VENDOR/build.prop': '\n'.join(vendor_build_prop),
        'VENDOR/etc/build_std.prop':
        'ro.product.vendor.device=vendor-device-std',
        'VENDOR/etc/build_pro.prop':
        'ro.product.vendor.device=vendor-device-pro',
    }, self.test_dir)

    common.OPTIONS.boot_variable_file = common.MakeTempFile()
    with open(common.OPTIONS.boot_variable_file, 'w') as f:
      f.write('ro.boot.sku_name=std,pro')

    source_dir = common.MakeTempDir()
    source_build_prop = [
        'ro.build.version.release=source-version-release',
        'ro.build.id=source-build-id',
        'ro.build.version.incremental=source-version-incremental',
        'ro.build.type=build-type',
        'ro.build.tags=build-tags',
        'ro.build.version.sdk=29',
        'ro.build.version.security_patch=2020',
        'ro.build.date.utc=12340000',
        'ro.system.build.version.release=source-version-release',
        'ro.system.build.id=source-build-id',
        'ro.system.build.version.incremental=source-version-incremental',
        'ro.system.build.type=build-type',
        'ro.system.build.tags=build-tags',
        'ro.system.build.version.sdk=29',
        'ro.system.build.version.security_patch=2020',
        'ro.system.build.date.utc=12340000',
        'ro.product.system.brand=generic',
        'ro.product.system.name=generic',
        'ro.product.system.device=generic',
    ]
    self.writeFiles({
        'META/misc_info.txt': '\n'.join(self.MISC_INFO),
        'META/ab_partitions.txt': '\n'.join(['system', 'vendor', 'product']),
        'SYSTEM/build.prop': '\n'.join(source_build_prop),
        'VENDOR/build.prop': '\n'.join(vendor_build_prop),
        'VENDOR/etc/build_std.prop':
        'ro.product.vendor.device=vendor-device-std',
        'VENDOR/etc/build_pro.prop':
        'ro.product.vendor.device=vendor-device-pro',
    }, source_dir)
    common.OPTIONS.incremental_source = source_dir

    target_info = common.BuildInfo(common.LoadInfoDict(self.test_dir))
    source_info = common.BuildInfo(common.LoadInfoDict(source_dir))

    metadata_proto = GetPackageMetadata(target_info, source_info)
    metadata_dict = BuildLegacyOtaMetadata(metadata_proto)
    self.assertEqual(
        'vendor-device-pro|vendor-device-std|vendor-product-device',
        metadata_dict['pre-device'])
    source_suffix = ':source-version-release/source-build-id/' \
                    'source-version-incremental:build-type/build-tags'
    pre_fingerprints = [
        'vendor-product-brand/vendor-product-name/vendor-device-pro'
        '{}'.format(source_suffix),
        'vendor-product-brand/vendor-product-name/vendor-device-std'
        '{}'.format(source_suffix),
        'vendor-product-brand/vendor-product-name/vendor-product-device'
        '{}'.format(source_suffix),
    ]
    self.assertEqual('|'.join(pre_fingerprints), metadata_dict['pre-build'])

    post_fingerprints = [
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-name/vendor-device-pro'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-name/vendor-device-std'),
        self.constructFingerprint(
            'vendor-product-brand/vendor-product-name/vendor-product-device'),
    ]
    self.assertEqual('|'.join(post_fingerprints), metadata_dict['post-build'])

    self.CheckMetadataEqual(metadata_dict, metadata_proto)

    pre_partition_states = metadata_proto.precondition.partition_state
    self.assertEqual(2, len(pre_partition_states))
    self.assertEqual('system', pre_partition_states[0].partition_name)
    self.assertEqual(['generic'], pre_partition_states[0].device)
    self.assertEqual(['generic/generic/generic{}'.format(source_suffix)],
                     pre_partition_states[0].build)

    self.assertEqual('vendor', pre_partition_states[1].partition_name)
    self.assertEqual(['vendor-device-pro', 'vendor-device-std',
                      'vendor-product-device'], pre_partition_states[1].device)
    vendor_fingerprints = post_fingerprints
    self.assertEqual(vendor_fingerprints, pre_partition_states[1].build)

    post_partition_states = metadata_proto.postcondition.partition_state
    self.assertEqual(2, len(post_partition_states))
    self.assertEqual('system', post_partition_states[0].partition_name)
    self.assertEqual(['generic'], post_partition_states[0].device)
    self.assertEqual([self.constructFingerprint('generic/generic/generic')],
                     post_partition_states[0].build)

    self.assertEqual('vendor', post_partition_states[1].partition_name)
    self.assertEqual(['vendor-device-pro', 'vendor-device-std',
                      'vendor-product-device'], post_partition_states[1].device)
    self.assertEqual(vendor_fingerprints, post_partition_states[1].build)
