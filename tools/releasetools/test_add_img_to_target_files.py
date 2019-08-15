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

import os
import os.path
import zipfile

import common
import test_utils
from add_img_to_target_files import (
    AddCareMapForAbOta, AddPackRadioImages,
    CheckAbOtaImages, GetCareMap)
from rangelib import RangeSet


OPTIONS = common.OPTIONS


class AddImagesToTargetFilesTest(test_utils.ReleaseToolsTestCase):

  def setUp(self):
    OPTIONS.input_tmp = common.MakeTempDir()

  @staticmethod
  def _create_images(images, prefix):
    """Creates images under OPTIONS.input_tmp/prefix."""
    path = os.path.join(OPTIONS.input_tmp, prefix)
    if not os.path.exists(path):
      os.mkdir(path)

    for image in images:
      image_path = os.path.join(path, image + '.img')
      with open(image_path, 'wb') as image_fp:
        image_fp.write(image.encode())

    images_path = os.path.join(OPTIONS.input_tmp, 'IMAGES')
    if not os.path.exists(images_path):
      os.mkdir(images_path)
    return images, images_path

  def test_CheckAbOtaImages_imageExistsUnderImages(self):
    """Tests the case with existing images under IMAGES/."""
    images, _ = self._create_images(['aboot', 'xbl'], 'IMAGES')
    CheckAbOtaImages(None, images)

  def test_CheckAbOtaImages_imageExistsUnderRadio(self):
    """Tests the case with some image under RADIO/."""
    images, _ = self._create_images(['system', 'vendor'], 'IMAGES')
    radio_path = os.path.join(OPTIONS.input_tmp, 'RADIO')
    if not os.path.exists(radio_path):
      os.mkdir(radio_path)
    with open(os.path.join(radio_path, 'modem.img'), 'wb') as image_fp:
      image_fp.write('modem'.encode())
    CheckAbOtaImages(None, images + ['modem'])

  def test_CheckAbOtaImages_missingImages(self):
    images, _ = self._create_images(['aboot', 'xbl'], 'RADIO')
    self.assertRaises(
        AssertionError, CheckAbOtaImages, None, images + ['baz'])

  def test_AddPackRadioImages(self):
    images, images_path = self._create_images(['foo', 'bar'], 'RADIO')
    AddPackRadioImages(None, images)

    for image in images:
      self.assertTrue(
          os.path.exists(os.path.join(images_path, image + '.img')))

  def test_AddPackRadioImages_with_suffix(self):
    images, images_path = self._create_images(['foo', 'bar'], 'RADIO')
    images_with_suffix = [image + '.img' for image in images]
    AddPackRadioImages(None, images_with_suffix)

    for image in images:
      self.assertTrue(
          os.path.exists(os.path.join(images_path, image + '.img')))

  def test_AddPackRadioImages_zipOutput(self):
    images, _ = self._create_images(['foo', 'bar'], 'RADIO')

    # Set up the output zip.
    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      AddPackRadioImages(output_zip, images)

    with zipfile.ZipFile(output_file, 'r') as verify_zip:
      for image in images:
        self.assertIn('IMAGES/' + image + '.img', verify_zip.namelist())

  def test_AddPackRadioImages_imageExists(self):
    images, images_path = self._create_images(['foo', 'bar'], 'RADIO')

    # Additionally create images under IMAGES/ so that they should be skipped.
    images, images_path = self._create_images(['foo', 'bar'], 'IMAGES')

    AddPackRadioImages(None, images)

    for image in images:
      self.assertTrue(
          os.path.exists(os.path.join(images_path, image + '.img')))

  def test_AddPackRadioImages_missingImages(self):
    images, _ = self._create_images(['foo', 'bar'], 'RADIO')
    AddPackRadioImages(None, images)

    self.assertRaises(AssertionError, AddPackRadioImages, None,
                      images + ['baz'])

  @staticmethod
  def _test_AddCareMapForAbOta():
    """Helper function to set up the test for test_AddCareMapForAbOta()."""
    OPTIONS.info_dict = {
        'extfs_sparse_flag' : '-s',
        'system_image_size' : 65536,
        'vendor_image_size' : 40960,
        'system_verity_block_device': '/dev/block/system',
        'vendor_verity_block_device': '/dev/block/vendor',
        'system.build.prop': {
            'ro.system.build.fingerprint':
                'google/sailfish/12345:user/dev-keys',
        },
        'vendor.build.prop': {
            'ro.vendor.build.fingerprint': 'google/sailfish/678:user/dev-keys',
        },
    }

    # Prepare the META/ folder.
    meta_path = os.path.join(OPTIONS.input_tmp, 'META')
    if not os.path.exists(meta_path):
      os.mkdir(meta_path)

    system_image = test_utils.construct_sparse_image([
        (0xCAC1, 6),
        (0xCAC3, 4),
        (0xCAC1, 8)])
    vendor_image = test_utils.construct_sparse_image([
        (0xCAC2, 12)])

    image_paths = {
        'system' : system_image,
        'vendor' : vendor_image,
    }
    return image_paths

  def _verifyCareMap(self, expected, file_name):
    """Parses the care_map.pb; and checks the content in plain text."""
    text_file = common.MakeTempFile(prefix="caremap-", suffix=".txt")

    # Calls an external binary to convert the proto message.
    cmd = ["care_map_generator", "--parse_proto", file_name, text_file]
    common.RunAndCheckOutput(cmd)

    with open(text_file) as verify_fp:
      plain_text = verify_fp.read()
    self.assertEqual('\n'.join(expected), plain_text)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta(self):
    image_paths = self._test_AddCareMapForAbOta()

    AddCareMapForAbOta(None, ['system', 'vendor'], image_paths)

    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    expected = ['system', RangeSet("0-5 10-15").to_string_raw(),
                "ro.system.build.fingerprint",
                "google/sailfish/12345:user/dev-keys",
                'vendor', RangeSet("0-9").to_string_raw(),
                "ro.vendor.build.fingerprint",
                "google/sailfish/678:user/dev-keys"]

    self._verifyCareMap(expected, care_map_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_withNonCareMapPartitions(self):
    """Partitions without care_map should be ignored."""
    image_paths = self._test_AddCareMapForAbOta()

    AddCareMapForAbOta(
        None, ['boot', 'system', 'vendor', 'vbmeta'], image_paths)

    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    expected = ['system', RangeSet("0-5 10-15").to_string_raw(),
                "ro.system.build.fingerprint",
                "google/sailfish/12345:user/dev-keys",
                'vendor', RangeSet("0-9").to_string_raw(),
                "ro.vendor.build.fingerprint",
                "google/sailfish/678:user/dev-keys"]

    self._verifyCareMap(expected, care_map_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_withAvb(self):
    """Tests the case for device using AVB."""
    image_paths = self._test_AddCareMapForAbOta()
    OPTIONS.info_dict = {
        'extfs_sparse_flag' : '-s',
        'system_image_size' : 65536,
        'vendor_image_size' : 40960,
        'avb_system_hashtree_enable' : 'true',
        'avb_vendor_hashtree_enable' : 'true',
        'system.build.prop': {
            'ro.system.build.fingerprint':
                'google/sailfish/12345:user/dev-keys',
        },
        'vendor.build.prop': {
            'ro.vendor.build.fingerprint': 'google/sailfish/678:user/dev-keys',
        }
    }

    AddCareMapForAbOta(None, ['system', 'vendor'], image_paths)

    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    expected = ['system', RangeSet("0-5 10-15").to_string_raw(),
                "ro.system.build.fingerprint",
                "google/sailfish/12345:user/dev-keys",
                'vendor', RangeSet("0-9").to_string_raw(),
                "ro.vendor.build.fingerprint",
                "google/sailfish/678:user/dev-keys"]

    self._verifyCareMap(expected, care_map_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_noFingerprint(self):
    """Tests the case for partitions without fingerprint."""
    image_paths = self._test_AddCareMapForAbOta()
    OPTIONS.info_dict = {
        'extfs_sparse_flag' : '-s',
        'system_image_size' : 65536,
        'vendor_image_size' : 40960,
        'system_verity_block_device': '/dev/block/system',
        'vendor_verity_block_device': '/dev/block/vendor',
    }

    AddCareMapForAbOta(None, ['system', 'vendor'], image_paths)

    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    expected = ['system', RangeSet("0-5 10-15").to_string_raw(), "unknown",
                "unknown", 'vendor', RangeSet("0-9").to_string_raw(), "unknown",
                "unknown"]

    self._verifyCareMap(expected, care_map_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_withThumbprint(self):
    """Tests the case for partitions with thumbprint."""
    image_paths = self._test_AddCareMapForAbOta()
    OPTIONS.info_dict = {
        'extfs_sparse_flag' : '-s',
        'system_image_size' : 65536,
        'vendor_image_size' : 40960,
        'system_verity_block_device': '/dev/block/system',
        'vendor_verity_block_device': '/dev/block/vendor',
        'system.build.prop': {
            'ro.system.build.thumbprint': 'google/sailfish/123:user/dev-keys',
        },
        'vendor.build.prop' : {
            'ro.vendor.build.thumbprint': 'google/sailfish/456:user/dev-keys',
        },
    }

    AddCareMapForAbOta(None, ['system', 'vendor'], image_paths)

    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    expected = ['system', RangeSet("0-5 10-15").to_string_raw(),
                "ro.system.build.thumbprint",
                "google/sailfish/123:user/dev-keys",
                'vendor', RangeSet("0-9").to_string_raw(),
                "ro.vendor.build.thumbprint",
                "google/sailfish/456:user/dev-keys"]

    self._verifyCareMap(expected, care_map_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_skipPartition(self):
    image_paths = self._test_AddCareMapForAbOta()

    # Remove vendor_image_size to invalidate the care_map for vendor.img.
    del OPTIONS.info_dict['vendor_image_size']

    AddCareMapForAbOta(None, ['system', 'vendor'], image_paths)

    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    expected = ['system', RangeSet("0-5 10-15").to_string_raw(),
                "ro.system.build.fingerprint",
                "google/sailfish/12345:user/dev-keys"]

    self._verifyCareMap(expected, care_map_file)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_skipAllPartitions(self):
    image_paths = self._test_AddCareMapForAbOta()

    # Remove the image_size properties for all the partitions.
    del OPTIONS.info_dict['system_image_size']
    del OPTIONS.info_dict['vendor_image_size']

    AddCareMapForAbOta(None, ['system', 'vendor'], image_paths)

    self.assertFalse(
        os.path.exists(os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')))

  def test_AddCareMapForAbOta_verityNotEnabled(self):
    """No care_map.pb should be generated if verity not enabled."""
    image_paths = self._test_AddCareMapForAbOta()
    OPTIONS.info_dict = {}
    AddCareMapForAbOta(None, ['system', 'vendor'], image_paths)

    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    self.assertFalse(os.path.exists(care_map_file))

  def test_AddCareMapForAbOta_missingImageFile(self):
    """Missing image file should be considered fatal."""
    image_paths = self._test_AddCareMapForAbOta()
    image_paths['vendor'] = ''
    self.assertRaises(AssertionError, AddCareMapForAbOta, None,
                      ['system', 'vendor'], image_paths)

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_zipOutput(self):
    """Tests the case with ZIP output."""
    image_paths = self._test_AddCareMapForAbOta()

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      AddCareMapForAbOta(output_zip, ['system', 'vendor'], image_paths)

    care_map_name = "META/care_map.pb"
    temp_dir = common.MakeTempDir()
    with zipfile.ZipFile(output_file, 'r') as verify_zip:
      self.assertTrue(care_map_name in verify_zip.namelist())
      verify_zip.extract(care_map_name, path=temp_dir)

    expected = ['system', RangeSet("0-5 10-15").to_string_raw(),
                "ro.system.build.fingerprint",
                "google/sailfish/12345:user/dev-keys",
                'vendor', RangeSet("0-9").to_string_raw(),
                "ro.vendor.build.fingerprint",
                "google/sailfish/678:user/dev-keys"]
    self._verifyCareMap(expected, os.path.join(temp_dir, care_map_name))

  @test_utils.SkipIfExternalToolsUnavailable()
  def test_AddCareMapForAbOta_zipOutput_careMapEntryExists(self):
    """Tests the case with ZIP output which already has care_map entry."""
    image_paths = self._test_AddCareMapForAbOta()

    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      # Create an existing META/care_map.pb entry.
      common.ZipWriteStr(output_zip, 'META/care_map.pb',
                         'dummy care_map.pb')

      # Request to add META/care_map.pb again.
      AddCareMapForAbOta(output_zip, ['system', 'vendor'], image_paths)

    # The one under OPTIONS.input_tmp must have been replaced.
    care_map_file = os.path.join(OPTIONS.input_tmp, 'META', 'care_map.pb')
    expected = ['system', RangeSet("0-5 10-15").to_string_raw(),
                "ro.system.build.fingerprint",
                "google/sailfish/12345:user/dev-keys",
                'vendor', RangeSet("0-9").to_string_raw(),
                "ro.vendor.build.fingerprint",
                "google/sailfish/678:user/dev-keys"]

    self._verifyCareMap(expected, care_map_file)

    # The existing entry should be scheduled to be replaced.
    self.assertIn('META/care_map.pb', OPTIONS.replace_updated_files_list)

  def test_GetCareMap(self):
    sparse_image = test_utils.construct_sparse_image([
        (0xCAC1, 6),
        (0xCAC3, 4),
        (0xCAC1, 6)])
    OPTIONS.info_dict = {
        'extfs_sparse_flag' : '-s',
        'system_image_size' : 53248,
    }
    name, care_map = GetCareMap('system', sparse_image)
    self.assertEqual('system', name)
    self.assertEqual(RangeSet("0-5 10-12").to_string_raw(), care_map)

  def test_GetCareMap_invalidPartition(self):
    self.assertRaises(AssertionError, GetCareMap, 'oem', None)

  def test_GetCareMap_invalidAdjustedPartitionSize(self):
    sparse_image = test_utils.construct_sparse_image([
        (0xCAC1, 6),
        (0xCAC3, 4),
        (0xCAC1, 6)])
    OPTIONS.info_dict = {
        'extfs_sparse_flag' : '-s',
        'system_image_size' : -45056,
    }
    self.assertRaises(AssertionError, GetCareMap, 'system', sparse_image)

  def test_GetCareMap_nonSparseImage(self):
    OPTIONS.info_dict = {
        'system_image_size' : 53248,
    }
    # 'foo' is the image filename, which is expected to be not used by
    # GetCareMap().
    name, care_map = GetCareMap('system', 'foo')
    self.assertEqual('system', name)
    self.assertEqual(RangeSet("0-12").to_string_raw(), care_map)
