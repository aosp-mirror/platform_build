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

import datetime
import errno
import os
import tempfile
import zipfile

import build_image
import common

OPTIONS = common.OPTIONS

OPTIONS.add_missing = False
OPTIONS.rebuild_recovery = False
OPTIONS.replace_verity_public_key = False
OPTIONS.replace_verity_private_key = False
OPTIONS.verity_signer_path = None

def AddSystem(output_zip, prefix="IMAGES/", recovery_img=None, boot_img=None):
  """Turn the contents of SYSTEM into a system image and store it in
  output_zip."""

  prebuilt_path = os.path.join(OPTIONS.input_tmp, prefix, "system.img")
  if os.path.exists(prebuilt_path):
    print "system.img already exists in %s, no need to rebuild..." % (prefix,)
    return

  def output_sink(fn, data):
    ofile = open(os.path.join(OPTIONS.input_tmp, "SYSTEM", fn), "w")
    ofile.write(data)
    ofile.close()

  if OPTIONS.rebuild_recovery:
    print "Building new recovery patch"
    common.MakeRecoveryPatch(OPTIONS.input_tmp, output_sink, recovery_img,
                             boot_img, info_dict=OPTIONS.info_dict)

  block_list = common.MakeTempFile(prefix="system-blocklist-", suffix=".map")
  imgname = BuildSystem(OPTIONS.input_tmp, OPTIONS.info_dict,
                        block_list=block_list)
  common.ZipWrite(output_zip, imgname, prefix + "system.img")
  common.ZipWrite(output_zip, block_list, prefix + "system.map")


def BuildSystem(input_dir, info_dict, block_list=None):
  """Build the (sparse) system image and return the name of a temp
  file containing it."""
  return CreateImage(input_dir, info_dict, "system", block_list=block_list)


def AddVendor(output_zip, prefix="IMAGES/"):
  """Turn the contents of VENDOR into a vendor image and store in it
  output_zip."""

  prebuilt_path = os.path.join(OPTIONS.input_tmp, prefix, "vendor.img")
  if os.path.exists(prebuilt_path):
    print "vendor.img already exists in %s, no need to rebuild..." % (prefix,)
    return

  block_list = common.MakeTempFile(prefix="vendor-blocklist-", suffix=".map")
  imgname = BuildVendor(OPTIONS.input_tmp, OPTIONS.info_dict,
                        block_list=block_list)
  common.ZipWrite(output_zip, imgname, prefix + "vendor.img")
  common.ZipWrite(output_zip, block_list, prefix + "vendor.map")


def BuildVendor(input_dir, info_dict, block_list=None):
  """Build the (sparse) vendor image and return the name of a temp
  file containing it."""
  return CreateImage(input_dir, info_dict, "vendor", block_list=block_list)


def CreateImage(input_dir, info_dict, what, block_list=None):
  print "creating " + what + ".img..."

  img = common.MakeTempFile(prefix=what + "-", suffix=".img")

  # The name of the directory it is making an image out of matters to
  # mkyaffs2image.  It wants "system" but we have a directory named
  # "SYSTEM", so create a symlink.
  try:
    os.symlink(os.path.join(input_dir, what.upper()),
               os.path.join(input_dir, what))
  except OSError as e:
    # bogus error on my mac version?
    #   File "./build/tools/releasetools/img_from_target_files"
    #     os.path.join(OPTIONS.input_tmp, "system"))
    # OSError: [Errno 17] File exists
    if e.errno == errno.EEXIST:
      pass

  image_props = build_image.ImagePropFromGlobalDict(info_dict, what)
  fstab = info_dict["fstab"]
  if fstab:
    image_props["fs_type"] = fstab["/" + what].fs_type

  # Use a fixed timestamp (01/01/2009) when packaging the image.
  # Bug: 24377993
  epoch = datetime.datetime.fromtimestamp(0)
  timestamp = (datetime.datetime(2009, 1, 1) - epoch).total_seconds()
  image_props["timestamp"] = int(timestamp)

  if what == "system":
    fs_config_prefix = ""
  else:
    fs_config_prefix = what + "_"

  fs_config = os.path.join(
      input_dir, "META/" + fs_config_prefix + "filesystem_config.txt")
  if not os.path.exists(fs_config):
    fs_config = None

  fc_config = os.path.join(input_dir, "BOOT/RAMDISK/file_contexts")
  if not os.path.exists(fc_config):
    fc_config = None

  # Override values loaded from info_dict.
  if fs_config:
    image_props["fs_config"] = fs_config
  if fc_config:
    image_props["selinux_fc"] = fc_config
  if block_list:
    image_props["block_list"] = block_list
  if image_props.get("system_root_image") == "true":
    image_props["ramdisk_dir"] = os.path.join(input_dir, "BOOT/RAMDISK")
    image_props["ramdisk_fs_config"] = os.path.join(
        input_dir, "META/boot_filesystem_config.txt")

  succ = build_image.BuildImage(os.path.join(input_dir, what),
                                image_props, img)
  assert succ, "build " + what + ".img image failed"

  return img


