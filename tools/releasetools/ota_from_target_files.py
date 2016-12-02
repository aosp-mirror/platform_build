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
Given a target-files zipfile, produces an OTA package that installs
that build.  An incremental OTA is produced if -i is given, otherwise
a full OTA is produced.

Usage:  ota_from_target_files [flags] input_target_files output_ota_package

  --board_config  <file>
      Deprecated.

  -k (--package_key) <key> Key to use to sign the package (default is
      the value of default_system_dev_certificate from the input
      target-files's META/misc_info.txt, or
      "build/target/product/security/testkey" if that value is not
      specified).

      For incremental OTAs, the default value is based on the source
      target-file, not the target build.

  -i  (--incremental_from)  <file>
      Generate an incremental OTA using the given target-files zip as
      the starting build.

  --full_radio
      When generating an incremental OTA, always include a full copy of
      radio image. This option is only meaningful when -i is specified,
      because a full radio is always included in a full OTA if applicable.

  --full_bootloader
      Similar to --full_radio. When generating an incremental OTA, always
      include a full copy of bootloader image.

  -v  (--verify)
      Remount and verify the checksums of the files written to the
      system and vendor (if used) partitions.  Incremental builds only.

  -o  (--oem_settings)  <file>
      Use the file to specify the expected OEM-specific properties
      on the OEM partition of the intended device.

  --oem_no_mount
      For devices with OEM-specific properties but without an OEM partition,
      do not mount the OEM partition in the updater-script. This should be
      very rarely used, since it's expected to have a dedicated OEM partition
      for OEM-specific properties. Only meaningful when -o is specified.

  -w  (--wipe_user_data)
      Generate an OTA package that will wipe the user data partition
      when installed.

  -n  (--no_prereq)
      Omit the timestamp prereq check normally included at the top of
      the build scripts (used for developer OTA packages which
      legitimately need to go back and forth).

  --downgrade
      Intentionally generate an incremental OTA that updates from a newer
      build to an older one (based on timestamp comparison). "post-timestamp"
      will be replaced by "ota-downgrade=yes" in the metadata file. A data
      wipe will always be enforced, so "ota-wipe=yes" will also be included in
      the metadata file. The update-binary in the source build will be used in
      the OTA package, unless --binary flag is specified.

  -e  (--extra_script)  <file>
      Insert the contents of file at the end of the update script.

  -a  (--aslr_mode)  <on|off>
      Specify whether to turn on ASLR for the package (on by default).

  -2  (--two_step)
      Generate a 'two-step' OTA package, where recovery is updated
      first, so that any changes made to the system partition are done
      using the new recovery (new kernel, etc.).

  --block
      Generate a block-based OTA if possible.  Will fall back to a
      file-based OTA if the target_files is older and doesn't support
      block-based OTAs.

  -b  (--binary)  <file>
      Use the given binary as the update-binary in the output package,
      instead of the binary in the build's target_files.  Use for
      development only.

  -t  (--worker_threads) <int>
      Specifies the number of worker-threads that will be used when
      generating patches for incremental updates (defaults to 3).

  --stash_threshold <float>
      Specifies the threshold that will be used to compute the maximum
      allowed stash size (defaults to 0.8).

  --gen_verify
      Generate an OTA package that verifies the partitions.

  --log_diff <file>
      Generate a log file that shows the differences in the source and target
      builds for an incremental package. This option is only meaningful when
      -i is specified.

  --payload_signer <signer>
      Specify the signer when signing the payload and metadata for A/B OTAs.
      By default (i.e. without this flag), it calls 'openssl pkeyutl' to sign
      with the package private key. If the private key cannot be accessed
      directly, a payload signer that knows how to do that should be specified.
      The signer will be supplied with "-inkey <path_to_key>",
      "-in <input_file>" and "-out <output_file>" parameters.

  --payload_signer_args <args>
      Specify the arguments needed for payload signer.
