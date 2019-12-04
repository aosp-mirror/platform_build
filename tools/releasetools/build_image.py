#!/usr/bin/env python
#
# Copyright (C) 2011 The Android Open Source Project
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
Builds output_image from the given input_directory, properties_file,
and writes the image to target_output_directory.

Usage:  build_image input_directory properties_file output_image \\
            target_output_directory
"""

from __future__ import print_function

import logging
import os
import os.path
import re
import shutil
import sys

import common
import verity_utils

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
BLOCK_SIZE = common.BLOCK_SIZE
BYTES_IN_MB = 1024 * 1024


class BuildImageError(Exception):
  """An Exception raised during image building."""

  def __init__(self, message):
    Exception.__init__(self, message)


def GetDiskUsage(path):
  """Returns the number of bytes that "path" occupies on host.

  Args:
    path: The directory or file to calculate size on.

  Returns:
    The number of bytes based on a 1K block_size.
  """
  cmd = ["du", "-k", "-s", path]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  return int(output.split()[0]) * 1024


def GetInodeUsage(path):
  """Returns the number of inodes that "path" occupies on host.

  Args:
    path: The directory or file to calculate inode number on.

  Returns:
    The number of inodes used.
  """
  cmd = ["find", path, "-print"]
  output = common.RunAndCheckOutput(cmd, verbose=False)
  # increase by > 4% as number of files and directories is not whole picture.
  inodes = output.count('\n')
  spare_inodes = inodes * 4 // 100
  min_spare_inodes = 12
  if spare_inodes < min_spare_inodes:
    spare_inodes = min_spare_inodes
  return inodes + spare_inodes


def GetFilesystemCharacteristics(image_path, sparse_image=True):
  """Returns various filesystem characteristics of "image_path".

  Args:
    image_path: The file to analyze.
    sparse_image: Image is sparse

  Returns:
    The characteristics dictionary.
  """
  unsparse_image_path = image_path
  if sparse_image:
    unsparse_image_path = UnsparseImage(image_path, replace=False)

  cmd = ["tune2fs", "-l", unsparse_image_path]
  try:
    output = common.RunAndCheckOutput(cmd, verbose=False)
  finally:
    if sparse_image:
      os.remove(unsparse_image_path)
  fs_dict = {}
  for line in output.splitlines():
    fields = line.split(":")
    if len(fields) == 2:
      fs_dict[fields[0].strip()] = fields[1].strip()
  return fs_dict


def UnsparseImage(sparse_image_path, replace=True):
  img_dir = os.path.dirname(sparse_image_path)
  unsparse_image_path = "unsparse_" + os.path.basename(sparse_image_path)
  unsparse_image_path = os.path.join(img_dir, unsparse_image_path)
  if os.path.exists(unsparse_image_path):
    if replace:
      os.unlink(unsparse_image_path)
    else:
      return unsparse_image_path
  inflate_command = ["simg2img", sparse_image_path, unsparse_image_path]
  try:
    common.RunAndCheckOutput(inflate_command)
  except:
    os.remove(unsparse_image_path)
    raise
  return unsparse_image_path


def ConvertBlockMapToBaseFs(block_map_file):
  base_fs_file = common.MakeTempFile(prefix="script_gen_", suffix=".base_fs")
  convert_command = ["blk_alloc_to_base_fs", block_map_file, base_fs_file]
  common.RunAndCheckOutput(convert_command)
  return base_fs_file


def SetUpInDirAndFsConfig(origin_in, prop_dict):
  """Returns the in_dir and fs_config that should be used for image building.

  When building system.img for all targets, it creates and returns a staged dir
  that combines the contents of /system (i.e. in the given in_dir) and root.

  Args:
    origin_in: Path to the input directory.
    prop_dict: A property dict that contains info like partition size. Values
        may be updated.

  Returns:
    A tuple of in_dir and fs_config that should be used to build the image.
  """
  fs_config = prop_dict.get("fs_config")

  if prop_dict["mount_point"] == "system_other":
    prop_dict["mount_point"] = "system"
    return origin_in, fs_config

  if prop_dict["mount_point"] != "system":
    return origin_in, fs_config

  if "first_pass" in prop_dict:
    prop_dict["mount_point"] = "/"
    return prop_dict["first_pass"]

  # Construct a staging directory of the root file system.
  in_dir = common.MakeTempDir()
  root_dir = prop_dict.get("root_dir")
  if root_dir:
    shutil.rmtree(in_dir)
    shutil.copytree(root_dir, in_dir, symlinks=True)
  in_dir_system = os.path.join(in_dir, "system")
  shutil.rmtree(in_dir_system, ignore_errors=True)
  shutil.copytree(origin_in, in_dir_system, symlinks=True)

  # Change the mount point to "/".
  prop_dict["mount_point"] = "/"
  if fs_config:
    # We need to merge the fs_config files of system and root.
    merged_fs_config = common.MakeTempFile(
        prefix="merged_fs_config", suffix=".txt")
    with open(merged_fs_config, "w") as fw:
      if "root_fs_config" in prop_dict:
        with open(prop_dict["root_fs_config"]) as fr:
          fw.writelines(fr.readlines())
      with open(fs_config) as fr:
        fw.writelines(fr.readlines())
    fs_config = merged_fs_config
  prop_dict["first_pass"] = (in_dir, fs_config)
  return in_dir, fs_config


def CheckHeadroom(ext4fs_output, prop_dict):
  """Checks if there's enough headroom space available.

  Headroom is the reserved space on system image (via PRODUCT_SYSTEM_HEADROOM),
  which is useful for devices with low disk space that have system image
  variation between builds. The 'partition_headroom' in prop_dict is the size
  in bytes, while the numbers in 'ext4fs_output' are for 4K-blocks.

  Args:
    ext4fs_output: The output string from mke2fs command.
    prop_dict: The property dict.

  Raises:
    AssertionError: On invalid input.
    BuildImageError: On check failure.
  """
  assert ext4fs_output is not None
  assert prop_dict.get('fs_type', '').startswith('ext4')
  assert 'partition_headroom' in prop_dict
  assert 'mount_point' in prop_dict

  ext4fs_stats = re.compile(
      r'Created filesystem with .* (?P<used_blocks>[0-9]+)/'
      r'(?P<total_blocks>[0-9]+) blocks')
  last_line = ext4fs_output.strip().split('\n')[-1]
  m = ext4fs_stats.match(last_line)
  used_blocks = int(m.groupdict().get('used_blocks'))
  total_blocks = int(m.groupdict().get('total_blocks'))
  headroom_blocks = int(prop_dict['partition_headroom']) // BLOCK_SIZE
  adjusted_blocks = total_blocks - headroom_blocks
  if used_blocks > adjusted_blocks:
    mount_point = prop_dict["mount_point"]
    raise BuildImageError(
        "Error: Not enough room on {} (total: {} blocks, used: {} blocks, "
        "headroom: {} blocks, available: {} blocks)".format(
            mount_point, total_blocks, used_blocks, headroom_blocks,
            adjusted_blocks))


def BuildImageMkfs(in_dir, prop_dict, out_file, target_out, fs_config):
  """Builds a pure image for the files under in_dir and writes it to out_file.

  Args:
    in_dir: Path to input directory.
    prop_dict: A property dict that contains info like partition size. Values
        will be updated with computed values.
    out_file: The output image file.
    target_out: Path to the TARGET_OUT directory as in Makefile. It actually
        points to the /system directory under PRODUCT_OUT. fs_config (the one
        under system/core/libcutils) reads device specific FS config files from
        there.
    fs_config: The fs_config file that drives the prototype

  Raises:
    BuildImageError: On build image failures.
  """
  build_command = []
  fs_type = prop_dict.get("fs_type", "")
  run_e2fsck = False

  if fs_type.startswith("ext"):
    build_command = [prop_dict["ext_mkuserimg"]]
    if "extfs_sparse_flag" in prop_dict:
      build_command.append(prop_dict["extfs_sparse_flag"])
      run_e2fsck = True
    build_command.extend([in_dir, out_file, fs_type,
                          prop_dict["mount_point"]])
    build_command.append(prop_dict["image_size"])
    if "journal_size" in prop_dict:
      build_command.extend(["-j", prop_dict["journal_size"]])
    if "timestamp" in prop_dict:
      build_command.extend(["-T", str(prop_dict["timestamp"])])
    if fs_config:
      build_command.extend(["-C", fs_config])
    if target_out:
      build_command.extend(["-D", target_out])
    if "block_list" in prop_dict:
      build_command.extend(["-B", prop_dict["block_list"]])
    if "base_fs_file" in prop_dict:
      base_fs_file = ConvertBlockMapToBaseFs(prop_dict["base_fs_file"])
      build_command.extend(["-d", base_fs_file])
    build_command.extend(["-L", prop_dict["mount_point"]])
    if "extfs_inode_count" in prop_dict:
      build_command.extend(["-i", prop_dict["extfs_inode_count"]])
    if "extfs_rsv_pct" in prop_dict:
      build_command.extend(["-M", prop_dict["extfs_rsv_pct"]])
    if "flash_erase_block_size" in prop_dict:
      build_command.extend(["-e", prop_dict["flash_erase_block_size"]])
    if "flash_logical_block_size" in prop_dict:
      build_command.extend(["-o", prop_dict["flash_logical_block_size"]])
    # Specify UUID and hash_seed if using mke2fs.
    if prop_dict["ext_mkuserimg"] == "mkuserimg_mke2fs":
      if "uuid" in prop_dict:
        build_command.extend(["-U", prop_dict["uuid"]])
      if "hash_seed" in prop_dict:
        build_command.extend(["-S", prop_dict["hash_seed"]])
    if "ext4_share_dup_blocks" in prop_dict:
      build_command.append("-c")
    build_command.extend(["--inode_size", "256"])
    if "selinux_fc" in prop_dict:
      build_command.append(prop_dict["selinux_fc"])
  elif fs_type.startswith("squash"):
    build_command = ["mksquashfsimage.sh"]
    build_command.extend([in_dir, out_file])
    if "squashfs_sparse_flag" in prop_dict:
      build_command.extend([prop_dict["squashfs_sparse_flag"]])
    build_command.extend(["-m", prop_dict["mount_point"]])
    if target_out:
      build_command.extend(["-d", target_out])
    if fs_config:
      build_command.extend(["-C", fs_config])
    if "selinux_fc" in prop_dict:
      build_command.extend(["-c", prop_dict["selinux_fc"]])
    if "block_list" in prop_dict:
      build_command.extend(["-B", prop_dict["block_list"]])
    if "squashfs_block_size" in prop_dict:
      build_command.extend(["-b", prop_dict["squashfs_block_size"]])
    if "squashfs_compressor" in prop_dict:
      build_command.extend(["-z", prop_dict["squashfs_compressor"]])
    if "squashfs_compressor_opt" in prop_dict:
      build_command.extend(["-zo", prop_dict["squashfs_compressor_opt"]])
    if prop_dict.get("squashfs_disable_4k_align") == "true":
      build_command.extend(["-a"])
  elif fs_type.startswith("f2fs"):
    build_command = ["mkf2fsuserimg.sh"]
    build_command.extend([out_file, prop_dict["image_size"]])
    if "f2fs_sparse_flag" in prop_dict:
      build_command.extend([prop_dict["f2fs_sparse_flag"]])
    if fs_config:
      build_command.extend(["-C", fs_config])
    build_command.extend(["-f", in_dir])
    if target_out:
      build_command.extend(["-D", target_out])
    if "selinux_fc" in prop_dict:
      build_command.extend(["-s", prop_dict["selinux_fc"]])
    build_command.extend(["-t", prop_dict["mount_point"]])
    if "timestamp" in prop_dict:
      build_command.extend(["-T", str(prop_dict["timestamp"])])
    build_command.extend(["-L", prop_dict["mount_point"]])
  else:
    raise BuildImageError(
        "Error: unknown filesystem type: {}".format(fs_type))

  try:
    mkfs_output = common.RunAndCheckOutput(build_command)
  except:
    try:
      du = GetDiskUsage(in_dir)
      du_str = "{} bytes ({} MB)".format(du, du // BYTES_IN_MB)
    # Suppress any errors from GetDiskUsage() to avoid hiding the real errors
    # from common.RunAndCheckOutput().
    except Exception:  # pylint: disable=broad-except
      logger.exception("Failed to compute disk usage with du")
      du_str = "unknown"
    print(
        "Out of space? Out of inodes? The tree size of {} is {}, "
        "with reserved space of {} bytes ({} MB).".format(
            in_dir, du_str,
            int(prop_dict.get("partition_reserved_size", 0)),
            int(prop_dict.get("partition_reserved_size", 0)) // BYTES_IN_MB))
    print(
        "The max image size for filesystem files is {} bytes ({} MB), out of a "
        "total partition size of {} bytes ({} MB).".format(
            int(prop_dict["image_size"]),
            int(prop_dict["image_size"]) // BYTES_IN_MB,
            int(prop_dict["partition_size"]),
            int(prop_dict["partition_size"]) // BYTES_IN_MB))
    raise

  if run_e2fsck and prop_dict.get("skip_fsck") != "true":
    unsparse_image = UnsparseImage(out_file, replace=False)

    # Run e2fsck on the inflated image file
    e2fsck_command = ["e2fsck", "-f", "-n", unsparse_image]
    try:
      common.RunAndCheckOutput(e2fsck_command)
    finally:
      os.remove(unsparse_image)

  return mkfs_output


def BuildImage(in_dir, prop_dict, out_file, target_out=None):
  """Builds an image for the files under in_dir and writes it to out_file.

  Args:
    in_dir: Path to input directory.
    prop_dict: A property dict that contains info like partition size. Values
        will be updated with computed values.
    out_file: The output image file.
    target_out: Path to the TARGET_OUT directory as in Makefile. It actually
        points to the /system directory under PRODUCT_OUT. fs_config (the one
        under system/core/libcutils) reads device specific FS config files from
        there.

  Raises:
    BuildImageError: On build image failures.
  """
  in_dir, fs_config = SetUpInDirAndFsConfig(in_dir, prop_dict)

  build_command = []
  fs_type = prop_dict.get("fs_type", "")

  fs_spans_partition = True
  if fs_type.startswith("squash"):
    fs_spans_partition = False

  # Get a builder for creating an image that's to be verified by Verified Boot,
  # or None if not applicable.
  verity_image_builder = verity_utils.CreateVerityImageBuilder(prop_dict)

  if (prop_dict.get("use_dynamic_partition_size") == "true" and
      "partition_size" not in prop_dict):
    # If partition_size is not defined, use output of `du' + reserved_size.
    size = GetDiskUsage(in_dir)
    logger.info(
        "The tree size of %s is %d MB.", in_dir, size // BYTES_IN_MB)
    # If not specified, give us 16MB margin for GetDiskUsage error ...
    reserved_size = int(prop_dict.get("partition_reserved_size", BYTES_IN_MB * 16))
    partition_headroom = int(prop_dict.get("partition_headroom", 0))
    if fs_type.startswith("ext4") and partition_headroom > reserved_size:
      reserved_size = partition_headroom
    size += reserved_size
    # Round this up to a multiple of 4K so that avbtool works
    size = common.RoundUpTo4K(size)
    if fs_type.startswith("ext"):
      prop_dict["partition_size"] = str(size)
      prop_dict["image_size"] = str(size)
      if "extfs_inode_count" not in prop_dict:
        prop_dict["extfs_inode_count"] = str(GetInodeUsage(in_dir))
      logger.info(
          "First Pass based on estimates of %d MB and %s inodes.",
          size // BYTES_IN_MB, prop_dict["extfs_inode_count"])
      BuildImageMkfs(in_dir, prop_dict, out_file, target_out, fs_config)
      sparse_image = False
      if "extfs_sparse_flag" in prop_dict:
        sparse_image = True
      fs_dict = GetFilesystemCharacteristics(out_file, sparse_image)
      os.remove(out_file)
      block_size = int(fs_dict.get("Block size", "4096"))
      free_size = int(fs_dict.get("Free blocks", "0")) * block_size
      reserved_size = int(prop_dict.get("partition_reserved_size", 0))
      partition_headroom = int(fs_dict.get("partition_headroom", 0))
      if fs_type.startswith("ext4") and partition_headroom > reserved_size:
        reserved_size = partition_headroom
      if free_size <= reserved_size:
        logger.info(
            "Not worth reducing image %d <= %d.", free_size, reserved_size)
      else:
        size -= free_size
        size += reserved_size
        if reserved_size == 0:
          # add .3% margin
          size = size * 1003 // 1000
        # Use a minimum size, otherwise we will fail to calculate an AVB footer
        # or fail to construct an ext4 image.
        size = max(size, 256 * 1024)
        if block_size <= 4096:
          size = common.RoundUpTo4K(size)
        else:
          size = ((size + block_size - 1) // block_size) * block_size
      extfs_inode_count = prop_dict["extfs_inode_count"]
      inodes = int(fs_dict.get("Inode count", extfs_inode_count))
      inodes -= int(fs_dict.get("Free inodes", "0"))
      # add .2% margin or 1 inode, whichever is greater
      spare_inodes = inodes * 2 // 1000
      min_spare_inodes = 1
      if spare_inodes < min_spare_inodes:
        spare_inodes = min_spare_inodes
      inodes += spare_inodes
      prop_dict["extfs_inode_count"] = str(inodes)
      prop_dict["partition_size"] = str(size)
      logger.info(
          "Allocating %d Inodes for %s.", inodes, out_file)
    if verity_image_builder:
      size = verity_image_builder.CalculateDynamicPartitionSize(size)
    prop_dict["partition_size"] = str(size)
    logger.info(
        "Allocating %d MB for %s.", size // BYTES_IN_MB, out_file)

  prop_dict["image_size"] = prop_dict["partition_size"]

  # Adjust the image size to make room for the hashes if this is to be verified.
  if verity_image_builder:
    max_image_size = verity_image_builder.CalculateMaxImageSize()
    prop_dict["image_size"] = str(max_image_size)

  mkfs_output = BuildImageMkfs(in_dir, prop_dict, out_file, target_out, fs_config)

  # Check if there's enough headroom space available for ext4 image.
  if "partition_headroom" in prop_dict and fs_type.startswith("ext4"):
    CheckHeadroom(mkfs_output, prop_dict)

  if not fs_spans_partition and verity_image_builder:
    verity_image_builder.PadSparseImage(out_file)

  # Create the verified image if this is to be verified.
  if verity_image_builder:
    verity_image_builder.Build(out_file)


def ImagePropFromGlobalDict(glob_dict, mount_point):
  """Build an image property dictionary from the global dictionary.

  Args:
    glob_dict: the global dictionary from the build system.
    mount_point: such as "system", "data" etc.
  """
  d = {}

  if "build.prop" in glob_dict:
    bp = glob_dict["build.prop"]
    if "ro.build.date.utc" in bp:
      d["timestamp"] = bp["ro.build.date.utc"]

  def copy_prop(src_p, dest_p):
    """Copy a property from the global dictionary.

    Args:
      src_p: The source property in the global dictionary.
      dest_p: The destination property.
    Returns:
      True if property was found and copied, False otherwise.
    """
    if src_p in glob_dict:
      d[dest_p] = str(glob_dict[src_p])
      return True
    return False

  common_props = (
      "extfs_sparse_flag",
      "squashfs_sparse_flag",
      "f2fs_sparse_flag",
      "skip_fsck",
      "ext_mkuserimg",
      "verity",
      "verity_key",
      "verity_signer_cmd",
      "verity_fec",
      "verity_disable",
      "avb_enable",
      "avb_avbtool",
      "avb_salt",
      "use_dynamic_partition_size",
  )
  for p in common_props:
    copy_prop(p, p)

  d["mount_point"] = mount_point
  if mount_point == "system":
    copy_prop("avb_system_hashtree_enable", "avb_hashtree_enable")
    copy_prop("avb_system_add_hashtree_footer_args",
              "avb_add_hashtree_footer_args")
    copy_prop("avb_system_key_path", "avb_key_path")
    copy_prop("avb_system_algorithm", "avb_algorithm")
    copy_prop("fs_type", "fs_type")
    # Copy the generic system fs type first, override with specific one if
    # available.
    copy_prop("system_fs_type", "fs_type")
    copy_prop("system_headroom", "partition_headroom")
    copy_prop("system_size", "partition_size")
    if not copy_prop("system_journal_size", "journal_size"):
      d["journal_size"] = "0"
    copy_prop("system_verity_block_device", "verity_block_device")
    copy_prop("system_root_image", "system_root_image")
    copy_prop("root_dir", "root_dir")
    copy_prop("root_fs_config", "root_fs_config")
    copy_prop("ext4_share_dup_blocks", "ext4_share_dup_blocks")
    copy_prop("system_squashfs_compressor", "squashfs_compressor")
    copy_prop("system_squashfs_compressor_opt", "squashfs_compressor_opt")
    copy_prop("system_squashfs_block_size", "squashfs_block_size")
    copy_prop("system_squashfs_disable_4k_align", "squashfs_disable_4k_align")
    copy_prop("system_base_fs_file", "base_fs_file")
    copy_prop("system_extfs_inode_count", "extfs_inode_count")
    if not copy_prop("system_extfs_rsv_pct", "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"
    copy_prop("system_reserved_size", "partition_reserved_size")
    copy_prop("system_selinux_fc", "selinux_fc")
  elif mount_point == "system_other":
    # We inherit the selinux policies of /system since we contain some of its
    # files.
    copy_prop("avb_system_other_hashtree_enable", "avb_hashtree_enable")
    copy_prop("avb_system_other_add_hashtree_footer_args",
              "avb_add_hashtree_footer_args")
    copy_prop("avb_system_other_key_path", "avb_key_path")
    copy_prop("avb_system_other_algorithm", "avb_algorithm")
    copy_prop("fs_type", "fs_type")
    copy_prop("system_fs_type", "fs_type")
    copy_prop("system_other_size", "partition_size")
    if not copy_prop("system_journal_size", "journal_size"):
      d["journal_size"] = "0"
    copy_prop("system_verity_block_device", "verity_block_device")
    copy_prop("ext4_share_dup_blocks", "ext4_share_dup_blocks")
    copy_prop("system_squashfs_compressor", "squashfs_compressor")
    copy_prop("system_squashfs_compressor_opt", "squashfs_compressor_opt")
    copy_prop("system_squashfs_block_size", "squashfs_block_size")
    copy_prop("system_extfs_inode_count", "extfs_inode_count")
    if not copy_prop("system_extfs_rsv_pct", "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"
    copy_prop("system_reserved_size", "partition_reserved_size")
    copy_prop("system_selinux_fc", "selinux_fc")
  elif mount_point == "data":
    # Copy the generic fs type first, override with specific one if available.
    copy_prop("fs_type", "fs_type")
    copy_prop("userdata_fs_type", "fs_type")
    copy_prop("userdata_size", "partition_size")
    copy_prop("flash_logical_block_size", "flash_logical_block_size")
    copy_prop("flash_erase_block_size", "flash_erase_block_size")
    copy_prop("userdata_selinux_fc", "selinux_fc")
  elif mount_point == "cache":
    copy_prop("cache_fs_type", "fs_type")
    copy_prop("cache_size", "partition_size")
    copy_prop("cache_selinux_fc", "selinux_fc")
  elif mount_point == "vendor":
    copy_prop("avb_vendor_hashtree_enable", "avb_hashtree_enable")
    copy_prop("avb_vendor_add_hashtree_footer_args",
              "avb_add_hashtree_footer_args")
    copy_prop("avb_vendor_key_path", "avb_key_path")
    copy_prop("avb_vendor_algorithm", "avb_algorithm")
    copy_prop("vendor_fs_type", "fs_type")
    copy_prop("vendor_size", "partition_size")
    if not copy_prop("vendor_journal_size", "journal_size"):
      d["journal_size"] = "0"
    copy_prop("vendor_verity_block_device", "verity_block_device")
    copy_prop("ext4_share_dup_blocks", "ext4_share_dup_blocks")
    copy_prop("vendor_squashfs_compressor", "squashfs_compressor")
    copy_prop("vendor_squashfs_compressor_opt", "squashfs_compressor_opt")
    copy_prop("vendor_squashfs_block_size", "squashfs_block_size")
    copy_prop("vendor_squashfs_disable_4k_align", "squashfs_disable_4k_align")
    copy_prop("vendor_base_fs_file", "base_fs_file")
    copy_prop("vendor_extfs_inode_count", "extfs_inode_count")
    if not copy_prop("vendor_extfs_rsv_pct", "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"
    copy_prop("vendor_reserved_size", "partition_reserved_size")
    copy_prop("vendor_selinux_fc", "selinux_fc")
  elif mount_point == "product":
    copy_prop("avb_product_hashtree_enable", "avb_hashtree_enable")
    copy_prop("avb_product_add_hashtree_footer_args",
              "avb_add_hashtree_footer_args")
    copy_prop("avb_product_key_path", "avb_key_path")
    copy_prop("avb_product_algorithm", "avb_algorithm")
    copy_prop("product_fs_type", "fs_type")
    copy_prop("product_size", "partition_size")
    if not copy_prop("product_journal_size", "journal_size"):
      d["journal_size"] = "0"
    copy_prop("product_verity_block_device", "verity_block_device")
    copy_prop("ext4_share_dup_blocks", "ext4_share_dup_blocks")
    copy_prop("product_squashfs_compressor", "squashfs_compressor")
    copy_prop("product_squashfs_compressor_opt", "squashfs_compressor_opt")
    copy_prop("product_squashfs_block_size", "squashfs_block_size")
    copy_prop("product_squashfs_disable_4k_align", "squashfs_disable_4k_align")
    copy_prop("product_base_fs_file", "base_fs_file")
    copy_prop("product_extfs_inode_count", "extfs_inode_count")
    if not copy_prop("product_extfs_rsv_pct", "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"
    copy_prop("product_reserved_size", "partition_reserved_size")
    copy_prop("product_selinux_fc", "selinux_fc")
  elif mount_point == "system_ext":
    copy_prop("avb_system_ext_hashtree_enable", "avb_hashtree_enable")
    copy_prop("avb_system_ext_add_hashtree_footer_args",
              "avb_add_hashtree_footer_args")
    copy_prop("avb_system_ext_key_path", "avb_key_path")
    copy_prop("avb_system_ext_algorithm", "avb_algorithm")
    copy_prop("system_ext_fs_type", "fs_type")
    copy_prop("system_ext_size", "partition_size")
    if not copy_prop("system_ext_journal_size", "journal_size"):
      d["journal_size"] = "0"
    copy_prop("system_ext_verity_block_device", "verity_block_device")
    copy_prop("ext4_share_dup_blocks", "ext4_share_dup_blocks")
    copy_prop("system_ext_squashfs_compressor", "squashfs_compressor")
    copy_prop("system_ext_squashfs_compressor_opt",
              "squashfs_compressor_opt")
    copy_prop("system_ext_squashfs_block_size", "squashfs_block_size")
    copy_prop("system_ext_squashfs_disable_4k_align",
              "squashfs_disable_4k_align")
    copy_prop("system_ext_base_fs_file", "base_fs_file")
    copy_prop("system_ext_extfs_inode_count", "extfs_inode_count")
    if not copy_prop("system_ext_extfs_rsv_pct", "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"
    copy_prop("system_ext_reserved_size", "partition_reserved_size")
    copy_prop("system_ext_selinux_fc", "selinux_fc")
  elif mount_point == "odm":
    copy_prop("avb_odm_hashtree_enable", "avb_hashtree_enable")
    copy_prop("avb_odm_add_hashtree_footer_args",
              "avb_add_hashtree_footer_args")
    copy_prop("avb_odm_key_path", "avb_key_path")
    copy_prop("avb_odm_algorithm", "avb_algorithm")
    copy_prop("odm_fs_type", "fs_type")
    copy_prop("odm_size", "partition_size")
    if not copy_prop("odm_journal_size", "journal_size"):
      d["journal_size"] = "0"
    copy_prop("odm_verity_block_device", "verity_block_device")
    copy_prop("ext4_share_dup_blocks", "ext4_share_dup_blocks")
    copy_prop("odm_squashfs_compressor", "squashfs_compressor")
    copy_prop("odm_squashfs_compressor_opt", "squashfs_compressor_opt")
    copy_prop("odm_squashfs_block_size", "squashfs_block_size")
    copy_prop("odm_squashfs_disable_4k_align", "squashfs_disable_4k_align")
    copy_prop("odm_base_fs_file", "base_fs_file")
    copy_prop("odm_extfs_inode_count", "extfs_inode_count")
    if not copy_prop("odm_extfs_rsv_pct", "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"
    copy_prop("odm_reserved_size", "partition_reserved_size")
    copy_prop("odm_selinux_fc", "selinux_fc")
  elif mount_point == "oem":
    copy_prop("fs_type", "fs_type")
    copy_prop("oem_size", "partition_size")
    if not copy_prop("oem_journal_size", "journal_size"):
      d["journal_size"] = "0"
    copy_prop("oem_extfs_inode_count", "extfs_inode_count")
    copy_prop("ext4_share_dup_blocks", "ext4_share_dup_blocks")
    if not copy_prop("oem_extfs_rsv_pct", "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"
    copy_prop("oem_selinux_fc", "selinux_fc")
  d["partition_name"] = mount_point
  return d


def LoadGlobalDict(filename):
  """Load "name=value" pairs from filename"""
  d = {}
  f = open(filename)
  for line in f:
    line = line.strip()
    if not line or line.startswith("#"):
      continue
    k, v = line.split("=", 1)
    d[k] = v
  f.close()
  return d


def GlobalDictFromImageProp(image_prop, mount_point):
  d = {}
  def copy_prop(src_p, dest_p):
    if src_p in image_prop:
      d[dest_p] = image_prop[src_p]
      return True
    return False

  if mount_point == "system":
    copy_prop("partition_size", "system_size")
  elif mount_point == "system_other":
    copy_prop("partition_size", "system_other_size")
  elif mount_point == "vendor":
    copy_prop("partition_size", "vendor_size")
  elif mount_point == "odm":
    copy_prop("partition_size", "odm_size")
  elif mount_point == "product":
    copy_prop("partition_size", "product_size")
  elif mount_point == "system_ext":
    copy_prop("partition_size", "system_ext_size")
  return d


def main(argv):
  if len(argv) != 4:
    print(__doc__)
    sys.exit(1)

  common.InitLogging()

  in_dir = argv[0]
  glob_dict_file = argv[1]
  out_file = argv[2]
  target_out = argv[3]

  glob_dict = LoadGlobalDict(glob_dict_file)
  if "mount_point" in glob_dict:
    # The caller knows the mount point and provides a dictionary needed by
    # BuildImage().
    image_properties = glob_dict
  else:
    image_filename = os.path.basename(out_file)
    mount_point = ""
    if image_filename == "system.img":
      mount_point = "system"
    elif image_filename == "system_other.img":
      mount_point = "system_other"
    elif image_filename == "userdata.img":
      mount_point = "data"
    elif image_filename == "cache.img":
      mount_point = "cache"
    elif image_filename == "vendor.img":
      mount_point = "vendor"
    elif image_filename == "odm.img":
      mount_point = "odm"
    elif image_filename == "oem.img":
      mount_point = "oem"
    elif image_filename == "product.img":
      mount_point = "product"
    elif image_filename == "system_ext.img":
      mount_point = "system_ext"
    else:
      logger.error("Unknown image file name %s", image_filename)
      sys.exit(1)

    image_properties = ImagePropFromGlobalDict(glob_dict, mount_point)

  try:
    BuildImage(in_dir, image_properties, out_file, target_out)
  except:
    logger.error("Failed to build %s from %s", out_file, in_dir)
    raise


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  finally:
    common.Cleanup()
