#!/usr/bin/env python
#
# Copyright (C) 2014 The Android Open Source Project
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
Given a target-files zipfile that does not contain images (ie, does
not have an IMAGES/ top-level subdirectory), produce the images and
add them to the zipfile.

Usage:  add_img_to_target_files [flag] target_files

  -a  (--add_missing)
      Build and add missing images to "IMAGES/". If this option is
      not specified, this script will simply exit when "IMAGES/"
      directory exists in the target file.

  -r  (--rebuild_recovery)
      Rebuild the recovery patch and write it to the system image. Only
      meaningful when system image needs to be rebuilt and there're separate
      boot / recovery images.

  --replace_verity_private_key
      Replace the private key used for verity signing. (same as the option
      in sign_target_files_apks)

  --replace_verity_public_key
       Replace the certificate (public key) used for verity verification. (same
       as the option in sign_target_files_apks)

  --is_signing
      Skip building & adding the images for "userdata" and "cache" if we
      are signing the target files.

  --avb-resolve-rollback-index-location-conflict
      If provided, resolve the conflict AVB rollback index location when
      necessary.
"""

from __future__ import print_function

import avbtool
import datetime
import logging
import os
import shlex
import shutil
import stat
import sys
import uuid
import tempfile
import zipfile

import build_image
import build_super_image
import common
import verity_utils
import ota_metadata_pb2
import rangelib
import sparse_img
from concurrent.futures import ThreadPoolExecutor
from apex_utils import GetApexInfoFromTargetFiles
from common import ZipDelete, PARTITIONS_WITH_CARE_MAP, ExternalError, RunAndCheckOutput, IsSparseImage, MakeTempFile, ZipWrite
from build_image import FIXED_FILE_TIMESTAMP

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
OPTIONS.add_missing = False
OPTIONS.rebuild_recovery = False
OPTIONS.replace_updated_files_list = []
OPTIONS.is_signing = False
OPTIONS.avb_resolve_rollback_index_location_conflict = False


def ParseAvbFooter(img_path) -> avbtool.AvbFooter:
  with open(img_path, 'rb') as fp:
    fp.seek(-avbtool.AvbFooter.SIZE, os.SEEK_END)
    data = fp.read(avbtool.AvbFooter.SIZE)
    return avbtool.AvbFooter(data)


def GetCareMap(which, imgname):
  """Returns the care_map string for the given partition.

  Args:
    which: The partition name, must be listed in PARTITIONS_WITH_CARE_MAP.
    imgname: The filename of the image.

  Returns:
    (which, care_map_ranges): care_map_ranges is the raw string of the care_map
    RangeSet; or None.
  """
  assert which in PARTITIONS_WITH_CARE_MAP

  is_sparse_img = IsSparseImage(imgname)
  unsparsed_image_size = os.path.getsize(imgname)

  # A verified image contains original image + hash tree data + FEC data
  # + AVB footer, all concatenated together. The caremap specifies a range
  # of blocks that update_verifier should read on top of dm-verity device
  # to verify correctness of OTA updates. When reading off of dm-verity device,
  # the hashtree and FEC part of image isn't available. So caremap should
  # only contain the original image blocks.
  try:
    avbfooter = None
    if is_sparse_img:
      with tempfile.NamedTemporaryFile() as tmpfile:
        img = sparse_img.SparseImage(imgname)
        unsparsed_image_size = img.total_blocks * img.blocksize
        for data in img.ReadBlocks(img.total_blocks - 1, 1):
          tmpfile.write(data)
        tmpfile.flush()
        avbfooter = ParseAvbFooter(tmpfile.name)
    else:
      avbfooter = ParseAvbFooter(imgname)
  except LookupError as e:
    logger.warning(
        "Failed to parse avbfooter for partition %s image %s, %s", which, imgname, e)
    return None

  image_size = avbfooter.original_image_size
  assert image_size < unsparsed_image_size, f"AVB footer's original image size {image_size} is larger than or equal to image size on disk {unsparsed_image_size}, this can't happen because a verified image = original image + hash tree data + FEC data + avbfooter."
  assert image_size > 0

  image_blocks = int(image_size) // 4096 - 1
  # It's OK for image_blocks to be 0, because care map ranges are inclusive.
  # So 0-0 means "just block 0", which is valid.
  assert image_blocks >= 0, "blocks for {} must be non-negative, image size: {}".format(
      which, image_size)

  # For sparse images, we will only check the blocks that are listed in the care
  # map, i.e. the ones with meaningful data.
  if is_sparse_img:
    simg = sparse_img.SparseImage(imgname)
    care_map_ranges = simg.care_map.intersect(
        rangelib.RangeSet("0-{}".format(image_blocks)))

  # Otherwise for non-sparse images, we read all the blocks in the filesystem
  # image.
  else:
    care_map_ranges = rangelib.RangeSet("0-{}".format(image_blocks))

  return [which, care_map_ranges.to_string_raw()]


def AddCareMapForAbOta(output_file, ab_partitions, image_paths):
  """Generates and adds care_map.pb for a/b partition that has care_map.

  Args:
    output_file: The output zip file (needs to be already open),
        or file path to write care_map.pb.
    ab_partitions: The list of A/B partitions.
    image_paths: A map from the partition name to the image path.
  """
  if not output_file:
    raise ExternalError('Expected output_file for AddCareMapForAbOta')

  care_map_list = []
  for partition in ab_partitions:
    partition = partition.strip()
    if partition not in PARTITIONS_WITH_CARE_MAP:
      continue

    verity_block_device = "{}_verity_block_device".format(partition)
    avb_hashtree_enable = "avb_{}_hashtree_enable".format(partition)
    if (verity_block_device in OPTIONS.info_dict or
            OPTIONS.info_dict.get(avb_hashtree_enable) == "true"):
      if partition not in image_paths:
        logger.warning('Potential partition with care_map missing from images: %s',
                       partition)
        continue
      image_path = image_paths[partition]
      if not os.path.exists(image_path):
        raise ExternalError('Expected image at path {}'.format(image_path))

      care_map = GetCareMap(partition, image_path)
      if not care_map:
        continue
      care_map_list += care_map

      # adds fingerprint field to the care_map
      # TODO(xunchang) revisit the fingerprint calculation for care_map.
      partition_props = OPTIONS.info_dict.get(partition + ".build.prop")
      prop_name_list = ["ro.{}.build.fingerprint".format(partition),
                        "ro.{}.build.thumbprint".format(partition)]

      present_props = [x for x in prop_name_list if
                       partition_props and partition_props.GetProp(x)]
      if not present_props:
        logger.warning(
            "fingerprint is not present for partition %s", partition)
        property_id, fingerprint = "unknown", "unknown"
      else:
        property_id = present_props[0]
        fingerprint = partition_props.GetProp(property_id)
      care_map_list += [property_id, fingerprint]

  if not care_map_list:
    return

  # Converts the list into proto buf message by calling care_map_generator; and
  # writes the result to a temp file.
  temp_care_map_text = MakeTempFile(prefix="caremap_text-",
                                           suffix=".txt")
  with open(temp_care_map_text, 'w') as text_file:
    text_file.write('\n'.join(care_map_list))

  temp_care_map = MakeTempFile(prefix="caremap-", suffix=".pb")
  care_map_gen_cmd = ["care_map_generator", temp_care_map_text, temp_care_map]
  RunAndCheckOutput(care_map_gen_cmd)

  if not isinstance(output_file, zipfile.ZipFile):
    shutil.copy(temp_care_map, output_file)
    return
  # output_file is a zip file
  care_map_path = "META/care_map.pb"
  if care_map_path in output_file.namelist():
    # Copy the temp file into the OPTIONS.input_tmp dir and update the
    # replace_updated_files_list used by add_img_to_target_files
    if not OPTIONS.replace_updated_files_list:
      OPTIONS.replace_updated_files_list = []
    shutil.copy(temp_care_map, os.path.join(OPTIONS.input_tmp, care_map_path))
    OPTIONS.replace_updated_files_list.append(care_map_path)
  else:
    ZipWrite(output_file, temp_care_map, arcname=care_map_path)


class OutputFile(object):
  """A helper class to write a generated file to the given dir or zip.

  When generating images, we want the outputs to go into the given zip file, or
  the given dir.

  Attributes:
    name: The name of the output file, regardless of the final destination.
  """

  def __init__(self, output_zip, input_dir, *args):
    # We write the intermediate output file under the given input_dir, even if
    # the final destination is a zip archive.
    self.name = os.path.join(input_dir, *args)
    self._output_zip = output_zip
    if self._output_zip:
      self._zip_name = os.path.join(*args)

  def Write(self, compress_type=None):
    if self._output_zip:
      common.ZipWrite(self._output_zip, self.name,
                      self._zip_name, compress_type=compress_type)


def AddSystem(output_zip, recovery_img=None, boot_img=None):
  """Turn the contents of SYSTEM into a system image and store it in
  output_zip. Returns the name of the system image file."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "system.img")
  if os.path.exists(img.name):
    logger.info("system.img already exists; no need to rebuild...")
    return img.name

  def output_sink(fn, data):
    output_file = os.path.join(OPTIONS.input_tmp, "SYSTEM", fn)
    with open(output_file, "wb") as ofile:
      ofile.write(data)

    if output_zip:
      arc_name = "SYSTEM/" + fn
      if arc_name in output_zip.namelist():
        OPTIONS.replace_updated_files_list.append(arc_name)
      else:
        common.ZipWrite(output_zip, output_file, arc_name)

  board_uses_vendorimage = OPTIONS.info_dict.get(
      "board_uses_vendorimage") == "true"

  if (OPTIONS.rebuild_recovery and not board_uses_vendorimage and
          recovery_img is not None and boot_img is not None):
    logger.info("Building new recovery patch on system at system/vendor")
    common.MakeRecoveryPatch(OPTIONS.input_tmp, output_sink, recovery_img,
                             boot_img, info_dict=OPTIONS.info_dict)

  block_list = OutputFile(output_zip, OPTIONS.input_tmp,
                          "IMAGES", "system.map")
  CreateImage(OPTIONS.input_tmp, OPTIONS.info_dict, "system", img,
              block_list=block_list)
  return img.name


