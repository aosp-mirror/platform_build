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

from __future__ import print_function

import os
import os.path
import unittest

import build_image
import common
import sparse_img
import test_utils
import verity_utils
from rangelib import RangeSet


class VerityUtilsTest(unittest.TestCase):
  def setUp(self):
    self.testdata_dir = test_utils.get_testdata_dir()

    self.partition_size = 1024 * 1024
    self.prop_dict = {
        'verity': 'true',
        'verity_fec': 'true',
        'system_verity_block_device': '/dev/block/system',
        'system_size': self.partition_size
    }

    self.hash_algorithm = "sha256"
    self.fixed_salt = \
        "aee087a5be3b982978c923f566a94613496b417f2af592639bc80d141e34dfe7"
    self.expected_root_hash = \
        "0b7c4565e87b1026e11fbab91c0bc29e185c847a5b44d40e6e86e461e8adf80d"

  def tearDown(self):
    common.Cleanup()

  def _create_simg(self, raw_data):
    output_file = common.MakeTempFile()
    raw_image = common.MakeTempFile()
    with open(raw_image, 'wb') as f:
      f.write(raw_data)

    cmd = ["img2simg", raw_image, output_file, '4096']
    p = common.Run(cmd)
    p.communicate()
    self.assertEqual(0, p.returncode)

    return output_file

  def _generate_image(self):
    partition_size = 1024 * 1024
    adjusted_size, verity_size = build_image.AdjustPartitionSizeForVerity(
        partition_size, True)

    raw_image = ""
    for i in range(adjusted_size):
      raw_image += str(i % 10)

    output_file = self._create_simg(raw_image)

    # Append the verity metadata.
    prop_dict = {
        'partition_size': str(partition_size),
        'image_size': str(adjusted_size),
        'verity_block_device': '/dev/block/system',
        'verity_key': os.path.join(self.testdata_dir, 'testkey'),
        'verity_signer_cmd': 'verity_signer',
        'verity_size': str(verity_size),
    }
    build_image.MakeVerityEnabledImage(output_file, True, prop_dict)

    return output_file

  def test_VerifiedBootVersion1HashtreeInfoGenerator_create(self):
    image_file = sparse_img.SparseImage(self._generate_image())

    generator = verity_utils.CreateHashtreeInfoGenerator(
        'system', image_file, self.prop_dict)
    self.assertEqual(
        verity_utils.VerifiedBootVersion1HashtreeInfoGenerator, type(generator))
    self.assertEqual(self.partition_size, generator.partition_size)
    self.assertTrue(generator.fec_supported)

  def test_VerifiedBootVersion1HashtreeInfoGenerator_decomposeImage(self):
    image_file = sparse_img.SparseImage(self._generate_image())

    generator = verity_utils.VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.DecomposeSparseImage(image_file)
    self.assertEqual(991232, generator.filesystem_size)
    self.assertEqual(12288, generator.hashtree_size)
    self.assertEqual(32768, generator.metadata_size)

  def test_VerifiedBootVersion1HashtreeInfoGenerator_parseHashtreeMetadata(
      self):
    image_file = sparse_img.SparseImage(self._generate_image())
    generator = verity_utils.VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.DecomposeSparseImage(image_file)

    generator._ParseHashtreeMetadata()

    self.assertEqual(
        self.hash_algorithm, generator.hashtree_info.hash_algorithm)
    self.assertEqual(self.fixed_salt, generator.hashtree_info.salt)
    self.assertEqual(self.expected_root_hash, generator.hashtree_info.root_hash)

  def test_VerifiedBootVersion1HashtreeInfoGenerator_validateHashtree_smoke(
      self):
    generator = verity_utils.VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.image = sparse_img.SparseImage(self._generate_image())

    generator.hashtree_info = info = verity_utils.HashtreeInfo()
    info.filesystem_range = RangeSet(data=[0, 991232 / 4096])
    info.hashtree_range = RangeSet(
        data=[991232 / 4096, (991232 + 12288) / 4096])
    info.hash_algorithm = self.hash_algorithm
    info.salt = self.fixed_salt
    info.root_hash = self.expected_root_hash

    self.assertTrue(generator.ValidateHashtree())

  def test_VerifiedBootVersion1HashtreeInfoGenerator_validateHashtree_failure(
      self):
    generator = verity_utils.VerifiedBootVersion1HashtreeInfoGenerator(
        self.partition_size, 4096, True)
    generator.image = sparse_img.SparseImage(self._generate_image())

    generator.hashtree_info = info = verity_utils.HashtreeInfo()
    info.filesystem_range = RangeSet(data=[0, 991232 / 4096])
    info.hashtree_range = RangeSet(
        data=[991232 / 4096, (991232 + 12288) / 4096])
    info.hash_algorithm = self.hash_algorithm
    info.salt = self.fixed_salt
    info.root_hash = "a" + self.expected_root_hash[1:]

    self.assertFalse(generator.ValidateHashtree())

  def test_VerifiedBootVersion1HashtreeInfoGenerator_generate(self):
    image_file = sparse_img.SparseImage(self._generate_image())
    generator = verity_utils.CreateHashtreeInfoGenerator(
        'system', 4096, self.prop_dict)
    info = generator.Generate(image_file)

    self.assertEqual(RangeSet(data=[0, 991232 / 4096]), info.filesystem_range)
    self.assertEqual(RangeSet(data=[991232 / 4096, (991232 + 12288) / 4096]),
                     info.hashtree_range)
    self.assertEqual(self.hash_algorithm, info.hash_algorithm)
    self.assertEqual(self.fixed_salt, info.salt)
    self.assertEqual(self.expected_root_hash, info.root_hash)