def AddUserdata(output_zip, prefix="IMAGES/"):
  """Create an empty userdata image and store it in output_zip."""

  prebuilt_path = os.path.join(OPTIONS.input_tmp, prefix, "userdata.img")
  if os.path.exists(prebuilt_path):
    print "userdata.img already exists in %s, no need to rebuild..." % (prefix,)
    return

  image_props = build_image.ImagePropFromGlobalDict(OPTIONS.info_dict,
                                                    "data")
  # We only allow yaffs to have a 0/missing partition_size.
  # Extfs, f2fs must have a size. Skip userdata.img if no size.
  if (not image_props.get("fs_type", "").startswith("yaffs") and
      not image_props.get("partition_size")):
    return

  print "creating userdata.img..."

  # Use a fixed timestamp (01/01/2009) when packaging the image.
  # Bug: 24377993
  epoch = datetime.datetime.fromtimestamp(0)
  timestamp = (datetime.datetime(2009, 1, 1) - epoch).total_seconds()
  image_props["timestamp"] = int(timestamp)

  # The name of the directory it is making an image out of matters to
  # mkyaffs2image.  So we create a temp dir, and within it we create an
  # empty dir named "data", and build the image from that.
  temp_dir = tempfile.mkdtemp()
  user_dir = os.path.join(temp_dir, "data")
  os.mkdir(user_dir)
  img = tempfile.NamedTemporaryFile()

  fstab = OPTIONS.info_dict["fstab"]
  if fstab:
    image_props["fs_type"] = fstab["/data"].fs_type
  succ = build_image.BuildImage(user_dir, image_props, img.name)
  assert succ, "build userdata.img image failed"

  common.CheckSize(img.name, "userdata.img", OPTIONS.info_dict)
  common.ZipWrite(output_zip, img.name, prefix + "userdata.img")
  img.close()
  os.rmdir(user_dir)
  os.rmdir(temp_dir)


def AddCache(output_zip, prefix="IMAGES/"):
  """Create an empty cache image and store it in output_zip."""

  prebuilt_path = os.path.join(OPTIONS.input_tmp, prefix, "cache.img")
  if os.path.exists(prebuilt_path):
    print "cache.img already exists in %s, no need to rebuild..." % (prefix,)
    return

  image_props = build_image.ImagePropFromGlobalDict(OPTIONS.info_dict,
                                                    "cache")
  # The build system has to explicitly request for cache.img.
  if "fs_type" not in image_props:
    return

  print "creating cache.img..."

  # Use a fixed timestamp (01/01/2009) when packaging the image.
  # Bug: 24377993
  epoch = datetime.datetime.fromtimestamp(0)
  timestamp = (datetime.datetime(2009, 1, 1) - epoch).total_seconds()
  image_props["timestamp"] = int(timestamp)

  # The name of the directory it is making an image out of matters to
  # mkyaffs2image.  So we create a temp dir, and within it we create an
  # empty dir named "cache", and build the image from that.
  temp_dir = tempfile.mkdtemp()
  user_dir = os.path.join(temp_dir, "cache")
  os.mkdir(user_dir)
  img = tempfile.NamedTemporaryFile()

  fstab = OPTIONS.info_dict["fstab"]
  if fstab:
    image_props["fs_type"] = fstab["/cache"].fs_type
  succ = build_image.BuildImage(user_dir, image_props, img.name)
  assert succ, "build cache.img image failed"

  common.CheckSize(img.name, "cache.img", OPTIONS.info_dict)
  common.ZipWrite(output_zip, img.name, prefix + "cache.img")
  img.close()
  os.rmdir(user_dir)
  os.rmdir(temp_dir)


