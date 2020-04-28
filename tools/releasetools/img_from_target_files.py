#!/usr/bin/env python
#
# Copyright (C) 2008 The Android Open Source Project
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
Given a target-files zipfile, produces an image zipfile suitable for
use with 'fastboot update'.

Usage:  img_from_target_files [flags] input_target_files output_image_zip

  -z  (--bootable_zip)
      Include only the bootable images (eg 'boot' and 'recovery') in
      the output.

"""

from __future__ import print_function

import logging
import os
import shutil
import sys
import zipfile

import common
from build_super_image import BuildSuperImage

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS


def LoadOptions(input_file):
  """
  Load information from input_file to OPTIONS.

  Args:
    input_file: A Zipfile instance of input zip file, or path to the directory
      of extracted zip.
  """
  info = OPTIONS.info_dict = common.LoadInfoDict(input_file)

  OPTIONS.put_super = info.get("super_image_in_update_package") == "true"
  OPTIONS.dynamic_partition_list = info.get("dynamic_partition_list",
                                            "").strip().split()
  OPTIONS.super_device_list = info.get("super_block_devices",
                                       "").strip().split()
  OPTIONS.retrofit_dap = info.get("dynamic_partition_retrofit") == "true"
  OPTIONS.build_super = info.get("build_super_partition") == "true"
  OPTIONS.sparse_userimages = bool(info.get("extfs_sparse_flag"))


def CopyInfo(input_tmp, output_zip):
  """Copy the android-info.txt file from the input to the output."""
  common.ZipWrite(
      output_zip, os.path.join(input_tmp, "OTA", "android-info.txt"),
      "android-info.txt")


def CopyUserImages(input_tmp, output_zip):
  """
  Copy user images from the unzipped input and write to output_zip.

  Args:
    input_tmp: path to the unzipped input.
    output_zip: a ZipFile instance to write images to.
  """
  dynamic_images = [p + ".img" for p in OPTIONS.dynamic_partition_list]

  # Filter out system_other for launch DAP devices because it is in super image.
  if not OPTIONS.retrofit_dap and "system" in OPTIONS.dynamic_partition_list:
    dynamic_images.append("system_other.img")

  images_path = os.path.join(input_tmp, "IMAGES")
  # A target-files zip must contain the images since Lollipop.
  assert os.path.exists(images_path)
  for image in sorted(os.listdir(images_path)):
    if OPTIONS.bootable_only and image not in ("boot.img", "recovery.img"):
      continue
    if not image.endswith(".img"):
      continue
    if image == "recovery-two-step.img":
      continue
    if OPTIONS.put_super:
      if image == "super_empty.img":
        continue
      if image in dynamic_images:
        continue
    logger.info("writing %s to archive...", os.path.join("IMAGES", image))
    common.ZipWrite(output_zip, os.path.join(images_path, image), image)


def WriteSuperImages(input_tmp, output_zip):
  """
  Write super images from the unzipped input and write to output_zip. This is
  only done if super_image_in_update_package is set to "true".

  - For retrofit dynamic partition devices, copy split super images from target
    files package.
  - For devices launched with dynamic partitions, build super image from target
    files package.

  Args:
    input_tmp: path to the unzipped input.
    output_zip: a ZipFile instance to write images to.
  """
  if not OPTIONS.build_super or not OPTIONS.put_super:
    return

  if OPTIONS.retrofit_dap:
    # retrofit devices already have split super images under OTA/
    images_path = os.path.join(input_tmp, "OTA")
    for device in OPTIONS.super_device_list:
      image = "super_%s.img" % device
      image_path = os.path.join(images_path, image)
      assert os.path.exists(image_path)
      logger.info("writing %s to archive...", os.path.join("OTA", image))
      common.ZipWrite(output_zip, image_path, image)
  else:
    # super image for non-retrofit devices aren't in target files package,
    # so build it.
    super_file = common.MakeTempFile("super_", ".img")
    logger.info("building super image %s...", super_file)
    BuildSuperImage(input_tmp, super_file)
    logger.info("writing super.img to archive...")
    common.ZipWrite(output_zip, super_file, "super.img")


def main(argv):
  # This allows modifying the value from inner function.
  bootable_only_array = [False]

  def option_handler(o, _):
    if o in ("-z", "--bootable_zip"):
      bootable_only_array[0] = True
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts="z",
                             extra_long_opts=["bootable_zip"],
                             extra_option_handler=option_handler)

  OPTIONS.bootable_only = bootable_only_array[0]

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  # We need files under IMAGES/, OTA/, META/ for img_from_target_files.py.
  # However, common.LoadInfoDict() may read additional files under BOOT/,
  # RECOVERY/ and ROOT/. So unzip everything from the target_files.zip.
  OPTIONS.input_tmp = common.UnzipTemp(args[0])
  LoadOptions(OPTIONS.input_tmp)
  output_zip = zipfile.ZipFile(args[1], "w", compression=zipfile.ZIP_DEFLATED,
                               allowZip64=not OPTIONS.sparse_userimages)

  try:
    CopyInfo(OPTIONS.input_tmp, output_zip)
    CopyUserImages(OPTIONS.input_tmp, output_zip)
    WriteSuperImages(OPTIONS.input_tmp, output_zip)
  finally:
    logger.info("cleaning up...")
    common.ZipClose(output_zip)
    shutil.rmtree(OPTIONS.input_tmp)

  logger.info("done.")


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  except common.ExternalError as e:
    logger.exception("\n   ERROR:\n")
    sys.exit(1)
