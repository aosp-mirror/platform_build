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

Usage:  add_img_to_target_files target_files
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

import build_image
import common

OPTIONS = common.OPTIONS


def AddSystem(output_zip, sparse=True, prefix="IMAGES/"):
  """Turn the contents of SYSTEM into a system image and store it in
  output_zip."""
  data = BuildSystem(OPTIONS.input_tmp, OPTIONS.info_dict, sparse=sparse)
  common.ZipWriteStr(output_zip, prefix + "system.img", data)

def BuildSystem(input_dir, info_dict, sparse=True, map_file=None):
  return CreateImage(input_dir, info_dict, "system",
                     sparse=sparse, map_file=map_file)

def AddVendor(output_zip, sparse=True, prefix="IMAGES/"):
  data = BuildVendor(OPTIONS.input_tmp, OPTIONS.info_dict, sparse=sparse)
  common.ZipWriteStr(output_zip, prefix + "vendor.img", data)

def BuildVendor(input_dir, info_dict, sparse=True, map_file=None):
  return CreateImage(input_dir, info_dict, "vendor",
                     sparse=sparse, map_file=map_file)


def CreateImage(input_dir, info_dict, what, sparse=True, map_file=None):
  print "creating " + what + ".img..."

  img = tempfile.NamedTemporaryFile()

  # The name of the directory it is making an image out of matters to
  # mkyaffs2image.  It wants "system" but we have a directory named
  # "SYSTEM", so create a symlink.
  try:
    os.symlink(os.path.join(input_dir, what.upper()),
               os.path.join(input_dir, what))
  except OSError, e:
      # bogus error on my mac version?
      #   File "./build/tools/releasetools/img_from_target_files", line 86, in AddSystem
      #     os.path.join(OPTIONS.input_tmp, "system"))
      # OSError: [Errno 17] File exists
    if (e.errno == errno.EEXIST):
      pass

  image_props = build_image.ImagePropFromGlobalDict(info_dict, what)
  fstab = info_dict["fstab"]
  if fstab:
    image_props["fs_type" ] = fstab["/" + what].fs_type

  if what == "system":
    fs_config_prefix = ""
  else:
    fs_config_prefix = what + "_"

  fs_config = os.path.join(
      input_dir, "META/" + fs_config_prefix + "filesystem_config.txt")
  if not os.path.exists(fs_config): fs_config = None

  fc_config = os.path.join(input_dir, "BOOT/RAMDISK/file_contexts")
  if not os.path.exists(fc_config): fc_config = None

  succ = build_image.BuildImage(os.path.join(input_dir, what),
                                image_props, img.name,
                                fs_config=fs_config,
                                fc_config=fc_config)
  assert succ, "build " + what + ".img image failed"

  mapdata = None

  if sparse:
    data = open(img.name).read()
    img.close()
  else:
    success, name = build_image.UnsparseImage(img.name, replace=False)
    if not success:
      assert False, "unsparsing " + what + ".img failed"

    if map_file:
      mmap = tempfile.NamedTemporaryFile()
      mimg = tempfile.NamedTemporaryFile(delete=False)
      success = build_image.MappedUnsparseImage(
          img.name, name, mmap.name, mimg.name)
      if not success:
        assert False, "creating sparse map failed"
      os.unlink(name)
      name = mimg.name

      with open(mmap.name) as f:
        mapdata = f.read()

    try:
      with open(name) as f:
        data = f.read()
    finally:
      os.unlink(name)

  if mapdata is None:
    return data
  else:
    return mapdata, data


