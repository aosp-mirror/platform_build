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

  -o  (--oem_settings)  <main_file[,additional_files...]>
      Comma seperated list of files used to specify the expected OEM-specific
      properties on the OEM partition of the intended device.
      Multiple expected values can be used by providing multiple files.

  --oem_no_mount
      For devices with OEM-specific properties but without an OEM partition,
      do not mount the OEM partition in the updater-script. This should be
      very rarely used, since it's expected to have a dedicated OEM partition
      for OEM-specific properties. Only meaningful when -o is specified.

  -w  (--wipe_user_data)
      Generate an OTA package that will wipe the user data partition
      when installed.

  --downgrade
      Intentionally generate an incremental OTA that updates from a newer
      build to an older one (based on timestamp comparison). "post-timestamp"
      will be replaced by "ota-downgrade=yes" in the metadata file. A data
      wipe will always be enforced, so "ota-wipe=yes" will also be included in
      the metadata file. The update-binary in the source build will be used in
      the OTA package, unless --binary flag is specified. Please also check the
      doc for --override_timestamp below.

  --override_timestamp
      Intentionally generate an incremental OTA that updates from a newer
      build to an older one (based on timestamp comparison), by overriding the
      timestamp in package metadata. This differs from --downgrade flag: we
      know for sure this is NOT an actual downgrade case, but two builds are
      cut in a reverse order. A legit use case is that we cut a new build C
      (after having A and B), but want to enfore an update path of A -> C -> B.
      Specifying --downgrade may not help since that would enforce a data wipe
      for C -> B update. The value of "post-timestamp" will be set to the newer
      timestamp plus one, so that the package can be pushed and applied.

  -e  (--extra_script)  <file>
      Insert the contents of file at the end of the update script.

  -2  (--two_step)
      Generate a 'two-step' OTA package, where recovery is updated
      first, so that any changes made to the system partition are done
      using the new recovery (new kernel, etc.).

  --block
      Generate a block-based OTA for non-A/B device. We have deprecated the
      support for file-based OTA since O. Block-based OTA will be used by
      default for all non-A/B devices. Keeping this flag here to not break
      existing callers.

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

from __future__ import print_function

import sys

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

import copy
import multiprocessing
import os.path
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
OPTIONS.patch_threshold = 0.95
OPTIONS.wipe_user_data = False
OPTIONS.downgrade = False
OPTIONS.timestamp = False
OPTIONS.extra_script = None
OPTIONS.worker_threads = multiprocessing.cpu_count() // 2
if OPTIONS.worker_threads == 0:
  OPTIONS.worker_threads = 1
OPTIONS.two_step = False
OPTIONS.no_signing = False
OPTIONS.block_based = True
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
OPTIONS.extracted_input = None

METADATA_NAME = 'META-INF/com/android/metadata'
UNZIP_PATTERN = ['IMAGES/*', 'META/*']


def SignOutput(temp_zip_name, output_zip_name):
  key_passwords = common.GetKeyPasswords([OPTIONS.package_key])
  pw = key_passwords[OPTIONS.package_key]

  common.SignFile(temp_zip_name, output_zip_name, OPTIONS.package_key, pw,
                  whole_file=True)


def AppendAssertions(script, info_dict, oem_dicts=None):
  oem_props = info_dict.get("oem_fingerprint_properties")
  if not oem_props:
    device = GetBuildProp("ro.product.device", info_dict)
    script.AssertDevice(device)
  else:
    if not oem_dicts:
      raise common.ExternalError(
          "No OEM file provided to answer expected assertions")
    for prop in oem_props.split():
      values = []
      for oem_dict in oem_dicts:
        if oem_dict.get(prop):
          values.append(oem_dict[prop])
      if not values:
        raise common.ExternalError(
            "The OEM file is missing the property %s" % prop)
      script.AssertOemProperty(prop, values)


def _LoadOemDicts(script, recovery_mount_options=None):
  """Returns the list of loaded OEM properties dict."""
  oem_dicts = None
  if OPTIONS.oem_source is None:
    raise common.ExternalError("OEM source required for this build")
  if not OPTIONS.oem_no_mount and script:
    script.Mount("/oem", recovery_mount_options)
  oem_dicts = []
  for oem_file in OPTIONS.oem_source:
    oem_dicts.append(common.LoadDictionaryFromLines(
        open(oem_file).readlines()))
  return oem_dicts


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
    print("two-step package: using %s in stage 1/3" % (
        recovery_two_step_img_name,))
    script.WriteRawImage("/boot", recovery_two_step_img_name)
  else:
    print("two-step package: using recovery.img in stage 1/3")
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


