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
import commands
import shutil
import tempfile

FIXED_SALT = "aee087a5be3b982978c923f566a94613496b417f2af592639bc80d141e34dfe7"

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

def GetVerityTreeSize(partition_size):
  cmd = "build_verity_tree -s %d"
  cmd %= partition_size
  status, output = commands.getstatusoutput(cmd)
  if status:
    print output
    return False, 0
  return True, int(output)

def GetVerityMetadataSize(partition_size):
  cmd = "system/extras/verity/build_verity_metadata.py -s %d"
  cmd %= partition_size
  status, output = commands.getstatusoutput(cmd)
  if status:
    print output
    return False, 0
  return True, int(output)

def AdjustPartitionSizeForVerity(partition_size):
  """Modifies the provided partition size to account for the verity metadata.

  This information is used to size the created image appropriately.
  Args:
    partition_size: the size of the partition to be verified.
  Returns:
    The size of the partition adjusted for verity metadata.
  """
  success, verity_tree_size = GetVerityTreeSize(partition_size)
  if not success:
    return 0;
  success, verity_metadata_size = GetVerityMetadataSize(partition_size)
  if not success:
    return 0
  return partition_size - verity_tree_size - verity_metadata_size

def BuildVerityTree(sparse_image_path, verity_image_path, prop_dict):
  cmd = ("build_verity_tree -A %s %s %s" % (FIXED_SALT, sparse_image_path, verity_image_path))
  print cmd
  status, output = commands.getstatusoutput(cmd)
  if status:
    print "Could not build verity tree! Error: %s" % output
    return False
  root, salt = output.split()
  prop_dict["verity_root_hash"] = root
  prop_dict["verity_salt"] = salt
  return True

def BuildVerityMetadata(image_size, verity_metadata_path, root_hash, salt,
                        block_device, signer_path, key):
  cmd = ("system/extras/verity/build_verity_metadata.py %s %s %s %s %s %s %s" %
              (image_size,
              verity_metadata_path,
              root_hash,
              salt,
              block_device,
              signer_path,
              key))
  print cmd
  status, output = commands.getstatusoutput(cmd)
  if status:
    print "Could not build verity metadata! Error: %s" % output
    return False
  return True

def Append2Simg(sparse_image_path, unsparse_image_path, error_message):
  """Appends the unsparse image to the given sparse image.

  Args:
    sparse_image_path: the path to the (sparse) image
    unsparse_image_path: the path to the (unsparse) image
  Returns:
    True on success, False on failure.
  """
  cmd = "append2simg %s %s"
  cmd %= (sparse_image_path, unsparse_image_path)
  print cmd
  status, output = commands.getstatusoutput(cmd)
  if status:
    print "%s: %s" % (error_message, output)
    return False
  return True

def BuildVerifiedImage(data_image_path, verity_image_path, verity_metadata_path):
  if not Append2Simg(data_image_path, verity_metadata_path, "Could not append verity metadata!"):
    return False
  if not Append2Simg(data_image_path, verity_image_path, "Could not append verity tree!"):
    return False
  return True

def UnsparseImage(sparse_image_path, replace=True):
  img_dir = os.path.dirname(sparse_image_path)
  unsparse_image_path = "unsparse_" + os.path.basename(sparse_image_path)
  unsparse_image_path = os.path.join(img_dir, unsparse_image_path)
  if os.path.exists(unsparse_image_path):
    if replace:
      os.unlink(unsparse_image_path)
    else:
      return True, unsparse_image_path
  inflate_command = ["simg2img", sparse_image_path, unsparse_image_path]
  exit_code = RunCommand(inflate_command)
  if exit_code != 0:
    os.remove(unsparse_image_path)
    return False, None
  return True, unsparse_image_path

def MakeVerityEnabledImage(out_file, prop_dict):
  """Creates an image that is verifiable using dm-verity.

  Args:
    out_file: the location to write the verifiable image at
    prop_dict: a dictionary of properties required for image creation and verification
  Returns:
    True on success, False otherwise.
  """
  # get properties
  image_size = prop_dict["partition_size"]
  block_dev = prop_dict["verity_block_device"]
  signer_key = prop_dict["verity_key"] + ".pk8"
  signer_path = prop_dict["verity_signer_cmd"]

  # make a tempdir
  tempdir_name = tempfile.mkdtemp(suffix="_verity_images")

  # get partial image paths
  verity_image_path = os.path.join(tempdir_name, "verity.img")
  verity_metadata_path = os.path.join(tempdir_name, "verity_metadata.img")

  # build the verity tree and get the root hash and salt
  if not BuildVerityTree(out_file, verity_image_path, prop_dict):
    shutil.rmtree(tempdir_name, ignore_errors=True)
    return False

  # build the metadata blocks
  root_hash = prop_dict["verity_root_hash"]
  salt = prop_dict["verity_salt"]
  if not BuildVerityMetadata(image_size,
                              verity_metadata_path,
                              root_hash,
                              salt,
                              block_dev,
                              signer_path,
                              signer_key):
    shutil.rmtree(tempdir_name, ignore_errors=True)
    return False

  # build the full verified image
  if not BuildVerifiedImage(out_file,
                            verity_image_path,
                            verity_metadata_path):
    shutil.rmtree(tempdir_name, ignore_errors=True)
    return False

  shutil.rmtree(tempdir_name, ignore_errors=True)
  return True