def AddSystemOther(output_zip):
  """Turn the contents of SYSTEM_OTHER into a system_other image
  and store it in output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "system_other.img")
  if os.path.exists(img.name):
    logger.info("system_other.img already exists; no need to rebuild...")
    return

  CreateImage(OPTIONS.input_tmp, OPTIONS.info_dict, "system_other", img)


def AddVendor(output_zip, recovery_img=None, boot_img=None):
  """Turn the contents of VENDOR into a vendor image and store in it
  output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "vendor.img")
  if os.path.exists(img.name):
    logger.info("vendor.img already exists; no need to rebuild...")
    return img.name

  def output_sink(fn, data):
    output_file = os.path.join(OPTIONS.input_tmp, "VENDOR", fn)
    with open(output_file, "wb") as ofile:
      ofile.write(data)

    if output_zip:
      arc_name = "VENDOR/" + fn
      if arc_name in output_zip.namelist():
        OPTIONS.replace_updated_files_list.append(arc_name)
      else:
        common.ZipWrite(output_zip, output_file, arc_name)

  board_uses_vendorimage = OPTIONS.info_dict.get(
      "board_uses_vendorimage") == "true"

  if (OPTIONS.rebuild_recovery and board_uses_vendorimage and
          recovery_img is not None and boot_img is not None):
    logger.info("Building new recovery patch on vendor")
    common.MakeRecoveryPatch(OPTIONS.input_tmp, output_sink, recovery_img,
                             boot_img, info_dict=OPTIONS.info_dict)

  block_list = OutputFile(output_zip, OPTIONS.input_tmp,
                          "IMAGES", "vendor.map")
  CreateImage(OPTIONS.input_tmp, OPTIONS.info_dict, "vendor", img,
              block_list=block_list)
  return img.name


