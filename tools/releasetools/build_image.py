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
Build image output_image_file from input_directory and properties_file.

Usage:  build_image input_directory properties_file output_image_file

"""
import os
import os.path
import subprocess
import sys

def RunCommand(cmd):
  """ Echo and run the given command

  Args:
    cmd: the command represented as a list of strings.
  Returns:
    The exit code.
  """
  print "Running: ", " ".join(cmd)
  p = subprocess.Popen(cmd)
  p.communicate()
  return p.returncode

def BuildImage(in_dir, prop_dict, out_file):
  """Build an image to out_file from in_dir with property prop_dict.

  Args:
    in_dir: path of input directory.
    prop_dict: property dictionary.
    out_file: path of the output image file.

  Returns:
    True iff the image is built successfully.
  """
  build_command = []
  fs_type = prop_dict.get("fs_type", "")
  run_fsck = False
  if fs_type.startswith("ext"):
    build_command = ["mkuserimg.sh"]
    if "extfs_sparse_flag" in prop_dict:
      build_command.append(prop_dict["extfs_sparse_flag"])
      run_fsck = True
    build_command.extend([in_dir, out_file, fs_type,
                          prop_dict["mount_point"]])
    if "partition_size" in prop_dict:
      build_command.append(prop_dict["partition_size"])
    if "selinux_fc" in prop_dict:
      build_command.append(prop_dict["selinux_fc"])
  else:
    build_command = ["mkyaffs2image", "-f"]
    if prop_dict.get("mkyaffs2_extra_flags", None):
      build_command.extend(prop_dict["mkyaffs2_extra_flags"].split())
    build_command.append(in_dir)
    build_command.append(out_file)
    if "selinux_fc" in prop_dict:
      build_command.append(prop_dict["selinux_fc"])
      build_command.append(prop_dict["mount_point"])

  exit_code = RunCommand(build_command)
  if exit_code != 0:
    return False

  if run_fsck and prop_dict.get("skip_fsck") != "true":
    # Inflate the sparse image
    unsparse_image = os.path.join(
        os.path.dirname(out_file), "unsparse_" + os.path.basename(out_file))
    inflate_command = ["simg2img", out_file, unsparse_image]
    exit_code = RunCommand(inflate_command)
    if exit_code != 0:
      os.remove(unsparse_image)
      return False

    # Run e2fsck on the inflated image file
    e2fsck_command = ["e2fsck", "-f", "-n", unsparse_image]
    exit_code = RunCommand(e2fsck_command)

    os.remove(unsparse_image)

  return exit_code == 0


def ImagePropFromGlobalDict(glob_dict, mount_point):
  """Build an image property dictionary from the global dictionary.

  Args:
    glob_dict: the global dictionary from the build system.
    mount_point: such as "system", "data" etc.
  """
  d = {}

  def copy_prop(src_p, dest_p):
    if src_p in glob_dict:
      d[dest_p] = str(glob_dict[src_p])

  common_props = (
      "extfs_sparse_flag",
      "mkyaffs2_extra_flags",
      "selinux_fc",
      "skip_fsck",
      )
  for p in common_props:
    copy_prop(p, p)

  d["mount_point"] = mount_point
  if mount_point == "system":
    copy_prop("fs_type", "fs_type")
    copy_prop("system_size", "partition_size")
  elif mount_point == "data":
    copy_prop("fs_type", "fs_type")
    copy_prop("userdata_size", "partition_size")
  elif mount_point == "cache":
    copy_prop("cache_fs_type", "fs_type")
    copy_prop("cache_size", "partition_size")
  elif mount_point == "vendor":
    copy_prop("vendor_fs_type", "fs_type")
    copy_prop("vendor_size", "partition_size")

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


def main(argv):
  if len(argv) != 3:
    print __doc__
    sys.exit(1)

  in_dir = argv[0]
  glob_dict_file = argv[1]
  out_file = argv[2]

  glob_dict = LoadGlobalDict(glob_dict_file)
  image_filename = os.path.basename(out_file)
  mount_point = ""
  if image_filename == "system.img":
    mount_point = "system"
  elif image_filename == "userdata.img":
    mount_point = "data"
  elif image_filename == "cache.img":
    mount_point = "cache"
  elif image_filename == "vendor.img":
    mount_point = "vendor"
  else:
    print >> sys.stderr, "error: unknown image file name ", image_filename
    exit(1)

  image_properties = ImagePropFromGlobalDict(glob_dict, mount_point)
  if not BuildImage(in_dir, image_properties, out_file):
    print >> sys.stderr, "error: failed to build %s from %s" % (out_file, in_dir)
    exit(1)


if __name__ == '__main__':
  main(sys.argv[1:])