"""

import sys

if sys.hexversion < 0x02070000:
  print >> sys.stderr, "Python 2.7 or newer is required."
  sys.exit(1)

import multiprocessing
import os
import subprocess
import shlex
import tempfile
import zipfile

import common
import edify_generator
import sparse_img

OPTIONS = common.OPTIONS
OPTIONS.package_key = None
OPTIONS.incremental_source = None
OPTIONS.verify = False
OPTIONS.require_verbatim = set()
OPTIONS.prohibit_verbatim = set(("system/build.prop",))
OPTIONS.patch_threshold = 0.95
OPTIONS.wipe_user_data = False
OPTIONS.omit_prereq = False
OPTIONS.downgrade = False
OPTIONS.extra_script = None
OPTIONS.aslr_mode = True
OPTIONS.worker_threads = multiprocessing.cpu_count() // 2
if OPTIONS.worker_threads == 0:
  OPTIONS.worker_threads = 1
OPTIONS.two_step = False
OPTIONS.no_signing = False
OPTIONS.block_based = False
OPTIONS.updater_binary = None
OPTIONS.oem_source = None
OPTIONS.oem_no_mount = False
OPTIONS.fallback_to_full = True
OPTIONS.full_radio = False
OPTIONS.full_bootloader = False
# Stash size cannot exceed cache_size * threshold.
OPTIONS.cache_size = None
OPTIONS.stash_threshold = 0.8
OPTIONS.gen_verify = False
OPTIONS.log_diff = None
OPTIONS.payload_signer = None
OPTIONS.payload_signer_args = []

def MostPopularKey(d, default):
  """Given a dict, return the key corresponding to the largest
  value.  Returns 'default' if the dict is empty."""
  x = [(v, k) for (k, v) in d.iteritems()]
  if not x:
    return default
  x.sort()
  return x[-1][1]


def IsSymlink(info):
  """Return true if the zipfile.ZipInfo object passed in represents a
  symlink."""
  return (info.external_attr >> 16) & 0o770000 == 0o120000

def IsRegular(info):
  """Return true if the zipfile.ZipInfo object passed in represents a
  regular file."""
  return (info.external_attr >> 16) & 0o770000 == 0o100000

def ClosestFileMatch(src, tgtfiles, existing):
  """Returns the closest file match between a source file and list
     of potential matches.  The exact filename match is preferred,
     then the sha1 is searched for, and finally a file with the same
     basename is evaluated.  Rename support in the updater-binary is
     required for the latter checks to be used."""

  result = tgtfiles.get("path:" + src.name)
  if result is not None:
    return result

  if not OPTIONS.target_info_dict.get("update_rename_support", False):
    return None

  if src.size < 1000:
    return None

  result = tgtfiles.get("sha1:" + src.sha1)
  if result is not None and existing.get(result.name) is None:
    return result
  result = tgtfiles.get("file:" + src.name.split("/")[-1])
  if result is not None and existing.get(result.name) is None:
    return result
  return None

class ItemSet(object):
  def __init__(self, partition, fs_config):
    self.partition = partition
    self.fs_config = fs_config
    self.ITEMS = {}

  def Get(self, name, is_dir=False):
    if name not in self.ITEMS:
      self.ITEMS[name] = Item(self, name, is_dir=is_dir)
    return self.ITEMS[name]

  def GetMetadata(self, input_zip):
    # The target_files contains a record of what the uid,
    # gid, and mode are supposed to be.
    output = input_zip.read(self.fs_config)

    for line in output.split("\n"):
      if not line:
        continue
      columns = line.split()
      name, uid, gid, mode = columns[:4]
      selabel = None
      capabilities = None

      # After the first 4 columns, there are a series of key=value
      # pairs. Extract out the fields we care about.
      for element in columns[4:]:
        key, value = element.split("=")
        if key == "selabel":
          selabel = value
        if key == "capabilities":
          capabilities = value

      i = self.ITEMS.get(name, None)
      if i is not None:
        i.uid = int(uid)
        i.gid = int(gid)
        i.mode = int(mode, 8)
        i.selabel = selabel
        i.capabilities = capabilities
        if i.is_dir:
          i.children.sort(key=lambda i: i.name)

    # Set metadata for the files generated by this script. For full recovery
    # image at system/etc/recovery.img, it will be taken care by fs_config.
    i = self.ITEMS.get("system/recovery-from-boot.p", None)
    if i:
      i.uid, i.gid, i.mode, i.selabel, i.capabilities = 0, 0, 0o644, None, None
    i = self.ITEMS.get("system/etc/install-recovery.sh", None)
    if i:
      i.uid, i.gid, i.mode, i.selabel, i.capabilities = 0, 0, 0o544, None, None


class Item(object):
  """Items represent the metadata (user, group, mode) of files and
  directories in the system image."""
  def __init__(self, itemset, name, is_dir=False):
    self.itemset = itemset
    self.name = name
    self.uid = None
    self.gid = None
    self.mode = None
    self.selabel = None
    self.capabilities = None
    self.is_dir = is_dir
    self.descendants = None
    self.best_subtree = None

    if name:
      self.parent = itemset.Get(os.path.dirname(name), is_dir=True)
      self.parent.children.append(self)
    else:
      self.parent = None
    if self.is_dir:
      self.children = []

  def Dump(self, indent=0):
    if self.uid is not None:
      print "%s%s %d %d %o" % (
          "  " * indent, self.name, self.uid, self.gid, self.mode)
    else:
      print "%s%s %s %s %s" % (
          "  " * indent, self.name, self.uid, self.gid, self.mode)
    if self.is_dir:
      print "%s%s" % ("  "*indent, self.descendants)
      print "%s%s" % ("  "*indent, self.best_subtree)
      for i in self.children:
        i.Dump(indent=indent+1)

  def CountChildMetadata(self):
    """Count up the (uid, gid, mode, selabel, capabilities) tuples for
    all children and determine the best strategy for using set_perm_recursive
    and set_perm to correctly chown/chmod all the files to their desired
    values.  Recursively calls itself for all descendants.

    Returns a dict of {(uid, gid, dmode, fmode, selabel, capabilities): count}
    counting up all descendants of this node.  (dmode or fmode may be None.)
    Also sets the best_subtree of each directory Item to the (uid, gid, dmode,
    fmode, selabel, capabilities) tuple that will match the most descendants of
    that Item.
    """

    assert self.is_dir
    key = (self.uid, self.gid, self.mode, None, self.selabel,
           self.capabilities)
    self.descendants = {key: 1}
    d = self.descendants
    for i in self.children:
      if i.is_dir:
        for k, v in i.CountChildMetadata().iteritems():
          d[k] = d.get(k, 0) + v
      else:
        k = (i.uid, i.gid, None, i.mode, i.selabel, i.capabilities)
        d[k] = d.get(k, 0) + 1

    # Find the (uid, gid, dmode, fmode, selabel, capabilities)
    # tuple that matches the most descendants.

    # First, find the (uid, gid) pair that matches the most
    # descendants.
    ug = {}
    for (uid, gid, _, _, _, _), count in d.iteritems():
      ug[(uid, gid)] = ug.get((uid, gid), 0) + count
    ug = MostPopularKey(ug, (0, 0))

    # Now find the dmode, fmode, selabel, and capabilities that match
    # the most descendants with that (uid, gid), and choose those.
    best_dmode = (0, 0o755)
    best_fmode = (0, 0o644)
    best_selabel = (0, None)
    best_capabilities = (0, None)
    for k, count in d.iteritems():
      if k[:2] != ug:
        continue
      if k[2] is not None and count >= best_dmode[0]:
        best_dmode = (count, k[2])
      if k[3] is not None and count >= best_fmode[0]:
        best_fmode = (count, k[3])
      if k[4] is not None and count >= best_selabel[0]:
        best_selabel = (count, k[4])
      if k[5] is not None and count >= best_capabilities[0]:
        best_capabilities = (count, k[5])
    self.best_subtree = ug + (
        best_dmode[1], best_fmode[1], best_selabel[1], best_capabilities[1])

    return d

  def SetPermissions(self, script):
    """Append set_perm/set_perm_recursive commands to 'script' to
    set all permissions, users, and groups for the tree of files
    rooted at 'self'."""

    self.CountChildMetadata()

    def recurse(item, current):
      # current is the (uid, gid, dmode, fmode, selabel, capabilities) tuple
      # that the current item (and all its children) have already been set to.
      # We only need to issue set_perm/set_perm_recursive commands if we're
      # supposed to be something different.
      if item.is_dir:
        if current != item.best_subtree:
          script.SetPermissionsRecursive("/"+item.name, *item.best_subtree)
          current = item.best_subtree

        if item.uid != current[0] or item.gid != current[1] or \
           item.mode != current[2] or item.selabel != current[4] or \
           item.capabilities != current[5]:
          script.SetPermissions("/"+item.name, item.uid, item.gid,
                                item.mode, item.selabel, item.capabilities)

        for i in item.children:
          recurse(i, current)
      else:
        if item.uid != current[0] or item.gid != current[1] or \
               item.mode != current[3] or item.selabel != current[4] or \
               item.capabilities != current[5]:
          script.SetPermissions("/"+item.name, item.uid, item.gid,
                                item.mode, item.selabel, item.capabilities)

    recurse(self, (-1, -1, -1, -1, None, None))


def CopyPartitionFiles(itemset, input_zip, output_zip=None, substitute=None):
  """Copies files for the partition in the input zip to the output
  zip.  Populates the Item class with their metadata, and returns a
  list of symlinks.  output_zip may be None, in which case the copy is
  skipped (but the other side effects still happen).  substitute is an
  optional dict of {output filename: contents} to be output instead of
  certain input files.
  """

  symlinks = []

  partition = itemset.partition

  for info in input_zip.infolist():
    prefix = partition.upper() + "/"
    if info.filename.startswith(prefix):
      basefilename = info.filename[len(prefix):]
      if IsSymlink(info):
        symlinks.append((input_zip.read(info.filename),
                         "/" + partition + "/" + basefilename))
      else:
        import copy
        info2 = copy.copy(info)
        fn = info2.filename = partition + "/" + basefilename
        if substitute and fn in substitute and substitute[fn] is None:
          continue
        if output_zip is not None:
          if substitute and fn in substitute:
            data = substitute[fn]
          else:
            data = input_zip.read(info.filename)
          common.ZipWriteStr(output_zip, info2, data)
        if fn.endswith("/"):
          itemset.Get(fn[:-1], is_dir=True)
        else:
          itemset.Get(fn)

  symlinks.sort()
  return symlinks


def SignOutput(temp_zip_name, output_zip_name):
  key_passwords = common.GetKeyPasswords([OPTIONS.package_key])
  pw = key_passwords[OPTIONS.package_key]

  common.SignFile(temp_zip_name, output_zip_name, OPTIONS.package_key, pw,
                  whole_file=True)


def AppendAssertions(script, info_dict, oem_dict=None):
  oem_props = info_dict.get("oem_fingerprint_properties")
  if oem_props is None or len(oem_props) == 0:
    device = GetBuildProp("ro.product.device", info_dict)
    script.AssertDevice(device)
  else:
    if oem_dict is None:
      raise common.ExternalError(
          "No OEM file provided to answer expected assertions")
    for prop in oem_props.split():
      if oem_dict.get(prop) is None:
        raise common.ExternalError(
            "The OEM file is missing the property %s" % prop)
      script.AssertOemProperty(prop, oem_dict.get(prop))


def _WriteRecoveryImageToBoot(script, output_zip):
  """Find and write recovery image to /boot in two-step OTA.

  In two-step OTAs, we write recovery image to /boot as the first step so that
  we can reboot to there and install a new recovery image to /recovery.
  A special "recovery-two-step.img" will be preferred, which encodes the correct
  path of "/boot". Otherwise the device may show "device is corrupt" message
  when booting into /boot.

  Fall back to using the regular recovery.img if the two-step recovery image
  doesn't exist. Note that rebuilding the special image at this point may be
  infeasible, because we don't have the desired boot signer and keys when
  calling ota_from_target_files.py.
  """

  recovery_two_step_img_name = "recovery-two-step.img"
  recovery_two_step_img_path = os.path.join(
      OPTIONS.input_tmp, "IMAGES", recovery_two_step_img_name)
  if os.path.exists(recovery_two_step_img_path):
    recovery_two_step_img = common.GetBootableImage(
        recovery_two_step_img_name, recovery_two_step_img_name,
        OPTIONS.input_tmp, "RECOVERY")
    common.ZipWriteStr(
        output_zip, recovery_two_step_img_name, recovery_two_step_img.data)
    print "two-step package: using %s in stage 1/3" % (
        recovery_two_step_img_name,)
    script.WriteRawImage("/boot", recovery_two_step_img_name)
  else:
    print "two-step package: using recovery.img in stage 1/3"
    # The "recovery.img" entry has been written into package earlier.
    script.WriteRawImage("/boot", "recovery.img")


def HasRecoveryPatch(target_files_zip):
  namelist = [name for name in target_files_zip.namelist()]
  return ("SYSTEM/recovery-from-boot.p" in namelist or
          "SYSTEM/etc/recovery.img" in namelist)

def HasVendorPartition(target_files_zip):
  try:
    target_files_zip.getinfo("VENDOR/")
    return True
  except KeyError:
    return False

def GetOemProperty(name, oem_props, oem_dict, info_dict):
  if oem_props is not None and name in oem_props:
    return oem_dict[name]
  return GetBuildProp(name, info_dict)


def CalculateFingerprint(oem_props, oem_dict, info_dict):
  if oem_props is None:
    return GetBuildProp("ro.build.fingerprint", info_dict)
  return "%s/%s/%s:%s" % (
      GetOemProperty("ro.product.brand", oem_props, oem_dict, info_dict),
      GetOemProperty("ro.product.name", oem_props, oem_dict, info_dict),
      GetOemProperty("ro.product.device", oem_props, oem_dict, info_dict),
      GetBuildProp("ro.build.thumbprint", info_dict))


def GetImage(which, tmpdir, info_dict):
  # Return an image object (suitable for passing to BlockImageDiff)
  # for the 'which' partition (most be "system" or "vendor").  If a
  # prebuilt image and file map are found in tmpdir they are used,
  # otherwise they are reconstructed from the individual files.

  assert which in ("system", "vendor")

  path = os.path.join(tmpdir, "IMAGES", which + ".img")
  mappath = os.path.join(tmpdir, "IMAGES", which + ".map")
  if os.path.exists(path) and os.path.exists(mappath):
    print "using %s.img from target-files" % (which,)
    # This is a 'new' target-files, which already has the image in it.

  else:
    print "building %s.img from target-files" % (which,)

    # This is an 'old' target-files, which does not contain images
    # already built.  Build them.

    mappath = tempfile.mkstemp()[1]
    OPTIONS.tempfiles.append(mappath)

    import add_img_to_target_files
    if which == "system":
      path = add_img_to_target_files.BuildSystem(
          tmpdir, info_dict, block_list=mappath)
    elif which == "vendor":
      path = add_img_to_target_files.BuildVendor(
          tmpdir, info_dict, block_list=mappath)

  # Bug: http://b/20939131
  # In ext4 filesystems, block 0 might be changed even being mounted
  # R/O. We add it to clobbered_blocks so that it will be written to the
  # target unconditionally. Note that they are still part of care_map.
  clobbered_blocks = "0"

  return sparse_img.SparseImage(path, mappath, clobbered_blocks)


def WriteFullOTAPackage(input_zip, output_zip):
  # TODO: how to determine this?  We don't know what version it will
  # be installed on top of. For now, we expect the API just won't
  # change very often. Similarly for fstab, it might have changed
  # in the target build.
  script = edify_generator.EdifyGenerator(3, OPTIONS.info_dict)

  oem_props = OPTIONS.info_dict.get("oem_fingerprint_properties")
  recovery_mount_options = OPTIONS.info_dict.get("recovery_mount_options")
  oem_dict = None
  if oem_props is not None and len(oem_props) > 0:
    if OPTIONS.oem_source is None:
      raise common.ExternalError("OEM source required for this build")
    if not OPTIONS.oem_no_mount:
      script.Mount("/oem", recovery_mount_options)
    oem_dict = common.LoadDictionaryFromLines(
        open(OPTIONS.oem_source).readlines())

  metadata = {
      "post-build": CalculateFingerprint(oem_props, oem_dict,
                                         OPTIONS.info_dict),
      "pre-device": GetOemProperty("ro.product.device", oem_props, oem_dict,
                                   OPTIONS.info_dict),
      "post-timestamp": GetBuildProp("ro.build.date.utc", OPTIONS.info_dict),
  }

  device_specific = common.DeviceSpecificParams(
      input_zip=input_zip,
      input_version=OPTIONS.info_dict["recovery_api_version"],
      output_zip=output_zip,
      script=script,
      input_tmp=OPTIONS.input_tmp,
      metadata=metadata,
      info_dict=OPTIONS.info_dict)

  has_recovery_patch = HasRecoveryPatch(input_zip)
  block_based = OPTIONS.block_based and has_recovery_patch

  metadata["ota-type"] = "BLOCK" if block_based else "FILE"

  if not OPTIONS.omit_prereq:
    ts = GetBuildProp("ro.build.date.utc", OPTIONS.info_dict)
    ts_text = GetBuildProp("ro.build.date", OPTIONS.info_dict)
    script.AssertOlderBuild(ts, ts_text)

  AppendAssertions(script, OPTIONS.info_dict, oem_dict)
  device_specific.FullOTA_Assertions()

  # Two-step package strategy (in chronological order, which is *not*
  # the order in which the generated script has things):
  #
  # if stage is not "2/3" or "3/3":
  #    write recovery image to boot partition
  #    set stage to "2/3"
  #    reboot to boot partition and restart recovery
  # else if stage is "2/3":
  #    write recovery image to recovery partition
  #    set stage to "3/3"
  #    reboot to recovery partition and restart recovery
  # else:
  #    (stage must be "3/3")
  #    set stage to ""
  #    do normal full package installation:
  #       wipe and install system, boot image, etc.
  #       set up system to update recovery partition on first boot
  #    complete script normally
  #    (allow recovery to mark itself finished and reboot)

  recovery_img = common.GetBootableImage("recovery.img", "recovery.img",
                                         OPTIONS.input_tmp, "RECOVERY")
  if OPTIONS.two_step:
    if not OPTIONS.info_dict.get("multistage_support", None):
      assert False, "two-step packages not supported by this build"
    fs = OPTIONS.info_dict["fstab"]["/misc"]
    assert fs.fs_type.upper() == "EMMC", \
        "two-step packages only supported on devices with EMMC /misc partitions"
    bcb_dev = {"bcb_dev": fs.device}
    common.ZipWriteStr(output_zip, "recovery.img", recovery_img.data)
    script.AppendExtra("""