def AddProduct(output_zip):
  """Turn the contents of PRODUCT into a product image and store it in
  output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "product.img")
  if os.path.exists(img.name):
    logger.info("product.img already exists; no need to rebuild...")
    return img.name

  block_list = OutputFile(
      output_zip, OPTIONS.input_tmp, "IMAGES", "product.map")
  CreateImage(
      OPTIONS.input_tmp, OPTIONS.info_dict, "product", img,
      block_list=block_list)
  return img.name


def AddSystemExt(output_zip):
  """Turn the contents of SYSTEM_EXT into a system_ext image and store it in
  output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES",
                   "system_ext.img")
  if os.path.exists(img.name):
    logger.info("system_ext.img already exists; no need to rebuild...")
    return img.name

  block_list = OutputFile(
      output_zip, OPTIONS.input_tmp, "IMAGES", "system_ext.map")
  CreateImage(
      OPTIONS.input_tmp, OPTIONS.info_dict, "system_ext", img,
      block_list=block_list)
  return img.name


def AddOdm(output_zip):
  """Turn the contents of ODM into an odm image and store it in output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "odm.img")
  if os.path.exists(img.name):
    logger.info("odm.img already exists; no need to rebuild...")
    return img.name

  block_list = OutputFile(
      output_zip, OPTIONS.input_tmp, "IMAGES", "odm.map")
  CreateImage(
      OPTIONS.input_tmp, OPTIONS.info_dict, "odm", img,
      block_list=block_list)
  return img.name


def AddVendorDlkm(output_zip):
  """Turn the contents of VENDOR_DLKM into an vendor_dlkm image and store it in output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "vendor_dlkm.img")
  if os.path.exists(img.name):
    logger.info("vendor_dlkm.img already exists; no need to rebuild...")
    return img.name

  block_list = OutputFile(
      output_zip, OPTIONS.input_tmp, "IMAGES", "vendor_dlkm.map")
  CreateImage(
      OPTIONS.input_tmp, OPTIONS.info_dict, "vendor_dlkm", img,
      block_list=block_list)
  return img.name


def AddOdmDlkm(output_zip):
  """Turn the contents of OdmDlkm into an odm_dlkm image and store it in output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "odm_dlkm.img")
  if os.path.exists(img.name):
    logger.info("odm_dlkm.img already exists; no need to rebuild...")
    return img.name

  block_list = OutputFile(
      output_zip, OPTIONS.input_tmp, "IMAGES", "odm_dlkm.map")
  CreateImage(
      OPTIONS.input_tmp, OPTIONS.info_dict, "odm_dlkm", img,
      block_list=block_list)
  return img.name


def AddSystemDlkm(output_zip):
  """Turn the contents of SystemDlkm into an system_dlkm image and store it in output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "system_dlkm.img")
  if os.path.exists(img.name):
    logger.info("system_dlkm.img already exists; no need to rebuild...")
    return img.name

  block_list = OutputFile(
      output_zip, OPTIONS.input_tmp, "IMAGES", "system_dlkm.map")
  CreateImage(
      OPTIONS.input_tmp, OPTIONS.info_dict, "system_dlkm", img,
      block_list=block_list)
  return img.name


def AddDtbo(output_zip):
  """Adds the DTBO image.

  Uses the image under IMAGES/ if it already exists. Otherwise looks for the
  image under PREBUILT_IMAGES/, signs it as needed, and returns the image name.
  """
  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "dtbo.img")
  if os.path.exists(img.name):
    logger.info("dtbo.img already exists; no need to rebuild...")
    return img.name

  dtbo_prebuilt_path = os.path.join(
      OPTIONS.input_tmp, "PREBUILT_IMAGES", "dtbo.img")
  assert os.path.exists(dtbo_prebuilt_path)
  shutil.copy(dtbo_prebuilt_path, img.name)

  # AVB-sign the image as needed.
  if OPTIONS.info_dict.get("avb_enable") == "true":
    # Signing requires +w
    os.chmod(img.name, os.stat(img.name).st_mode | stat.S_IWUSR)

    avbtool = OPTIONS.info_dict["avb_avbtool"]
    part_size = OPTIONS.info_dict["dtbo_size"]
    # The AVB hash footer will be replaced if already present.
    cmd = [avbtool, "add_hash_footer", "--image", img.name,
           "--partition_size", str(part_size), "--partition_name", "dtbo"]
    common.AppendAVBSigningArgs(cmd, "dtbo")
    args = OPTIONS.info_dict.get("avb_dtbo_add_hash_footer_args")
    if args and args.strip():
      cmd.extend(shlex.split(args))
    common.RunAndCheckOutput(cmd)

  img.Write()
  return img.name


def AddPvmfw(output_zip):
  """Adds the pvmfw image.

  Uses the image under IMAGES/ if it already exists. Otherwise looks for the
  image under PREBUILT_IMAGES/, signs it as needed, and returns the image name.
  """
  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "pvmfw.img")
  if os.path.exists(img.name):
    logger.info("pvmfw.img already exists; no need to rebuild...")
    return img.name

  pvmfw_prebuilt_path = os.path.join(
      OPTIONS.input_tmp, "PREBUILT_IMAGES", "pvmfw.img")
  assert os.path.exists(pvmfw_prebuilt_path)
  shutil.copy(pvmfw_prebuilt_path, img.name)

  # AVB-sign the image as needed.
  if OPTIONS.info_dict.get("avb_enable") == "true":
    # Signing requires +w
    os.chmod(img.name, os.stat(img.name).st_mode | stat.S_IWUSR)

    avbtool = OPTIONS.info_dict["avb_avbtool"]
    part_size = OPTIONS.info_dict["pvmfw_size"]
    # The AVB hash footer will be replaced if already present.
    cmd = [avbtool, "add_hash_footer", "--image", img.name,
           "--partition_size", str(part_size), "--partition_name", "pvmfw"]
    common.AppendAVBSigningArgs(cmd, "pvmfw")
    args = OPTIONS.info_dict.get("avb_pvmfw_add_hash_footer_args")
    if args and args.strip():
      cmd.extend(shlex.split(args))
    common.RunAndCheckOutput(cmd)

  img.Write()
  return img.name