def AddUserdata(output_zip, prefix="IMAGES/"):
  """Create an empty userdata image and store it in output_zip."""

  image_props = build_image.ImagePropFromGlobalDict(OPTIONS.info_dict,
                                                    "data")
  # We only allow yaffs to have a 0/missing partition_size.
  # Extfs, f2fs must have a size. Skip userdata.img if no size.
  if (not image_props.get("fs_type", "").startswith("yaffs") and
      not image_props.get("partition_size")):
    return

  print "creating userdata.img..."

  # The name of the directory it is making an image out of matters to
  # mkyaffs2image.  So we create a temp dir, and within it we create an
  # empty dir named "data", and build the image from that.
  temp_dir = tempfile.mkdtemp()
  user_dir = os.path.join(temp_dir, "data")
  os.mkdir(user_dir)
  img = tempfile.NamedTemporaryFile()

  fstab = OPTIONS.info_dict["fstab"]
  if fstab:
    image_props["fs_type" ] = fstab["/data"].fs_type
  succ = build_image.BuildImage(user_dir, image_props, img.name)
  assert succ, "build userdata.img image failed"

  common.CheckSize(img.name, "userdata.img", OPTIONS.info_dict)
  output_zip.write(img.name, prefix + "userdata.img")
  img.close()
  os.rmdir(user_dir)
  os.rmdir(temp_dir)


def AddCache(output_zip, prefix="IMAGES/"):
  """Create an empty cache image and store it in output_zip."""

  image_props = build_image.ImagePropFromGlobalDict(OPTIONS.info_dict,
                                                    "cache")
  # The build system has to explicitly request for cache.img.
  if "fs_type" not in image_props:
    return

  print "creating cache.img..."

  # The name of the directory it is making an image out of matters to
  # mkyaffs2image.  So we create a temp dir, and within it we create an
  # empty dir named "cache", and build the image from that.
  temp_dir = tempfile.mkdtemp()
  user_dir = os.path.join(temp_dir, "cache")
  os.mkdir(user_dir)
  img = tempfile.NamedTemporaryFile()

  fstab = OPTIONS.info_dict["fstab"]
  if fstab:
    image_props["fs_type" ] = fstab["/cache"].fs_type
  succ = build_image.BuildImage(user_dir, image_props, img.name)
  assert succ, "build cache.img image failed"

  common.CheckSize(img.name, "cache.img", OPTIONS.info_dict)
  output_zip.write(img.name, prefix + "cache.img")
  img.close()
  os.rmdir(user_dir)
  os.rmdir(temp_dir)


def AddImagesToTargetFiles(filename):
  OPTIONS.input_tmp, input_zip = common.UnzipTemp(filename)
  try:

    for n in input_zip.namelist():
      if n.startswith("IMAGES/"):
        print "target_files appears to already contain images."
        sys.exit(1)

    try:
      input_zip.getinfo("VENDOR/")
      has_vendor = True
    except KeyError:
      has_vendor = False

    OPTIONS.info_dict = common.LoadInfoDict(input_zip)
    if "selinux_fc" in OPTIONS.info_dict:
      OPTIONS.info_dict["selinux_fc"] = os.path.join(
          OPTIONS.input_tmp, "BOOT", "RAMDISK", "file_contexts")

    input_zip.close()
    output_zip = zipfile.ZipFile(filename, "a",
                                 compression=zipfile.ZIP_DEFLATED)

    def banner(s):
      print "\n\n++++ " + s + " ++++\n\n"

    banner("boot")
    boot_image = common.GetBootableImage(
        "IMAGES/boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")
    if boot_image:
      boot_image.AddToZip(output_zip)

    banner("recovery")
    recovery_image = common.GetBootableImage(
        "IMAGES/recovery.img", "recovery.img", OPTIONS.input_tmp, "RECOVERY")
    if recovery_image:
      recovery_image.AddToZip(output_zip)

    banner("system")
    AddSystem(output_zip)
    if has_vendor:
      banner("vendor")
      AddVendor(output_zip)
    banner("userdata")
    AddUserdata(output_zip)
    banner("cache")
    AddCache(output_zip)

    output_zip.close()

  finally:
    shutil.rmtree(OPTIONS.input_tmp)


def main(argv):
  args = common.ParseOptions(argv, __doc__)

  if len(args) != 1:
    common.Usage(__doc__)
    sys.exit(1)

  AddImagesToTargetFiles(args[0])
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