if get_stage("%(bcb_dev)s") == "2/3" then
""" % bcb_dev)

    # Stage 2/3: Write recovery image to /recovery (currently running /boot).
    script.Comment("Stage 2/3")
    script.WriteRawImage("/recovery", "recovery.img")
    script.AppendExtra("""
set_stage("%(bcb_dev)s", "3/3");
reboot_now("%(bcb_dev)s", "recovery");
else if get_stage("%(bcb_dev)s") == "3/3" then
""" % bcb_dev)

    # Stage 3/3: Make changes.
    script.Comment("Stage 3/3")

  # Dump fingerprints
  script.Print("Target: %s" % CalculateFingerprint(
      oem_props, oem_dict, OPTIONS.info_dict))

  device_specific.FullOTA_InstallBegin()

  system_progress = 0.75

  if OPTIONS.wipe_user_data:
    system_progress -= 0.1
  if HasVendorPartition(input_zip):
    system_progress -= 0.1

  # Place a copy of file_contexts.bin into the OTA package which will be used
  # by the recovery program.
  if "selinux_fc" in OPTIONS.info_dict:
    WritePolicyConfig(OPTIONS.info_dict["selinux_fc"], output_zip)

  recovery_mount_options = OPTIONS.info_dict.get("recovery_mount_options")

  system_items = ItemSet("system", "META/filesystem_config.txt")
  script.ShowProgress(system_progress, 0)

  if block_based:
    # Full OTA is done as an "incremental" against an empty source
    # image.  This has the effect of writing new data from the package
    # to the entire partition, but lets us reuse the updater code that
    # writes incrementals to do it.
    system_tgt = GetImage("system", OPTIONS.input_tmp, OPTIONS.info_dict)
    system_tgt.ResetFileMap()
    system_diff = common.BlockDifference("system", system_tgt, src=None)
    system_diff.WriteScript(script, output_zip)
  else:
    script.FormatPartition("/system")
    script.Mount("/system", recovery_mount_options)
    if not has_recovery_patch:
      script.UnpackPackageDir("recovery", "/system")
    script.UnpackPackageDir("system", "/system")

    symlinks = CopyPartitionFiles(system_items, input_zip, output_zip)
    script.MakeSymlinks(symlinks)

  boot_img = common.GetBootableImage(
      "boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")

  if not block_based:
    def output_sink(fn, data):
      common.ZipWriteStr(output_zip, "recovery/" + fn, data)
      system_items.Get("system/" + fn)

    common.MakeRecoveryPatch(OPTIONS.input_tmp, output_sink,
                             recovery_img, boot_img)

    system_items.GetMetadata(input_zip)
    system_items.Get("system").SetPermissions(script)

  if HasVendorPartition(input_zip):
    vendor_items = ItemSet("vendor", "META/vendor_filesystem_config.txt")
    script.ShowProgress(0.1, 0)

    if block_based:
      vendor_tgt = GetImage("vendor", OPTIONS.input_tmp, OPTIONS.info_dict)
      vendor_tgt.ResetFileMap()
      vendor_diff = common.BlockDifference("vendor", vendor_tgt)
      vendor_diff.WriteScript(script, output_zip)
    else:
      script.FormatPartition("/vendor")
      script.Mount("/vendor", recovery_mount_options)
      script.UnpackPackageDir("vendor", "/vendor")

      symlinks = CopyPartitionFiles(vendor_items, input_zip, output_zip)
      script.MakeSymlinks(symlinks)

      vendor_items.GetMetadata(input_zip)
      vendor_items.Get("vendor").SetPermissions(script)

  common.CheckSize(boot_img.data, "boot.img", OPTIONS.info_dict)
  common.ZipWriteStr(output_zip, "boot.img", boot_img.data)

  script.ShowProgress(0.05, 5)
  script.WriteRawImage("/boot", "boot.img")

  script.ShowProgress(0.2, 10)
  device_specific.FullOTA_InstallEnd()

  if OPTIONS.extra_script is not None:
    script.AppendExtra(OPTIONS.extra_script)

  script.UnmountAll()

  if OPTIONS.wipe_user_data:
    script.ShowProgress(0.1, 10)
    script.FormatPartition("/data")

  if OPTIONS.two_step:
    script.AppendExtra("""
set_stage("%(bcb_dev)s", "");
""" % bcb_dev)
    script.AppendExtra("else\n")

    # Stage 1/3: Nothing to verify for full OTA. Write recovery image to /boot.
    script.Comment("Stage 1/3")
    _WriteRecoveryImageToBoot(script, output_zip)

    script.AppendExtra("""