def GetImage(which, tmpdir):
  """Returns an image object suitable for passing to BlockImageDiff.

  'which' partition must be "system" or "vendor". A prebuilt image and file
  map must already exist in tmpdir.
  """

  assert which in ("system", "vendor")

  path = os.path.join(tmpdir, "IMAGES", which + ".img")
  mappath = os.path.join(tmpdir, "IMAGES", which + ".map")

  # The image and map files must have been created prior to calling
  # ota_from_target_files.py (since LMP).
  assert os.path.exists(path) and os.path.exists(mappath)

  # Bug: http://b/20939131
  # In ext4 filesystems, block 0 might be changed even being mounted
  # R/O. We add it to clobbered_blocks so that it will be written to the
  # target unconditionally. Note that they are still part of care_map.
  clobbered_blocks = "0"

  return sparse_img.SparseImage(path, mappath, clobbered_blocks)


def AddCompatibilityArchive(target_zip, output_zip, system_included=True,
                            vendor_included=True):
  """Adds compatibility info from target files into the output zip.

  Metadata used for on-device compatibility verification is retrieved from
  target_zip then added to compatibility.zip which is added to the output_zip
  archive.

  Compatibility archive should only be included for devices with a vendor
  partition as checking provides value when system and vendor are independently
  versioned.

  Args:
    target_zip: Zip file containing the source files to be included for OTA.
    output_zip: Zip file that will be sent for OTA.
    system_included: If True, the system image will be updated and therefore
        its metadata should be included.
    vendor_included: If True, the vendor image will be updated and therefore
        its metadata should be included.
  """

  # Determine what metadata we need. Files are names relative to META/.
  compatibility_files = []
  vendor_metadata = ("vendor_manifest.xml", "vendor_matrix.xml")
  system_metadata = ("system_manifest.xml", "system_matrix.xml")
  if vendor_included:
    compatibility_files += vendor_metadata
  if system_included:
    compatibility_files += system_metadata

  # Create new archive.
  compatibility_archive = tempfile.NamedTemporaryFile()
  compatibility_archive_zip = zipfile.ZipFile(compatibility_archive, "w",
      compression=zipfile.ZIP_DEFLATED)

  # Add metadata.
  for file_name in compatibility_files:
    target_file_name = "META/" + file_name

    if target_file_name in target_zip.namelist():
      data = target_zip.read(target_file_name)
      common.ZipWriteStr(compatibility_archive_zip, file_name, data)

  # Ensure files are written before we copy into output_zip.
  compatibility_archive_zip.close()

  # Only add the archive if we have any compatibility info.
  if compatibility_archive_zip.namelist():
    common.ZipWrite(output_zip, compatibility_archive.name,
                    arcname="compatibility.zip",
                    compress_type=zipfile.ZIP_STORED)