def AddCustomImages(output_zip, partition_name, image_list):
  """Adds and signs avb custom images as needed in IMAGES/.

  Args:
    output_zip: The output zip file (needs to be already open), or None to
        write images to OPTIONS.input_tmp/.
    partition_name: The custom image partition name.
    image_list: The image list of the custom image partition.

  Uses the image under IMAGES/ if it already exists. Otherwise looks for the
  image under PREBUILT_IMAGES/, signs it as needed, and returns the image name.

  Raises:
    AssertionError: If image can't be found.
  """

  builder = None
  key_path = OPTIONS.info_dict.get("avb_{}_key_path".format(partition_name))
  if key_path is not None:
    algorithm = OPTIONS.info_dict.get("avb_{}_algorithm".format(partition_name))
    extra_args = OPTIONS.info_dict.get(
        "avb_{}_add_hashtree_footer_args".format(partition_name))
    partition_size = OPTIONS.info_dict.get(
        "avb_{}_partition_size".format(partition_name))

    builder = verity_utils.CreateCustomImageBuilder(
        OPTIONS.info_dict, partition_name, partition_size,
        key_path, algorithm, extra_args)

  for img_name in image_list:
    custom_image = OutputFile(
        output_zip, OPTIONS.input_tmp, "IMAGES", img_name)
    if os.path.exists(custom_image.name):
      continue

    custom_image_prebuilt_path = os.path.join(
        OPTIONS.input_tmp, "PREBUILT_IMAGES", img_name)
    assert os.path.exists(custom_image_prebuilt_path), \
        "Failed to find %s at %s" % (img_name, custom_image_prebuilt_path)

    shutil.copy(custom_image_prebuilt_path, custom_image.name)

    if builder is not None:
      builder.Build(custom_image.name)

    custom_image.Write()

  default = os.path.join(OPTIONS.input_tmp, "IMAGES", partition_name + ".img")
  assert os.path.exists(default), \
      "There should be one %s.img" % (partition_name)
  return default


def CreateImage(input_dir, info_dict, what, output_file, block_list=None):
  logger.info("creating %s.img...", what)

  image_props = build_image.ImagePropFromGlobalDict(info_dict, what)
  image_props["timestamp"] = FIXED_FILE_TIMESTAMP

  if what == "system":
    fs_config_prefix = ""
  else:
    fs_config_prefix = what + "_"

  fs_config = os.path.join(
      input_dir, "META/" + fs_config_prefix + "filesystem_config.txt")
  if not os.path.exists(fs_config):
    fs_config = None

  # Override values loaded from info_dict.
  if fs_config:
    image_props["fs_config"] = fs_config
  if block_list:
    image_props["block_list"] = block_list.name

  build_image.BuildImage(
      os.path.join(input_dir, what.upper()), image_props, output_file.name)

  output_file.Write()
  if block_list:
    block_list.Write()

  # Set the '_image_size' for given image size.
  is_verity_partition = "verity_block_device" in image_props
  verity_supported = (image_props.get("avb_enable") == "true")
  is_avb_enable = image_props.get("avb_hashtree_enable") == "true"
  if verity_supported and (is_verity_partition or is_avb_enable):
    image_size = image_props.get("image_size")
    if image_size:
      image_size_key = what + "_image_size"
      info_dict[image_size_key] = int(image_size)

  use_dynamic_size = (
      info_dict.get("use_dynamic_partition_size") == "true" and
      what in shlex.split(info_dict.get("dynamic_partition_list", "").strip()))
  if use_dynamic_size:
    info_dict.update(build_image.GlobalDictFromImageProp(image_props, what))


def AddUserdata(output_zip):
  """Create a userdata image and store it in output_zip.

  In most case we just create and store an empty userdata.img;
  But the invoker can also request to create userdata.img with real
  data from the target files, by setting "userdata_img_with_data=true"
  in OPTIONS.info_dict.
  """

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "userdata.img")
  if os.path.exists(img.name):
    logger.info("userdata.img already exists; no need to rebuild...")
    return

  # Skip userdata.img if no size.
  image_props = build_image.ImagePropFromGlobalDict(OPTIONS.info_dict, "data")
  if not image_props.get("partition_size"):
    return

  logger.info("creating userdata.img...")

  image_props["timestamp"] = FIXED_FILE_TIMESTAMP

  if OPTIONS.info_dict.get("userdata_img_with_data") == "true":
    user_dir = os.path.join(OPTIONS.input_tmp, "DATA")
  else:
    user_dir = common.MakeTempDir()

  build_image.BuildImage(user_dir, image_props, img.name)

  common.CheckSize(img.name, "userdata.img", OPTIONS.info_dict)
  # Always use compression for useradata image.
  # As it's likely huge and consist of lots of 0s.
  img.Write(zipfile.ZIP_DEFLATED)


def AddVBMeta(output_zip, partitions, name, needed_partitions):
  """Creates a VBMeta image and stores it in output_zip.

  It generates the requested VBMeta image. The requested image could be for
  top-level or chained VBMeta image, which is determined based on the name.

  Args:
    output_zip: The output zip file, which needs to be already open.
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
  assert needed_partitions, "Needed partitions must be specified"

  img = OutputFile(
      output_zip, OPTIONS.input_tmp, "IMAGES", "{}.img".format(name))
  if os.path.exists(img.name):
    logger.info("%s.img already exists; not rebuilding...", name)
    return img.name

  common.BuildVBMeta(img.name, partitions, name, needed_partitions,
                     OPTIONS.avb_resolve_rollback_index_location_conflict)
  img.Write()
  return img.name


def AddCache(output_zip):
  """Create an empty cache image and store it in output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "cache.img")
  if os.path.exists(img.name):
    logger.info("cache.img already exists; no need to rebuild...")
    return

  image_props = build_image.ImagePropFromGlobalDict(OPTIONS.info_dict, "cache")
  # The build system has to explicitly request for cache.img.
  if "fs_type" not in image_props:
    return

  logger.info("creating cache.img...")

  image_props["timestamp"] = FIXED_FILE_TIMESTAMP

  user_dir = common.MakeTempDir()
  build_image.BuildImage(user_dir, image_props, img.name)

  common.CheckSize(img.name, "cache.img", OPTIONS.info_dict)
  img.Write()