set_stage("%(bcb_dev)s", "2/3");
reboot_now("%(bcb_dev)s", "");
endif;
endif;
""" % bcb_dev)

  script.SetProgress(1)
  script.AddToZip(input_zip, output_zip, input_path=OPTIONS.updater_binary)
  metadata["ota-required-cache"] = str(script.required_cache)
  WriteMetadata(metadata, output_zip)


def WritePolicyConfig(file_name, output_zip):
  common.ZipWrite(output_zip, file_name, os.path.basename(file_name))


def WriteMetadata(metadata, output_zip):
  common.ZipWriteStr(output_zip, "META-INF/com/android/metadata",
                     "".join(["%s=%s\n" % kv
                              for kv in sorted(metadata.iteritems())]))


def LoadPartitionFiles(z, partition):
  """Load all the files from the given partition in a given target-files
  ZipFile, and return a dict of {filename: File object}."""
  out = {}
  prefix = partition.upper() + "/"
  for info in z.infolist():
    if info.filename.startswith(prefix) and not IsSymlink(info):
      basefilename = info.filename[len(prefix):]
      fn = partition + "/" + basefilename
      data = z.read(info.filename)
      out[fn] = common.File(fn, data)
  return out


def GetBuildProp(prop, info_dict):
  """Return the fingerprint of the build of a given target-files info_dict."""
  try:
    return info_dict.get("build.prop", {})[prop]
  except KeyError:
    raise common.ExternalError("couldn't find %s in build.prop" % (prop,))


def AddToKnownPaths(filename, known_paths):
  if filename[-1] == "/":
    return
  dirs = filename.split("/")[:-1]
  while len(dirs) > 0:
    path = "/".join(dirs)
    if path in known_paths:
      break
    known_paths.add(path)
    dirs.pop()


def WriteBlockIncrementalOTAPackage(target_zip, source_zip, output_zip):
  # TODO(tbao): We should factor out the common parts between
  # WriteBlockIncrementalOTAPackage() and WriteIncrementalOTAPackage().
  source_version = OPTIONS.source_info_dict["recovery_api_version"]
  target_version = OPTIONS.target_info_dict["recovery_api_version"]

  if source_version == 0:
    print ("WARNING: generating edify script for a source that "
           "can't install it.")
  script = edify_generator.EdifyGenerator(
      source_version, OPTIONS.target_info_dict,
      fstab=OPTIONS.source_info_dict["fstab"])

  oem_props = OPTIONS.info_dict.get("oem_fingerprint_properties")
  recovery_mount_options = OPTIONS.source_info_dict.get(
      "recovery_mount_options")
  oem_dict = None
  if oem_props is not None and len(oem_props) > 0:
    if OPTIONS.oem_source is None:
      raise common.ExternalError("OEM source required for this build")
    if not OPTIONS.oem_no_mount:
      script.Mount("/oem", recovery_mount_options)
    oem_dict = common.LoadDictionaryFromLines(
        open(OPTIONS.oem_source).readlines())

  metadata = {
      "pre-device": GetOemProperty("ro.product.device", oem_props, oem_dict,
                                   OPTIONS.source_info_dict),
      "ota-type": "BLOCK",
  }

  post_timestamp = GetBuildProp("ro.build.date.utc", OPTIONS.target_info_dict)
  pre_timestamp = GetBuildProp("ro.build.date.utc", OPTIONS.source_info_dict)
  is_downgrade = long(post_timestamp) < long(pre_timestamp)

  if OPTIONS.downgrade:
    metadata["ota-downgrade"] = "yes"
    if not is_downgrade:
      raise RuntimeError("--downgrade specified but no downgrade detected: "
                         "pre: %s, post: %s" % (pre_timestamp, post_timestamp))
  else:
    if is_downgrade:
      # Non-fatal here to allow generating such a package which may require
      # manual work to adjust the post-timestamp. A legit use case is that we
      # cut a new build C (after having A and B), but want to enfore the
      # update path of A -> C -> B. Specifying --downgrade may not help since
      # that would enforce a data wipe for C -> B update.
      print("\nWARNING: downgrade detected: pre: %s, post: %s.\n"
            "The package may not be deployed properly. "
            "Try --downgrade?\n" % (pre_timestamp, post_timestamp))
    metadata["post-timestamp"] = post_timestamp

  device_specific = common.DeviceSpecificParams(
      source_zip=source_zip,
      source_version=source_version,
      target_zip=target_zip,
      target_version=target_version,
      output_zip=output_zip,
      script=script,
      metadata=metadata,
      info_dict=OPTIONS.source_info_dict)

  source_fp = CalculateFingerprint(oem_props, oem_dict,
                                   OPTIONS.source_info_dict)
  target_fp = CalculateFingerprint(oem_props, oem_dict,
                                   OPTIONS.target_info_dict)
  metadata["pre-build"] = source_fp
  metadata["post-build"] = target_fp
  metadata["pre-build-incremental"] = GetBuildProp(
      "ro.build.version.incremental", OPTIONS.source_info_dict)
  metadata["post-build-incremental"] = GetBuildProp(
      "ro.build.version.incremental", OPTIONS.target_info_dict)

  source_boot = common.GetBootableImage(
      "/tmp/boot.img", "boot.img", OPTIONS.source_tmp, "BOOT",
      OPTIONS.source_info_dict)
  target_boot = common.GetBootableImage(
      "/tmp/boot.img", "boot.img", OPTIONS.target_tmp, "BOOT")
  updating_boot = (not OPTIONS.two_step and
                   (source_boot.data != target_boot.data))

  target_recovery = common.GetBootableImage(
      "/tmp/recovery.img", "recovery.img", OPTIONS.target_tmp, "RECOVERY")

  system_src = GetImage("system", OPTIONS.source_tmp, OPTIONS.source_info_dict)
  system_tgt = GetImage("system", OPTIONS.target_tmp, OPTIONS.target_info_dict)

  blockimgdiff_version = 1
  if OPTIONS.info_dict:
    blockimgdiff_version = max(
        int(i) for i in
        OPTIONS.info_dict.get("blockimgdiff_versions", "1").split(","))

  # Check the first block of the source system partition for remount R/W only
  # if the filesystem is ext4.
  system_src_partition = OPTIONS.source_info_dict["fstab"]["/system"]
  check_first_block = system_src_partition.fs_type == "ext4"
  # Disable using imgdiff for squashfs. 'imgdiff -z' expects input files to be
  # in zip formats. However with squashfs, a) all files are compressed in LZ4;
  # b) the blocks listed in block map may not contain all the bytes for a given
  # file (because they're rounded to be 4K-aligned).
  system_tgt_partition = OPTIONS.target_info_dict["fstab"]["/system"]
  disable_imgdiff = (system_src_partition.fs_type == "squashfs" or
                     system_tgt_partition.fs_type == "squashfs")
  system_diff = common.BlockDifference("system", system_tgt, system_src,
                                       check_first_block,
                                       version=blockimgdiff_version,
                                       disable_imgdiff=disable_imgdiff)

  if HasVendorPartition(target_zip):
    if not HasVendorPartition(source_zip):
      raise RuntimeError("can't generate incremental that adds /vendor")
    vendor_src = GetImage("vendor", OPTIONS.source_tmp,
                          OPTIONS.source_info_dict)
    vendor_tgt = GetImage("vendor", OPTIONS.target_tmp,
                          OPTIONS.target_info_dict)

    # Check first block of vendor partition for remount R/W only if
    # disk type is ext4
    vendor_partition = OPTIONS.source_info_dict["fstab"]["/vendor"]
    check_first_block = vendor_partition.fs_type == "ext4"
    disable_imgdiff = vendor_partition.fs_type == "squashfs"
    vendor_diff = common.BlockDifference("vendor", vendor_tgt, vendor_src,
                                         check_first_block,
                                         version=blockimgdiff_version,
                                         disable_imgdiff=disable_imgdiff)
  else:
    vendor_diff = None

  AppendAssertions(script, OPTIONS.target_info_dict, oem_dict)
  device_specific.IncrementalOTA_Assertions()

  # Two-step incremental package strategy (in chronological order,
  # which is *not* the order in which the generated script has
  # things):
  #
  # if stage is not "2/3" or "3/3":
  #    do verification on current system
  #    write recovery image to boot partition
  #    set stage to "2/3"
  #    reboot to boot partition and restart recovery
  # else if stage is "2/3":
  #    write recovery image to recovery partition
  #    set stage to "3/3"
  #    reboot to recovery partition and restart recovery
  # else:
  #    (stage must be "3/3")
  #    perform update:
  #       patch system files, etc.
  #       force full install of new boot image
  #       set up system to update recovery partition on first boot
  #    complete script normally
  #    (allow recovery to mark itself finished and reboot)

  if OPTIONS.two_step:
    if not OPTIONS.source_info_dict.get("multistage_support", None):
      assert False, "two-step packages not supported by this build"
    fs = OPTIONS.source_info_dict["fstab"]["/misc"]
    assert fs.fs_type.upper() == "EMMC", \
        "two-step packages only supported on devices with EMMC /misc partitions"
    bcb_dev = {"bcb_dev": fs.device}
    common.ZipWriteStr(output_zip, "recovery.img", target_recovery.data)
    script.AppendExtra("""
if get_stage("%(bcb_dev)s") == "2/3" then
""" % bcb_dev)

    # Stage 2/3: Write recovery image to /recovery (currently running /boot).
    script.Comment("Stage 2/3")
    script.AppendExtra("sleep(20);\n")
    script.WriteRawImage("/recovery", "recovery.img")
    script.AppendExtra("""
set_stage("%(bcb_dev)s", "3/3");
reboot_now("%(bcb_dev)s", "recovery");
else if get_stage("%(bcb_dev)s") != "3/3" then
""" % bcb_dev)

    # Stage 1/3: (a) Verify the current system.
    script.Comment("Stage 1/3")

  # Dump fingerprints
  script.Print("Source: %s" % CalculateFingerprint(
      oem_props, oem_dict, OPTIONS.source_info_dict))
  script.Print("Target: %s" % CalculateFingerprint(
      oem_props, oem_dict, OPTIONS.target_info_dict))

  script.Print("Verifying current system...")

  device_specific.IncrementalOTA_VerifyBegin()

  if oem_props is None:
    # When blockimgdiff version is less than 3 (non-resumable block-based OTA),
    # patching on a device that's already on the target build will damage the
    # system. Because operations like move don't check the block state, they
    # always apply the changes unconditionally.
    if blockimgdiff_version <= 2:
      script.AssertSomeFingerprint(source_fp)
    else:
      script.AssertSomeFingerprint(source_fp, target_fp)
  else:
    if blockimgdiff_version <= 2:
      script.AssertSomeThumbprint(
          GetBuildProp("ro.build.thumbprint", OPTIONS.source_info_dict))
    else:
      script.AssertSomeThumbprint(
          GetBuildProp("ro.build.thumbprint", OPTIONS.target_info_dict),
          GetBuildProp("ro.build.thumbprint", OPTIONS.source_info_dict))

  # Check the required cache size (i.e. stashed blocks).
  size = []
  if system_diff:
    size.append(system_diff.required_cache)
  if vendor_diff:
    size.append(vendor_diff.required_cache)

  if updating_boot:
    boot_type, boot_device = common.GetTypeAndDevice(
        "/boot", OPTIONS.source_info_dict)
    d = common.Difference(target_boot, source_boot)
    _, _, d = d.ComputePatch()
    if d is None:
      include_full_boot = True
      common.ZipWriteStr(output_zip, "boot.img", target_boot.data)
    else:
      include_full_boot = False

      print "boot      target: %d  source: %d  diff: %d" % (
          target_boot.size, source_boot.size, len(d))

      common.ZipWriteStr(output_zip, "patch/boot.img.p", d)

      script.PatchCheck("%s:%s:%d:%s:%d:%s" %
                        (boot_type, boot_device,
                         source_boot.size, source_boot.sha1,
                         target_boot.size, target_boot.sha1))
      size.append(target_boot.size)

  if size:
    script.CacheFreeSpaceCheck(max(size))

  device_specific.IncrementalOTA_VerifyEnd()

  if OPTIONS.two_step:
    # Stage 1/3: (b) Write recovery image to /boot.
    _WriteRecoveryImageToBoot(script, output_zip)

    script.AppendExtra("""
set_stage("%(bcb_dev)s", "2/3");
reboot_now("%(bcb_dev)s", "");
else
""" % bcb_dev)

    # Stage 3/3: Make changes.
    script.Comment("Stage 3/3")

  # Verify the existing partitions.
  system_diff.WriteVerifyScript(script, touched_blocks_only=True)
  if vendor_diff:
    vendor_diff.WriteVerifyScript(script, touched_blocks_only=True)

  script.Comment("---- start making changes here ----")

  device_specific.IncrementalOTA_InstallBegin()

  system_diff.WriteScript(script, output_zip,
                          progress=0.8 if vendor_diff else 0.9)

  if vendor_diff:
    vendor_diff.WriteScript(script, output_zip, progress=0.1)

  if OPTIONS.two_step:
    common.ZipWriteStr(output_zip, "boot.img", target_boot.data)
    script.WriteRawImage("/boot", "boot.img")
    print "writing full boot image (forced by two-step mode)"

  if not OPTIONS.two_step:
    if updating_boot:
      if include_full_boot:
        print "boot image changed; including full."
        script.Print("Installing boot image...")
        script.WriteRawImage("/boot", "boot.img")
      else:
        # Produce the boot image by applying a patch to the current
        # contents of the boot partition, and write it back to the
        # partition.
        print "boot image changed; including patch."
        script.Print("Patching boot image...")
        script.ShowProgress(0.1, 10)
        script.ApplyPatch("%s:%s:%d:%s:%d:%s"
                          % (boot_type, boot_device,
                             source_boot.size, source_boot.sha1,
                             target_boot.size, target_boot.sha1),
                          "-",
                          target_boot.size, target_boot.sha1,
                          source_boot.sha1, "patch/boot.img.p")
    else:
      print "boot image unchanged; skipping."

  # Do device-specific installation (eg, write radio image).
  device_specific.IncrementalOTA_InstallEnd()

  if OPTIONS.extra_script is not None:
    script.AppendExtra(OPTIONS.extra_script)

  if OPTIONS.wipe_user_data:
    script.Print("Erasing user data...")
    script.FormatPartition("/data")
    metadata["ota-wipe"] = "yes"

  if OPTIONS.two_step:
    script.AppendExtra("""
