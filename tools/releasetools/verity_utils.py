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

import logging
import os.path
import shlex
import struct

import common
import sparse_img
from rangelib import RangeSet

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
BLOCK_SIZE = common.BLOCK_SIZE
FIXED_SALT = "aee087a5be3b982978c923f566a94613496b417f2af592639bc80d141e34dfe7"


class BuildVerityImageError(Exception):
  """An Exception raised during verity image building."""

  def __init__(self, message):
    Exception.__init__(self, message)


def GetVerityFECSize(partition_size):
  cmd = ["fec", "-s", str(partition_size)]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output)


def GetVerityTreeSize(partition_size):
  cmd = ["build_verity_tree", "-s", str(partition_size)]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output)


def GetVerityMetadataSize(partition_size):
  cmd = ["build_verity_metadata.py", "size", str(partition_size)]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output)


def GetVeritySize(partition_size, fec_supported):
  verity_tree_size = GetVerityTreeSize(partition_size)
  verity_metadata_size = GetVerityMetadataSize(partition_size)
  verity_size = verity_tree_size + verity_metadata_size
  if fec_supported:
    fec_size = GetVerityFECSize(partition_size + verity_size)
    return verity_size + fec_size
  return verity_size


def GetSimgSize(image_file):
  simg = sparse_img.SparseImage(image_file, build_map=False)
  return simg.blocksize * simg.total_blocks


def ZeroPadSimg(image_file, pad_size):
  blocks = pad_size // BLOCK_SIZE
  logger.info("Padding %d blocks (%d bytes)", blocks, pad_size)
  simg = sparse_img.SparseImage(image_file, mode="r+b", build_map=False)
  simg.AppendFillChunk(0, blocks)


