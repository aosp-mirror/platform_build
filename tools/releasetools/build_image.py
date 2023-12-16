#!/usr/bin/env python3
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

import datetime

import argparse
import glob
import logging
import os
import os.path
import re
import shlex
import shutil
import sys
import uuid
import tempfile

import common
import verity_utils


logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
BLOCK_SIZE = common.BLOCK_SIZE
BYTES_IN_MB = 1024 * 1024

# Use a fixed timestamp (01/01/2009 00:00:00 UTC) for files when packaging
# images. (b/24377993, b/80600931)
FIXED_FILE_TIMESTAMP = int((
    datetime.datetime(2009, 1, 1, 0, 0, 0, 0, None) -
    datetime.datetime.utcfromtimestamp(0)).total_seconds())


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
  cmd = ["du", "-b", "-k", "-s", path]
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
  # increase by > 6% as number of files and directories is not whole picture.
  inodes = output.count('\n')
  spare_inodes = inodes * 6 // 100
  min_spare_inodes = 12
  if spare_inodes < min_spare_inodes:
    spare_inodes = min_spare_inodes
  return inodes + spare_inodes


def GetFilesystemCharacteristics(fs_type, image_path, sparse_image=True):
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

  if fs_type.startswith("ext"):
    cmd = ["tune2fs", "-l", unsparse_image_path]
  elif fs_type.startswith("f2fs"):
    cmd = ["fsck.f2fs", "-l", unsparse_image_path]

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