set_stage("%(bcb_dev)s", "");
endif;
endif;
""" % bcb_dev)

  script.SetProgress(1)
  # For downgrade OTAs, we prefer to use the update-binary in the source
  # build that is actually newer than the one in the target build.
  if OPTIONS.downgrade:
    script.AddToZip(source_zip, output_zip, input_path=OPTIONS.updater_binary)
  else:
    script.AddToZip(target_zip, output_zip, input_path=OPTIONS.updater_binary)
  metadata["ota-required-cache"] = str(script.required_cache)
  WriteMetadata(metadata, output_zip)


def WriteVerifyPackage(input_zip, output_zip):
  script = edify_generator.EdifyGenerator(3, OPTIONS.info_dict)

  oem_props = OPTIONS.info_dict.get("oem_fingerprint_properties")
  recovery_mount_options = OPTIONS.info_dict.get(
      "recovery_mount_options")
  oem_dict = None
  if oem_props is not None and len(oem_props) > 0:
    if OPTIONS.oem_source is None:
      raise common.ExternalError("OEM source required for this build")
    script.Mount("/oem", recovery_mount_options)
    oem_dict = common.LoadDictionaryFromLines(
        open(OPTIONS.oem_source).readlines())

  target_fp = CalculateFingerprint(oem_props, oem_dict, OPTIONS.info_dict)
  metadata = {
      "post-build": target_fp,
      "pre-device": GetOemProperty("ro.product.device", oem_props, oem_dict,
                                   OPTIONS.info_dict),
      "post-timestamp": GetBuildProp("ro.build.date.utc", OPTIONS.info_dict),
  }

  device_specific = common.DeviceSpecificParams(
      input_zip=input_zip,
      input_version=OPTIONS.info_dict["recovery_api_version"],
      output_zip=output_zip,
      script=script,
      input_tmp=OPTIONS.input_tmp,
      metadata=metadata,
      info_dict=OPTIONS.info_dict)

  AppendAssertions(script, OPTIONS.info_dict, oem_dict)

  script.Print("Verifying device images against %s..." % target_fp)
  script.AppendExtra("")

  script.Print("Verifying boot...")
  boot_img = common.GetBootableImage(
      "boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")
  boot_type, boot_device = common.GetTypeAndDevice(
      "/boot", OPTIONS.info_dict)
  script.Verify("%s:%s:%d:%s" % (
      boot_type, boot_device, boot_img.size, boot_img.sha1))
  script.AppendExtra("")

  script.Print("Verifying recovery...")
  recovery_img = common.GetBootableImage(
      "recovery.img", "recovery.img", OPTIONS.input_tmp, "RECOVERY")
  recovery_type, recovery_device = common.GetTypeAndDevice(
      "/recovery", OPTIONS.info_dict)
  script.Verify("%s:%s:%d:%s" % (
      recovery_type, recovery_device, recovery_img.size, recovery_img.sha1))
  script.AppendExtra("")

  system_tgt = GetImage("system", OPTIONS.input_tmp, OPTIONS.info_dict)
  system_tgt.ResetFileMap()
  system_diff = common.BlockDifference("system", system_tgt, src=None)
  system_diff.WriteStrictVerifyScript(script)

  if HasVendorPartition(input_zip):
    vendor_tgt = GetImage("vendor", OPTIONS.input_tmp, OPTIONS.info_dict)
    vendor_tgt.ResetFileMap()
    vendor_diff = common.BlockDifference("vendor", vendor_tgt, src=None)
    vendor_diff.WriteStrictVerifyScript(script)

  # Device specific partitions, such as radio, bootloader and etc.
  device_specific.VerifyOTA_Assertions()

  script.SetProgress(1.0)
  script.AddToZip(input_zip, output_zip, input_path=OPTIONS.updater_binary)
  metadata["ota-required-cache"] = str(script.required_cache)
  WriteMetadata(metadata, output_zip)


def WriteABOTAPackageWithBrilloScript(target_file, output_file,
                                      source_file=None):
  """Generate an Android OTA package that has A/B update payload."""

  # Setup signing keys.
  if OPTIONS.package_key is None:
    OPTIONS.package_key = OPTIONS.info_dict.get(
        "default_system_dev_certificate",
        "build/target/product/security/testkey")

  # A/B updater expects a signing key in RSA format. Gets the key ready for
  # later use in step 3, unless a payload_signer has been specified.
  if OPTIONS.payload_signer is None:
    cmd = ["openssl", "pkcs8",
           "-in", OPTIONS.package_key + OPTIONS.private_key_suffix,
           "-inform", "DER", "-nocrypt"]
    rsa_key = common.MakeTempFile(prefix="key-", suffix=".key")
    cmd.extend(["-out", rsa_key])
    p1 = common.Run(cmd, stdout=subprocess.PIPE)
    p1.wait()
    assert p1.returncode == 0, "openssl pkcs8 failed"

  # Stage the output zip package for package signing.
  temp_zip_file = tempfile.NamedTemporaryFile()
  output_zip = zipfile.ZipFile(temp_zip_file, "w",
                               compression=zipfile.ZIP_DEFLATED)

  # Metadata to comply with Android OTA package format.
  oem_props = OPTIONS.info_dict.get("oem_fingerprint_properties", None)
  oem_dict = None
  if oem_props:
    if OPTIONS.oem_source is None:
      raise common.ExternalError("OEM source required for this build")
    oem_dict = common.LoadDictionaryFromLines(
        open(OPTIONS.oem_source).readlines())

  metadata = {
      "post-build": CalculateFingerprint(oem_props, oem_dict,
                                         OPTIONS.info_dict),
      "post-build-incremental" : GetBuildProp("ro.build.version.incremental",
                                              OPTIONS.info_dict),
      "pre-device": GetOemProperty("ro.product.device", oem_props, oem_dict,
                                   OPTIONS.info_dict),
      "post-timestamp": GetBuildProp("ro.build.date.utc", OPTIONS.info_dict),
      "ota-required-cache": "0",
      "ota-type": "AB",
  }

  if source_file is not None:
    metadata["pre-build"] = CalculateFingerprint(oem_props, oem_dict,
                                                 OPTIONS.source_info_dict)
    metadata["pre-build-incremental"] = GetBuildProp(
        "ro.build.version.incremental", OPTIONS.source_info_dict)

  # 1. Generate payload.
  payload_file = common.MakeTempFile(prefix="payload-", suffix=".bin")
  cmd = ["brillo_update_payload", "generate",
         "--payload", payload_file,
         "--target_image", target_file]
  if source_file is not None:
    cmd.extend(["--source_image", source_file])
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  p1.wait()
  assert p1.returncode == 0, "brillo_update_payload generate failed"

  # 2. Generate hashes of the payload and metadata files.
  payload_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
  metadata_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
  cmd = ["brillo_update_payload", "hash",
         "--unsigned_payload", payload_file,
         "--signature_size", "256",
         "--metadata_hash_file", metadata_sig_file,
         "--payload_hash_file", payload_sig_file]
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  p1.wait()
  assert p1.returncode == 0, "brillo_update_payload hash failed"

  # 3. Sign the hashes and insert them back into the payload file.
  signed_payload_sig_file = common.MakeTempFile(prefix="signed-sig-",
                                                suffix=".bin")
  signed_metadata_sig_file = common.MakeTempFile(prefix="signed-sig-",
                                                 suffix=".bin")
  # 3a. Sign the payload hash.
  if OPTIONS.payload_signer is not None:
    cmd = [OPTIONS.payload_signer]
    cmd.extend(OPTIONS.payload_signer_args)
  else:
    cmd = ["openssl", "pkeyutl", "-sign",
           "-inkey", rsa_key,
           "-pkeyopt", "digest:sha256"]
  cmd.extend(["-in", payload_sig_file,
              "-out", signed_payload_sig_file])

  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  p1.wait()
  assert p1.returncode == 0, "openssl sign payload failed"

  # 3b. Sign the metadata hash.
  if OPTIONS.payload_signer is not None:
    cmd = [OPTIONS.payload_signer]
    cmd.extend(OPTIONS.payload_signer_args)
  else:
    cmd = ["openssl", "pkeyutl", "-sign",
           "-inkey", rsa_key,
           "-pkeyopt", "digest:sha256"]
  cmd.extend(["-in", metadata_sig_file,
              "-out", signed_metadata_sig_file])
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  p1.wait()
  assert p1.returncode == 0, "openssl sign metadata failed"

  # 3c. Insert the signatures back into the payload file.
  signed_payload_file = common.MakeTempFile(prefix="signed-payload-",
                                            suffix=".bin")
  cmd = ["brillo_update_payload", "sign",
         "--unsigned_payload", payload_file,
         "--payload", signed_payload_file,
         "--signature_size", "256",
         "--metadata_signature_file", signed_metadata_sig_file,
         "--payload_signature_file", signed_payload_sig_file]
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  p1.wait()
  assert p1.returncode == 0, "brillo_update_payload sign failed"

  # 4. Dump the signed payload properties.
  properties_file = common.MakeTempFile(prefix="payload-properties-",
                                        suffix=".txt")
  cmd = ["brillo_update_payload", "properties",
         "--payload", signed_payload_file,
         "--properties_file", properties_file]
  p1 = common.Run(cmd, stdout=subprocess.PIPE)
  p1.wait()
  assert p1.returncode == 0, "brillo_update_payload properties failed"

  if OPTIONS.wipe_user_data:
    with open(properties_file, "a") as f:
      f.write("POWERWASH=1\n")
    metadata["ota-wipe"] = "yes"

  # Add the signed payload file and properties into the zip.
  common.ZipWrite(output_zip, properties_file, arcname="payload_properties.txt")
  common.ZipWrite(output_zip, signed_payload_file, arcname="payload.bin",
                  compress_type=zipfile.ZIP_STORED)
  WriteMetadata(metadata, output_zip)

  # If dm-verity is supported for the device, copy contents of care_map
  # into A/B OTA package.
  if OPTIONS.info_dict.get("verity") == "true":
    target_zip = zipfile.ZipFile(target_file, "r")
    care_map_path = "META/care_map.txt"
    namelist = target_zip.namelist()
    if care_map_path in namelist:
      care_map_data = target_zip.read(care_map_path)
      common.ZipWriteStr(output_zip, "care_map.txt", care_map_data)
    else:
      print "Warning: cannot find care map file in target_file package"
    common.ZipClose(target_zip)

  # Sign the whole package to comply with the Android OTA package format.
  common.ZipClose(output_zip)
  SignOutput(temp_zip_file.name, output_file)
  temp_zip_file.close()


class FileDifference(object):
  def __init__(self, partition, source_zip, target_zip, output_zip):
    self.deferred_patch_list = None
    print "Loading target..."
    self.target_data = target_data = LoadPartitionFiles(target_zip, partition)
    print "Loading source..."
    self.source_data = source_data = LoadPartitionFiles(source_zip, partition)

    self.verbatim_targets = verbatim_targets = []
    self.patch_list = patch_list = []
    diffs = []
    self.renames = renames = {}
    known_paths = set()
    largest_source_size = 0

    matching_file_cache = {}
    for fn, sf in source_data.items():
      assert fn == sf.name
      matching_file_cache["path:" + fn] = sf
      if fn in target_data.keys():
        AddToKnownPaths(fn, known_paths)
      # Only allow eligibility for filename/sha matching
      # if there isn't a perfect path match.
      if target_data.get(sf.name) is None:
        matching_file_cache["file:" + fn.split("/")[-1]] = sf
        matching_file_cache["sha:" + sf.sha1] = sf

    for fn in sorted(target_data.keys()):
      tf = target_data[fn]
      assert fn == tf.name
      sf = ClosestFileMatch(tf, matching_file_cache, renames)
      if sf is not None and sf.name != tf.name:
        print "File has moved from " + sf.name + " to " + tf.name
        renames[sf.name] = tf

      if sf is None or fn in OPTIONS.require_verbatim:
        # This file should be included verbatim
        if fn in OPTIONS.prohibit_verbatim:
          raise common.ExternalError("\"%s\" must be sent verbatim" % (fn,))
        print "send", fn, "verbatim"
        tf.AddToZip(output_zip)
        verbatim_targets.append((fn, tf.size, tf.sha1))
        if fn in target_data.keys():
          AddToKnownPaths(fn, known_paths)
      elif tf.sha1 != sf.sha1:
        # File is different; consider sending as a patch
        diffs.append(common.Difference(tf, sf))
      else:
        # Target file data identical to source (may still be renamed)
        pass

    common.ComputeDifferences(diffs)

    for diff in diffs:
      tf, sf, d = diff.GetPatch()
      path = "/".join(tf.name.split("/")[:-1])
      if d is None or len(d) > tf.size * OPTIONS.patch_threshold or \
          path not in known_paths:
        # patch is almost as big as the file; don't bother patching
        # or a patch + rename cannot take place due to the target
        # directory not existing
        tf.AddToZip(output_zip)
        verbatim_targets.append((tf.name, tf.size, tf.sha1))
        if sf.name in renames:
          del renames[sf.name]
        AddToKnownPaths(tf.name, known_paths)
      else:
        common.ZipWriteStr(output_zip, "patch/" + sf.name + ".p", d)
        patch_list.append((tf, sf, tf.size, common.sha1(d).hexdigest()))
        largest_source_size = max(largest_source_size, sf.size)

    self.largest_source_size = largest_source_size

  def EmitVerification(self, script):
    so_far = 0
    for tf, sf, _, _ in self.patch_list:
      if tf.name != sf.name:
        script.SkipNextActionIfTargetExists(tf.name, tf.sha1)
      script.PatchCheck("/"+sf.name, tf.sha1, sf.sha1)
      so_far += sf.size
    return so_far

  def EmitExplicitTargetVerification(self, script):
    for fn, _, sha1 in self.verbatim_targets:
      if fn[-1] != "/":
        script.FileCheck("/"+fn, sha1)
    for tf, _, _, _ in self.patch_list:
      script.FileCheck(tf.name, tf.sha1)

  def RemoveUnneededFiles(self, script, extras=()):
    file_list = ["/" + i[0] for i in self.verbatim_targets]
    file_list += ["/" + i for i in self.source_data
                  if i not in self.target_data and i not in self.renames]
    file_list += list(extras)
    # Sort the list in descending order, which removes all the files first
    # before attempting to remove the folder. (Bug: 22960996)
    script.DeleteFiles(sorted(file_list, reverse=True))

  def TotalPatchSize(self):
    return sum(i[1].size for i in self.patch_list)

  def EmitPatches(self, script, total_patch_size, so_far):
    self.deferred_patch_list = deferred_patch_list = []
    for item in self.patch_list:
      tf, sf, _, _ = item
      if tf.name == "system/build.prop":
        deferred_patch_list.append(item)
        continue
      if sf.name != tf.name:
        script.SkipNextActionIfTargetExists(tf.name, tf.sha1)
      script.ApplyPatch("/" + sf.name, "-", tf.size, tf.sha1, sf.sha1,
                        "patch/" + sf.name + ".p")
      so_far += tf.size
      script.SetProgress(so_far / total_patch_size)
    return so_far

  def EmitDeferredPatches(self, script):
    for item in self.deferred_patch_list:
      tf, sf, _, _ = item
      script.ApplyPatch("/"+sf.name, "-", tf.size, tf.sha1, sf.sha1,
                        "patch/" + sf.name + ".p")
    script.SetPermissions("/system/build.prop", 0, 0, 0o644, None, None)

  def EmitRenames(self, script):
    if len(self.renames) > 0:
      script.Print("Renaming files...")
      for src, tgt in self.renames.iteritems():
        print "Renaming " + src + " to " + tgt.name
        script.RenameFile(src, tgt.name)


def WriteIncrementalOTAPackage(target_zip, source_zip, output_zip):
  target_has_recovery_patch = HasRecoveryPatch(target_zip)
  source_has_recovery_patch = HasRecoveryPatch(source_zip)

  if (OPTIONS.block_based and
      target_has_recovery_patch and
      source_has_recovery_patch):
    return WriteBlockIncrementalOTAPackage(target_zip, source_zip, output_zip)

  source_version = OPTIONS.source_info_dict["recovery_api_version"]
  target_version = OPTIONS.target_info_dict["recovery_api_version"]

  if source_version == 0:
    print ("WARNING: generating edify script for a source that "
           "can't install it.")
  script = edify_generator.EdifyGenerator(
      source_version, OPTIONS.target_info_dict,
      fstab=OPTIONS.source_info_dict["fstab"])

  oem_props = OPTIONS.info_dict.get("oem_fingerprint_properties")
  recovery_mount_options = OPTIONS.source_info_dict.get(
      "recovery_mount_options")
  oem_dict = None
  if oem_props is not None and len(oem_props) > 0:
    if OPTIONS.oem_source is None:
      raise common.ExternalError("OEM source required for this build")
    if not OPTIONS.oem_no_mount:
      script.Mount("/oem", recovery_mount_options)
    oem_dict = common.LoadDictionaryFromLines(
        open(OPTIONS.oem_source).readlines())

  metadata = {
      "pre-device": GetOemProperty("ro.product.device", oem_props, oem_dict,
                                   OPTIONS.source_info_dict),
      "ota-type": "FILE",
  }

  post_timestamp = GetBuildProp("ro.build.date.utc", OPTIONS.target_info_dict)
  pre_timestamp = GetBuildProp("ro.build.date.utc", OPTIONS.source_info_dict)
  is_downgrade = long(post_timestamp) < long(pre_timestamp)

  if OPTIONS.downgrade:
    metadata["ota-downgrade"] = "yes"
    if not is_downgrade:
      raise RuntimeError("--downgrade specified but no downgrade detected: "
                         "pre: %s, post: %s" % (pre_timestamp, post_timestamp))
  else:
    if is_downgrade:
      # Non-fatal here to allow generating such a package which may require
      # manual work to adjust the post-timestamp. A legit use case is that we
      # cut a new build C (after having A and B), but want to enfore the
      # update path of A -> C -> B. Specifying --downgrade may not help since
      # that would enforce a data wipe for C -> B update.
      print("\nWARNING: downgrade detected: pre: %s, post: %s.\n"
            "The package may not be deployed properly. "
            "Try --downgrade?\n" % (pre_timestamp, post_timestamp))
    metadata["post-timestamp"] = post_timestamp

  device_specific = common.DeviceSpecificParams(
      source_zip=source_zip,
      source_version=source_version,
      target_zip=target_zip,
      target_version=target_version,
      output_zip=output_zip,
      script=script,
      metadata=metadata,
      info_dict=OPTIONS.source_info_dict)

  system_diff = FileDifference("system", source_zip, target_zip, output_zip)
  script.Mount("/system", recovery_mount_options)
  if HasVendorPartition(target_zip):
    vendor_diff = FileDifference("vendor", source_zip, target_zip, output_zip)
    script.Mount("/vendor", recovery_mount_options)
  else:
    vendor_diff = None

  target_fp = CalculateFingerprint(oem_props, oem_dict,
                                   OPTIONS.target_info_dict)
  source_fp = CalculateFingerprint(oem_props, oem_dict,
                                   OPTIONS.source_info_dict)

  if oem_props is None:
    script.AssertSomeFingerprint(source_fp, target_fp)
  else:
    script.AssertSomeThumbprint(
        GetBuildProp("ro.build.thumbprint", OPTIONS.target_info_dict),
        GetBuildProp("ro.build.thumbprint", OPTIONS.source_info_dict))

  metadata["pre-build"] = source_fp
  metadata["post-build"] = target_fp
  metadata["pre-build-incremental"] = GetBuildProp(
      "ro.build.version.incremental", OPTIONS.source_info_dict)
  metadata["post-build-incremental"] = GetBuildProp(
      "ro.build.version.incremental", OPTIONS.target_info_dict)

  source_boot = common.GetBootableImage(
      "/tmp/boot.img", "boot.img", OPTIONS.source_tmp, "BOOT",
      OPTIONS.source_info_dict)
  target_boot = common.GetBootableImage(
      "/tmp/boot.img", "boot.img", OPTIONS.target_tmp, "BOOT")
  updating_boot = (not OPTIONS.two_step and
                   (source_boot.data != target_boot.data))

  source_recovery = common.GetBootableImage(
      "/tmp/recovery.img", "recovery.img", OPTIONS.source_tmp, "RECOVERY",
      OPTIONS.source_info_dict)
  target_recovery = common.GetBootableImage(
      "/tmp/recovery.img", "recovery.img", OPTIONS.target_tmp, "RECOVERY")
  updating_recovery = (source_recovery.data != target_recovery.data)

  # Here's how we divide up the progress bar:
  #  0.1 for verifying the start state (PatchCheck calls)
  #  0.8 for applying patches (ApplyPatch calls)
  #  0.1 for unpacking verbatim files, symlinking, and doing the
  #      device-specific commands.

  AppendAssertions(script, OPTIONS.target_info_dict, oem_dict)
  device_specific.IncrementalOTA_Assertions()

  # Two-step incremental package strategy (in chronological order,
  # which is *not* the order in which the generated script has
  # things):
  #
  # if stage is not "2/3" or "3/3":
  #    do verification on current system
  #    write recovery image to boot partition
  #    set stage to "2/3"
  #    reboot to boot partition and restart recovery
  # else if stage is "2/3":
  #    write recovery image to recovery partition
  #    set stage to "3/3"
  #    reboot to recovery partition and restart recovery
  # else:
  #    (stage must be "3/3")
  #    perform update:
  #       patch system files, etc.
  #       force full install of new boot image
  #       set up system to update recovery partition on first boot
  #    complete script normally
  #    (allow recovery to mark itself finished and reboot)

  if OPTIONS.two_step:
    if not OPTIONS.source_info_dict.get("multistage_support", None):
      assert False, "two-step packages not supported by this build"
    fs = OPTIONS.source_info_dict["fstab"]["/misc"]
    assert fs.fs_type.upper() == "EMMC", \
        "two-step packages only supported on devices with EMMC /misc partitions"
    bcb_dev = {"bcb_dev": fs.device}
    common.ZipWriteStr(output_zip, "recovery.img", target_recovery.data)
    script.AppendExtra("""