def CheckAbOtaImages(output_zip, ab_partitions):
  """Checks that all the listed A/B partitions have their images available.

  The images need to be available under IMAGES/ or RADIO/, with the former takes
  a priority.

  Args:
    output_zip: The output zip file (needs to be already open), or None to
        find images in OPTIONS.input_tmp/.
    ab_partitions: The list of A/B partitions.

  Raises:
    AssertionError: If it can't find an image.
  """
  for partition in ab_partitions:
    img_name = partition + ".img"

    # Assert that the image is present under IMAGES/ now.
    if output_zip:
      # Zip spec says: All slashes MUST be forward slashes.
      images_path = "IMAGES/" + img_name
      radio_path = "RADIO/" + img_name
      available = (images_path in output_zip.namelist() or
                   radio_path in output_zip.namelist())
    else:
      images_path = os.path.join(OPTIONS.input_tmp, "IMAGES", img_name)
      radio_path = os.path.join(OPTIONS.input_tmp, "RADIO", img_name)
      available = os.path.exists(images_path) or os.path.exists(radio_path)

    assert available, "Failed to find " + img_name


def AddPackRadioImages(output_zip, images):
  """Copies images listed in META/pack_radioimages.txt from RADIO/ to IMAGES/.

  Args:
    output_zip: The output zip file (needs to be already open), or None to
        write images to OPTIONS.input_tmp/.
    images: A list of image names.

  Raises:
    AssertionError: If a listed image can't be found.
  """
  for image in images:
    img_name = image.strip()
    _, ext = os.path.splitext(img_name)
    if not ext:
      img_name += ".img"

    prebuilt_path = os.path.join(OPTIONS.input_tmp, "IMAGES", img_name)
    if os.path.exists(prebuilt_path):
      logger.info("%s already exists, no need to overwrite...", img_name)
      continue

    img_radio_path = os.path.join(OPTIONS.input_tmp, "RADIO", img_name)
    assert os.path.exists(img_radio_path), \
        "Failed to find %s at %s" % (img_name, img_radio_path)

    if output_zip:
      common.ZipWrite(output_zip, img_radio_path, "IMAGES/" + img_name)
    else:
      shutil.copy(img_radio_path, prebuilt_path)


def AddSuperEmpty(output_zip):
  """Create a super_empty.img and store it in output_zip."""

  img = OutputFile(output_zip, OPTIONS.input_tmp, "IMAGES", "super_empty.img")
  if os.path.exists(img.name):
    logger.info("super_empty.img already exists; no need to rebuild...")
    return
  build_super_image.BuildSuperImage(OPTIONS.info_dict, img.name)
  img.Write()


def AddSuperSplit(output_zip):
  """Create split super_*.img and store it in output_zip."""

  outdir = os.path.join(OPTIONS.input_tmp, "OTA")
  built = build_super_image.BuildSuperImage(OPTIONS.input_tmp, outdir)

  if built:
    for dev in OPTIONS.info_dict['super_block_devices'].strip().split():
      img = OutputFile(output_zip, OPTIONS.input_tmp, "OTA",
                       "super_" + dev + ".img")
      img.Write()


def ReplaceUpdatedFiles(zip_filename, files_list):
  """Updates all the ZIP entries listed in files_list.

  For now the list includes META/care_map.pb, and the related files under
  SYSTEM/ after rebuilding recovery.
  """
  common.ZipDelete(zip_filename, files_list)
  output_zip = zipfile.ZipFile(zip_filename, "a",
                               compression=zipfile.ZIP_DEFLATED,
                               allowZip64=True)
  for item in files_list:
    file_path = os.path.join(OPTIONS.input_tmp, item)
    assert os.path.exists(file_path)
    common.ZipWrite(output_zip, file_path, arcname=item)
  common.ZipClose(output_zip)


def HasPartition(partition_name):
  """Determines if the target files archive should build a given partition."""

  return ((os.path.isdir(
      os.path.join(OPTIONS.input_tmp, partition_name.upper())) and
      OPTIONS.info_dict.get(
      "building_{}_image".format(partition_name)) == "true") or
      os.path.exists(
      os.path.join(OPTIONS.input_tmp, "IMAGES",
                   "{}.img".format(partition_name))))


def AddApexInfo(output_zip):
  apex_infos = GetApexInfoFromTargetFiles(OPTIONS.input_tmp)
  apex_metadata_proto = ota_metadata_pb2.ApexMetadata()
  apex_metadata_proto.apex_info.extend(apex_infos)
  apex_info_bytes = apex_metadata_proto.SerializeToString()

  output_file = os.path.join(OPTIONS.input_tmp, "META", "apex_info.pb")
  with open(output_file, "wb") as ofile:
    ofile.write(apex_info_bytes)
  if output_zip:
    arc_name = "META/apex_info.pb"
    if arc_name in output_zip.namelist():
      OPTIONS.replace_updated_files_list.append(arc_name)
    else:
      common.ZipWrite(output_zip, output_file, arc_name)


