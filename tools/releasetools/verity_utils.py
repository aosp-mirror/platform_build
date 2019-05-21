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


def GetVerityFECSize(image_size):
  cmd = ["fec", "-s", str(image_size)]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output)


def GetVerityTreeSize(image_size):
  cmd = ["build_verity_tree", "-s", str(image_size)]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output)


def GetVerityMetadataSize(image_size):
  cmd = ["build_verity_metadata", "size", str(image_size)]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output)


def GetVeritySize(image_size, fec_supported):
  verity_tree_size = GetVerityTreeSize(image_size)
  verity_metadata_size = GetVerityMetadataSize(image_size)
  verity_size = verity_tree_size + verity_metadata_size
  if fec_supported:
    fec_size = GetVerityFECSize(image_size + verity_size)
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
  cmd = ["build_verity_metadata", "build", str(image_size),
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
    logger.exception(error_message)
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
    logger.exception(error_message)
    raise BuildVerityImageError(error_message)


def CreateVerityImageBuilder(prop_dict):
  """Returns a verity image builder based on the given build properties.

  Args:
    prop_dict: A dict that contains the build properties. In particular, it will
        look for verity-related property values.

  Returns:
    A VerityImageBuilder instance for Verified Boot 1.0 or Verified Boot 2.0; or
        None if the given build doesn't support Verified Boot.
  """
  partition_size = prop_dict.get("partition_size")
  # partition_size could be None at this point, if using dynamic partitions.
  if partition_size:
    partition_size = int(partition_size)

  # Verified Boot 1.0
  verity_supported = prop_dict.get("verity") == "true"
  is_verity_partition = "verity_block_device" in prop_dict
  if verity_supported and is_verity_partition:
    if OPTIONS.verity_signer_path is not None:
      signer_path = OPTIONS.verity_signer_path
    else:
      signer_path = prop_dict["verity_signer_cmd"]
    return Version1VerityImageBuilder(
        partition_size,
        prop_dict["verity_block_device"],
        prop_dict.get("verity_fec") == "true",
        signer_path,
        prop_dict["verity_key"] + ".pk8",
        OPTIONS.verity_signer_args,
        "verity_disable" in prop_dict)

  # Verified Boot 2.0
  if (prop_dict.get("avb_hash_enable") == "true" or
      prop_dict.get("avb_hashtree_enable") == "true"):
    # key_path and algorithm are only available when chain partition is used.
    key_path = prop_dict.get("avb_key_path")
    algorithm = prop_dict.get("avb_algorithm")
    if prop_dict.get("avb_hash_enable") == "true":
      return VerifiedBootVersion2VerityImageBuilder(
          prop_dict["partition_name"],
          partition_size,
          VerifiedBootVersion2VerityImageBuilder.AVB_HASH_FOOTER,
          prop_dict["avb_avbtool"],
          key_path,
          algorithm,
          prop_dict.get("avb_salt"),
          prop_dict["avb_add_hash_footer_args"])
    else:
      return VerifiedBootVersion2VerityImageBuilder(
          prop_dict["partition_name"],
          partition_size,
          VerifiedBootVersion2VerityImageBuilder.AVB_HASHTREE_FOOTER,
          prop_dict["avb_avbtool"],
          key_path,
          algorithm,
          prop_dict.get("avb_salt"),
          prop_dict["avb_add_hashtree_footer_args"])

  return None


class VerityImageBuilder(object):
  """A builder that generates an image with verity metadata for Verified Boot.

  A VerityImageBuilder instance handles the works for building an image with
  verity metadata for supporting Android Verified Boot. This class defines the
  common interface between Verified Boot 1.0 and Verified Boot 2.0. A matching
  builder will be returned based on the given build properties.

  More info on the verity image generation can be found at the following link.
  https://source.android.com/security/verifiedboot/dm-verity#implementation
  """

  def CalculateMaxImageSize(self, partition_size):
    """Calculates the filesystem image size for the given partition size."""
    raise NotImplementedError

  def CalculateDynamicPartitionSize(self, image_size):
    """Calculates and sets the partition size for a dynamic partition."""
    raise NotImplementedError

  def PadSparseImage(self, out_file):
    """Adds padding to the generated sparse image."""
    raise NotImplementedError

  def Build(self, out_file):
    """Builds the verity image and writes it to the given file."""
    raise NotImplementedError


class Version1VerityImageBuilder(VerityImageBuilder):
  """A VerityImageBuilder for Verified Boot 1.0."""

  def __init__(self, partition_size, block_dev, fec_supported, signer_path,
               signer_key, signer_args, verity_disable):
    self.version = 1
    self.partition_size = partition_size
    self.block_device = block_dev
    self.fec_supported = fec_supported
    self.signer_path = signer_path
    self.signer_key = signer_key
    self.signer_args = signer_args
    self.verity_disable = verity_disable
    self.image_size = None
    self.verity_size = None

  def CalculateDynamicPartitionSize(self, image_size):
    # This needs to be implemented. Note that returning the given image size as
    # the partition size doesn't make sense, as it will fail later.
    raise NotImplementedError

  def CalculateMaxImageSize(self, partition_size=None):
    """Calculates the max image size by accounting for the verity metadata.

    Args:
      partition_size: The partition size, which defaults to self.partition_size
          if unspecified.

    Returns:
      The size of the image adjusted for verity metadata.
    """
    if partition_size is None:
      partition_size = self.partition_size
    assert partition_size > 0, \
        "Invalid partition size: {}".format(partition_size)

    hi = partition_size
    if hi % BLOCK_SIZE != 0:
      hi = (hi // BLOCK_SIZE) * BLOCK_SIZE

    # verity tree and fec sizes depend on the partition size, which
    # means this estimate is always going to be unnecessarily small
    verity_size = GetVeritySize(hi, self.fec_supported)
    lo = partition_size - verity_size
    result = lo

    # do a binary search for the optimal size
    while lo < hi:
      i = ((lo + hi) // (2 * BLOCK_SIZE)) * BLOCK_SIZE
      v = GetVeritySize(i, self.fec_supported)
      if i + v <= partition_size:
        if result < i:
          result = i
          verity_size = v
        lo = i + BLOCK_SIZE
      else:
        hi = i

    self.image_size = result
    self.verity_size = verity_size

    logger.info(
        "Calculated image size for verity: partition_size %d, image_size %d, "
        "verity_size %d", partition_size, result, verity_size)
    return result

  def Build(self, out_file):
    """Creates an image that is verifiable using dm-verity.

    Args:
      out_file: the output image.

    Returns:
      AssertionError: On invalid partition sizes.
      BuildVerityImageError: On other errors.
    """
    image_size = int(self.image_size)
    tempdir_name = common.MakeTempDir(suffix="_verity_images")

    # Get partial image paths.
    verity_image_path = os.path.join(tempdir_name, "verity.img")
    verity_metadata_path = os.path.join(tempdir_name, "verity_metadata.img")

    # Build the verity tree and get the root hash and salt.
    root_hash, salt = BuildVerityTree(out_file, verity_image_path)

    # Build the metadata blocks.
    BuildVerityMetadata(
        image_size, verity_metadata_path, root_hash, salt, self.block_device,
        self.signer_path, self.signer_key, self.signer_args,
        self.verity_disable)

    padding_size = self.partition_size - self.image_size - self.verity_size
    assert padding_size >= 0

    # Build the full verified image.
    Append(
        verity_image_path, verity_metadata_path,
        "Failed to append verity metadata")

    if self.fec_supported:
      # Build FEC for the entire partition, including metadata.
      verity_fec_path = os.path.join(tempdir_name, "verity_fec.img")
      BuildVerityFEC(
          out_file, verity_image_path, verity_fec_path, padding_size)
      Append(verity_image_path, verity_fec_path, "Failed to append FEC")

    Append2Simg(
        out_file, verity_image_path, "Failed to append verity data")

  def PadSparseImage(self, out_file):
    sparse_image_size = GetSimgSize(out_file)
    if sparse_image_size > self.image_size:
      raise BuildVerityImageError(
          "Error: image size of {} is larger than partition size of "
          "{}".format(sparse_image_size, self.image_size))
    ZeroPadSimg(out_file, self.image_size - sparse_image_size)


class VerifiedBootVersion2VerityImageBuilder(VerityImageBuilder):
  """A VerityImageBuilder for Verified Boot 2.0."""

  AVB_HASH_FOOTER = 1
  AVB_HASHTREE_FOOTER = 2

  def __init__(self, partition_name, partition_size, footer_type, avbtool,
               key_path, algorithm, salt, signing_args):
    self.version = 2
    self.partition_name = partition_name
    self.partition_size = partition_size
    self.footer_type = footer_type
    self.avbtool = avbtool
    self.algorithm = algorithm
    self.key_path = key_path
    self.salt = salt
    self.signing_args = signing_args
    self.image_size = None

  def CalculateMinPartitionSize(self, image_size, size_calculator=None):
    """Calculates min partition size for a given image size.

    This is used when determining the partition size for a dynamic partition,
    which should be cover the given image size (for filesystem files) as well as
    the verity metadata size.

    Args:
      image_size: The size of the image in question.
      size_calculator: The function to calculate max image size
          for a given partition size.

    Returns:
      The minimum partition size required to accommodate the image size.
    """
    if size_calculator is None:
      size_calculator = self.CalculateMaxImageSize

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
        "CalculateMinPartitionSize(%d): partition_size %d.", image_size,
        partition_size)

    return partition_size

  def CalculateDynamicPartitionSize(self, image_size):
    self.partition_size = self.CalculateMinPartitionSize(image_size)
    return self.partition_size

  def CalculateMaxImageSize(self, partition_size=None):
    """Calculates max image size for a given partition size.

    Args:
      partition_size: The partition size, which defaults to self.partition_size
          if unspecified.

    Returns:
      The maximum image size.

    Raises:
      BuildVerityImageError: On error or getting invalid image size.
    """
    if partition_size is None:
      partition_size = self.partition_size
    assert partition_size > 0, \
        "Invalid partition size: {}".format(partition_size)

    add_footer = ("add_hash_footer" if self.footer_type == self.AVB_HASH_FOOTER
                  else "add_hashtree_footer")
    cmd = [self.avbtool, add_footer, "--partition_size",
           str(partition_size), "--calc_max_image_size"]
    cmd.extend(shlex.split(self.signing_args))

    proc = common.Run(cmd)
    output, _ = proc.communicate()
    if proc.returncode != 0:
      raise BuildVerityImageError(
          "Failed to calculate max image size:\n{}".format(output))
    image_size = int(output)
    if image_size <= 0:
      raise BuildVerityImageError(
          "Invalid max image size: {}".format(output))
    self.image_size = image_size
    return image_size

  def PadSparseImage(self, out_file):
    # No-op as the padding is taken care of by avbtool.
    pass

  def Build(self, out_file):
    """Adds dm-verity hashtree and AVB metadata to an image.

    Args:
      out_file: Path to image to modify.
    """
    add_footer = ("add_hash_footer" if self.footer_type == self.AVB_HASH_FOOTER
                  else "add_hashtree_footer")
    cmd = [self.avbtool, add_footer,
           "--partition_size", str(self.partition_size),
           "--partition_name", self.partition_name,
           "--image", out_file]
    if self.key_path and self.algorithm:
      cmd.extend(["--key", self.key_path, "--algorithm", self.algorithm])
    if self.salt:
      cmd.extend(["--salt", self.salt])
    cmd.extend(shlex.split(self.signing_args))

    proc = common.Run(cmd)
    output, _ = proc.communicate()
    if proc.returncode != 0:
      raise BuildVerityImageError("Failed to add AVB footer: {}".format(output))


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

    prop_dict = {
        'partition_size': str(partition_size),
        'verity': 'true',
        'verity_fec': 'true' if fec_supported else None,
        # 'verity_block_device' needs to be present to indicate a verity-enabled
        # partition.
        'verity_block_device': '',
        # We don't need the following properties that are needed for signing the
        # verity metadata.
        'verity_key': '',
        'verity_signer_cmd': None,
    }
    self.verity_image_builder = CreateVerityImageBuilder(prop_dict)

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

    adjusted_size = self.verity_image_builder.CalculateMaxImageSize()
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

    # Writes the filesystem section to a temp file; and calls the executable
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
