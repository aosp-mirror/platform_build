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
    CreateHashtreeInfoGenerator, CreateVerityImageBuilder, HashtreeInfo,
    VerifiedBootVersion1HashtreeInfoGenerator)

BLOCK_SIZE = common.BLOCK_SIZE


class VerifiedBootVersion1HashtreeInfoGeneratorTest(ReleaseToolsTestCase):

  def setUp(self):
    self.testdata_dir = get_testdata_dir()

    self.partition_size = 1024 * 1024
    self.prop_dict = {
        'verity': 'true',
        'verity_fec': 'true',
        'system_verity_block_device': '/dev/block/system',
        'system_size': self.partition_size
    }

    self.hash_algorithm = "sha256"
    self.fixed_salt = (
        "aee087a5be3b982978c923f566a94613496b417f2af592639bc80d141e34dfe7")
    self.expected_root_hash = (
        "0b7c4565e87b1026e11fbab91c0bc29e185c847a5b44d40e6e86e461e8adf80d")

  def _CreateSimg(self, raw_data):  # pylint: disable=no-self-use
    output_file = common.MakeTempFile()
    raw_image = common.MakeTempFile()
    with open(raw_image, 'wb') as f:
      f.write(raw_data)

    cmd = ["img2simg", raw_image, output_file, '4096']
    common.RunAndCheckOutput(cmd)
    return output_file

  def _GenerateImage(self):
    partition_size = 1024 * 1024
    prop_dict = {
        'partition_size': str(partition_size),
        'verity': 'true',
        'verity_block_device': '/dev/block/system',
        'verity_key': os.path.join(self.testdata_dir, 'testkey'),
        'verity_fec': 'true',
        'verity_signer_cmd': 'verity_signer',
    }
    verity_image_builder = CreateVerityImageBuilder(prop_dict)
    self.assertIsNotNone(verity_image_builder)
    adjusted_size = verity_image_builder.CalculateMaxImageSize()

    raw_image = bytearray(adjusted_size)
    for i in range(adjusted_size):
      raw_image[i] = ord('0') + i % 10

    output_file = self._CreateSimg(raw_image)

    # Append the verity metadata.
    verity_image_builder.Build(output_file)

    return output_file

  @SkipIfExternalToolsUnavailable()
  def test_CreateHashtreeInfoGenerator(self):
    image_file = sparse_img.SparseImage(self._GenerateImage())

    generator = CreateHashtreeInfoGenerator(
        'system', image_file, self.prop_dict)
    self.assertEqual(
        VerifiedBootVersion1HashtreeInfoGenerator, type(generator))
    self.assertEqual(self.partition_size, generator.partition_size)
    self.assertTrue(generator.fec_supported)

  @SkipIfExternalToolsUnavailable()
  def test_DecomposeSparseImage(self):
    image_file = sparse_img.SparseImage(self._GenerateImage())

    generator = VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.DecomposeSparseImage(image_file)
    self.assertEqual(991232, generator.filesystem_size)
    self.assertEqual(12288, generator.hashtree_size)
    self.assertEqual(32768, generator.metadata_size)

  @SkipIfExternalToolsUnavailable()
  def test_ParseHashtreeMetadata(self):
    image_file = sparse_img.SparseImage(self._GenerateImage())
    generator = VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.DecomposeSparseImage(image_file)

    # pylint: disable=protected-access
    generator._ParseHashtreeMetadata()

    self.assertEqual(
        self.hash_algorithm, generator.hashtree_info.hash_algorithm)
    self.assertEqual(self.fixed_salt, generator.hashtree_info.salt)
    self.assertEqual(self.expected_root_hash, generator.hashtree_info.root_hash)

  @SkipIfExternalToolsUnavailable()
  def test_ValidateHashtree_smoke(self):
    generator = VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.image = sparse_img.SparseImage(self._GenerateImage())

    generator.hashtree_info = info = HashtreeInfo()
    info.filesystem_range = RangeSet(data=[0, 991232 // 4096])
    info.hashtree_range = RangeSet(
        data=[991232 // 4096, (991232 + 12288) // 4096])
    info.hash_algorithm = self.hash_algorithm
    info.salt = self.fixed_salt
    info.root_hash = self.expected_root_hash

    self.assertTrue(generator.ValidateHashtree())

  @SkipIfExternalToolsUnavailable()
  def test_ValidateHashtree_failure(self):
    generator = VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.image = sparse_img.SparseImage(self._GenerateImage())

    generator.hashtree_info = info = HashtreeInfo()
    info.filesystem_range = RangeSet(data=[0, 991232 // 4096])
    info.hashtree_range = RangeSet(
        data=[991232 // 4096, (991232 + 12288) // 4096])
    info.hash_algorithm = self.hash_algorithm
    info.salt = self.fixed_salt
    info.root_hash = "a" + self.expected_root_hash[1:]

    self.assertFalse(generator.ValidateHashtree())

  @SkipIfExternalToolsUnavailable()
  def test_Generate(self):
    image_file = sparse_img.SparseImage(self._GenerateImage())
    generator = CreateHashtreeInfoGenerator('system', 4096, self.prop_dict)
    info = generator.Generate(image_file)

    self.assertEqual(RangeSet(data=[0, 991232 // 4096]), info.filesystem_range)
    self.assertEqual(RangeSet(data=[991232 // 4096, (991232 + 12288) // 4096]),
                     info.hashtree_range)
    self.assertEqual(self.hash_algorithm, info.hash_algorithm)
    self.assertEqual(self.fixed_salt, info.salt)
    self.assertEqual(self.expected_root_hash, info.root_hash)


class VerifiedBootVersion1VerityImageBuilderTest(ReleaseToolsTestCase):

  DEFAULT_PARTITION_SIZE = 4096 * 1024
  DEFAULT_PROP_DICT = {
      'partition_size': str(DEFAULT_PARTITION_SIZE),
      'verity': 'true',
      'verity_block_device': '/dev/block/system',
      'verity_key': os.path.join(get_testdata_dir(), 'testkey'),
      'verity_fec': 'true',
      'verity_signer_cmd': 'verity_signer',
  }

  def test_init(self):
    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    verity_image_builder = CreateVerityImageBuilder(prop_dict)
    self.assertIsNotNone(verity_image_builder)
    self.assertEqual(1, verity_image_builder.version)

  def test_init_MissingProps(self):
    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    del prop_dict['verity']
    self.assertIsNone(CreateVerityImageBuilder(prop_dict))

    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    del prop_dict['verity_block_device']
    self.assertIsNone(CreateVerityImageBuilder(prop_dict))

  @SkipIfExternalToolsUnavailable()
  def test_CalculateMaxImageSize(self):
    verity_image_builder = CreateVerityImageBuilder(self.DEFAULT_PROP_DICT)
    size = verity_image_builder.CalculateMaxImageSize()
    self.assertLess(size, self.DEFAULT_PARTITION_SIZE)

    # Same result by explicitly passing the partition size.
    self.assertEqual(
        verity_image_builder.CalculateMaxImageSize(),
        verity_image_builder.CalculateMaxImageSize(
            self.DEFAULT_PARTITION_SIZE))

  @staticmethod
  def _BuildAndVerify(prop, verify_key):
    verity_image_builder = CreateVerityImageBuilder(prop)
    image_size = verity_image_builder.CalculateMaxImageSize()

    # Build the sparse image with verity metadata.
    input_dir = common.MakeTempDir()
    image = common.MakeTempFile(suffix='.img')
    cmd = ['mkuserimg_mke2fs', input_dir, image, 'ext4', '/system',
           str(image_size), '-j', '0', '-s']
    common.RunAndCheckOutput(cmd)
    verity_image_builder.Build(image)

    # Verify the verity metadata.
    cmd = ['verity_verifier', image, '-mincrypt', verify_key]
    common.RunAndCheckOutput(cmd)

  @SkipIfExternalToolsUnavailable()
  def test_Build(self):
    self._BuildAndVerify(
        self.DEFAULT_PROP_DICT,
        os.path.join(get_testdata_dir(), 'testkey_mincrypt'))

  @SkipIfExternalToolsUnavailable()
  def test_Build_SanityCheck(self):
    # A sanity check for the test itself: the image shouldn't be verifiable
    # with wrong key.
    self.assertRaises(
        common.ExternalError,
        self._BuildAndVerify,
        self.DEFAULT_PROP_DICT,
        os.path.join(get_testdata_dir(), 'verity_mincrypt'))

  @SkipIfExternalToolsUnavailable()
  def test_Build_FecDisabled(self):
    prop_dict = copy.deepcopy(self.DEFAULT_PROP_DICT)
    del prop_dict['verity_fec']
    self._BuildAndVerify(
        prop_dict,
        os.path.join(get_testdata_dir(), 'testkey_mincrypt'))

  @SkipIfExternalToolsUnavailable()
  def test_Build_SquashFs(self):
    verity_image_builder = CreateVerityImageBuilder(self.DEFAULT_PROP_DICT)
    verity_image_builder.CalculateMaxImageSize()

    # Build the sparse image with verity metadata.
    input_dir = common.MakeTempDir()
    image = common.MakeTempFile(suffix='.img')
    cmd = ['mksquashfsimage.sh', input_dir, image, '-s']
    common.RunAndCheckOutput(cmd)
    verity_image_builder.PadSparseImage(image)
    verity_image_builder.Build(image)

    # Verify the verity metadata.
    cmd = ["verity_verifier", image, '-mincrypt',
           os.path.join(get_testdata_dir(), 'testkey_mincrypt')]
    common.RunAndCheckOutput(cmd)


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