def AddVbmetaDigest(output_zip):
  """Write the vbmeta digest to the output dir and zipfile."""

  # Calculate the vbmeta digest and put the result in to META/
  boot_images = OPTIONS.info_dict.get("boot_images")
  # Disable the digest calculation if the target_file is used as a container
  # for boot images. A boot container might contain boot-5.4.img, boot-5.10.img
  # etc., instead of just a boot.img and will fail in vbmeta digest calculation.
  boot_container = boot_images and (
      len(boot_images.split()) >= 2 or boot_images.split()[0] != 'boot.img')
  if (OPTIONS.info_dict.get("avb_enable") == "true" and not boot_container and
          OPTIONS.info_dict.get("avb_building_vbmeta_image") == "true"):
    avbtool = OPTIONS.info_dict["avb_avbtool"]
    digest = verity_utils.CalculateVbmetaDigest(OPTIONS.input_tmp, avbtool)
    vbmeta_digest_txt = os.path.join(OPTIONS.input_tmp, "META",
                                     "vbmeta_digest.txt")
    with open(vbmeta_digest_txt, 'w') as f:
      f.write(digest)
    # writes to the output zipfile
    if output_zip:
      arc_name = "META/vbmeta_digest.txt"
      if arc_name in output_zip.namelist():
        OPTIONS.replace_updated_files_list.append(arc_name)
      else:
        common.ZipWriteStr(output_zip, arc_name, digest)