if get_stage("%(bcb_dev)s") == "2/3" then
""" % bcb_dev)

    # Stage 2/3: Write recovery image to /recovery (currently running /boot).
    script.Comment("Stage 2/3")
    script.AppendExtra("sleep(20);\n")
    script.WriteRawImage("/recovery", "recovery.img")
    script.AppendExtra("""
set_stage("%(bcb_dev)s", "3/3");
reboot_now("%(bcb_dev)s", "recovery");
else if get_stage("%(bcb_dev)s") != "3/3" then
""" % bcb_dev)

    # Stage 1/3: (a) Verify the current system.
    script.Comment("Stage 1/3")

  # Dump fingerprints
  script.Print("Source: %s" % (source_fp,))
  script.Print("Target: %s" % (target_fp,))

  script.Print("Verifying current system...")

  device_specific.IncrementalOTA_VerifyBegin()

  script.ShowProgress(0.1, 0)
  so_far = system_diff.EmitVerification(script)
  if vendor_diff:
    so_far += vendor_diff.EmitVerification(script)

  size = []
  if system_diff.patch_list:
    size.append(system_diff.largest_source_size)
  if vendor_diff:
    if vendor_diff.patch_list:
      size.append(vendor_diff.largest_source_size)

  if updating_boot:
    d = common.Difference(target_boot, source_boot)
    _, _, d = d.ComputePatch()
    print "boot      target: %d  source: %d  diff: %d" % (
        target_boot.size, source_boot.size, len(d))

    common.ZipWriteStr(output_zip, "patch/boot.img.p", d)

    boot_type, boot_device = common.GetTypeAndDevice(
        "/boot", OPTIONS.source_info_dict)

    script.PatchCheck("%s:%s:%d:%s:%d:%s" %
                      (boot_type, boot_device,
                       source_boot.size, source_boot.sha1,
                       target_boot.size, target_boot.sha1))
    so_far += source_boot.size
    size.append(target_boot.size)

  if size:
    script.CacheFreeSpaceCheck(max(size))

  device_specific.IncrementalOTA_VerifyEnd()

  if OPTIONS.two_step:
    # Stage 1/3: (b) Write recovery image to /boot.
    _WriteRecoveryImageToBoot(script, output_zip)

    script.AppendExtra("""