def AddImagesToTargetFiles(filename):
  OPTIONS.input_tmp, input_zip = common.UnzipTemp(filename)

  if not OPTIONS.add_missing:
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

  common.ZipClose(input_zip)
  output_zip = zipfile.ZipFile(filename, "a",
                               compression=zipfile.ZIP_DEFLATED)

  def banner(s):
    print "\n\n++++ " + s + " ++++\n\n"

  banner("boot")
  prebuilt_path = os.path.join(OPTIONS.input_tmp, "IMAGES", "boot.img")
  boot_image = None
  if os.path.exists(prebuilt_path):
    print "boot.img already exists in IMAGES/, no need to rebuild..."
    if OPTIONS.rebuild_recovery:
      boot_image = common.GetBootableImage(
          "IMAGES/boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")
  else:
    boot_image = common.GetBootableImage(
        "IMAGES/boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")
    if boot_image:
      boot_image.AddToZip(output_zip)

  banner("recovery")
  recovery_image = None
  prebuilt_path = os.path.join(OPTIONS.input_tmp, "IMAGES", "recovery.img")
  if os.path.exists(prebuilt_path):
    print "recovery.img already exists in IMAGES/, no need to rebuild..."
    if OPTIONS.rebuild_recovery:
      recovery_image = common.GetBootableImage(
          "IMAGES/recovery.img", "recovery.img", OPTIONS.input_tmp, "RECOVERY")
  else:
    recovery_image = common.GetBootableImage(
        "IMAGES/recovery.img", "recovery.img", OPTIONS.input_tmp, "RECOVERY")
    if recovery_image:
      recovery_image.AddToZip(output_zip)

  banner("system")
  AddSystem(output_zip, recovery_img=recovery_image, boot_img=boot_image)
  if has_vendor:
    banner("vendor")
    AddVendor(output_zip)
  banner("userdata")
  AddUserdata(output_zip)
  banner("cache")
  AddCache(output_zip)

  common.ZipClose(output_zip)

def main(argv):
  def option_handler(o, a):
    if o in ("-a", "--add_missing"):
      OPTIONS.add_missing = True
    elif o in ("-r", "--rebuild_recovery",):
      OPTIONS.rebuild_recovery = True
    elif o == "--replace_verity_private_key":
      OPTIONS.replace_verity_private_key = (True, a)
    elif o == "--replace_verity_public_key":
      OPTIONS.replace_verity_public_key = (True, a)
    elif o == "--verity_signer_path":
      OPTIONS.verity_signer_path = a
    else:
      return False
    return True

  args = common.ParseOptions(
      argv, __doc__, extra_opts="ar",
      extra_long_opts=["add_missing", "rebuild_recovery",
                       "replace_verity_public_key=",
                       "replace_verity_private_key=",
                       "verity_signer_path="],
      extra_option_handler=option_handler)


  if len(args) != 1:
    common.Usage(__doc__)
    sys.exit(1)

  AddImagesToTargetFiles(args[0])
  print "done."

if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  except common.ExternalError as e:
    print
    print "   ERROR: %s" % (e,)
    print
    sys.exit(1)
  finally:
    common.Cleanup()