def BuildImage(in_dir, prop_dict, out_file,
               fs_config=None,
               fc_config=None,
               block_list=None):
  """Build an image to out_file from in_dir with property prop_dict.

  Args:
    in_dir: path of input directory.
    prop_dict: property dictionary.
    out_file: path of the output image file.
    fs_config: path to the fs_config file (typically
      META/filesystem_config.txt).  If None then the configuration in
      the local client will be used.
    fc_config: path to the SELinux file_contexts file.  If None then
      the value from prop_dict['selinux_fc'] will be used.

  Returns:
    True iff the image is built successfully.
  """
  build_command = []
  fs_type = prop_dict.get("fs_type", "")
  run_fsck = False

  is_verity_partition = "verity_block_device" in prop_dict
  verity_supported = prop_dict.get("verity") == "true"
  # adjust the partition size to make room for the hashes if this is to be verified
  if verity_supported and is_verity_partition:
    partition_size = int(prop_dict.get("partition_size"))
    adjusted_size = AdjustPartitionSizeForVerity(partition_size)
    if not adjusted_size:
      return False
    prop_dict["partition_size"] = str(adjusted_size)
    prop_dict["original_partition_size"] = str(partition_size)

  if fs_type.startswith("ext"):
    build_command = ["mkuserimg.sh"]
    if "extfs_sparse_flag" in prop_dict:
      build_command.append(prop_dict["extfs_sparse_flag"])
      run_fsck = True
    build_command.extend([in_dir, out_file, fs_type,
                          prop_dict["mount_point"]])
    build_command.append(prop_dict["partition_size"])
    if "journal_size" in prop_dict:
      build_command.extend(["-j", prop_dict["journal_size"]])
    if "timestamp" in prop_dict:
      build_command.extend(["-T", str(prop_dict["timestamp"])])
    if fs_config is not None:
      build_command.extend(["-C", fs_config])
    if block_list is not None:
      build_command.extend(["-B", block_list])
    if fc_config is not None:
      build_command.append(fc_config)
    elif "selinux_fc" in prop_dict:
      build_command.append(prop_dict["selinux_fc"])
  elif fs_type.startswith("f2fs"):
    build_command = ["mkf2fsuserimg.sh"]
    build_command.extend([out_file, prop_dict["partition_size"]])
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

  # create the verified image if this is to be verified
  if verity_supported and is_verity_partition:
    if not MakeVerityEnabledImage(out_file, prop_dict):
      return False

  if run_fsck and prop_dict.get("skip_fsck") != "true":
    success, unsparse_image = UnsparseImage(out_file, replace=False)
    if not success:
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
  if "build.prop" in glob_dict:
    bp = glob_dict["build.prop"]
    if "ro.build.date.utc" in bp:
      d["timestamp"] = bp["ro.build.date.utc"]

  def copy_prop(src_p, dest_p):
    if src_p in glob_dict:
      d[dest_p] = str(glob_dict[src_p])

  common_props = (
      "extfs_sparse_flag",
      "mkyaffs2_extra_flags",
      "selinux_fc",
      "skip_fsck",
      "verity",
      "verity_key",
      "verity_signer_cmd"
      )
  for p in common_props:
    copy_prop(p, p)

  d["mount_point"] = mount_point
  if mount_point == "system":
    copy_prop("fs_type", "fs_type")
    copy_prop("system_size", "partition_size")
    copy_prop("system_journal_size", "journal_size")
    copy_prop("system_verity_block_device", "verity_block_device")
  elif mount_point == "data":
    # Copy the generic fs type first, override with specific one if available.
    copy_prop("fs_type", "fs_type")
    copy_prop("userdata_fs_type", "fs_type")
    copy_prop("userdata_size", "partition_size")
  elif mount_point == "cache":
    copy_prop("cache_fs_type", "fs_type")
    copy_prop("cache_size", "partition_size")
  elif mount_point == "vendor":
    copy_prop("vendor_fs_type", "fs_type")
    copy_prop("vendor_size", "partition_size")
    copy_prop("vendor_journal_size", "journal_size")
    copy_prop("vendor_verity_block_device", "verity_block_device")
  elif mount_point == "oem":
    copy_prop("fs_type", "fs_type")
    copy_prop("oem_size", "partition_size")
    copy_prop("oem_journal_size", "journal_size")

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
  elif image_filename == "oem.img":
    mount_point = "oem"
  else:
    print >> sys.stderr, "error: unknown image file name ", image_filename
    exit(1)

  image_properties = ImagePropFromGlobalDict(glob_dict, mount_point)
  if not BuildImage(in_dir, image_properties, out_file):
    print >> sys.stderr, "error: failed to build %s from %s" % (out_file, in_dir)
    exit(1)


if __name__ == '__main__':
  main(sys.argv[1:])