set_stage("%(bcb_dev)s", "2/3");
reboot_now("%(bcb_dev)s", "");
else
""" % bcb_dev)

    # Stage 3/3: Make changes.
    script.Comment("Stage 3/3")

  script.Comment("---- start making changes here ----")

  device_specific.IncrementalOTA_InstallBegin()

  if OPTIONS.two_step:
    common.ZipWriteStr(output_zip, "boot.img", target_boot.data)
    script.WriteRawImage("/boot", "boot.img")
    print "writing full boot image (forced by two-step mode)"

  script.Print("Removing unneeded files...")
  system_diff.RemoveUnneededFiles(script, ("/system/recovery.img",))
  if vendor_diff:
    vendor_diff.RemoveUnneededFiles(script)

  script.ShowProgress(0.8, 0)
  total_patch_size = 1.0 + system_diff.TotalPatchSize()
  if vendor_diff:
    total_patch_size += vendor_diff.TotalPatchSize()
  if updating_boot:
    total_patch_size += target_boot.size

  script.Print("Patching system files...")
  so_far = system_diff.EmitPatches(script, total_patch_size, 0)
  if vendor_diff:
    script.Print("Patching vendor files...")
    so_far = vendor_diff.EmitPatches(script, total_patch_size, so_far)

  if not OPTIONS.two_step:
    if updating_boot:
      # Produce the boot image by applying a patch to the current
      # contents of the boot partition, and write it back to the
      # partition.
      script.Print("Patching boot image...")
      script.ApplyPatch("%s:%s:%d:%s:%d:%s"
                        % (boot_type, boot_device,
                           source_boot.size, source_boot.sha1,
                           target_boot.size, target_boot.sha1),
                        "-",
                        target_boot.size, target_boot.sha1,
                        source_boot.sha1, "patch/boot.img.p")
      so_far += target_boot.size
      script.SetProgress(so_far / total_patch_size)
      print "boot image changed; including."
    else:
      print "boot image unchanged; skipping."

  system_items = ItemSet("system", "META/filesystem_config.txt")
  if vendor_diff:
    vendor_items = ItemSet("vendor", "META/vendor_filesystem_config.txt")

  if updating_recovery:
    # Recovery is generated as a patch using both the boot image
    # (which contains the same linux kernel as recovery) and the file
    # /system/etc/recovery-resource.dat (which contains all the images
    # used in the recovery UI) as sources.  This lets us minimize the
    # size of the patch, which must be included in every OTA package.
    #
    # For older builds where recovery-resource.dat is not present, we
    # use only the boot image as the source.

    if not target_has_recovery_patch:
      def output_sink(fn, data):
        common.ZipWriteStr(output_zip, "recovery/" + fn, data)
        system_items.Get("system/" + fn)

      common.MakeRecoveryPatch(OPTIONS.target_tmp, output_sink,
                               target_recovery, target_boot)
      script.DeleteFiles(["/system/recovery-from-boot.p",
                          "/system/etc/recovery.img",
                          "/system/etc/install-recovery.sh"])
    print "recovery image changed; including as patch from boot."
  else:
    print "recovery image unchanged; skipping."

  script.ShowProgress(0.1, 10)

  target_symlinks = CopyPartitionFiles(system_items, target_zip, None)
  if vendor_diff:
    target_symlinks.extend(CopyPartitionFiles(vendor_items, target_zip, None))

  temp_script = script.MakeTemporary()
  system_items.GetMetadata(target_zip)
  system_items.Get("system").SetPermissions(temp_script)
  if vendor_diff:
    vendor_items.GetMetadata(target_zip)
    vendor_items.Get("vendor").SetPermissions(temp_script)

  # Note that this call will mess up the trees of Items, so make sure
  # we're done with them.
  source_symlinks = CopyPartitionFiles(system_items, source_zip, None)
  if vendor_diff:
    source_symlinks.extend(CopyPartitionFiles(vendor_items, source_zip, None))

  target_symlinks_d = dict([(i[1], i[0]) for i in target_symlinks])
  source_symlinks_d = dict([(i[1], i[0]) for i in source_symlinks])

  # Delete all the symlinks in source that aren't in target.  This
  # needs to happen before verbatim files are unpacked, in case a
  # symlink in the source is replaced by a real file in the target.

  # If a symlink in the source will be replaced by a regular file, we cannot
  # delete the symlink/file in case the package gets applied again. For such
  # a symlink, we prepend a sha1_check() to detect if it has been updated.
  # (Bug: 23646151)
  replaced_symlinks = dict()
  if system_diff:
    for i in system_diff.verbatim_targets:
      replaced_symlinks["/%s" % (i[0],)] = i[2]
  if vendor_diff:
    for i in vendor_diff.verbatim_targets:
      replaced_symlinks["/%s" % (i[0],)] = i[2]

  if system_diff:
    for tf in system_diff.renames.values():
      replaced_symlinks["/%s" % (tf.name,)] = tf.sha1
  if vendor_diff:
    for tf in vendor_diff.renames.values():
      replaced_symlinks["/%s" % (tf.name,)] = tf.sha1

  always_delete = []
  may_delete = []
  for dest, link in source_symlinks:
    if link not in target_symlinks_d:
      if link in replaced_symlinks:
        may_delete.append((link, replaced_symlinks[link]))
      else:
        always_delete.append(link)
  script.DeleteFiles(always_delete)
  script.DeleteFilesIfNotMatching(may_delete)

  if system_diff.verbatim_targets:
    script.Print("Unpacking new system files...")
    script.UnpackPackageDir("system", "/system")
  if vendor_diff and vendor_diff.verbatim_targets:
    script.Print("Unpacking new vendor files...")
    script.UnpackPackageDir("vendor", "/vendor")

  if updating_recovery and not target_has_recovery_patch:
    script.Print("Unpacking new recovery...")
    script.UnpackPackageDir("recovery", "/system")

  system_diff.EmitRenames(script)
  if vendor_diff:
    vendor_diff.EmitRenames(script)

  script.Print("Symlinks and permissions...")

  # Create all the symlinks that don't already exist, or point to
  # somewhere different than what we want.  Delete each symlink before
  # creating it, since the 'symlink' command won't overwrite.
  to_create = []
  for dest, link in target_symlinks:
    if link in source_symlinks_d:
      if dest != source_symlinks_d[link]:
        to_create.append((dest, link))
    else:
      to_create.append((dest, link))
  script.DeleteFiles([i[1] for i in to_create])
  script.MakeSymlinks(to_create)

  # Now that the symlinks are created, we can set all the
  # permissions.
  script.AppendScript(temp_script)

  # Do device-specific installation (eg, write radio image).
  device_specific.IncrementalOTA_InstallEnd()

  if OPTIONS.extra_script is not None:
    script.AppendExtra(OPTIONS.extra_script)

  # Patch the build.prop file last, so if something fails but the
  # device can still come up, it appears to be the old build and will
  # get set the OTA package again to retry.
  script.Print("Patching remaining system files...")
  system_diff.EmitDeferredPatches(script)

  if OPTIONS.wipe_user_data:
    script.Print("Erasing user data...")
    script.FormatPartition("/data")
    metadata["ota-wipe"] = "yes"

  if OPTIONS.two_step:
    script.AppendExtra("""