def AddImagesToTargetFiles(filename):
  """Creates and adds images (boot/recovery/system/...) to a target_files.zip.

  It works with either a zip file (zip mode), or a directory that contains the
  files to be packed into a target_files.zip (dir mode). The latter is used when
  being called from build/make/core/Makefile.

  The images will be created under IMAGES/ in the input target_files.zip.

  Args:
    filename: the target_files.zip, or the zip root directory.
  """
  if os.path.isdir(filename):
    OPTIONS.input_tmp = os.path.abspath(filename)
  else:
    OPTIONS.input_tmp = common.UnzipTemp(filename)

  if not OPTIONS.add_missing:
    if os.path.isdir(os.path.join(OPTIONS.input_tmp, "IMAGES")):
      logger.warning("target_files appears to already contain images.")
      sys.exit(1)

  OPTIONS.info_dict = common.LoadInfoDict(OPTIONS.input_tmp, repacking=True)

  has_recovery = OPTIONS.info_dict.get("no_recovery") != "true"
  has_boot = OPTIONS.info_dict.get("no_boot") != "true"
  has_init_boot = OPTIONS.info_dict.get("init_boot") == "true"
  has_vendor_boot = OPTIONS.info_dict.get("vendor_boot") == "true"
  has_vendor_kernel_boot = OPTIONS.info_dict.get(
      "vendor_kernel_boot") == "true"

  # {vendor,odm,product,system_ext,vendor_dlkm,odm_dlkm, system_dlkm, system, system_other}.img
  # can be built from source, or  dropped into target_files.zip as a prebuilt blob.
  has_vendor = HasPartition("vendor")
  has_odm = HasPartition("odm")
  has_vendor_dlkm = HasPartition("vendor_dlkm")
  has_odm_dlkm = HasPartition("odm_dlkm")
  has_system_dlkm = HasPartition("system_dlkm")
  has_product = HasPartition("product")
  has_system_ext = HasPartition("system_ext")
  has_system = HasPartition("system")
  has_system_other = HasPartition("system_other")
  has_userdata = OPTIONS.info_dict.get("building_userdata_image") == "true"
  has_cache = OPTIONS.info_dict.get("building_cache_image") == "true"

  # Set up the output destination. It writes to the given directory for dir
  # mode; otherwise appends to the given ZIP.
  if os.path.isdir(filename):
    output_zip = None
  else:
    output_zip = zipfile.ZipFile(filename, "a",
                                 compression=zipfile.ZIP_DEFLATED,
                                 allowZip64=True)

  # Always make input_tmp/IMAGES available, since we may stage boot / recovery
  # images there even under zip mode. The directory will be cleaned up as part
  # of OPTIONS.input_tmp.
  images_dir = os.path.join(OPTIONS.input_tmp, "IMAGES")
  if not os.path.isdir(images_dir):
    os.makedirs(images_dir)

  # A map between partition names and their paths, which could be used when
  # generating AVB vbmeta image.
  partitions = {}

  def banner(s):
    logger.info("\n\n++++ %s  ++++\n\n", s)

  boot_image = None
  if has_boot:
    banner("boot")
    boot_images = OPTIONS.info_dict.get("boot_images")
    if boot_images is None:
      boot_images = "boot.img"
    for index, b in enumerate(boot_images.split()):
      # common.GetBootableImage() returns the image directly if present.
      boot_image = common.GetBootableImage(
          "IMAGES/" + b, b, OPTIONS.input_tmp, "BOOT")
      # boot.img may be unavailable in some targets (e.g. aosp_arm64).
      if boot_image:
        boot_image_path = os.path.join(OPTIONS.input_tmp, "IMAGES", b)
        # Although multiple boot images can be generated, include the image
        # descriptor of only the first boot image in vbmeta
        if index == 0:
          partitions['boot'] = boot_image_path
        if not os.path.exists(boot_image_path):
          boot_image.WriteToDir(OPTIONS.input_tmp)
          if output_zip:
            boot_image.AddToZip(output_zip)

  if has_init_boot:
    banner("init_boot")
    init_boot_image = common.GetBootableImage(
        "IMAGES/init_boot.img", "init_boot.img", OPTIONS.input_tmp, "INIT_BOOT",
        dev_nodes=True)
    if init_boot_image:
      partitions['init_boot'] = os.path.join(
          OPTIONS.input_tmp, "IMAGES", "init_boot.img")
      if not os.path.exists(partitions['init_boot']):
        init_boot_image.WriteToDir(OPTIONS.input_tmp)
        if output_zip:
          init_boot_image.AddToZip(output_zip)

  if has_vendor_boot:
    banner("vendor_boot")
    vendor_boot_image = common.GetVendorBootImage(
        "IMAGES/vendor_boot.img", "vendor_boot.img", OPTIONS.input_tmp,
        "VENDOR_BOOT")
    if vendor_boot_image:
      partitions['vendor_boot'] = os.path.join(OPTIONS.input_tmp, "IMAGES",
                                               "vendor_boot.img")
      if not os.path.exists(partitions['vendor_boot']):
        vendor_boot_image.WriteToDir(OPTIONS.input_tmp)
        if output_zip:
          vendor_boot_image.AddToZip(output_zip)

  if has_vendor_kernel_boot:
    banner("vendor_kernel_boot")
    vendor_kernel_boot_image = common.GetVendorKernelBootImage(
        "IMAGES/vendor_kernel_boot.img", "vendor_kernel_boot.img", OPTIONS.input_tmp,
        "VENDOR_KERNEL_BOOT")
    if vendor_kernel_boot_image:
      partitions['vendor_kernel_boot'] = os.path.join(OPTIONS.input_tmp, "IMAGES",
                                                      "vendor_kernel_boot.img")
      if not os.path.exists(partitions['vendor_kernel_boot']):
        vendor_kernel_boot_image.WriteToDir(OPTIONS.input_tmp)
        if output_zip:
          vendor_kernel_boot_image.AddToZip(output_zip)

  recovery_image = None
  if has_recovery:
    banner("recovery")
    recovery_image = common.GetBootableImage(
        "IMAGES/recovery.img", "recovery.img", OPTIONS.input_tmp, "RECOVERY")
    assert recovery_image, "Failed to create recovery.img."
    partitions['recovery'] = os.path.join(
        OPTIONS.input_tmp, "IMAGES", "recovery.img")
    if not os.path.exists(partitions['recovery']):
      recovery_image.WriteToDir(OPTIONS.input_tmp)
      if output_zip:
        recovery_image.AddToZip(output_zip)

      banner("recovery (two-step image)")
      # The special recovery.img for two-step package use.
      recovery_two_step_image = common.GetBootableImage(
          "OTA/recovery-two-step.img", "recovery-two-step.img",
          OPTIONS.input_tmp, "RECOVERY", two_step_image=True)
      assert recovery_two_step_image, "Failed to create recovery-two-step.img."
      recovery_two_step_image_path = os.path.join(
          OPTIONS.input_tmp, "OTA", "recovery-two-step.img")
      if not os.path.exists(recovery_two_step_image_path):
        recovery_two_step_image.WriteToDir(OPTIONS.input_tmp)
        if output_zip:
          recovery_two_step_image.AddToZip(output_zip)

  def add_partition(partition, has_partition, add_func, add_args):
    if has_partition:
      banner(partition)
      partitions[partition] = add_func(output_zip, *add_args)

  add_partition_calls = (
      ("system", has_system, AddSystem, [recovery_image, boot_image]),
      ("vendor", has_vendor, AddVendor, [recovery_image, boot_image]),
      ("product", has_product, AddProduct, []),
      ("system_ext", has_system_ext, AddSystemExt, []),
      ("odm", has_odm, AddOdm, []),
      ("vendor_dlkm", has_vendor_dlkm, AddVendorDlkm, []),
      ("odm_dlkm", has_odm_dlkm, AddOdmDlkm, []),
      ("system_dlkm", has_system_dlkm, AddSystemDlkm, []),
      ("system_other", has_system_other, AddSystemOther, []),
  )
  # If output_zip exists, each add_partition_calls writes bytes to the same output_zip,
  # which is not thread-safe. So, run them in serial if output_zip exists.
  if output_zip:
    for call in add_partition_calls:
      add_partition(*call)
  else:
    with ThreadPoolExecutor(max_workers=len(add_partition_calls)) as executor:
      for future in [executor.submit(add_partition, *call) for call in add_partition_calls]:
        future.result()

  AddApexInfo(output_zip)

  if not OPTIONS.is_signing:
    banner("userdata")
    AddUserdata(output_zip)
    banner("cache")
    AddCache(output_zip)

  add_partition("dtbo",
                OPTIONS.info_dict.get("has_dtbo") == "true", AddDtbo, [])
  add_partition("pvmfw",
                OPTIONS.info_dict.get("has_pvmfw") == "true", AddPvmfw, [])

  # Custom images.
  custom_partitions = OPTIONS.info_dict.get(
      "custom_images_partition_list", "").strip().split()
  for partition_name in custom_partitions:
    partition_name = partition_name.strip()
    banner("custom images for " + partition_name)
    image_list = OPTIONS.info_dict.get(
          "{}_image_list".format(partition_name)).split()
    partitions[partition_name] = AddCustomImages(output_zip, partition_name, image_list)

  avb_custom_partitions = OPTIONS.info_dict.get(
      "avb_custom_images_partition_list", "").strip().split()
  for partition_name in avb_custom_partitions:
    partition_name = partition_name.strip()
    banner("avb custom images for " + partition_name)
    image_list = OPTIONS.info_dict.get(
          "avb_{}_image_list".format(partition_name)).split()
    partitions[partition_name] = AddCustomImages(output_zip, partition_name, image_list)

  if OPTIONS.info_dict.get("avb_enable") == "true":
    # vbmeta_partitions includes the partitions that should be included into
    # top-level vbmeta.img, which are the ones that are not included in any
    # chained VBMeta image plus the chained VBMeta images themselves.
    # Currently avb_custom_partitions are all chained to VBMeta image.
    vbmeta_partitions = common.AVB_PARTITIONS[:] + tuple(avb_custom_partitions)

    vbmeta_system = OPTIONS.info_dict.get("avb_vbmeta_system", "").strip()
    if vbmeta_system:
      banner("vbmeta_system")
      partitions["vbmeta_system"] = AddVBMeta(
          output_zip, partitions, "vbmeta_system", vbmeta_system.split())
      vbmeta_partitions = [
          item for item in vbmeta_partitions
          if item not in vbmeta_system.split()]
      vbmeta_partitions.append("vbmeta_system")

    vbmeta_vendor = OPTIONS.info_dict.get("avb_vbmeta_vendor", "").strip()
    if vbmeta_vendor:
      banner("vbmeta_vendor")
      partitions["vbmeta_vendor"] = AddVBMeta(
          output_zip, partitions, "vbmeta_vendor", vbmeta_vendor.split())
      vbmeta_partitions = [
          item for item in vbmeta_partitions
          if item not in vbmeta_vendor.split()]
      vbmeta_partitions.append("vbmeta_vendor")
    custom_avb_partitions = OPTIONS.info_dict.get(
        "avb_custom_vbmeta_images_partition_list", "").strip().split()
    if custom_avb_partitions:
      for avb_part in custom_avb_partitions:
        partition_name = "vbmeta_" + avb_part
        included_partitions = OPTIONS.info_dict.get(
            "avb_vbmeta_{}".format(avb_part), "").strip().split()
        assert included_partitions, "Custom vbmeta partition {0} missing avb_vbmeta_{0} prop".format(
            avb_part)
        banner(partition_name)
        logger.info("VBMeta partition {} needs {}".format(
            partition_name, included_partitions))
        partitions[partition_name] = AddVBMeta(
            output_zip, partitions, partition_name, included_partitions)
        vbmeta_partitions = [
            item for item in vbmeta_partitions
            if item not in included_partitions]
        vbmeta_partitions.append(partition_name)

    if OPTIONS.info_dict.get("avb_building_vbmeta_image") == "true":
      banner("vbmeta")
      AddVBMeta(output_zip, partitions, "vbmeta", vbmeta_partitions)

  if OPTIONS.info_dict.get("use_dynamic_partitions") == "true":
    if OPTIONS.info_dict.get("build_super_empty_partition") == "true":
      banner("super_empty")
      AddSuperEmpty(output_zip)

  if OPTIONS.info_dict.get("build_super_partition") == "true":
    if OPTIONS.info_dict.get(
            "build_retrofit_dynamic_partitions_ota_package") == "true":
      banner("super split images")
      AddSuperSplit(output_zip)

  banner("radio")
  ab_partitions_txt = os.path.join(OPTIONS.input_tmp, "META",
                                   "ab_partitions.txt")
  if os.path.exists(ab_partitions_txt):
    with open(ab_partitions_txt) as f:
      ab_partitions = f.read().splitlines()

    # For devices using A/B update, make sure we have all the needed images
    # ready under IMAGES/ or RADIO/.
    CheckAbOtaImages(output_zip, ab_partitions)

    # Generate care_map.pb for ab_partitions, then write this file to
    # target_files package.
    output_care_map = os.path.join(OPTIONS.input_tmp, "META", "care_map.pb")
    AddCareMapForAbOta(output_zip if output_zip else output_care_map,
                       ab_partitions, partitions)

  # Radio images that need to be packed into IMAGES/, and product-img.zip.
  pack_radioimages_txt = os.path.join(
      OPTIONS.input_tmp, "META", "pack_radioimages.txt")
  if os.path.exists(pack_radioimages_txt):
    with open(pack_radioimages_txt) as f:
      AddPackRadioImages(output_zip, f.readlines())

  AddVbmetaDigest(output_zip)

  if output_zip:
    common.ZipClose(output_zip)
    if OPTIONS.replace_updated_files_list:
      ReplaceUpdatedFiles(output_zip.filename,
                          OPTIONS.replace_updated_files_list)


