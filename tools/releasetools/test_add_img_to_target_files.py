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
import unittest
import zipfile

import common
from add_img_to_target_files import AddPackRadioImages, AddRadioImagesForAbOta


OPTIONS = common.OPTIONS


class AddImagesToTargetFilesTest(unittest.TestCase):

  def setUp(self):
    OPTIONS.input_tmp = common.MakeTempDir()

  def tearDown(self):
    common.Cleanup()

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

  def test_AddRadioImagesForAbOta_imageExists(self):
    """Tests the case with existing images under IMAGES/."""
    images, images_path = self._create_images(['aboot', 'xbl'], 'IMAGES')
    AddRadioImagesForAbOta(None, images)

    for image in images:
      self.assertTrue(
          os.path.exists(os.path.join(images_path, image + '.img')))

  def test_AddRadioImagesForAbOta_copyFromRadio(self):
    """Tests the case that copies images from RADIO/."""
    images, images_path = self._create_images(['aboot', 'xbl'], 'RADIO')
    AddRadioImagesForAbOta(None, images)

    for image in images:
      self.assertTrue(
          os.path.exists(os.path.join(images_path, image + '.img')))

  def test_AddRadioImagesForAbOta_copyFromRadio_zipOutput(self):
    images, _ = self._create_images(['aboot', 'xbl'], 'RADIO')

    # Set up the output zip.
    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      AddRadioImagesForAbOta(output_zip, images)

    with zipfile.ZipFile(output_file, 'r') as verify_zip:
      for image in images:
        self.assertIn('IMAGES/' + image + '.img', verify_zip.namelist())

  def test_AddRadioImagesForAbOta_copyFromVendorImages(self):
    """Tests the case that copies images from VENDOR_IMAGES/."""
    vendor_images_path = os.path.join(OPTIONS.input_tmp, 'VENDOR_IMAGES')
    os.mkdir(vendor_images_path)

    partitions = ['aboot', 'xbl']
    for index, partition in enumerate(partitions):
      subdir = os.path.join(vendor_images_path, 'subdir-{}'.format(index))
      os.mkdir(subdir)

      partition_image_path = os.path.join(subdir, partition + '.img')
      with open(partition_image_path, 'wb') as partition_fp:
        partition_fp.write(partition.encode())

    # Set up the output dir.
    images_path = os.path.join(OPTIONS.input_tmp, 'IMAGES')
    os.mkdir(images_path)

    AddRadioImagesForAbOta(None, partitions)

    for partition in partitions:
      self.assertTrue(
          os.path.exists(os.path.join(images_path, partition + '.img')))

  def test_AddRadioImagesForAbOta_missingImages(self):
    images, _ = self._create_images(['aboot', 'xbl'], 'RADIO')
    self.assertRaises(AssertionError, AddRadioImagesForAbOta, None,
                      images + ['baz'])

  def test_AddRadioImagesForAbOta_missingImages_zipOutput(self):
    images, _ = self._create_images(['aboot', 'xbl'], 'RADIO')

    # Set up the output zip.
    output_file = common.MakeTempFile(suffix='.zip')
    with zipfile.ZipFile(output_file, 'w') as output_zip:
      self.assertRaises(AssertionError, AddRadioImagesForAbOta, output_zip,
                        images + ['baz'])

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
