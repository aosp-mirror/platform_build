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

import sys

if sys.hexversion < 0x02070000:
  print >> sys.stderr, "Python 2.7 or newer is required."
  sys.exit(1)

import errno
import os
import re
import shutil
import subprocess
import tempfile
import zipfile

# missing in Python 2.4 and before
if not hasattr(os, "SEEK_SET"):
  os.SEEK_SET = 0

import common

OPTIONS = common.OPTIONS


def CopyInfo(output_zip):
  """Copy the android-info.txt file from the input to the output."""
  output_zip.write(os.path.join(OPTIONS.input_tmp, "OTA", "android-info.txt"),
                   "android-info.txt")


def main(argv):
  bootable_only = [False]

  def option_handler(o, a):
    if o in ("-z", "--bootable_zip"):
      bootable_only[0] = True
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts="z",
                             extra_long_opts=["bootable_zip"],
                             extra_option_handler=option_handler)

  bootable_only = bootable_only[0]

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  OPTIONS.input_tmp, input_zip = common.UnzipTemp(args[0])
  output_zip = zipfile.ZipFile(args[1], "w", compression=zipfile.ZIP_DEFLATED)
  CopyInfo(output_zip)

  try:
    done = False
    images_path = os.path.join(OPTIONS.input_tmp, "IMAGES")
    if os.path.exists(images_path):
      # If this is a new target-files, it already contains the images,
      # and all we have to do is copy them to the output zip.
      images = os.listdir(images_path)
      if images:
        for i in images:
          if bootable_only and i not in ("boot.img", "recovery.img"): continue
          if not i.endswith(".img"): continue
          with open(os.path.join(images_path, i), "r") as f:
            common.ZipWriteStr(output_zip, i, f.read())
        done = True

    if not done:
      # We have an old target-files that doesn't already contain the
      # images, so build them.
      import add_img_to_target_files

      OPTIONS.info_dict = common.LoadInfoDict(input_zip)

      # If this image was originally labelled with SELinux contexts,
      # make sure we also apply the labels in our new image. During
      # building, the "file_contexts" is in the out/ directory tree,
      # but for repacking from target-files.zip it's in the root
      # directory of the ramdisk.
      if "selinux_fc" in OPTIONS.info_dict:
        OPTIONS.info_dict["selinux_fc"] = os.path.join(
            OPTIONS.input_tmp, "BOOT", "RAMDISK", "file_contexts")

      boot_image = common.GetBootableImage(
          "boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")
      if boot_image:
          boot_image.AddToZip(output_zip)
      recovery_image = common.GetBootableImage(
          "recovery.img", "recovery.img", OPTIONS.input_tmp, "RECOVERY")
      if recovery_image:
        recovery_image.AddToZip(output_zip)

      def banner(s):
        print "\n\n++++ " + s + " ++++\n\n"

      if not bootable_only:
        banner("AddSystem")
        add_img_to_target_files.AddSystem(output_zip, prefix="")
        try:
          input_zip.getinfo("VENDOR/")
          banner("AddVendor")
          add_img_to_target_files.AddVendor(output_zip, prefix="")
        except KeyError:
          pass   # no vendor partition for this device
        banner("AddUserdata")
        add_img_to_target_files.AddUserdata(output_zip, prefix="")
        banner("AddCache")
        add_img_to_target_files.AddCache(output_zip, prefix="")

  finally:
    print "cleaning up..."
    output_zip.close()
    shutil.rmtree(OPTIONS.input_tmp)

  print "done."


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  except common.ExternalError, e:
    print
    print "   ERROR: %s" % (e,)
    print
    sys.exit(1)