def AdjustPartitionSizeForVerity(partition_size, fec_supported):
  """Modifies the provided partition size to account for the verity metadata.

  This information is used to size the created image appropriately.

  Args:
    partition_size: the size of the partition to be verified.

  Returns:
    A tuple of the size of the partition adjusted for verity metadata, and
    the size of verity metadata.
  """
  key = "%d %d" % (partition_size, fec_supported)
  if key in AdjustPartitionSizeForVerity.results:
    return AdjustPartitionSizeForVerity.results[key]

  hi = partition_size
  if hi % BLOCK_SIZE != 0:
    hi = (hi // BLOCK_SIZE) * BLOCK_SIZE

  # verity tree and fec sizes depend on the partition size, which
  # means this estimate is always going to be unnecessarily small
  verity_size = GetVeritySize(hi, fec_supported)
  lo = partition_size - verity_size
  result = lo

  # do a binary search for the optimal size
  while lo < hi:
    i = ((lo + hi) // (2 * BLOCK_SIZE)) * BLOCK_SIZE
    v = GetVeritySize(i, fec_supported)
    if i + v <= partition_size:
      if result < i:
        result = i
        verity_size = v
      lo = i + BLOCK_SIZE
    else:
      hi = i

  logger.info(
      "Adjusted partition size for verity, partition_size: %s, verity_size: %s",
      result, verity_size)
  AdjustPartitionSizeForVerity.results[key] = (result, verity_size)
  return (result, verity_size)


AdjustPartitionSizeForVerity.results = {}


def BuildVerityFEC(sparse_image_path, verity_path, verity_fec_path,
                   padding_size):
  cmd = ["fec", "-e", "-p", str(padding_size), sparse_image_path,
         verity_path, verity_fec_path]
  common.RunAndCheckOutput(cmd)


def BuildVerityTree(sparse_image_path, verity_image_path):
  cmd = ["build_verity_tree", "-A", FIXED_SALT, sparse_image_path,
         verity_image_path]
  output = common.RunAndCheckOutput(cmd)
  root, salt = output.split()
  return root, salt


def BuildVerityMetadata(image_size, verity_metadata_path, root_hash, salt,
                        block_device, signer_path, key, signer_args,
                        verity_disable):
  cmd = ["build_verity_metadata.py", "build", str(image_size),
         verity_metadata_path, root_hash, salt, block_device, signer_path, key]
  if signer_args:
    cmd.append("--signer_args=\"%s\"" % (' '.join(signer_args),))
  if verity_disable:
    cmd.append("--verity_disable")
  common.RunAndCheckOutput(cmd)


def Append2Simg(sparse_image_path, unsparse_image_path, error_message):
  """Appends the unsparse image to the given sparse image.

  Args:
    sparse_image_path: the path to the (sparse) image
    unsparse_image_path: the path to the (unsparse) image

  Raises:
    BuildVerityImageError: On error.
  """
  cmd = ["append2simg", sparse_image_path, unsparse_image_path]
  try:
    common.RunAndCheckOutput(cmd)
  except:
    raise BuildVerityImageError(error_message)


def Append(target, file_to_append, error_message):
  """Appends file_to_append to target.

  Raises:
    BuildVerityImageError: On error.
  """
  try:
    with open(target, "a") as out_file, open(file_to_append, "r") as input_file:
      for line in input_file:
        out_file.write(line)
  except IOError:
    raise BuildVerityImageError(error_message)


def BuildVerifiedImage(data_image_path, verity_image_path,
                       verity_metadata_path, verity_fec_path,
                       padding_size, fec_supported):
  Append(
      verity_image_path, verity_metadata_path,
      "Could not append verity metadata!")

  if fec_supported:
    # Build FEC for the entire partition, including metadata.
    BuildVerityFEC(
        data_image_path, verity_image_path, verity_fec_path, padding_size)
    Append(verity_image_path, verity_fec_path, "Could not append FEC!")

  Append2Simg(
      data_image_path, verity_image_path, "Could not append verity data!")


def MakeVerityEnabledImage(out_file, fec_supported, prop_dict):
  """Creates an image that is verifiable using dm-verity.

  Args:
    out_file: the location to write the verifiable image at
    prop_dict: a dictionary of properties required for image creation and
               verification

  Raises:
    AssertionError: On invalid partition sizes.
  """
  # get properties
  image_size = int(prop_dict["image_size"])
  block_dev = prop_dict["verity_block_device"]
  signer_key = prop_dict["verity_key"] + ".pk8"
  if OPTIONS.verity_signer_path is not None:
    signer_path = OPTIONS.verity_signer_path
  else:
    signer_path = prop_dict["verity_signer_cmd"]
  signer_args = OPTIONS.verity_signer_args

  tempdir_name = common.MakeTempDir(suffix="_verity_images")

  # Get partial image paths.
  verity_image_path = os.path.join(tempdir_name, "verity.img")
  verity_metadata_path = os.path.join(tempdir_name, "verity_metadata.img")
  verity_fec_path = os.path.join(tempdir_name, "verity_fec.img")

  # Build the verity tree and get the root hash and salt.
  root_hash, salt = BuildVerityTree(out_file, verity_image_path)

  # Build the metadata blocks.
  verity_disable = "verity_disable" in prop_dict
  BuildVerityMetadata(
      image_size, verity_metadata_path, root_hash, salt, block_dev, signer_path,
      signer_key, signer_args, verity_disable)

  # Build the full verified image.
  partition_size = int(prop_dict["partition_size"])
  verity_size = int(prop_dict["verity_size"])

  padding_size = partition_size - image_size - verity_size
  assert padding_size >= 0

  BuildVerifiedImage(
      out_file, verity_image_path, verity_metadata_path, verity_fec_path,
      padding_size, fec_supported)


def AVBCalcMaxImageSize(avbtool, footer_type, partition_size, additional_args):
  """Calculates max image size for a given partition size.

  Args:
    avbtool: String with path to avbtool.
    footer_type: 'hash' or 'hashtree' for generating footer.
    partition_size: The size of the partition in question.
    additional_args: Additional arguments to pass to "avbtool add_hash_footer"
        or "avbtool add_hashtree_footer".

  Returns:
    The maximum image size.

  Raises:
    BuildVerityImageError: On invalid image size.
  """
  cmd = [avbtool, "add_%s_footer" % footer_type,
         "--partition_size", str(partition_size), "--calc_max_image_size"]
  cmd.extend(shlex.split(additional_args))

  output = common.RunAndCheckOutput(cmd)
  image_size = int(output)
  if image_size <= 0:
    raise BuildVerityImageError(
        "Invalid max image size: {}".format(output))
  return image_size


def AVBCalcMinPartitionSize(image_size, size_calculator):
  """Calculates min partition size for a given image size.

  Args:
    image_size: The size of the image in question.
    size_calculator: The function to calculate max image size
        for a given partition size.

  Returns:
    The minimum partition size required to accommodate the image size.
  """
  # Use image size as partition size to approximate final partition size.
  image_ratio = size_calculator(image_size) / float(image_size)

  # Prepare a binary search for the optimal partition size.
  lo = int(image_size / image_ratio) // BLOCK_SIZE * BLOCK_SIZE - BLOCK_SIZE

  # Ensure lo is small enough: max_image_size should <= image_size.
  delta = BLOCK_SIZE
  max_image_size = size_calculator(lo)
  while max_image_size > image_size:
    image_ratio = max_image_size / float(lo)
    lo = int(image_size / image_ratio) // BLOCK_SIZE * BLOCK_SIZE - delta
    delta *= 2
    max_image_size = size_calculator(lo)

  hi = lo + BLOCK_SIZE

  # Ensure hi is large enough: max_image_size should >= image_size.
  delta = BLOCK_SIZE
  max_image_size = size_calculator(hi)
  while max_image_size < image_size:
    image_ratio = max_image_size / float(hi)
    hi = int(image_size / image_ratio) // BLOCK_SIZE * BLOCK_SIZE + delta
    delta *= 2
    max_image_size = size_calculator(hi)

  partition_size = hi

  # Start to binary search.
  while lo < hi:
    mid = ((lo + hi) // (2 * BLOCK_SIZE)) * BLOCK_SIZE
    max_image_size = size_calculator(mid)
    if max_image_size >= image_size:  # if mid can accommodate image_size
      if mid < partition_size:  # if a smaller partition size is found
        partition_size = mid
      hi = mid
    else:
      lo = mid + BLOCK_SIZE

  logger.info(
      "AVBCalcMinPartitionSize(%d): partition_size: %d.",
      image_size, partition_size)

  return partition_size


def AVBAddFooter(image_path, avbtool, footer_type, partition_size,
                 partition_name, key_path, algorithm, salt,
                 additional_args):
  """Adds dm-verity hashtree and AVB metadata to an image.

  Args:
    image_path: Path to image to modify.
    avbtool: String with path to avbtool.
    footer_type: 'hash' or 'hashtree' for generating footer.
    partition_size: The size of the partition in question.
    partition_name: The name of the partition - will be embedded in metadata.
    key_path: Path to key to use or None.
    algorithm: Name of algorithm to use or None.
    salt: The salt to use (a hexadecimal string) or None.
    additional_args: Additional arguments to pass to "avbtool add_hash_footer"
        or "avbtool add_hashtree_footer".
  """
  cmd = [avbtool, "add_%s_footer" % footer_type,
         "--partition_size", partition_size,
         "--partition_name", partition_name,
         "--image", image_path]

  if key_path and algorithm:
    cmd.extend(["--key", key_path, "--algorithm", algorithm])
  if salt:
    cmd.extend(["--salt", salt])

  cmd.extend(shlex.split(additional_args))

  common.RunAndCheckOutput(cmd)


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
      logger.warning(
          "Calculated root hash %s doesn't match the one in metadata %s",
          root_hash, self.hashtree_info.root_hash)
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
