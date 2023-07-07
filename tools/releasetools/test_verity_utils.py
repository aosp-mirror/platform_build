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

"""Unittests for verity_utils.py."""

import copy
import math
import os.path
import random

import common
import sparse_img
from rangelib import RangeSet
from test_utils import (
    get_testdata_dir, ReleaseToolsTestCase, SkipIfExternalToolsUnavailable)
from verity_utils import (
    CalculateVbmetaDigest, CreateVerityImageBuilder)

BLOCK_SIZE = common.BLOCK_SIZE


class VerifiedBootVersion2VerityImageBuilderTest(ReleaseToolsTestCase):

  DEFAULT_PROP_DICT = {
      'partition_size': str(4096 * 1024),
      'partition_name': 'system',
      'avb_avbtool': 'avbtool',
      'avb_hashtree_enable': 'true',
      'avb_add_hashtree_footer_args': '',
  }

  def test_init(self):
    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    verity_image_builder = CreateVerityImageBuilder(prop_dict)
    self.assertIsNotNone(verity_image_builder)
    self.assertEqual(2, verity_image_builder.version)

  def test_init_MissingProps(self):
    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    del prop_dict['avb_hashtree_enable']
    verity_image_builder = CreateVerityImageBuilder(prop_dict)
    self.assertIsNone(verity_image_builder)

  @SkipIfExternalToolsUnavailable()
  def test_Build(self):
    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    verity_image_builder = CreateVerityImageBuilder(prop_dict)
    self.assertIsNotNone(verity_image_builder)
    self.assertEqual(2, verity_image_builder.version)

    input_dir = common.MakeTempDir()
    image_dir = common.MakeTempDir()
    system_image = os.path.join(image_dir, 'system.img')
    system_image_size = verity_image_builder.CalculateMaxImageSize()
    cmd = ['mkuserimg_mke2fs', input_dir, system_image, 'ext4', '/system',
           str(system_image_size), '-j', '0', '-s']
    common.RunAndCheckOutput(cmd)
    verity_image_builder.Build(system_image)

    # Additionally make vbmeta image so that we can verify with avbtool.
    vbmeta_image = os.path.join(image_dir, 'vbmeta.img')
    cmd = ['avbtool', 'make_vbmeta_image', '--include_descriptors_from_image',
           system_image, '--output', vbmeta_image]
    common.RunAndCheckOutput(cmd)

    # Verify the verity metadata.
    cmd = ['avbtool', 'verify_image', '--image', vbmeta_image]
    common.RunAndCheckOutput(cmd)

  def _test_CalculateMinPartitionSize_SetUp(self):
    # To test CalculateMinPartitionSize(), by using 200MB to 2GB image size.
    #   -  51200 = 200MB * 1024 * 1024 / 4096
    #   - 524288 = 2GB * 1024 * 1024 * 1024 / 4096
    image_sizes = [BLOCK_SIZE * random.randint(51200, 524288) + offset
                   for offset in range(BLOCK_SIZE)]

    prop_dict = {
        'partition_size': None,
        'partition_name': 'system',
        'avb_avbtool': 'avbtool',
        'avb_hashtree_enable': 'true',
        'avb_add_hashtree_footer_args': None,
    }
    builder = CreateVerityImageBuilder(prop_dict)
    self.assertEqual(2, builder.version)
    return image_sizes, builder

  def test_CalculateMinPartitionSize_LinearFooterSize(self):
    """Tests with footer size which is linear to partition size."""
    image_sizes, builder = self._test_CalculateMinPartitionSize_SetUp()
    for image_size in image_sizes:
      for ratio in 0.95, 0.56, 0.22:
        expected_size = common.RoundUpTo4K(int(math.ceil(image_size / ratio)))
        self.assertEqual(
            expected_size,
            builder.CalculateMinPartitionSize(
                image_size, lambda x, ratio=ratio: int(x * ratio)))

  def test_AVBCalcMinPartitionSize_SlowerGrowthFooterSize(self):
    """Tests with footer size which grows slower than partition size."""

    def _SizeCalculator(partition_size):
      """Footer size is the power of 0.95 of partition size."""
      # Minus footer size to return max image size.
      return partition_size - int(math.pow(partition_size, 0.95))

    image_sizes, builder = self._test_CalculateMinPartitionSize_SetUp()
    for image_size in image_sizes:
      min_partition_size = builder.CalculateMinPartitionSize(
          image_size, _SizeCalculator)
      # Checks min_partition_size can accommodate image_size.
      self.assertGreaterEqual(
          _SizeCalculator(min_partition_size),
          image_size)
      # Checks min_partition_size (round to BLOCK_SIZE) is the minimum.
      self.assertLess(
          _SizeCalculator(min_partition_size - BLOCK_SIZE),
          image_size)

  def test_CalculateMinPartitionSize_FasterGrowthFooterSize(self):
    """Tests with footer size which grows faster than partition size."""

    def _SizeCalculator(partition_size):
      """Max image size is the power of 0.95 of partition size."""
      # Max image size grows less than partition size, which means
      # footer size grows faster than partition size.
      return int(math.pow(partition_size, 0.95))

    image_sizes, builder = self._test_CalculateMinPartitionSize_SetUp()
    for image_size in image_sizes:
      min_partition_size = builder.CalculateMinPartitionSize(
          image_size, _SizeCalculator)
      # Checks min_partition_size can accommodate image_size.
      self.assertGreaterEqual(
          _SizeCalculator(min_partition_size),
          image_size)
      # Checks min_partition_size (round to BLOCK_SIZE) is the minimum.
      self.assertLess(
          _SizeCalculator(min_partition_size - BLOCK_SIZE),
          image_size)

  @SkipIfExternalToolsUnavailable()
  def test_CalculateVbmetaDigest(self):
    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    verity_image_builder = CreateVerityImageBuilder(prop_dict)
    self.assertEqual(2, verity_image_builder.version)

    input_dir = common.MakeTempDir()
    image_dir = common.MakeTempDir()
    os.mkdir(os.path.join(image_dir, 'IMAGES'))
    system_image = os.path.join(image_dir, 'IMAGES', 'system.img')
    system_image_size = verity_image_builder.CalculateMaxImageSize()
    cmd = ['mkuserimg_mke2fs', input_dir, system_image, 'ext4', '/system',
           str(system_image_size), '-j', '0', '-s']
    common.RunAndCheckOutput(cmd)
    verity_image_builder.Build(system_image)

    # Additionally make vbmeta image
    vbmeta_image = os.path.join(image_dir, 'IMAGES', 'vbmeta.img')
    cmd = ['avbtool', 'make_vbmeta_image', '--include_descriptors_from_image',
           system_image, '--output', vbmeta_image]
    common.RunAndCheckOutput(cmd)

    # Verify the verity metadata.
    cmd = ['avbtool', 'verify_image', '--image', vbmeta_image]
    common.RunAndCheckOutput(cmd)
    digest = CalculateVbmetaDigest(image_dir, 'avbtool')
    self.assertIsNotNone(digest)