def OptimizeCompressedEntries(zipfile_path):
  """Convert files that do not compress well to uncompressed storage

  EROFS images tend to be compressed already, so compressing them again
  yields little space savings. Leaving them uncompressed will make
  downstream tooling's job easier, and save compute time.
  """
  if not zipfile.is_zipfile(zipfile_path):
    return
  entries_to_store = []
  with tempfile.TemporaryDirectory() as tmpdir:
    with zipfile.ZipFile(zipfile_path, "r", allowZip64=True) as zfp:
      for zinfo in zfp.filelist:
        if not zinfo.filename.startswith("IMAGES/") and not zinfo.filename.startswith("META"):
          continue
        # Don't try to store userdata.img uncompressed, it's usually huge.
        if zinfo.filename.endswith("userdata.img"):
          continue
        if zinfo.compress_size > zinfo.file_size * 0.80 and zinfo.compress_type != zipfile.ZIP_STORED:
          entries_to_store.append(zinfo)
          zfp.extract(zinfo, tmpdir)
    if len(entries_to_store) == 0:
      return
    # Remove these entries, then re-add them as ZIP_STORED
    ZipDelete(zipfile_path, [entry.filename for entry in entries_to_store])
    with zipfile.ZipFile(zipfile_path, "a", allowZip64=True) as zfp:
      for entry in entries_to_store:
        zfp.write(os.path.join(tmpdir, entry.filename),
                  entry.filename, compress_type=zipfile.ZIP_STORED)


def main(argv):
  def option_handler(o, a):
    if o in ("-a", "--add_missing"):
      OPTIONS.add_missing = True
    elif o in ("-r", "--rebuild_recovery",):
      OPTIONS.rebuild_recovery = True
    elif o == "--replace_verity_private_key":
      raise ValueError("--replace_verity_private_key is no longer supported,"
                       " please switch to AVB")
    elif o == "--replace_verity_public_key":
      raise ValueError("--replace_verity_public_key is no longer supported,"
                       " please switch to AVB")
    elif o == "--is_signing":
      OPTIONS.is_signing = True
    elif o == "--avb_resolve_rollback_index_location_conflict":
      OPTIONS.avb_resolve_rollback_index_location_conflict = True
    else:
      return False
    return True

  args = common.ParseOptions(
      argv, __doc__, extra_opts="ar",
      extra_long_opts=["add_missing", "rebuild_recovery",
                       "replace_verity_public_key=",
                       "replace_verity_private_key=",
                       "is_signing",
                       "avb_resolve_rollback_index_location_conflict"],
      extra_option_handler=option_handler)

  if len(args) != 1:
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  AddImagesToTargetFiles(args[0])
  OptimizeCompressedEntries(args[0])
  logger.info("done.")


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  finally:
    common.Cleanup()