def WriteFullOTAPackage(input_zip, output_zip):
  # TODO: how to determine this?  We don't know what version it will
  # be installed on top of. For now, we expect the API just won't
  # change very often. Similarly for fstab, it might have changed
  # in the target build.
  script = edify_generator.EdifyGenerator(3, OPTIONS.info_dict)

  recovery_mount_options = OPTIONS.info_dict.get("recovery_mount_options")
  oem_props = OPTIONS.info_dict.get("oem_fingerprint_properties")
  oem_dicts = None
  if oem_props:
    oem_dicts = _LoadOemDicts(script, recovery_mount_options)

  target_fp = CalculateFingerprint(oem_props, oem_dicts and oem_dicts[0],
                                   OPTIONS.info_dict)
  metadata = {
      "post-build": target_fp,
      "pre-device": GetOemProperty("ro.product.device", oem_props,
                                   oem_dicts and oem_dicts[0],
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

  assert HasRecoveryPatch(input_zip)

  metadata["ota-type"] = "BLOCK"

  ts = GetBuildProp("ro.build.date.utc", OPTIONS.info_dict)
  ts_text = GetBuildProp("ro.build.date", OPTIONS.info_dict)
  script.AssertOlderBuild(ts, ts_text)

  AppendAssertions(script, OPTIONS.info_dict, oem_dicts)
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
  script.Print("Target: %s" % target_fp)

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

  script.ShowProgress(system_progress, 0)

  # Full OTA is done as an "incremental" against an empty source image. This
  # has the effect of writing new data from the package to the entire
  # partition, but lets us reuse the updater code that writes incrementals to
  # do it.
  system_tgt = GetImage("system", OPTIONS.input_tmp)
  system_tgt.ResetFileMap()
  system_diff = common.BlockDifference("system", system_tgt, src=None)
  system_diff.WriteScript(script, output_zip)

  boot_img = common.GetBootableImage(
      "boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")

  if HasVendorPartition(input_zip):
    script.ShowProgress(0.1, 0)

    vendor_tgt = GetImage("vendor", OPTIONS.input_tmp)
    vendor_tgt.ResetFileMap()
    vendor_diff = common.BlockDifference("vendor", vendor_tgt)
    vendor_diff.WriteScript(script, output_zip)

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
  value = "".join(["%s=%s\n" % kv for kv in sorted(metadata.iteritems())])
  common.ZipWriteStr(output_zip, METADATA_NAME, value,
                     compress_type=zipfile.ZIP_STORED)


def GetBuildProp(prop, info_dict):
  """Return the fingerprint of the build of a given target-files info_dict."""
  try:
    return info_dict.get("build.prop", {})[prop]
  except KeyError:
    raise common.ExternalError("couldn't find %s in build.prop" % (prop,))


def HandleDowngradeMetadata(metadata):
  # Only incremental OTAs are allowed to reach here.
  assert OPTIONS.incremental_source is not None

  post_timestamp = GetBuildProp("ro.build.date.utc", OPTIONS.target_info_dict)
  pre_timestamp = GetBuildProp("ro.build.date.utc", OPTIONS.source_info_dict)
  is_downgrade = long(post_timestamp) < long(pre_timestamp)

  if OPTIONS.downgrade:
    if not is_downgrade:
      raise RuntimeError("--downgrade specified but no downgrade detected: "
                         "pre: %s, post: %s" % (pre_timestamp, post_timestamp))
    metadata["ota-downgrade"] = "yes"
  elif OPTIONS.timestamp:
    if not is_downgrade:
      raise RuntimeError("--timestamp specified but no timestamp hack needed: "
                         "pre: %s, post: %s" % (pre_timestamp, post_timestamp))
    metadata["post-timestamp"] = str(long(pre_timestamp) + 1)
  else:
    if is_downgrade:
      raise RuntimeError("Downgrade detected based on timestamp check: "
                         "pre: %s, post: %s. Need to specify --timestamp OR "
                         "--downgrade to allow building the incremental." % (
                             pre_timestamp, post_timestamp))
    metadata["post-timestamp"] = post_timestamp


def WriteBlockIncrementalOTAPackage(target_zip, source_zip, output_zip):
  source_version = OPTIONS.source_info_dict["recovery_api_version"]
  target_version = OPTIONS.target_info_dict["recovery_api_version"]

  if source_version == 0:
    print("WARNING: generating edify script for a source that "
          "can't install it.")
  script = edify_generator.EdifyGenerator(
      source_version, OPTIONS.target_info_dict,
      fstab=OPTIONS.source_info_dict["fstab"])

  recovery_mount_options = OPTIONS.source_info_dict.get(
      "recovery_mount_options")
  source_oem_props = OPTIONS.source_info_dict.get("oem_fingerprint_properties")
  target_oem_props = OPTIONS.target_info_dict.get("oem_fingerprint_properties")
  oem_dicts = None
  if source_oem_props and target_oem_props:
    oem_dicts = _LoadOemDicts(script, recovery_mount_options)

  metadata = {
      "pre-device": GetOemProperty("ro.product.device", source_oem_props,
                                   oem_dicts and oem_dicts[0],
                                   OPTIONS.source_info_dict),
      "ota-type": "BLOCK",
  }

  HandleDowngradeMetadata(metadata)

  device_specific = common.DeviceSpecificParams(
      source_zip=source_zip,
      source_version=source_version,
      target_zip=target_zip,
      target_version=target_version,
      output_zip=output_zip,
      script=script,
      metadata=metadata,
      info_dict=OPTIONS.source_info_dict)

  source_fp = CalculateFingerprint(source_oem_props, oem_dicts and oem_dicts[0],
                                   OPTIONS.source_info_dict)
  target_fp = CalculateFingerprint(target_oem_props, oem_dicts and oem_dicts[0],
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

  system_src = GetImage("system", OPTIONS.source_tmp)
  system_tgt = GetImage("system", OPTIONS.target_tmp)

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
    vendor_src = GetImage("vendor", OPTIONS.source_tmp)
    vendor_tgt = GetImage("vendor", OPTIONS.target_tmp)

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

  AppendAssertions(script, OPTIONS.target_info_dict, oem_dicts)
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

  # When blockimgdiff version is less than 3 (non-resumable block-based OTA),
  # patching on a device that's already on the target build will damage the
  # system. Because operations like move don't check the block state, they
  # always apply the changes unconditionally.
  if blockimgdiff_version <= 2:
    if source_oem_props is None:
      script.AssertSomeFingerprint(source_fp)
    else:
      script.AssertSomeThumbprint(
          GetBuildProp("ro.build.thumbprint", OPTIONS.source_info_dict))

  else: # blockimgdiff_version > 2
    if source_oem_props is None and target_oem_props is None:
      script.AssertSomeFingerprint(source_fp, target_fp)
    elif source_oem_props is not None and target_oem_props is not None:
      script.AssertSomeThumbprint(
          GetBuildProp("ro.build.thumbprint", OPTIONS.target_info_dict),
          GetBuildProp("ro.build.thumbprint", OPTIONS.source_info_dict))
    elif source_oem_props is None and target_oem_props is not None:
      script.AssertFingerprintOrThumbprint(
          source_fp,
          GetBuildProp("ro.build.thumbprint", OPTIONS.target_info_dict))
    else:
      script.AssertFingerprintOrThumbprint(
          target_fp,
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

      print("boot      target: %d  source: %d  diff: %d" % (
          target_boot.size, source_boot.size, len(d)))

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
    print("writing full boot image (forced by two-step mode)")

  if not OPTIONS.two_step:
    if updating_boot:
      if include_full_boot:
        print("boot image changed; including full.")
        script.Print("Installing boot image...")
        script.WriteRawImage("/boot", "boot.img")
      else:
        # Produce the boot image by applying a patch to the current
        # contents of the boot partition, and write it back to the
        # partition.
        print("boot image changed; including patch.")
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
      print("boot image unchanged; skipping.")

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
  oem_dicts = None
  if oem_props:
    oem_dicts = _LoadOemDicts(script, recovery_mount_options)

  target_fp = CalculateFingerprint(oem_props, oem_dicts and oem_dicts[0],
                                   OPTIONS.info_dict)
  metadata = {
      "post-build": target_fp,
      "pre-device": GetOemProperty("ro.product.device", oem_props,
                                   oem_dicts and oem_dicts[0],
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

  AppendAssertions(script, OPTIONS.info_dict, oem_dicts)

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

  system_tgt = GetImage("system", OPTIONS.input_tmp)
  system_tgt.ResetFileMap()
  system_diff = common.BlockDifference("system", system_tgt, src=None)
  system_diff.WriteStrictVerifyScript(script)

  if HasVendorPartition(input_zip):
    vendor_tgt = GetImage("vendor", OPTIONS.input_tmp)
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

  def ComputeStreamingMetadata(zip_file, reserve_space=False,
                               expected_length=None):
    """Compute the streaming metadata for a given zip.

    When 'reserve_space' is True, we reserve extra space for the offset and
    length of the metadata entry itself, although we don't know the final
    values until the package gets signed. This function will be called again
    after signing. We then write the actual values and pad the string to the
    length we set earlier. Note that we can't use the actual length of the
    metadata entry in the second run. Otherwise the offsets for other entries
    will be changing again.
    """

    def ComputeEntryOffsetSize(name):
      """Compute the zip entry offset and size."""
      info = zip_file.getinfo(name)
      offset = info.header_offset + len(info.FileHeader())
      size = info.file_size
      return '%s:%d:%d' % (os.path.basename(name), offset, size)

    # payload.bin and payload_properties.txt must exist.
    offsets = [ComputeEntryOffsetSize('payload.bin'),
               ComputeEntryOffsetSize('payload_properties.txt')]

    # care_map.txt is available only if dm-verity is enabled.
    if 'care_map.txt' in zip_file.namelist():
      offsets.append(ComputeEntryOffsetSize('care_map.txt'))

    if 'compatibility.zip' in zip_file.namelist():
      offsets.append(ComputeEntryOffsetSize('compatibility.zip'))

    # 'META-INF/com/android/metadata' is required. We don't know its actual
    # offset and length (as well as the values for other entries). So we
    # reserve 10-byte as a placeholder, which is to cover the space for metadata
    # entry ('xx:xxx', since it's ZIP_STORED which should appear at the
    # beginning of the zip), as well as the possible value changes in other
    # entries.
    if reserve_space:
      offsets.append('metadata:' + ' ' * 10)
    else:
      offsets.append(ComputeEntryOffsetSize(METADATA_NAME))

    value = ','.join(offsets)
    if expected_length is not None:
      assert len(value) <= expected_length, \
          'Insufficient reserved space: reserved=%d, actual=%d' % (
              expected_length, len(value))
      value += ' ' * (expected_length - len(value))
    return value

  # The place where the output from the subprocess should go.
  log_file = sys.stdout if OPTIONS.verbose else subprocess.PIPE

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
    p1 = common.Run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
    p1.communicate()
    assert p1.returncode == 0, "openssl pkcs8 failed"

  # Stage the output zip package for package signing.
  temp_zip_file = tempfile.NamedTemporaryFile()
  output_zip = zipfile.ZipFile(temp_zip_file, "w",
                               compression=zipfile.ZIP_DEFLATED)

  # Metadata to comply with Android OTA package format.
  oem_props = OPTIONS.info_dict.get("oem_fingerprint_properties", None)
  oem_dicts = None
  if oem_props:
    oem_dicts = _LoadOemDicts(None)

  metadata = {
      "post-build": CalculateFingerprint(oem_props, oem_dicts and oem_dicts[0],
                                         OPTIONS.info_dict),
      "post-build-incremental" : GetBuildProp("ro.build.version.incremental",
                                              OPTIONS.info_dict),
      "pre-device": GetOemProperty("ro.product.device", oem_props,
                                   oem_dicts and oem_dicts[0],
                                   OPTIONS.info_dict),
      "ota-required-cache": "0",
      "ota-type": "AB",
  }

  if source_file is not None:
    metadata["pre-build"] = CalculateFingerprint(oem_props,
                                                 oem_dicts and oem_dicts[0],
                                                 OPTIONS.source_info_dict)
    metadata["pre-build-incremental"] = GetBuildProp(
        "ro.build.version.incremental", OPTIONS.source_info_dict)

    HandleDowngradeMetadata(metadata)
  else:
    metadata["post-timestamp"] = GetBuildProp(
        "ro.build.date.utc", OPTIONS.info_dict)

  # 1. Generate payload.
  payload_file = common.MakeTempFile(prefix="payload-", suffix=".bin")
  cmd = ["brillo_update_payload", "generate",
         "--payload", payload_file,
         "--target_image", target_file]
  if source_file is not None:
    cmd.extend(["--source_image", source_file])
  p1 = common.Run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
  p1.communicate()
  assert p1.returncode == 0, "brillo_update_payload generate failed"

  # 2. Generate hashes of the payload and metadata files.
  payload_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
  metadata_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
  cmd = ["brillo_update_payload", "hash",
         "--unsigned_payload", payload_file,
         "--signature_size", "256",
         "--metadata_hash_file", metadata_sig_file,
         "--payload_hash_file", payload_sig_file]
  p1 = common.Run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
  p1.communicate()
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
  p1 = common.Run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
  p1.communicate()
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
  p1 = common.Run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
  p1.communicate()
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
  p1 = common.Run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
  p1.communicate()
  assert p1.returncode == 0, "brillo_update_payload sign failed"

  # 4. Dump the signed payload properties.
  properties_file = common.MakeTempFile(prefix="payload-properties-",
                                        suffix=".txt")
  cmd = ["brillo_update_payload", "properties",
         "--payload", signed_payload_file,
         "--properties_file", properties_file]
  p1 = common.Run(cmd, stdout=log_file, stderr=subprocess.STDOUT)
  p1.communicate()
  assert p1.returncode == 0, "brillo_update_payload properties failed"

  if OPTIONS.wipe_user_data:
    with open(properties_file, "a") as f:
      f.write("POWERWASH=1\n")
    metadata["ota-wipe"] = "yes"

  # Add the signed payload file and properties into the zip. In order to
  # support streaming, we pack payload.bin, payload_properties.txt and
  # care_map.txt as ZIP_STORED. So these entries can be read directly with
  # the offset and length pairs.
  common.ZipWrite(output_zip, signed_payload_file, arcname="payload.bin",
                  compress_type=zipfile.ZIP_STORED)
  common.ZipWrite(output_zip, properties_file,
                  arcname="payload_properties.txt",
                  compress_type=zipfile.ZIP_STORED)

  # If dm-verity is supported for the device, copy contents of care_map
  # into A/B OTA package.
  target_zip = zipfile.ZipFile(target_file, "r")
  if OPTIONS.info_dict.get("verity") == "true":
    care_map_path = "META/care_map.txt"
    namelist = target_zip.namelist()
    if care_map_path in namelist:
      care_map_data = target_zip.read(care_map_path)
      common.ZipWriteStr(output_zip, "care_map.txt", care_map_data,
          compress_type=zipfile.ZIP_STORED)
    else:
      print("Warning: cannot find care map file in target_file package")

  if HasVendorPartition(target_zip):
    update_vendor = True
    update_system = True

    # If incremental then figure out what is being updated so metadata only for
    # the updated image is included.
    if source_file is not None:
      input_tmp, input_zip = common.UnzipTemp(
          target_file, UNZIP_PATTERN)
      source_tmp, source_zip = common.UnzipTemp(
          source_file, UNZIP_PATTERN)

      vendor_src = GetImage("vendor", source_tmp)
      vendor_tgt = GetImage("vendor", input_tmp)
      system_src = GetImage("system", source_tmp)
      system_tgt = GetImage("system", input_tmp)

      update_system = system_src.TotalSha1() != system_tgt.TotalSha1()
      update_vendor = vendor_src.TotalSha1() != vendor_tgt.TotalSha1()

      input_zip.close()
      source_zip.close()

    target_zip = zipfile.ZipFile(target_file, "r")
    AddCompatibilityArchive(target_zip, output_zip, update_system,
                            update_vendor)
  common.ZipClose(target_zip)

  # Write the current metadata entry with placeholders.
  metadata['ota-streaming-property-files'] = ComputeStreamingMetadata(
      output_zip, reserve_space=True)
  WriteMetadata(metadata, output_zip)
  common.ZipClose(output_zip)

  # SignOutput(), which in turn calls signapk.jar, will possibly reorder the
  # zip entries, as well as padding the entry headers. We do a preliminary
  # signing (with an incomplete metadata entry) to allow that to happen. Then
  # compute the zip entry offsets, write back the final metadata and do the
  # final signing.
  prelim_signing = tempfile.NamedTemporaryFile()
  SignOutput(temp_zip_file.name, prelim_signing.name)
  common.ZipClose(temp_zip_file)

  # Open the signed zip. Compute the final metadata that's needed for streaming.
  prelim_zip = zipfile.ZipFile(prelim_signing, "r",
                               compression=zipfile.ZIP_DEFLATED)
  expected_length = len(metadata['ota-streaming-property-files'])
  metadata['ota-streaming-property-files'] = ComputeStreamingMetadata(
      prelim_zip, reserve_space=False, expected_length=expected_length)

  # Copy the zip entries, as we cannot update / delete entries with zipfile.
  final_signing = tempfile.NamedTemporaryFile()
  output_zip = zipfile.ZipFile(final_signing, "w",
                               compression=zipfile.ZIP_DEFLATED)
  for item in prelim_zip.infolist():
    if item.filename == METADATA_NAME:
      continue

    data = prelim_zip.read(item.filename)
    out_info = copy.copy(item)
    common.ZipWriteStr(output_zip, out_info, data)

  # Now write the final metadata entry.
  WriteMetadata(metadata, output_zip)
  common.ZipClose(prelim_zip)
  common.ZipClose(output_zip)

  # Re-sign the package after updating the metadata entry.
  SignOutput(final_signing.name, output_file)
  final_signing.close()

  # Reopen the final signed zip to double check the streaming metadata.
  output_zip = zipfile.ZipFile(output_file, "r")
  actual = metadata['ota-streaming-property-files'].strip()
  expected = ComputeStreamingMetadata(output_zip)
  assert actual == expected, \
      "Mismatching streaming metadata: %s vs %s." % (actual, expected)
  common.ZipClose(output_zip)


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
    elif o == "--downgrade":
      OPTIONS.downgrade = True
      OPTIONS.wipe_user_data = True
    elif o == "--override_timestamp":
      OPTIONS.timestamp = True
    elif o in ("-o", "--oem_settings"):
      OPTIONS.oem_source = a.split(',')
    elif o == "--oem_no_mount":
      OPTIONS.oem_no_mount = True
    elif o in ("-e", "--extra_script"):
      OPTIONS.extra_script = a
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
    elif o == "--extracted_input_target_files":
      OPTIONS.extracted_input = a
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts="b:k:i:d:we:t:2o:",
                             extra_long_opts=[
                                 "board_config=",
                                 "package_key=",
                                 "incremental_from=",
                                 "full_radio",
                                 "full_bootloader",
                                 "wipe_user_data",
                                 "downgrade",
                                 "override_timestamp",
                                 "extra_script=",
                                 "worker_threads=",
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
                                 "extracted_input_target_files=",
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
      raise ValueError("Cannot generate downgradable full OTAs")

  assert not (OPTIONS.downgrade and OPTIONS.timestamp), \
      "Cannot have --downgrade AND --override_timestamp both"

  # Load the dict file from the zip directly to have a peek at the OTA type.
  # For packages using A/B update, unzipping is not needed.
  if OPTIONS.extracted_input is not None:
    OPTIONS.info_dict = common.LoadInfoDict(OPTIONS.extracted_input, OPTIONS.extracted_input)
  else:
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
      print("--- target info ---")
      common.DumpInfoDict(OPTIONS.info_dict)

      if OPTIONS.incremental_source is not None:
        print("--- source info ---")
        common.DumpInfoDict(OPTIONS.source_info_dict)

    WriteABOTAPackageWithBrilloScript(
        target_file=args[0],
        output_file=args[1],
        source_file=OPTIONS.incremental_source)

    print("done.")
    return

  if OPTIONS.extra_script is not None:
    OPTIONS.extra_script = open(OPTIONS.extra_script).read()

  if OPTIONS.extracted_input is not None:
    OPTIONS.input_tmp = OPTIONS.extracted_input
    OPTIONS.target_tmp = OPTIONS.input_tmp
    OPTIONS.info_dict = common.LoadInfoDict(OPTIONS.input_tmp, OPTIONS.input_tmp)
    input_zip = zipfile.ZipFile(args[0], "r")
  else:
    print("unzipping target target-files...")
    OPTIONS.input_tmp, input_zip = common.UnzipTemp(
        args[0], UNZIP_PATTERN)

    OPTIONS.target_tmp = OPTIONS.input_tmp
    OPTIONS.info_dict = common.LoadInfoDict(input_zip, OPTIONS.target_tmp)

  if OPTIONS.verbose:
    print("--- target info ---")
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
      print("(using device-specific extensions from target_files)")
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
    print("--- can't determine the cache partition size ---")
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
    print("unzipping source target-files...")
    OPTIONS.source_tmp, source_zip = common.UnzipTemp(
        OPTIONS.incremental_source,
        UNZIP_PATTERN)
    OPTIONS.target_info_dict = OPTIONS.info_dict
    OPTIONS.source_info_dict = common.LoadInfoDict(source_zip,
                                                   OPTIONS.source_tmp)
    if OPTIONS.verbose:
      print("--- source info ---")
      common.DumpInfoDict(OPTIONS.source_info_dict)
    try:
      WriteBlockIncrementalOTAPackage(input_zip, source_zip, output_zip)
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
      print("--- failed to build incremental; falling back to full ---")
      OPTIONS.incremental_source = None
      WriteFullOTAPackage(input_zip, output_zip)

  common.ZipClose(output_zip)

  # Sign the generated zip package unless no_signing is specified.
  if not OPTIONS.no_signing:
    SignOutput(temp_zip_file.name, args[1])
    temp_zip_file.close()

  print("done.")


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  except common.ExternalError as e:
    print("\n   ERROR: %s\n" % (e,))
    sys.exit(1)
  finally:
    common.Cleanup()
