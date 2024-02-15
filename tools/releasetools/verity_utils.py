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

"""
Signs a given image using avbtool

Usage:  verity_utils properties_file output_image
"""

from __future__ import print_function

import logging
import os.path
import shlex
import struct
import sys

import common
import sparse_img
from rangelib import RangeSet
from hashlib import sha256

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
BLOCK_SIZE = common.BLOCK_SIZE
FIXED_SALT = "aee087a5be3b982978c923f566a94613496b417f2af592639bc80d141e34dfe7"

# From external/avb/avbtool.py
MAX_VBMETA_SIZE = 64 * 1024
MAX_FOOTER_SIZE = 4096


class BuildVerityImageError(Exception):
  """An Exception raised during verity image building."""

  def __init__(self, message):
    Exception.__init__(self, message)


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
  # Set up the salt (based on fingerprint) that will be used when adding AVB
  # hash / hashtree footers.
  salt = prop_dict.get("avb_salt")
  if salt is None:
    salt = sha256(prop_dict.get("fingerprint", "").encode()).hexdigest()

  # Verified Boot 2.0
  if (prop_dict.get("avb_hash_enable") == "true" or
      prop_dict.get("avb_hashtree_enable") == "true"):
    # key_path and algorithm are only available when chain partition is used.
    key_path = prop_dict.get("avb_key_path")
    algorithm = prop_dict.get("avb_algorithm")

    # Image uses hash footer.
    if prop_dict.get("avb_hash_enable") == "true":
      return VerifiedBootVersion2VerityImageBuilder(
          prop_dict["partition_name"],
          partition_size,
          VerifiedBootVersion2VerityImageBuilder.AVB_HASH_FOOTER,
          prop_dict["avb_avbtool"],
          key_path,
          algorithm,
          salt,
          prop_dict["avb_add_hash_footer_args"])

    # Image uses hashtree footer.
    return VerifiedBootVersion2VerityImageBuilder(
        prop_dict["partition_name"],
        partition_size,
        VerifiedBootVersion2VerityImageBuilder.AVB_HASHTREE_FOOTER,
        prop_dict["avb_avbtool"],
        key_path,
        algorithm,
        salt,
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
    self.key_path = common.ResolveAVBSigningPathArgs(key_path)

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


def CreateCustomImageBuilder(info_dict, partition_name, partition_size,
                             key_path, algorithm, signing_args):
  builder = None
  if info_dict.get("avb_enable") == "true":
    builder = VerifiedBootVersion2VerityImageBuilder(
        partition_name,
        partition_size,
        VerifiedBootVersion2VerityImageBuilder.AVB_HASHTREE_FOOTER,
        info_dict.get("avb_avbtool"),
        key_path,
        algorithm,
        # Salt is None because custom images have no fingerprint property to be
        # used as the salt.
        None,
        signing_args)

  return builder


def GetDiskUsage(path):
  """Returns the number of bytes that "path" occupies on host.

  Args:
    path: The directory or file to calculate size on.

  Returns:
    The number of bytes based on a 1K block_size.
  """
  cmd = ["du", "-b", "-k", "-s", path]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output.split()[0]) * 1024


def CalculateVbmetaDigest(extracted_dir, avbtool):
  """Calculates the vbmeta digest of the images in the extracted target_file"""

  images_dir = common.MakeTempDir()
  for name in ("PREBUILT_IMAGES", "RADIO", "IMAGES"):
    path = os.path.join(extracted_dir, name)
    if not os.path.exists(path):
      continue

    # Create symlink for image files under PREBUILT_IMAGES, RADIO and IMAGES,
    # and put them into one directory.
    for filename in os.listdir(path):
      if not filename.endswith(".img"):
        continue
      symlink_path = os.path.join(images_dir, filename)
      # The files in latter directory overwrite the existing links
      common.RunAndCheckOutput(
        ['ln', '-sf', os.path.join(path, filename), symlink_path])

  cmd = [avbtool, "calculate_vbmeta_digest", "--image",
         os.path.join(images_dir, 'vbmeta.img')]
  return common.RunAndCheckOutput(cmd)


def main(argv):
  if len(argv) != 2:
    print(__doc__)
    sys.exit(1)

  common.InitLogging()

  dict_file = argv[0]
  out_file = argv[1]

  prop_dict = {}
  with open(dict_file, 'r') as f:
    for line in f:
      line = line.strip()
      if not line or line.startswith("#"):
        continue
      k, v = line.split("=", 1)
      prop_dict[k] = v

  builder = CreateVerityImageBuilder(prop_dict)

  if "partition_size" not in prop_dict:
    image_size = GetDiskUsage(out_file)
    # make sure that the image is big enough to hold vbmeta and footer
    image_size = image_size + (MAX_VBMETA_SIZE + MAX_FOOTER_SIZE)
    size = builder.CalculateDynamicPartitionSize(image_size)
    prop_dict["partition_size"] = size

  builder.Build(out_file)


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  finally:
    common.Cleanup()