set_stage("%(bcb_dev)s", "");
endif;
endif;
""" % bcb_dev)

  if OPTIONS.verify and system_diff:
    script.Print("Remounting and verifying system partition files...")
    script.Unmount("/system")
    script.Mount("/system", recovery_mount_options)
    system_diff.EmitExplicitTargetVerification(script)

  if OPTIONS.verify and vendor_diff:
    script.Print("Remounting and verifying vendor partition files...")
    script.Unmount("/vendor")
    script.Mount("/vendor", recovery_mount_options)
    vendor_diff.EmitExplicitTargetVerification(script)

  # For downgrade OTAs, we prefer to use the update-binary in the source
  # build that is actually newer than the one in the target build.
  if OPTIONS.downgrade:
    script.AddToZip(source_zip, output_zip, input_path=OPTIONS.updater_binary)
  else:
    script.AddToZip(target_zip, output_zip, input_path=OPTIONS.updater_binary)

  metadata["ota-required-cache"] = str(script.required_cache)
  WriteMetadata(metadata, output_zip)


def main(argv):

  def option_handler(o, a):
    if o == "--board_config":
      pass   # deprecated
    elif o in ("-k", "--package_key"):
      OPTIONS.package_key = a
    elif o in ("-i", "--incremental_from"):
      OPTIONS.incremental_source = a
    elif o == "--full_radio":
      OPTIONS.full_radio = True
    elif o == "--full_bootloader":
      OPTIONS.full_bootloader = True
    elif o in ("-w", "--wipe_user_data"):
      OPTIONS.wipe_user_data = True
    elif o in ("-n", "--no_prereq"):
      OPTIONS.omit_prereq = True
    elif o == "--downgrade":
      OPTIONS.downgrade = True
      OPTIONS.wipe_user_data = True
    elif o in ("-o", "--oem_settings"):
      OPTIONS.oem_source = a
    elif o == "--oem_no_mount":
      OPTIONS.oem_no_mount = True
    elif o in ("-e", "--extra_script"):
      OPTIONS.extra_script = a
    elif o in ("-a", "--aslr_mode"):
      if a in ("on", "On", "true", "True", "yes", "Yes"):
        OPTIONS.aslr_mode = True
      else:
        OPTIONS.aslr_mode = False
    elif o in ("-t", "--worker_threads"):
      if a.isdigit():
        OPTIONS.worker_threads = int(a)
      else:
        raise ValueError("Cannot parse value %r for option %r - only "
                         "integers are allowed." % (a, o))
    elif o in ("-2", "--two_step"):
      OPTIONS.two_step = True
    elif o == "--no_signing":
      OPTIONS.no_signing = True
    elif o == "--verify":
      OPTIONS.verify = True
    elif o == "--block":
      OPTIONS.block_based = True
    elif o in ("-b", "--binary"):
      OPTIONS.updater_binary = a
    elif o in ("--no_fallback_to_full",):
      OPTIONS.fallback_to_full = False
    elif o == "--stash_threshold":
      try:
        OPTIONS.stash_threshold = float(a)
      except ValueError:
        raise ValueError("Cannot parse value %r for option %r - expecting "
                         "a float" % (a, o))
    elif o == "--gen_verify":
      OPTIONS.gen_verify = True
    elif o == "--log_diff":
      OPTIONS.log_diff = a
    elif o == "--payload_signer":
      OPTIONS.payload_signer = a
    elif o == "--payload_signer_args":
      OPTIONS.payload_signer_args = shlex.split(a)
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts="b:k:i:d:wne:t:a:2o:",
                             extra_long_opts=[
                                 "board_config=",
                                 "package_key=",
                                 "incremental_from=",
                                 "full_radio",
                                 "full_bootloader",
                                 "wipe_user_data",
                                 "no_prereq",
                                 "downgrade",
                                 "extra_script=",
                                 "worker_threads=",
                                 "aslr_mode=",
                                 "two_step",
                                 "no_signing",
                                 "block",
                                 "binary=",
                                 "oem_settings=",
                                 "oem_no_mount",
                                 "verify",
                                 "no_fallback_to_full",
                                 "stash_threshold=",
                                 "gen_verify",
                                 "log_diff=",
                                 "payload_signer=",
                                 "payload_signer_args=",
                             ], extra_option_handler=option_handler)

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  if OPTIONS.downgrade:
    # Sanity check to enforce a data wipe.
    if not OPTIONS.wipe_user_data:
      raise ValueError("Cannot downgrade without a data wipe")

    # We should only allow downgrading incrementals (as opposed to full).
    # Otherwise the device may go back from arbitrary build with this full
    # OTA package.
    if OPTIONS.incremental_source is None:
      raise ValueError("Cannot generate downgradable full OTAs - consider"
                       "using --omit_prereq?")

  # Load the dict file from the zip directly to have a peek at the OTA type.
  # For packages using A/B update, unzipping is not needed.
  input_zip = zipfile.ZipFile(args[0], "r")
  OPTIONS.info_dict = common.LoadInfoDict(input_zip)
  common.ZipClose(input_zip)

  ab_update = OPTIONS.info_dict.get("ab_update") == "true"

  if ab_update:
    if OPTIONS.incremental_source is not None:
      OPTIONS.target_info_dict = OPTIONS.info_dict
      source_zip = zipfile.ZipFile(OPTIONS.incremental_source, "r")
      OPTIONS.source_info_dict = common.LoadInfoDict(source_zip)
      common.ZipClose(source_zip)

    if OPTIONS.verbose:
      print "--- target info ---"
      common.DumpInfoDict(OPTIONS.info_dict)

      if OPTIONS.incremental_source is not None:
        print "--- source info ---"
        common.DumpInfoDict(OPTIONS.source_info_dict)

    WriteABOTAPackageWithBrilloScript(
        target_file=args[0],
        output_file=args[1],
        source_file=OPTIONS.incremental_source)

    print "done."
    return

  if OPTIONS.extra_script is not None:
    OPTIONS.extra_script = open(OPTIONS.extra_script).read()

  print "unzipping target target-files..."
  OPTIONS.input_tmp, input_zip = common.UnzipTemp(args[0])

  OPTIONS.target_tmp = OPTIONS.input_tmp
  OPTIONS.info_dict = common.LoadInfoDict(input_zip, OPTIONS.target_tmp)

  if OPTIONS.verbose:
    print "--- target info ---"
    common.DumpInfoDict(OPTIONS.info_dict)

  # If the caller explicitly specified the device-specific extensions
  # path via -s/--device_specific, use that.  Otherwise, use
  # META/releasetools.py if it is present in the target target_files.
  # Otherwise, take the path of the file from 'tool_extensions' in the
  # info dict and look for that in the local filesystem, relative to
  # the current directory.

  if OPTIONS.device_specific is None:
    from_input = os.path.join(OPTIONS.input_tmp, "META", "releasetools.py")
    if os.path.exists(from_input):
      print "(using device-specific extensions from target_files)"
      OPTIONS.device_specific = from_input
    else:
      OPTIONS.device_specific = OPTIONS.info_dict.get("tool_extensions", None)

  if OPTIONS.device_specific is not None:
    OPTIONS.device_specific = os.path.abspath(OPTIONS.device_specific)

  if OPTIONS.info_dict.get("no_recovery") == "true":
    raise common.ExternalError(
        "--- target build has specified no recovery ---")

  # Use the default key to sign the package if not specified with package_key.
  if not OPTIONS.no_signing:
    if OPTIONS.package_key is None:
      OPTIONS.package_key = OPTIONS.info_dict.get(
          "default_system_dev_certificate",
          "build/target/product/security/testkey")

  # Set up the output zip. Create a temporary zip file if signing is needed.
  if OPTIONS.no_signing:
    if os.path.exists(args[1]):
      os.unlink(args[1])
    output_zip = zipfile.ZipFile(args[1], "w",
                                 compression=zipfile.ZIP_DEFLATED)
  else:
    temp_zip_file = tempfile.NamedTemporaryFile()
    output_zip = zipfile.ZipFile(temp_zip_file, "w",
                                 compression=zipfile.ZIP_DEFLATED)

  # Non A/B OTAs rely on /cache partition to store temporary files.
  cache_size = OPTIONS.info_dict.get("cache_size", None)
  if cache_size is None:
    print "--- can't determine the cache partition size ---"
  OPTIONS.cache_size = cache_size

  # Generate a verify package.
  if OPTIONS.gen_verify:
    WriteVerifyPackage(input_zip, output_zip)

  # Generate a full OTA.
  elif OPTIONS.incremental_source is None:
    WriteFullOTAPackage(input_zip, output_zip)

  # Generate an incremental OTA. It will fall back to generate a full OTA on
  # failure unless no_fallback_to_full is specified.
  else:
    print "unzipping source target-files..."
    OPTIONS.source_tmp, source_zip = common.UnzipTemp(
        OPTIONS.incremental_source)
    OPTIONS.target_info_dict = OPTIONS.info_dict
    OPTIONS.source_info_dict = common.LoadInfoDict(source_zip,
                                                   OPTIONS.source_tmp)
    if OPTIONS.verbose:
      print "--- source info ---"
      common.DumpInfoDict(OPTIONS.source_info_dict)
    try:
      WriteIncrementalOTAPackage(input_zip, source_zip, output_zip)
      if OPTIONS.log_diff:
        out_file = open(OPTIONS.log_diff, 'w')
        import target_files_diff
        target_files_diff.recursiveDiff('',
                                        OPTIONS.source_tmp,
                                        OPTIONS.input_tmp,
                                        out_file)
        out_file.close()
    except ValueError:
      if not OPTIONS.fallback_to_full:
        raise
      print "--- failed to build incremental; falling back to full ---"
      OPTIONS.incremental_source = None
      WriteFullOTAPackage(input_zip, output_zip)

  common.ZipClose(output_zip)

  # Sign the generated zip package unless no_signing is specified.
  if not OPTIONS.no_signing:
    SignOutput(temp_zip_file.name, args[1])
    temp_zip_file.close()

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
