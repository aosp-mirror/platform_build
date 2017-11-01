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

import sys

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

import os
import shutil
import zipfile

import common

OPTIONS = common.OPTIONS


def CopyInfo(output_zip):
  """Copy the android-info.txt file from the input to the output."""
  common.ZipWrite(
      output_zip, os.path.join(OPTIONS.input_tmp, "OTA", "android-info.txt"),
      "android-info.txt")


def main(argv):
  bootable_only = [False]

  def option_handler(o, _):
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

  OPTIONS.input_tmp, input_zip = common.UnzipTemp(
      args[0], ["IMAGES/*", "OTA/*"])
  output_zip = zipfile.ZipFile(args[1], "w", compression=zipfile.ZIP_DEFLATED)
  CopyInfo(output_zip)

  try:
    images_path = os.path.join(OPTIONS.input_tmp, "IMAGES")
    # A target-files zip must contain the images since Lollipop.
    assert os.path.exists(images_path)
    for image in sorted(os.listdir(images_path)):
      if bootable_only and image not in ("boot.img", "recovery.img"):
        continue
      if not image.endswith(".img"):
        continue
      if image == "recovery-two-step.img":
        continue
      common.ZipWrite(output_zip, os.path.join(images_path, image), image)

  finally:
    print("cleaning up...")
    common.ZipClose(output_zip)
    shutil.rmtree(OPTIONS.input_tmp)

  print("done.")


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  except common.ExternalError as e:
    print("\n   ERROR: %s\n" % (e,))
    sys.exit(1)
