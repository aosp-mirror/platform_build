#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#
"""Merges two non-dist partial builds together.

Given two partial builds, a framework build and a vendor build, merge the builds
together so that the images can be flashed using 'fastboot flashall'.

To support both DAP and non-DAP vendor builds with a single framework partial
build, the framework partial build should always be built with DAP enabled. The
vendor partial build determines whether the merged result supports DAP.

This script does not require builds to be built with 'make dist'.
This script regenerates super_empty.img and vbmeta.img if necessary. Other
images are assumed to not require regeneration.

Usage: merge_builds.py [args]

  --framework_images comma_separated_image_list
      Comma-separated list of image names that should come from the framework
      build.

  --product_out_framework product_out_framework_path
      Path to out/target/product/<framework build>.

  --product_out_vendor product_out_vendor_path
      Path to out/target/product/<vendor build>.

  --build_vbmeta
      If provided, vbmeta.img will be regenerated in out/target/product/<vendor
      build>.

  --framework_misc_info_keys
      The optional path to a newline-separated config file containing keys to
      obtain from the framework instance of misc_info.txt, used for creating
      vbmeta.img. The remaining keys come from the vendor instance.
"""
from __future__ import print_function

import logging
import os
import sys

import build_super_image
import common

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
OPTIONS.framework_images = ("system",)
OPTIONS.product_out_framework = None
OPTIONS.product_out_vendor = None
OPTIONS.build_vbmeta = False
OPTIONS.framework_misc_info_keys = None


def CreateImageSymlinks():
  for image in OPTIONS.framework_images:
    image_path = os.path.join(OPTIONS.product_out_framework, "%s.img" % image)
    symlink_path = os.path.join(OPTIONS.product_out_vendor, "%s.img" % image)
    if os.path.exists(symlink_path):
      if os.path.islink(symlink_path):
        os.remove(symlink_path)
      else:
        raise ValueError("Attempting to overwrite built image: %s" %
                         symlink_path)
    os.symlink(image_path, symlink_path)


def BuildSuperEmpty():
  framework_dict = common.LoadDictionaryFromFile(
      os.path.join(OPTIONS.product_out_framework, "misc_info.txt"))
  vendor_dict = common.LoadDictionaryFromFile(
      os.path.join(OPTIONS.product_out_vendor, "misc_info.txt"))
  # Regenerate super_empty.img if both partial builds enable DAP. If only the
  # the vendor build enables DAP, the vendor build's existing super_empty.img
  # will be reused. If only the framework build should enable DAP, super_empty
  # should be included in the --framework_images flag to copy the existing
  # super_empty.img from the framework build.
  if (framework_dict.get("use_dynamic_partitions") == "true") and (
      vendor_dict.get("use_dynamic_partitions") == "true"):
    logger.info("Building super_empty.img.")
    merged_dict = dict(vendor_dict)
    merged_dict.update(
        common.MergeDynamicPartitionInfoDicts(
            framework_dict=framework_dict, vendor_dict=vendor_dict))
    output_super_empty_path = os.path.join(OPTIONS.product_out_vendor,
                                           "super_empty.img")
    build_super_image.BuildSuperImage(merged_dict, output_super_empty_path)


def BuildVBMeta():
  logger.info("Building vbmeta.img.")

  framework_dict = common.LoadDictionaryFromFile(
      os.path.join(OPTIONS.product_out_framework, "misc_info.txt"))
  vendor_dict = common.LoadDictionaryFromFile(
      os.path.join(OPTIONS.product_out_vendor, "misc_info.txt"))
  merged_dict = dict(vendor_dict)
  if OPTIONS.framework_misc_info_keys:
    for key in common.LoadListFromFile(OPTIONS.framework_misc_info_keys):
      merged_dict[key] = framework_dict[key]

  # Build vbmeta.img using partitions in product_out_vendor.
  partitions = {}
  for partition in common.AVB_PARTITIONS:
    partition_path = os.path.join(OPTIONS.product_out_vendor,
                                  "%s.img" % partition)
    if os.path.exists(partition_path):
      partitions[partition] = partition_path

  # vbmeta_partitions includes the partitions that should be included into
  # top-level vbmeta.img, which are the ones that are not included in any
  # chained VBMeta image plus the chained VBMeta images themselves.
  vbmeta_partitions = common.AVB_PARTITIONS[:]
  for partition in common.AVB_VBMETA_PARTITIONS:
    chained_partitions = merged_dict.get("avb_%s" % partition, "").strip()
    if chained_partitions:
      partitions[partition] = os.path.join(OPTIONS.product_out_vendor,
                                           "%s.img" % partition)
      vbmeta_partitions = [
          item for item in vbmeta_partitions
          if item not in chained_partitions.split()
      ]
      vbmeta_partitions.append(partition)

  output_vbmeta_path = os.path.join(OPTIONS.product_out_vendor, "vbmeta.img")
  OPTIONS.info_dict = merged_dict
  common.BuildVBMeta(output_vbmeta_path, partitions, "vbmeta",
                     vbmeta_partitions)


def MergeBuilds():
  CreateImageSymlinks()
  BuildSuperEmpty()
  if OPTIONS.build_vbmeta:
    BuildVBMeta()


def main():
  common.InitLogging()

  def option_handler(o, a):
    if o == "--framework_images":
      OPTIONS.framework_images = [i.strip() for i in a.split(",")]
    elif o == "--product_out_framework":
      OPTIONS.product_out_framework = a
    elif o == "--product_out_vendor":
      OPTIONS.product_out_vendor = a
    elif o == "--build_vbmeta":
      OPTIONS.build_vbmeta = True
    elif o == "--framework_misc_info_keys":
      OPTIONS.framework_misc_info_keys = a
    else:
      return False
    return True

  args = common.ParseOptions(
      sys.argv[1:],
      __doc__,
      extra_long_opts=[
          "framework_images=",
          "product_out_framework=",
          "product_out_vendor=",
          "build_vbmeta",
          "framework_misc_info_keys=",
      ],
      extra_option_handler=option_handler)

  if (args or OPTIONS.product_out_framework is None or
      OPTIONS.product_out_vendor is None):
    common.Usage(__doc__)
    sys.exit(1)

  MergeBuilds()


if __name__ == "__main__":
  main()