def CalculateSizeAndReserved(prop_dict, size):
  fs_type = prop_dict.get("fs_type", "")
  partition_headroom = int(prop_dict.get("partition_headroom", 0))
  # If not specified, give us 16MB margin for GetDiskUsage error ...
  reserved_size = int(prop_dict.get(
      "partition_reserved_size", BYTES_IN_MB * 16))

  if fs_type == "erofs":
    reserved_size = int(prop_dict.get("partition_reserved_size", 0))
    if reserved_size == 0:
      # give .3% margin or a minimum size for AVB footer
      return max(size * 1003 // 1000, 256 * 1024)

  if fs_type.startswith("ext4") and partition_headroom > reserved_size:
    reserved_size = partition_headroom

  return size + reserved_size


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
  run_fsck = None
  needs_projid = prop_dict.get("needs_projid", 0)
  needs_casefold = prop_dict.get("needs_casefold", 0)
  needs_compress = prop_dict.get("needs_compress", 0)

  disable_sparse = "disable_sparse" in prop_dict
  manual_sparse = False

  if fs_type.startswith("ext"):
    build_command = [prop_dict["ext_mkuserimg"]]
    if "extfs_sparse_flag" in prop_dict and not disable_sparse:
      build_command.append(prop_dict["extfs_sparse_flag"])
      run_e2fsck = RunE2fsck
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
    if os.path.basename(prop_dict["ext_mkuserimg"]) == "mkuserimg_mke2fs":
      if "uuid" in prop_dict:
        build_command.extend(["-U", prop_dict["uuid"]])
      if "hash_seed" in prop_dict:
        build_command.extend(["-S", prop_dict["hash_seed"]])
    if prop_dict.get("ext4_share_dup_blocks") == "true":
      build_command.append("-c")
    if (needs_projid):
      build_command.extend(["--inode_size", "512"])
    else:
      build_command.extend(["--inode_size", "256"])
    if "selinux_fc" in prop_dict:
      build_command.append(prop_dict["selinux_fc"])
  elif fs_type.startswith("erofs"):
    build_command = ["mkfs.erofs"]

    compressor = None
    if "erofs_default_compressor" in prop_dict:
      compressor = prop_dict["erofs_default_compressor"]
    if "erofs_compressor" in prop_dict:
      compressor = prop_dict["erofs_compressor"]
    if compressor and compressor != "none":
      build_command.extend(["-z", compressor])

    compress_hints = None
    if "erofs_default_compress_hints" in prop_dict:
      compress_hints = prop_dict["erofs_default_compress_hints"]
    if "erofs_compress_hints" in prop_dict:
      compress_hints = prop_dict["erofs_compress_hints"]
    if compress_hints:
      build_command.extend(["--compress-hints", compress_hints])

    build_command.extend(["-b", prop_dict.get("erofs_blocksize", "4096")])

    build_command.extend(["--mount-point", prop_dict["mount_point"]])
    if target_out:
      build_command.extend(["--product-out", target_out])
    if fs_config:
      build_command.extend(["--fs-config-file", fs_config])
    if "selinux_fc" in prop_dict:
      build_command.extend(["--file-contexts", prop_dict["selinux_fc"]])
    if "timestamp" in prop_dict:
      build_command.extend(["-T", str(prop_dict["timestamp"])])
    if "uuid" in prop_dict:
      build_command.extend(["-U", prop_dict["uuid"]])
    if "block_list" in prop_dict:
      build_command.extend(["--block-list-file", prop_dict["block_list"]])
    if "erofs_pcluster_size" in prop_dict:
      build_command.extend(["-C", prop_dict["erofs_pcluster_size"]])
    if "erofs_share_dup_blocks" in prop_dict:
      build_command.extend(["--chunksize", "4096"])
    if "erofs_use_legacy_compression" in prop_dict:
      build_command.extend(["-E", "legacy-compress"])

    build_command.extend([out_file, in_dir])
    if "erofs_sparse_flag" in prop_dict and not disable_sparse:
      manual_sparse = True

    run_fsck = RunErofsFsck
  elif fs_type.startswith("squash"):
    build_command = ["mksquashfsimage"]
    build_command.extend([in_dir, out_file])
    if "squashfs_sparse_flag" in prop_dict and not disable_sparse:
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
    build_command = ["mkf2fsuserimg"]
    build_command.extend([out_file, prop_dict["image_size"]])
    if "f2fs_sparse_flag" in prop_dict and not disable_sparse:
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
    if "block_list" in prop_dict:
      build_command.extend(["-B", prop_dict["block_list"]])
    build_command.extend(["-L", prop_dict["mount_point"]])
    if (needs_projid):
      build_command.append("--prjquota")
    if (needs_casefold):
      build_command.append("--casefold")
    if (needs_compress or prop_dict.get("f2fs_compress") == "true"):
      build_command.append("--compression")
    if "ro_mount_point" in prop_dict:
      build_command.append("--readonly")
    if (prop_dict.get("f2fs_compress") == "true"):
      build_command.append("--sldc")
      if (prop_dict.get("f2fs_sldc_flags") == None):
        build_command.append(str(0))
      else:
        sldc_flags_str = prop_dict.get("f2fs_sldc_flags")
        sldc_flags = sldc_flags_str.split()
        build_command.append(str(len(sldc_flags)))
        build_command.extend(sldc_flags)
    f2fs_blocksize = prop_dict.get("f2fs_blocksize", "4096")
    build_command.extend(["-b", f2fs_blocksize])
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
    if ("image_size" in prop_dict and "partition_size" in prop_dict):
      print(
          "The max image size for filesystem files is {} bytes ({} MB), "
          "out of a total partition size of {} bytes ({} MB).".format(
              int(prop_dict["image_size"]),
              int(prop_dict["image_size"]) // BYTES_IN_MB,
              int(prop_dict["partition_size"]),
              int(prop_dict["partition_size"]) // BYTES_IN_MB))
    raise

  if run_fsck and prop_dict.get("skip_fsck") != "true":
    run_fsck(out_file)

  if manual_sparse:
    temp_file = out_file + ".sparse"
    img2simg_argv = ["img2simg", out_file, temp_file]
    common.RunAndCheckOutput(img2simg_argv)
    os.rename(temp_file, out_file)

  return mkfs_output


def RunE2fsck(out_file):
  unsparse_image = UnsparseImage(out_file, replace=False)

  # Run e2fsck on the inflated image file
  e2fsck_command = ["e2fsck", "-f", "-n", unsparse_image]
  try:
    common.RunAndCheckOutput(e2fsck_command)
  finally:
    os.remove(unsparse_image)


def RunErofsFsck(out_file):
  fsck_command = ["fsck.erofs", "--extract", out_file]
  try:
    common.RunAndCheckOutput(fsck_command)
  except:
    print("Check failed for EROFS image {}".format(out_file))
    raise


def SetUUIDIfNotExist(image_props):

  # Use repeatable ext4 FS UUID and hash_seed UUID (based on partition name and
  # build fingerprint). Also use the legacy build id, because the vbmeta digest
  # isn't available at this point.
  what = image_props["mount_point"]
  fingerprint = image_props.get("fingerprint", "")
  uuid_seed = what + "-" + fingerprint
  logger.info("Using fingerprint %s for partition %s", fingerprint, what)
  image_props["uuid"] = str(uuid.uuid5(uuid.NAMESPACE_URL, uuid_seed))
  hash_seed = "hash_seed-" + uuid_seed
  image_props["hash_seed"] = str(uuid.uuid5(uuid.NAMESPACE_URL, hash_seed))


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
  SetUUIDIfNotExist(prop_dict)

  build_command = []
  fs_type = prop_dict.get("fs_type", "")

  fs_spans_partition = True
  if fs_type.startswith("squash") or fs_type.startswith("erofs"):
    fs_spans_partition = False
  elif fs_type.startswith("f2fs") and prop_dict.get("f2fs_compress") == "true":
    fs_spans_partition = False

  # Get a builder for creating an image that's to be verified by Verified Boot,
  # or None if not applicable.
  verity_image_builder = verity_utils.CreateVerityImageBuilder(prop_dict)

  disable_sparse = "disable_sparse" in prop_dict
  mkfs_output = None
  if (prop_dict.get("use_dynamic_partition_size") == "true" and
          "partition_size" not in prop_dict):
    # If partition_size is not defined, use output of `du' + reserved_size.
    # For compressed file system, it's better to use the compressed size to avoid wasting space.
    if fs_type.startswith("erofs"):
      mkfs_output = BuildImageMkfs(
          in_dir, prop_dict, out_file, target_out, fs_config)
      if "erofs_sparse_flag" in prop_dict and not disable_sparse:
        image_path = UnsparseImage(out_file, replace=False)
        size = GetDiskUsage(image_path)
        os.remove(image_path)
      else:
        size = GetDiskUsage(out_file)
    else:
      size = GetDiskUsage(in_dir)
    logger.info(
        "The tree size of %s is %d MB.", in_dir, size // BYTES_IN_MB)
    size = CalculateSizeAndReserved(prop_dict, size)
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
      if "extfs_sparse_flag" in prop_dict and not disable_sparse:
        sparse_image = True
      fs_dict = GetFilesystemCharacteristics(fs_type, out_file, sparse_image)
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
    elif fs_type.startswith("f2fs") and prop_dict.get("f2fs_compress") == "true":
      prop_dict["partition_size"] = str(size)
      prop_dict["image_size"] = str(size)
      BuildImageMkfs(in_dir, prop_dict, out_file, target_out, fs_config)
      sparse_image = False
      if "f2fs_sparse_flag" in prop_dict and not disable_sparse:
        sparse_image = True
      fs_dict = GetFilesystemCharacteristics(fs_type, out_file, sparse_image)
      os.remove(out_file)
      block_count = int(fs_dict.get("block_count", "0"))
      log_blocksize = int(fs_dict.get("log_blocksize", "12"))
      size = block_count << log_blocksize
      prop_dict["partition_size"] = str(size)
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

  if not mkfs_output:
    mkfs_output = BuildImageMkfs(
        in_dir, prop_dict, out_file, target_out, fs_config)

  # Update the image (eg filesystem size). This can be different eg if mkfs
  # rounds the requested size down due to alignment.
  prop_dict["image_size"] = common.sparse_img.GetImagePartitionSize(out_file)

  # Check if there's enough headroom space available for ext4 image.
  if "partition_headroom" in prop_dict and fs_type.startswith("ext4"):
    CheckHeadroom(mkfs_output, prop_dict)

  if not fs_spans_partition and verity_image_builder:
    verity_image_builder.PadSparseImage(out_file)

  # Create the verified image if this is to be verified.
  if verity_image_builder:
    verity_image_builder.Build(out_file)


def TryParseFingerprint(glob_dict: dict):
  for (key, val) in glob_dict.items():
    if not key.endswith("_add_hashtree_footer_args") and not key.endswith("_add_hash_footer_args"):
      continue
    for arg in shlex.split(val):
      m = re.match(r"^com\.android\.build\.\w+\.fingerprint:", arg)
      if m is None:
        continue
      fingerprint = arg[len(m.group()):]
      glob_dict["fingerprint"] = fingerprint
      return


def ImagePropFromGlobalDict(glob_dict, mount_point):
  """Build an image property dictionary from the global dictionary.

  Args:
    glob_dict: the global dictionary from the build system.
    mount_point: such as "system", "data" etc.
  """
  d = {}
  TryParseFingerprint(glob_dict)

  # Set fixed timestamp for building the OTA package.
  if "use_fixed_timestamp" in glob_dict:
    d["timestamp"] = FIXED_FILE_TIMESTAMP
  if "build.prop" in glob_dict:
    timestamp = glob_dict["build.prop"].GetProp("ro.build.date.utc")
    if timestamp:
      d["timestamp"] = timestamp

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
      "erofs_default_compressor",
      "erofs_default_compress_hints",
      "erofs_pcluster_size",
      "erofs_blocksize",
      "erofs_share_dup_blocks",
      "erofs_sparse_flag",
      "erofs_use_legacy_compression",
      "squashfs_sparse_flag",
      "system_f2fs_compress",
      "system_f2fs_sldc_flags",
      "f2fs_sparse_flag",
      "f2fs_blocksize",
      "skip_fsck",
      "ext_mkuserimg",
      "avb_enable",
      "avb_avbtool",
      "use_dynamic_partition_size",
      "fingerprint",
  )
  for p in common_props:
    copy_prop(p, p)

  ro_mount_points = set([
      "odm",
      "odm_dlkm",
      "oem",
      "product",
      "system",
      "system_dlkm",
      "system_ext",
      "system_other",
      "vendor",
      "vendor_dlkm",
  ])

  # Tuple layout: (readonly, specific prop, general prop)
  fmt_props = (
      # Generic first, then specific file type.
      (False, "fs_type", "fs_type"),
      (False, "{}_fs_type", "fs_type"),

      # Ordering for these doesn't matter.
      (False, "{}_selinux_fc", "selinux_fc"),
      (False, "{}_size", "partition_size"),
      (True, "avb_{}_add_hashtree_footer_args", "avb_add_hashtree_footer_args"),
      (True, "avb_{}_algorithm", "avb_algorithm"),
      (True, "avb_{}_hashtree_enable", "avb_hashtree_enable"),
      (True, "avb_{}_key_path", "avb_key_path"),
      (True, "avb_{}_salt", "avb_salt"),
      (True, "erofs_use_legacy_compression", "erofs_use_legacy_compression"),
      (True, "ext4_share_dup_blocks", "ext4_share_dup_blocks"),
      (True, "{}_base_fs_file", "base_fs_file"),
      (True, "{}_disable_sparse", "disable_sparse"),
      (True, "{}_erofs_compressor", "erofs_compressor"),
      (True, "{}_erofs_compress_hints", "erofs_compress_hints"),
      (True, "{}_erofs_pcluster_size", "erofs_pcluster_size"),
      (True, "{}_erofs_blocksize", "erofs_blocksize"),
      (True, "{}_erofs_share_dup_blocks", "erofs_share_dup_blocks"),
      (True, "{}_extfs_inode_count", "extfs_inode_count"),
      (True, "{}_f2fs_compress", "f2fs_compress"),
      (True, "{}_f2fs_sldc_flags", "f2fs_sldc_flags"),
      (True, "{}_f2fs_blocksize", "f2fs_block_size"),
      (True, "{}_reserved_size", "partition_reserved_size"),
      (True, "{}_squashfs_block_size", "squashfs_block_size"),
      (True, "{}_squashfs_compressor", "squashfs_compressor"),
      (True, "{}_squashfs_compressor_opt", "squashfs_compressor_opt"),
      (True, "{}_squashfs_disable_4k_align", "squashfs_disable_4k_align"),
      (True, "{}_verity_block_device", "verity_block_device"),
  )

  # Translate prefixed properties into generic ones.
  if mount_point == "data":
    prefix = "userdata"
  else:
    prefix = mount_point

  for readonly, src_prop, dest_prop in fmt_props:
    if readonly and mount_point not in ro_mount_points:
      continue

    if src_prop == "fs_type":
      # This property is legacy and only used on a few partitions. b/202600377
      allowed_partitions = set(["system", "system_other", "data", "oem"])
      if mount_point not in allowed_partitions:
        continue

    if (mount_point == "system_other") and (dest_prop != "partition_size"):
      # Propagate system properties to system_other. They'll get overridden
      # after as needed.
      copy_prop(src_prop.format("system"), dest_prop)

    copy_prop(src_prop.format(prefix), dest_prop)

  # Set prefixed properties that need a default value.
  if mount_point in ro_mount_points:
    prop = "{}_journal_size".format(prefix)
    if not copy_prop(prop, "journal_size"):
      d["journal_size"] = "0"

    prop = "{}_extfs_rsv_pct".format(prefix)
    if not copy_prop(prop, "extfs_rsv_pct"):
      d["extfs_rsv_pct"] = "0"

    d["ro_mount_point"] = "1"

  # Copy partition-specific properties.
  d["mount_point"] = mount_point
  if mount_point == "system":
    copy_prop("system_headroom", "partition_headroom")
    copy_prop("root_dir", "root_dir")
    copy_prop("root_fs_config", "root_fs_config")
  elif mount_point == "data":
    # Copy the generic fs type first, override with specific one if available.
    copy_prop("flash_logical_block_size", "flash_logical_block_size")
    copy_prop("flash_erase_block_size", "flash_erase_block_size")
    copy_prop("needs_casefold", "needs_casefold")
    copy_prop("needs_projid", "needs_projid")
    copy_prop("needs_compress", "needs_compress")
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
  elif mount_point == "vendor_dlkm":
    copy_prop("partition_size", "vendor_dlkm_size")
  elif mount_point == "odm_dlkm":
    copy_prop("partition_size", "odm_dlkm_size")
  elif mount_point == "system_dlkm":
    copy_prop("partition_size", "system_dlkm_size")
  elif mount_point == "product":
    copy_prop("partition_size", "product_size")
  elif mount_point == "system_ext":
    copy_prop("partition_size", "system_ext_size")
  return d


def BuildVBMeta(in_dir, glob_dict, output_path):
  """Creates a VBMeta image.

  It generates the requested VBMeta image. The requested image could be for
  top-level or chained VBMeta image, which is determined based on the name.

  Args:
    output_path: Path to generated vbmeta.img
    partitions: A dict that's keyed by partition names with image paths as
        values. Only valid partition names are accepted, as partitions listed
        in common.AVB_PARTITIONS and custom partitions listed in
        OPTIONS.info_dict.get("avb_custom_images_partition_list")
    name: Name of the VBMeta partition, e.g. 'vbmeta', 'vbmeta_system'.
    needed_partitions: Partitions whose descriptors should be included into the
        generated VBMeta image.

  Returns:
    Path to the created image.

  Raises:
    AssertionError: On invalid input args.
  """
  vbmeta_partitions = common.AVB_PARTITIONS[:]
  name = os.path.basename(output_path).rstrip(".img")
  vbmeta_system = glob_dict.get("avb_vbmeta_system", "").strip()
  vbmeta_vendor = glob_dict.get("avb_vbmeta_vendor", "").strip()
  if "vbmeta_system" in name:
    vbmeta_partitions = vbmeta_system.split()
  elif "vbmeta_vendor" in name:
    vbmeta_partitions = vbmeta_vendor.split()
  else:
    if vbmeta_system:
      vbmeta_partitions = [
          item for item in vbmeta_partitions
          if item not in vbmeta_system.split()]
      vbmeta_partitions.append("vbmeta_system")

    if vbmeta_vendor:
      vbmeta_partitions = [
          item for item in vbmeta_partitions
          if item not in vbmeta_vendor.split()]
      vbmeta_partitions.append("vbmeta_vendor")

  partitions = {part: os.path.join(in_dir, part + ".img")
                for part in vbmeta_partitions}
  partitions = {part: path for (part, path) in partitions.items() if os.path.exists(path)}
  common.BuildVBMeta(output_path, partitions, name, vbmeta_partitions)


def BuildImageOrVBMeta(input_directory, target_out, glob_dict, image_properties, out_file):
  try:
    if "vbmeta" in os.path.basename(out_file):
      OPTIONS.info_dict = glob_dict
      BuildVBMeta(input_directory, glob_dict, out_file)
    else:
      BuildImage(input_directory, image_properties, out_file, target_out)
  except:
    logger.error("Failed to build %s from %s", out_file, input_directory)
    raise


def CopyInputDirectory(src, dst, filter_file):
  with open(filter_file, 'r') as f:
    for line in f:
      line = line.strip()
      if not line:
        return
      if line != os.path.normpath(line):
        sys.exit(f"{line}: not normalized")
      if line.startswith("../") or line.startswith('/'):
        sys.exit(f"{line}: escapes staging directory by starting with ../ or /")
      full_src = os.path.join(src, line)
      full_dst = os.path.join(dst, line)
      if os.path.isdir(full_src):
        os.makedirs(full_dst, exist_ok=True)
      else:
        os.makedirs(os.path.dirname(full_dst), exist_ok=True)
        os.link(full_src, full_dst, follow_symlinks=False)


def main(argv):
  parser = argparse.ArgumentParser(
    description="Builds output_image from the given input_directory and properties_file, and "
    "writes the image to target_output_directory.")
  parser.add_argument("--input-directory-filter-file",
    help="the path to a file that contains a list of all files in the input_directory. If this "
    "option is provided, all files under the input_directory that are not listed in this file will "
    "be deleted before building the image. This is to work around the fact that building a module "
    "will install in by default, so there could be files in the input_directory that are not "
    "actually supposed to be part of the partition. The paths in this file must be relative to "
    "input_directory.")
  parser.add_argument("input_directory",
    help="the staging directory to be converted to an image file")
  parser.add_argument("properties_file",
    help="a file containing the 'global dictionary' of properties that affect how the image is "
    "built")
  parser.add_argument("out_file",
    help="the output file to write")
  parser.add_argument("target_out",
    help="the path to $(TARGET_OUT). Certain tools will use this to look through multiple staging "
    "directories for fs config files.")
  args = parser.parse_args()

  common.InitLogging()

  glob_dict = LoadGlobalDict(args.properties_file)
  if "mount_point" in glob_dict:
    # The caller knows the mount point and provides a dictionary needed by
    # BuildImage().
    image_properties = glob_dict
  else:
    image_filename = os.path.basename(args.out_file)
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
    elif image_filename == "vendor_dlkm.img":
      mount_point = "vendor_dlkm"
    elif image_filename == "odm_dlkm.img":
      mount_point = "odm_dlkm"
    elif image_filename == "system_dlkm.img":
      mount_point = "system_dlkm"
    elif image_filename == "oem.img":
      mount_point = "oem"
    elif image_filename == "product.img":
      mount_point = "product"
    elif image_filename == "system_ext.img":
      mount_point = "system_ext"
    elif "vbmeta" in image_filename:
      mount_point = "vbmeta"
    else:
      logger.error("Unknown image file name %s", image_filename)
      sys.exit(1)

    if "vbmeta" != mount_point:
      image_properties = ImagePropFromGlobalDict(glob_dict, mount_point)

  if args.input_directory_filter_file and not os.environ.get("BUILD_BROKEN_INCORRECT_PARTITION_IMAGES"):
    with tempfile.TemporaryDirectory(dir=os.path.dirname(args.input_directory)) as new_input_directory:
      CopyInputDirectory(args.input_directory, new_input_directory, args.input_directory_filter_file)
      BuildImageOrVBMeta(new_input_directory, args.target_out, glob_dict, image_properties, args.out_file)
  else:
    BuildImageOrVBMeta(args.input_directory, args.target_out, glob_dict, image_properties, args.out_file)


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  finally:
    common.Cleanup()
