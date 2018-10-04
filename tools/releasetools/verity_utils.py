#!/usr/bin/env python
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

from __future__ import print_function

import struct

import common
from build_image import (AdjustPartitionSizeForVerity, GetVerityTreeSize,
                         GetVerityMetadataSize, BuildVerityTree)
from rangelib import RangeSet


class HashtreeInfoGenerationError(Exception):
  """An Exception raised during hashtree info generation."""

  def __init__(self, message):
    Exception.__init__(self, message)


class HashtreeInfo(object):
  def __init__(self):
    self.hashtree_range = None
    self.filesystem_range = None
    self.hash_algorithm = None
    self.salt = None
    self.root_hash = None


def CreateHashtreeInfoGenerator(partition_name, block_size, info_dict):
  generator = None
  if (info_dict.get("verity") == "true" and
      info_dict.get("{}_verity_block_device".format(partition_name))):
    partition_size = info_dict["{}_size".format(partition_name)]
    fec_supported = info_dict.get("verity_fec") == "true"
    generator = VerifiedBootVersion1HashtreeInfoGenerator(
        partition_size, block_size, fec_supported)

  return generator


class HashtreeInfoGenerator(object):
  def Generate(self, image):
    raise NotImplementedError

  def DecomposeSparseImage(self, image):
    raise NotImplementedError

  def ValidateHashtree(self):
    raise NotImplementedError


class VerifiedBootVersion2HashtreeInfoGenerator(HashtreeInfoGenerator):
  pass


class VerifiedBootVersion1HashtreeInfoGenerator(HashtreeInfoGenerator):
  """A class that parses the metadata of hashtree for a given partition."""

  def __init__(self, partition_size, block_size, fec_supported):
    """Initialize VerityTreeInfo with the sparse image and input property.

    Arguments:
      partition_size: The whole size in bytes of a partition, including the
        filesystem size, padding size, and verity size.
      block_size: Expected size in bytes of each block for the sparse image.
      fec_supported: True if the verity section contains fec data.
    """

    self.block_size = block_size
    self.partition_size = partition_size
    self.fec_supported = fec_supported

    self.image = None
    self.filesystem_size = None
    self.hashtree_size = None
    self.metadata_size = None

    self.hashtree_info = HashtreeInfo()

  def DecomposeSparseImage(self, image):
    """Calculate the verity size based on the size of the input image.

    Since we already know the structure of a verity enabled image to be:
    [filesystem, verity_hashtree, verity_metadata, fec_data]. We can then
    calculate the size and offset of each section.
    """

    self.image = image
    assert self.block_size == image.blocksize
    assert self.partition_size == image.total_blocks * self.block_size, \
        "partition size {} doesn't match with the calculated image size." \
        " total_blocks: {}".format(self.partition_size, image.total_blocks)

    adjusted_size, _ = AdjustPartitionSizeForVerity(
        self.partition_size, self.fec_supported)
    assert adjusted_size % self.block_size == 0

    verity_tree_size = GetVerityTreeSize(adjusted_size)
    assert verity_tree_size % self.block_size == 0

    metadata_size = GetVerityMetadataSize(adjusted_size)
    assert metadata_size % self.block_size == 0

    self.filesystem_size = adjusted_size
    self.hashtree_size = verity_tree_size
    self.metadata_size = metadata_size

    self.hashtree_info.filesystem_range = RangeSet(
        data=[0, adjusted_size / self.block_size])
    self.hashtree_info.hashtree_range = RangeSet(
        data=[adjusted_size / self.block_size,
              (adjusted_size + verity_tree_size) / self.block_size])

  def _ParseHashtreeMetadata(self):
    """Parses the hash_algorithm, root_hash, salt from the metadata block."""

    metadata_start = self.filesystem_size + self.hashtree_size
    metadata_range = RangeSet(
        data=[metadata_start / self.block_size,
              (metadata_start + self.metadata_size) / self.block_size])
    meta_data = ''.join(self.image.ReadRangeSet(metadata_range))

    # More info about the metadata structure available in:
    # system/extras/verity/build_verity_metadata.py
    META_HEADER_SIZE = 268
    header_bin = meta_data[0:META_HEADER_SIZE]
    header = struct.unpack("II256sI", header_bin)

    # header: magic_number, version, signature, table_len
    assert header[0] == 0xb001b001, header[0]
    table_len = header[3]
    verity_table = meta_data[META_HEADER_SIZE: META_HEADER_SIZE + table_len]
    table_entries = verity_table.rstrip().split()

    # Expected verity table format: "1 block_device block_device block_size
    # block_size data_blocks data_blocks hash_algorithm root_hash salt"
    assert len(table_entries) == 10, "Unexpected verity table size {}".format(
        len(table_entries))
    assert (int(table_entries[3]) == self.block_size and
            int(table_entries[4]) == self.block_size)
    assert (int(table_entries[5]) * self.block_size == self.filesystem_size and
            int(table_entries[6]) * self.block_size == self.filesystem_size)

    self.hashtree_info.hash_algorithm = table_entries[7]
    self.hashtree_info.root_hash = table_entries[8]
    self.hashtree_info.salt = table_entries[9]

  def ValidateHashtree(self):
    """Checks that we can reconstruct the verity hash tree."""

    # Writes the file system section to a temp file; and calls the executable
    # build_verity_tree to construct the hash tree.
    adjusted_partition = common.MakeTempFile(prefix="adjusted_partition")
    with open(adjusted_partition, "wb") as fd:
      self.image.WriteRangeDataToFd(self.hashtree_info.filesystem_range, fd)

    generated_verity_tree = common.MakeTempFile(prefix="verity")
    root_hash, salt = BuildVerityTree(adjusted_partition, generated_verity_tree)

    # The salt should be always identical, as we use fixed value.
    assert salt == self.hashtree_info.salt, \
        "Calculated salt {} doesn't match the one in metadata {}".format(
            salt, self.hashtree_info.salt)

    if root_hash != self.hashtree_info.root_hash:
      print(
          "Calculated root hash {} doesn't match the one in metadata {}".format(
              root_hash, self.hashtree_info.root_hash))
      return False

    # Reads the generated hash tree and checks if it has the exact same bytes
    # as the one in the sparse image.
    with open(generated_verity_tree, "rb") as fd:
      return fd.read() == ''.join(self.image.ReadRangeSet(
          self.hashtree_info.hashtree_range))

  def Generate(self, image):
    """Parses and validates the hashtree info in a sparse image.

    Returns:
      hashtree_info: The information needed to reconstruct the hashtree.

    Raises:
      HashtreeInfoGenerationError: If we fail to generate the exact bytes of
          the hashtree.
    """

    self.DecomposeSparseImage(image)
    self._ParseHashtreeMetadata()

    if not self.ValidateHashtree():
      raise HashtreeInfoGenerationError("Failed to reconstruct the verity tree")

    return self.hashtree_info
