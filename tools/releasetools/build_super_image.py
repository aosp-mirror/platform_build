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
Usage: build_super_image input_file output_dir_or_file

input_file: one of the following:
  - directory containing extracted target files. It will load info from
    META/misc_info.txt and build full super image / split images using source
    images from IMAGES/.
  - target files package. Same as above, but extracts the archive before
    building super image.
  - a dictionary file containing input arguments to build. Check
    `dump-super-image-info' for details.
    In addition:
    - If source images should be included in the output image (for super.img
      and super split images), a list of "*_image" should be paths of each
      source images.

output_dir_or_file:
    If a single super image is built (for super_empty.img, or super.img for
    launch devices), this argument is the output file.
    If a collection of split images are built (for retrofit devices), this
    argument is the output directory.
"""

from __future__ import print_function

import logging
import os.path
import shlex
import sys
import zipfile

import common
import sparse_img

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

logger = logging.getLogger(__name__)


UNZIP_PATTERN = ["IMAGES/*", "META/*", "*/build.prop"]


def GetArgumentsForImage(partition, group, image=None):
  image_size = sparse_img.GetImagePartitionSize(image) if image else 0

  cmd = ["--partition",
         "{}:readonly:{}:{}".format(partition, image_size, group)]
  if image:
    cmd += ["--image", "{}={}".format(partition, image)]

  return cmd


def BuildSuperImageFromDict(info_dict, output):

  cmd = [info_dict["lpmake"],
         "--metadata-size", "65536",
         "--super-name", info_dict["super_metadata_device"]]

  ab_update = info_dict.get("ab_update") == "true"
  virtual_ab = info_dict.get("virtual_ab") == "true"
  virtual_ab_retrofit = info_dict.get("virtual_ab_retrofit") == "true"
  retrofit = info_dict.get("dynamic_partition_retrofit") == "true"
  block_devices = shlex.split(info_dict.get("super_block_devices", "").strip())
  groups = shlex.split(info_dict.get("super_partition_groups", "").strip())

  if ab_update and retrofit:
    cmd += ["--metadata-slots", "2"]
  elif ab_update:
    cmd += ["--metadata-slots", "3"]
  else:
    cmd += ["--metadata-slots", "2"]

  if ab_update and retrofit:
    cmd.append("--auto-slot-suffixing")
  if virtual_ab and not virtual_ab_retrofit:
    cmd.append("--virtual-ab")

  for device in block_devices:
    size = info_dict["super_{}_device_size".format(device)]
    cmd += ["--device", "{}:{}".format(device, size)]

  append_suffix = ab_update and not retrofit
  has_image = False
  for group in groups:
    group_size = info_dict["super_{}_group_size".format(group)]
    if append_suffix:
      cmd += ["--group", "{}_a:{}".format(group, group_size),
              "--group", "{}_b:{}".format(group, group_size)]
    else:
      cmd += ["--group", "{}:{}".format(group, group_size)]

    partition_list = shlex.split(
        info_dict["super_{}_partition_list".format(group)].strip())

    for partition in partition_list:
      image = info_dict.get("{}_image".format(partition))
      if image:
        has_image = True

      if not append_suffix:
        cmd += GetArgumentsForImage(partition, group, image)
        continue

      # For A/B devices, super partition always contains sub-partitions in
      # the _a slot, because this image should only be used for
      # bootstrapping / initializing the device. When flashing the image,
      # bootloader fastboot should always mark _a slot as bootable.
      cmd += GetArgumentsForImage(partition + "_a", group + "_a", image)

      other_image = None
      if partition == "system" and "system_other_image" in info_dict:
        other_image = info_dict["system_other_image"]
        has_image = True

      cmd += GetArgumentsForImage(partition + "_b", group + "_b", other_image)

  if info_dict.get("build_non_sparse_super_partition") != "true":
    cmd.append("--sparse")

  cmd += ["--output", output]

  common.RunAndCheckOutput(cmd)

  if retrofit and has_image:
    logger.info("Done writing images to directory %s", output)
  else:
    logger.info("Done writing image %s", output)

  return True


def BuildSuperImageFromExtractedTargetFiles(inp, out):
  info_dict = common.LoadInfoDict(inp)
  partition_list = shlex.split(
      info_dict.get("dynamic_partition_list", "").strip())

  if "system" in partition_list:
    image_path = os.path.join(inp, "IMAGES", "system_other.img")
    if os.path.isfile(image_path):
      info_dict["system_other_image"] = image_path

  missing_images = []
  for partition in partition_list:
    image_path = os.path.join(inp, "IMAGES", "{}.img".format(partition))
    if not os.path.isfile(image_path):
      missing_images.append(image_path)
    else:
      info_dict["{}_image".format(partition)] = image_path
  if missing_images:
    logger.warning("Skip building super image because the following "
                   "images are missing from target files:\n%s",
                   "\n".join(missing_images))
    return False
  return BuildSuperImageFromDict(info_dict, out)


def BuildSuperImageFromTargetFiles(inp, out):
  input_tmp = common.UnzipTemp(inp, UNZIP_PATTERN)
  return BuildSuperImageFromExtractedTargetFiles(input_tmp, out)


def BuildSuperImage(inp, out):

  if isinstance(inp, dict):
    logger.info("Building super image from info dict...")
    return BuildSuperImageFromDict(inp, out)

  if isinstance(inp, str):
    if os.path.isdir(inp):
      logger.info("Building super image from extracted target files...")
      return BuildSuperImageFromExtractedTargetFiles(inp, out)

    if zipfile.is_zipfile(inp):
      logger.info("Building super image from target files...")
      return BuildSuperImageFromTargetFiles(inp, out)

    if os.path.isfile(inp):
      with open(inp) as f:
        lines = f.read()
      logger.info("Building super image from info dict...")
      return BuildSuperImageFromDict(common.LoadDictionaryFromLines(lines.split("\n")), out)

  raise ValueError("{} is not a dictionary or a valid path".format(inp))


def main(argv):

  args = common.ParseOptions(argv, __doc__)

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  BuildSuperImage(args[0], args[1])


if __name__ == "__main__":
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  except common.ExternalError:
    logger.exception("\n   ERROR:\n")
    sys.exit(1)
  finally:
    common.Cleanup()
