# Copyright (C) 2020 The Android Open Source Project
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

import collections
import copy
import imp
import logging
import os
import time
import threading
import tempfile
import zipfile
import subprocess
import shlex

import common
import edify_generator
from edify_generator import ErrorCode
from check_target_files_vintf import CheckVintfIfTrebleEnabled, HasPartition
from common import OPTIONS, Run, MakeTempDir, RunAndCheckOutput, ZipWrite, MakeTempFile
from ota_utils import UNZIP_PATTERN, FinalizeMetadata, GetPackageMetadata, PropertyFiles
from blockimgdiff import BlockImageDiff
from hashlib import sha1

logger = logging.getLogger(__name__)


def GetBlockDifferences(target_zip, source_zip, target_info, source_info,
                        device_specific):
  """Returns a ordered dict of block differences with partition name as key."""

  def GetIncrementalBlockDifferenceForPartition(name):
    if not HasPartition(source_zip, name):
      raise RuntimeError(
          "can't generate incremental that adds {}".format(name))

    partition_src = common.GetUserImage(name, OPTIONS.source_tmp, source_zip,
                                        info_dict=source_info,
                                        allow_shared_blocks=allow_shared_blocks)

    partition_tgt = common.GetUserImage(name, OPTIONS.target_tmp, target_zip,
                                        info_dict=target_info,
                                        allow_shared_blocks=allow_shared_blocks)

    # Check the first block of the source system partition for remount R/W only
    # if the filesystem is ext4.
    partition_source_info = source_info["fstab"]["/" + name]
    check_first_block = partition_source_info.fs_type == "ext4"
    # Disable imgdiff because it relies on zlib to produce stable output
    # across different versions, which is often not the case.
    return BlockDifference(name, partition_tgt, partition_src,
                                  check_first_block,
                                  version=blockimgdiff_version,
                                  disable_imgdiff=True)

  if source_zip:
    # See notes in common.GetUserImage()
    allow_shared_blocks = (source_info.get('ext4_share_dup_blocks') == "true" or
                           target_info.get('ext4_share_dup_blocks') == "true")
    blockimgdiff_version = max(
        int(i) for i in target_info.get(
            "blockimgdiff_versions", "1").split(","))
    assert blockimgdiff_version >= 3

  block_diff_dict = collections.OrderedDict()
  partition_names = ["system", "vendor", "product", "odm", "system_ext",
                     "vendor_dlkm", "odm_dlkm", "system_dlkm"]
  for partition in partition_names:
    if not HasPartition(target_zip, partition):
      continue
    # Full OTA update.
    if not source_zip:
      tgt = common.GetUserImage(partition, OPTIONS.input_tmp, target_zip,
                                info_dict=target_info,
                                reset_file_map=True)
      block_diff_dict[partition] = BlockDifference(partition, tgt,
                                                          src=None)
    # Incremental OTA update.
    else:
      block_diff_dict[partition] = GetIncrementalBlockDifferenceForPartition(
          partition)
  assert "system" in block_diff_dict

  # Get the block diffs from the device specific script. If there is a
  # duplicate block diff for a partition, ignore the diff in the generic script
  # and use the one in the device specific script instead.
  if source_zip:
    device_specific_diffs = device_specific.IncrementalOTA_GetBlockDifferences()
    function_name = "IncrementalOTA_GetBlockDifferences"
  else:
    device_specific_diffs = device_specific.FullOTA_GetBlockDifferences()
    function_name = "FullOTA_GetBlockDifferences"

  if device_specific_diffs:
    assert all(isinstance(diff, BlockDifference)
               for diff in device_specific_diffs), \
        "{} is not returning a list of BlockDifference objects".format(
            function_name)
    for diff in device_specific_diffs:
      if diff.partition in block_diff_dict:
        logger.warning("Duplicate block difference found. Device specific block"
                       " diff for partition '%s' overrides the one in generic"
                       " script.", diff.partition)
      block_diff_dict[diff.partition] = diff

  return block_diff_dict


def WriteFullOTAPackage(input_zip, output_file):
  target_info = common.BuildInfo(OPTIONS.info_dict, OPTIONS.oem_dicts)

  # We don't know what version it will be installed on top of. We expect the API
  # just won't change very often. Similarly for fstab, it might have changed in
  # the target build.
  target_api_version = target_info["recovery_api_version"]
  script = edify_generator.EdifyGenerator(target_api_version, target_info)

  if target_info.oem_props and not OPTIONS.oem_no_mount:
    target_info.WriteMountOemScript(script)

  metadata = GetPackageMetadata(target_info)

  if not OPTIONS.no_signing:
    staging_file = common.MakeTempFile(suffix='.zip')
  else:
    staging_file = output_file

  output_zip = zipfile.ZipFile(
      staging_file, "w", compression=zipfile.ZIP_DEFLATED)

  device_specific = DeviceSpecificParams(
      input_zip=input_zip,
      input_version=target_api_version,
      output_zip=output_zip,
      script=script,
      input_tmp=OPTIONS.input_tmp,
      metadata=metadata,
      info_dict=OPTIONS.info_dict)

  assert HasRecoveryPatch(input_zip, info_dict=OPTIONS.info_dict)

  # Assertions (e.g. downgrade check, device properties check).
  ts = target_info.GetBuildProp("ro.build.date.utc")
  ts_text = target_info.GetBuildProp("ro.build.date")
  script.AssertOlderBuild(ts, ts_text)

  target_info.WriteDeviceAssertions(script, OPTIONS.oem_no_mount)
  device_specific.FullOTA_Assertions()

  block_diff_dict = GetBlockDifferences(target_zip=input_zip, source_zip=None,
                                        target_info=target_info,
                                        source_info=None,
                                        device_specific=device_specific)

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
    if not target_info.get("multistage_support"):
      assert False, "two-step packages not supported by this build"
    fs = target_info["fstab"]["/misc"]
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
  script.Print("Target: {}".format(target_info.fingerprint))

  device_specific.FullOTA_InstallBegin()

  # All other partitions as well as the data wipe use 10% of the progress, and
  # the update of the system partition takes the remaining progress.
  system_progress = 0.9 - (len(block_diff_dict) - 1) * 0.1
  if OPTIONS.wipe_user_data:
    system_progress -= 0.1
  progress_dict = {partition: 0.1 for partition in block_diff_dict}
  progress_dict["system"] = system_progress

  if target_info.get('use_dynamic_partitions') == "true":
    # Use empty source_info_dict to indicate that all partitions / groups must
    # be re-added.
    dynamic_partitions_diff = DynamicPartitionsDifference(
        info_dict=OPTIONS.info_dict,
        block_diffs=block_diff_dict.values(),
        progress_dict=progress_dict)
    dynamic_partitions_diff.WriteScript(script, output_zip,
                                        write_verify_script=OPTIONS.verify)
  else:
    for block_diff in block_diff_dict.values():
      block_diff.WriteScript(script, output_zip,
                             progress=progress_dict.get(block_diff.partition),
                             write_verify_script=OPTIONS.verify)

  CheckVintfIfTrebleEnabled(OPTIONS.input_tmp, target_info)

  boot_img = common.GetBootableImage(
      "boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")
  common.CheckSize(boot_img.data, "boot.img", target_info)
  common.ZipWriteStr(output_zip, "boot.img", boot_img.data)

  script.WriteRawImage("/boot", "boot.img")

  script.ShowProgress(0.1, 10)
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
  metadata.required_cache = script.required_cache

  # We haven't written the metadata entry, which will be done in
  # FinalizeMetadata.
  common.ZipClose(output_zip)

  needed_property_files = (
      NonAbOtaPropertyFiles(),
  )
  FinalizeMetadata(metadata, staging_file, output_file,
                   needed_property_files, package_key=OPTIONS.package_key)


def WriteBlockIncrementalOTAPackage(target_zip, source_zip, output_file):
  target_info = common.BuildInfo(OPTIONS.target_info_dict, OPTIONS.oem_dicts)
  source_info = common.BuildInfo(OPTIONS.source_info_dict, OPTIONS.oem_dicts)

  target_api_version = target_info["recovery_api_version"]
  source_api_version = source_info["recovery_api_version"]
  if source_api_version == 0:
    logger.warning(
        "Generating edify script for a source that can't install it.")

  script = edify_generator.EdifyGenerator(
      source_api_version, target_info, fstab=source_info["fstab"])

  if target_info.oem_props or source_info.oem_props:
    if not OPTIONS.oem_no_mount:
      source_info.WriteMountOemScript(script)

  metadata = GetPackageMetadata(target_info, source_info)

  if not OPTIONS.no_signing:
    staging_file = common.MakeTempFile(suffix='.zip')
  else:
    staging_file = output_file

  output_zip = zipfile.ZipFile(
      staging_file, "w", compression=zipfile.ZIP_DEFLATED)

  device_specific = DeviceSpecificParams(
      source_zip=source_zip,
      source_version=source_api_version,
      source_tmp=OPTIONS.source_tmp,
      target_zip=target_zip,
      target_version=target_api_version,
      target_tmp=OPTIONS.target_tmp,
      output_zip=output_zip,
      script=script,
      metadata=metadata,
      info_dict=source_info)

  source_boot = common.GetBootableImage(
      "/tmp/boot.img", "boot.img", OPTIONS.source_tmp, "BOOT", source_info)
  target_boot = common.GetBootableImage(
      "/tmp/boot.img", "boot.img", OPTIONS.target_tmp, "BOOT", target_info)
  updating_boot = (not OPTIONS.two_step and
                   (source_boot.data != target_boot.data))

  target_recovery = common.GetBootableImage(
      "/tmp/recovery.img", "recovery.img", OPTIONS.target_tmp, "RECOVERY")

  block_diff_dict = GetBlockDifferences(target_zip=target_zip,
                                        source_zip=source_zip,
                                        target_info=target_info,
                                        source_info=source_info,
                                        device_specific=device_specific)

  CheckVintfIfTrebleEnabled(OPTIONS.target_tmp, target_info)

  # Assertions (e.g. device properties check).
  target_info.WriteDeviceAssertions(script, OPTIONS.oem_no_mount)
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
    if not source_info.get("multistage_support"):
      assert False, "two-step packages not supported by this build"
    fs = source_info["fstab"]["/misc"]
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
  script.Print("Source: {}".format(source_info.fingerprint))
  script.Print("Target: {}".format(target_info.fingerprint))

  script.Print("Verifying current system...")

  device_specific.IncrementalOTA_VerifyBegin()

  WriteFingerprintAssertion(script, target_info, source_info)

  # Check the required cache size (i.e. stashed blocks).
  required_cache_sizes = [diff.required_cache for diff in
                          block_diff_dict.values()]
  if updating_boot:
    boot_type, boot_device_expr = GetTypeAndDeviceExpr("/boot",
                                                              source_info)
    d = Difference(target_boot, source_boot, "bsdiff")
    _, _, d = d.ComputePatch()
    if d is None:
      include_full_boot = True
      common.ZipWriteStr(output_zip, "boot.img", target_boot.data)
    else:
      include_full_boot = False

      logger.info(
          "boot      target: %d  source: %d  diff: %d", target_boot.size,
          source_boot.size, len(d))

      common.ZipWriteStr(output_zip, "boot.img.p", d)

      target_expr = 'concat("{}:",{},":{}:{}")'.format(
          boot_type, boot_device_expr, target_boot.size, target_boot.sha1)
      source_expr = 'concat("{}:",{},":{}:{}")'.format(
          boot_type, boot_device_expr, source_boot.size, source_boot.sha1)
      script.PatchPartitionExprCheck(target_expr, source_expr)

      required_cache_sizes.append(target_boot.size)

  if required_cache_sizes:
    script.CacheFreeSpaceCheck(max(required_cache_sizes))

  # Verify the existing partitions.
  for diff in block_diff_dict.values():
    diff.WriteVerifyScript(script, touched_blocks_only=True)

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

  progress_dict = {partition: 0.1 for partition in block_diff_dict}
  progress_dict["system"] = 1 - len(block_diff_dict) * 0.1

  if OPTIONS.source_info_dict.get("use_dynamic_partitions") == "true":
    if OPTIONS.target_info_dict.get("use_dynamic_partitions") != "true":
      raise RuntimeError(
          "can't generate incremental that disables dynamic partitions")
    dynamic_partitions_diff = DynamicPartitionsDifference(
        info_dict=OPTIONS.target_info_dict,
        source_info_dict=OPTIONS.source_info_dict,
        block_diffs=block_diff_dict.values(),
        progress_dict=progress_dict)
    dynamic_partitions_diff.WriteScript(
        script, output_zip, write_verify_script=OPTIONS.verify)
  else:
    for block_diff in block_diff_dict.values():
      block_diff.WriteScript(script, output_zip,
                             progress=progress_dict.get(block_diff.partition),
                             write_verify_script=OPTIONS.verify)

  if OPTIONS.two_step:
    common.ZipWriteStr(output_zip, "boot.img", target_boot.data)
    script.WriteRawImage("/boot", "boot.img")
    logger.info("writing full boot image (forced by two-step mode)")

  if not OPTIONS.two_step:
    if updating_boot:
      if include_full_boot:
        logger.info("boot image changed; including full.")
        script.Print("Installing boot image...")
        script.WriteRawImage("/boot", "boot.img")
      else:
        # Produce the boot image by applying a patch to the current
        # contents of the boot partition, and write it back to the
        # partition.
        logger.info("boot image changed; including patch.")
        script.Print("Patching boot image...")
        script.ShowProgress(0.1, 10)
        target_expr = 'concat("{}:",{},":{}:{}")'.format(
            boot_type, boot_device_expr, target_boot.size, target_boot.sha1)
        source_expr = 'concat("{}:",{},":{}:{}")'.format(
            boot_type, boot_device_expr, source_boot.size, source_boot.sha1)
        script.PatchPartitionExpr(target_expr, source_expr, '"boot.img.p"')
    else:
      logger.info("boot image unchanged; skipping.")

  # Do device-specific installation (eg, write radio image).
  device_specific.IncrementalOTA_InstallEnd()

  if OPTIONS.extra_script is not None:
    script.AppendExtra(OPTIONS.extra_script)

  if OPTIONS.wipe_user_data:
    script.Print("Erasing user data...")
    script.FormatPartition("/data")

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
  metadata.required_cache = script.required_cache

  # We haven't written the metadata entry yet, which will be handled in
  # FinalizeMetadata().
  common.ZipClose(output_zip)

  # Sign the generated zip package unless no_signing is specified.
  needed_property_files = (
      NonAbOtaPropertyFiles(),
  )
  FinalizeMetadata(metadata, staging_file, output_file,
                   needed_property_files, package_key=OPTIONS.package_key)


def GenerateNonAbOtaPackage(target_file, output_file, source_file=None):
  """Generates a non-A/B OTA package."""
  # Check the loaded info dicts first.
  if OPTIONS.info_dict.get("no_recovery") == "true":
    raise common.ExternalError(
        "--- target build has specified no recovery ---")

  # Non-A/B OTAs rely on /cache partition to store temporary files.
  cache_size = OPTIONS.info_dict.get("cache_size")
  if cache_size is None:
    logger.warning("--- can't determine the cache partition size ---")
  OPTIONS.cache_size = cache_size

  if OPTIONS.extra_script is not None:
    with open(OPTIONS.extra_script) as fp:
      OPTIONS.extra_script = fp.read()

  if OPTIONS.extracted_input is not None:
    OPTIONS.input_tmp = OPTIONS.extracted_input
  else:
    if not os.path.isdir(target_file):
      logger.info("unzipping target target-files...")
      OPTIONS.input_tmp = common.UnzipTemp(target_file, UNZIP_PATTERN)
    else:
      OPTIONS.input_tmp = target_file
      tmpfile = common.MakeTempFile(suffix=".zip")
      os.unlink(tmpfile)
      common.RunAndCheckOutput(
          ["zip", tmpfile, "-r", ".", "-0"], cwd=target_file)
      assert zipfile.is_zipfile(tmpfile)
      target_file = tmpfile

  OPTIONS.target_tmp = OPTIONS.input_tmp

  # If the caller explicitly specified the device-specific extensions path via
  # -s / --device_specific, use that. Otherwise, use META/releasetools.py if it
  # is present in the target target_files. Otherwise, take the path of the file
  # from 'tool_extensions' in the info dict and look for that in the local
  # filesystem, relative to the current directory.
  if OPTIONS.device_specific is None:
    from_input = os.path.join(OPTIONS.input_tmp, "META", "releasetools.py")
    if os.path.exists(from_input):
      logger.info("(using device-specific extensions from target_files)")
      OPTIONS.device_specific = from_input
    else:
      OPTIONS.device_specific = OPTIONS.info_dict.get("tool_extensions")

  if OPTIONS.device_specific is not None:
    OPTIONS.device_specific = os.path.abspath(OPTIONS.device_specific)

  # Generate a full OTA.
  if source_file is None:
    with zipfile.ZipFile(target_file) as input_zip:
      WriteFullOTAPackage(
          input_zip,
          output_file)

  # Generate an incremental OTA.
  else:
    logger.info("unzipping source target-files...")
    OPTIONS.source_tmp = common.UnzipTemp(
        OPTIONS.incremental_source, UNZIP_PATTERN)
    with zipfile.ZipFile(target_file) as input_zip, \
            zipfile.ZipFile(source_file) as source_zip:
      WriteBlockIncrementalOTAPackage(
          input_zip,
          source_zip,
          output_file)


def WriteFingerprintAssertion(script, target_info, source_info):
  source_oem_props = source_info.oem_props
  target_oem_props = target_info.oem_props

  if source_oem_props is None and target_oem_props is None:
    script.AssertSomeFingerprint(
        source_info.fingerprint, target_info.fingerprint)
  elif source_oem_props is not None and target_oem_props is not None:
    script.AssertSomeThumbprint(
        target_info.GetBuildProp("ro.build.thumbprint"),
        source_info.GetBuildProp("ro.build.thumbprint"))
  elif source_oem_props is None and target_oem_props is not None:
    script.AssertFingerprintOrThumbprint(
        source_info.fingerprint,
        target_info.GetBuildProp("ro.build.thumbprint"))
  else:
    script.AssertFingerprintOrThumbprint(
        target_info.fingerprint,
        source_info.GetBuildProp("ro.build.thumbprint"))


class NonAbOtaPropertyFiles(PropertyFiles):
  """The property-files for non-A/B OTA.

  For non-A/B OTA, the property-files string contains the info for METADATA
  entry, with which a system updater can be fetched the package metadata prior
  to downloading the entire package.
  """

  def __init__(self):
    super(NonAbOtaPropertyFiles, self).__init__()
    self.name = 'ota-property-files'


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
      OPTIONS.input_tmp, "OTA", recovery_two_step_img_name)
  if os.path.exists(recovery_two_step_img_path):
    common.ZipWrite(
        output_zip,
        recovery_two_step_img_path,
        arcname=recovery_two_step_img_name)
    logger.info(
        "two-step package: using %s in stage 1/3", recovery_two_step_img_name)
    script.WriteRawImage("/boot", recovery_two_step_img_name)
  else:
    logger.info("two-step package: using recovery.img in stage 1/3")
    # The "recovery.img" entry has been written into package earlier.
    script.WriteRawImage("/boot", "recovery.img")


def HasRecoveryPatch(target_files_zip, info_dict):
  board_uses_vendorimage = info_dict.get("board_uses_vendorimage") == "true"

  if board_uses_vendorimage:
    target_files_dir = "VENDOR"
  else:
    target_files_dir = "SYSTEM/vendor"

  patch = "%s/recovery-from-boot.p" % target_files_dir
  img = "%s/etc/recovery.img" % target_files_dir

  namelist = target_files_zip.namelist()
  return patch in namelist or img in namelist


class DeviceSpecificParams(object):
  module = None

  def __init__(self, **kwargs):
    """Keyword arguments to the constructor become attributes of this
    object, which is passed to all functions in the device-specific
    module."""
    for k, v in kwargs.items():
      setattr(self, k, v)
    self.extras = OPTIONS.extras

    if self.module is None:
      path = OPTIONS.device_specific
      if not path:
        return
      try:
        if os.path.isdir(path):
          info = imp.find_module("releasetools", [path])
        else:
          d, f = os.path.split(path)
          b, x = os.path.splitext(f)
          if x == ".py":
            f = b
          info = imp.find_module(f, [d])
        logger.info("loaded device-specific extensions from %s", path)
        self.module = imp.load_module("device_specific", *info)
      except ImportError:
        logger.info("unable to load device-specific module; assuming none")

  def _DoCall(self, function_name, *args, **kwargs):
    """Call the named function in the device-specific module, passing
    the given args and kwargs.  The first argument to the call will be
    the DeviceSpecific object itself.  If there is no module, or the
    module does not define the function, return the value of the
    'default' kwarg (which itself defaults to None)."""
    if self.module is None or not hasattr(self.module, function_name):
      return kwargs.get("default")
    return getattr(self.module, function_name)(*((self,) + args), **kwargs)

  def FullOTA_Assertions(self):
    """Called after emitting the block of assertions at the top of a
    full OTA package.  Implementations can add whatever additional
    assertions they like."""
    return self._DoCall("FullOTA_Assertions")

  def FullOTA_InstallBegin(self):
    """Called at the start of full OTA installation."""
    return self._DoCall("FullOTA_InstallBegin")

  def FullOTA_GetBlockDifferences(self):
    """Called during full OTA installation and verification.
    Implementation should return a list of BlockDifference objects describing
    the update on each additional partitions.
    """
    return self._DoCall("FullOTA_GetBlockDifferences")

  def FullOTA_InstallEnd(self):
    """Called at the end of full OTA installation; typically this is
    used to install the image for the device's baseband processor."""
    return self._DoCall("FullOTA_InstallEnd")

  def IncrementalOTA_Assertions(self):
    """Called after emitting the block of assertions at the top of an
    incremental OTA package.  Implementations can add whatever
    additional assertions they like."""
    return self._DoCall("IncrementalOTA_Assertions")

  def IncrementalOTA_VerifyBegin(self):
    """Called at the start of the verification phase of incremental
    OTA installation; additional checks can be placed here to abort
    the script before any changes are made."""
    return self._DoCall("IncrementalOTA_VerifyBegin")

  def IncrementalOTA_VerifyEnd(self):
    """Called at the end of the verification phase of incremental OTA
    installation; additional checks can be placed here to abort the
    script before any changes are made."""
    return self._DoCall("IncrementalOTA_VerifyEnd")

  def IncrementalOTA_InstallBegin(self):
    """Called at the start of incremental OTA installation (after
    verification is complete)."""
    return self._DoCall("IncrementalOTA_InstallBegin")

  def IncrementalOTA_GetBlockDifferences(self):
    """Called during incremental OTA installation and verification.
    Implementation should return a list of BlockDifference objects describing
    the update on each additional partitions.
    """
    return self._DoCall("IncrementalOTA_GetBlockDifferences")

  def IncrementalOTA_InstallEnd(self):
    """Called at the end of incremental OTA installation; typically
    this is used to install the image for the device's baseband
    processor."""
    return self._DoCall("IncrementalOTA_InstallEnd")

  def VerifyOTA_Assertions(self):
    return self._DoCall("VerifyOTA_Assertions")


DIFF_PROGRAM_BY_EXT = {
    ".gz": "imgdiff",
    ".zip": ["imgdiff", "-z"],
    ".jar": ["imgdiff", "-z"],
    ".apk": ["imgdiff", "-z"],
    ".img": "imgdiff",
}


class Difference(object):
  def __init__(self, tf, sf, diff_program=None):
    self.tf = tf
    self.sf = sf
    self.patch = None
    self.diff_program = diff_program

  def ComputePatch(self):
    """Compute the patch (as a string of data) needed to turn sf into
    tf.  Returns the same tuple as GetPatch()."""

    tf = self.tf
    sf = self.sf

    if self.diff_program:
      diff_program = self.diff_program
    else:
      ext = os.path.splitext(tf.name)[1]
      diff_program = DIFF_PROGRAM_BY_EXT.get(ext, "bsdiff")

    ttemp = tf.WriteToTemp()
    stemp = sf.WriteToTemp()

    ext = os.path.splitext(tf.name)[1]

    try:
      ptemp = tempfile.NamedTemporaryFile()
      if isinstance(diff_program, list):
        cmd = copy.copy(diff_program)
      else:
        cmd = [diff_program]
      cmd.append(stemp.name)
      cmd.append(ttemp.name)
      cmd.append(ptemp.name)
      p = Run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
      err = []

      def run():
        _, e = p.communicate()
        if e:
          err.append(e)
      th = threading.Thread(target=run)
      th.start()
      th.join(timeout=300)   # 5 mins
      if th.is_alive():
        logger.warning("diff command timed out")
        p.terminate()
        th.join(5)
        if th.is_alive():
          p.kill()
          th.join()

      if p.returncode != 0:
        logger.warning("Failure running %s:\n%s\n", cmd, "".join(err))
        self.patch = None
        return None, None, None
      diff = ptemp.read()
    finally:
      ptemp.close()
      stemp.close()
      ttemp.close()

    self.patch = diff
    return self.tf, self.sf, self.patch

  def GetPatch(self):
    """Returns a tuple of (target_file, source_file, patch_data).

    patch_data may be None if ComputePatch hasn't been called, or if
    computing the patch failed.
    """
    return self.tf, self.sf, self.patch


def ComputeDifferences(diffs):
  """Call ComputePatch on all the Difference objects in 'diffs'."""
  logger.info("%d diffs to compute", len(diffs))

  # Do the largest files first, to try and reduce the long-pole effect.
  by_size = [(i.tf.size, i) for i in diffs]
  by_size.sort(reverse=True)
  by_size = [i[1] for i in by_size]

  lock = threading.Lock()
  diff_iter = iter(by_size)   # accessed under lock

  def worker():
    try:
      lock.acquire()
      for d in diff_iter:
        lock.release()
        start = time.time()
        d.ComputePatch()
        dur = time.time() - start
        lock.acquire()

        tf, sf, patch = d.GetPatch()
        if sf.name == tf.name:
          name = tf.name
        else:
          name = "%s (%s)" % (tf.name, sf.name)
        if patch is None:
          logger.error("patching failed! %40s", name)
        else:
          logger.info(
              "%8.2f sec %8d / %8d bytes (%6.2f%%) %s", dur, len(patch),
              tf.size, 100.0 * len(patch) / tf.size, name)
      lock.release()
    except Exception:
      logger.exception("Failed to compute diff from worker")
      raise

  # start worker threads; wait for them all to finish.
  threads = [threading.Thread(target=worker)
             for i in range(OPTIONS.worker_threads)]
  for th in threads:
    th.start()
  while threads:
    threads.pop().join()


class BlockDifference(object):
  def __init__(self, partition, tgt, src=None, check_first_block=False,
               version=None, disable_imgdiff=False):
    self.tgt = tgt
    self.src = src
    self.partition = partition
    self.check_first_block = check_first_block
    self.disable_imgdiff = disable_imgdiff

    if version is None:
      version = max(
          int(i) for i in
          OPTIONS.info_dict.get("blockimgdiff_versions", "1").split(","))
    assert version >= 3
    self.version = version

    b = BlockImageDiff(tgt, src, threads=OPTIONS.worker_threads,
                       version=self.version,
                       disable_imgdiff=self.disable_imgdiff)
    self.path = os.path.join(MakeTempDir(), partition)
    b.Compute(self.path)
    self._required_cache = b.max_stashed_size
    self.touched_src_ranges = b.touched_src_ranges
    self.touched_src_sha1 = b.touched_src_sha1

    # On devices with dynamic partitions, for new partitions,
    # src is None but OPTIONS.source_info_dict is not.
    if OPTIONS.source_info_dict is None:
      is_dynamic_build = OPTIONS.info_dict.get(
          "use_dynamic_partitions") == "true"
      is_dynamic_source = False
    else:
      is_dynamic_build = OPTIONS.source_info_dict.get(
          "use_dynamic_partitions") == "true"
      is_dynamic_source = partition in shlex.split(
          OPTIONS.source_info_dict.get("dynamic_partition_list", "").strip())

    is_dynamic_target = partition in shlex.split(
        OPTIONS.info_dict.get("dynamic_partition_list", "").strip())

    # For dynamic partitions builds, check partition list in both source
    # and target build because new partitions may be added, and existing
    # partitions may be removed.
    is_dynamic = is_dynamic_build and (is_dynamic_source or is_dynamic_target)

    if is_dynamic:
      self.device = 'map_partition("%s")' % partition
    else:
      if OPTIONS.source_info_dict is None:
        _, device_expr = GetTypeAndDeviceExpr("/" + partition,
                                              OPTIONS.info_dict)
      else:
        _, device_expr = GetTypeAndDeviceExpr("/" + partition,
                                              OPTIONS.source_info_dict)
      self.device = device_expr

  @property
  def required_cache(self):
    return self._required_cache

  def WriteScript(self, script, output_zip, progress=None,
                  write_verify_script=False):
    if not self.src:
      # write the output unconditionally
      script.Print("Patching %s image unconditionally..." % (self.partition,))
    else:
      script.Print("Patching %s image after verification." % (self.partition,))

    if progress:
      script.ShowProgress(progress, 0)
    self._WriteUpdate(script, output_zip)

    if write_verify_script:
      self.WritePostInstallVerifyScript(script)

  def WriteStrictVerifyScript(self, script):
    """Verify all the blocks in the care_map, including clobbered blocks.

    This differs from the WriteVerifyScript() function: a) it prints different
    error messages; b) it doesn't allow half-way updated images to pass the
    verification."""

    partition = self.partition
    script.Print("Verifying %s..." % (partition,))
    ranges = self.tgt.care_map
    ranges_str = ranges.to_string_raw()
    script.AppendExtra(
        'range_sha1(%s, "%s") == "%s" && ui_print("    Verified.") || '
        'ui_print("%s has unexpected contents.");' % (
            self.device, ranges_str,
            self.tgt.TotalSha1(include_clobbered_blocks=True),
            self.partition))
    script.AppendExtra("")

  def WriteVerifyScript(self, script, touched_blocks_only=False):
    partition = self.partition

    # full OTA
    if not self.src:
      script.Print("Image %s will be patched unconditionally." % (partition,))

    # incremental OTA
    else:
      if touched_blocks_only:
        ranges = self.touched_src_ranges
        expected_sha1 = self.touched_src_sha1
      else:
        ranges = self.src.care_map.subtract(self.src.clobbered_blocks)
        expected_sha1 = self.src.TotalSha1()

      # No blocks to be checked, skipping.
      if not ranges:
        return

      ranges_str = ranges.to_string_raw()
      script.AppendExtra(
          'if (range_sha1(%s, "%s") == "%s" || block_image_verify(%s, '
          'package_extract_file("%s.transfer.list"), "%s.new.dat", '
          '"%s.patch.dat")) then' % (
              self.device, ranges_str, expected_sha1,
              self.device, partition, partition, partition))
      script.Print('Verified %s image...' % (partition,))
      script.AppendExtra('else')

      if self.version >= 4:

        # Bug: 21124327
        # When generating incrementals for the system and vendor partitions in
        # version 4 or newer, explicitly check the first block (which contains
        # the superblock) of the partition to see if it's what we expect. If
        # this check fails, give an explicit log message about the partition
        # having been remounted R/W (the most likely explanation).
        if self.check_first_block:
          script.AppendExtra('check_first_block(%s);' % (self.device,))

        # If version >= 4, try block recovery before abort update
        if partition == "system":
          code = ErrorCode.SYSTEM_RECOVER_FAILURE
        else:
          code = ErrorCode.VENDOR_RECOVER_FAILURE
        script.AppendExtra((
            'ifelse (block_image_recover({device}, "{ranges}") && '
            'block_image_verify({device}, '
            'package_extract_file("{partition}.transfer.list"), '
            '"{partition}.new.dat", "{partition}.patch.dat"), '
            'ui_print("{partition} recovered successfully."), '
            'abort("E{code}: {partition} partition fails to recover"));\n'
            'endif;').format(device=self.device, ranges=ranges_str,
                             partition=partition, code=code))

      # Abort the OTA update. Note that the incremental OTA cannot be applied
      # even if it may match the checksum of the target partition.
      # a) If version < 3, operations like move and erase will make changes
      #    unconditionally and damage the partition.
      # b) If version >= 3, it won't even reach here.
      else:
        if partition == "system":
          code = ErrorCode.SYSTEM_VERIFICATION_FAILURE
        else:
          code = ErrorCode.VENDOR_VERIFICATION_FAILURE
        script.AppendExtra((
            'abort("E%d: %s partition has unexpected contents");\n'
            'endif;') % (code, partition))

  def WritePostInstallVerifyScript(self, script):
    partition = self.partition
    script.Print('Verifying the updated %s image...' % (partition,))
    # Unlike pre-install verification, clobbered_blocks should not be ignored.
    ranges = self.tgt.care_map
    ranges_str = ranges.to_string_raw()
    script.AppendExtra(
        'if range_sha1(%s, "%s") == "%s" then' % (
            self.device, ranges_str,
            self.tgt.TotalSha1(include_clobbered_blocks=True)))

    # Bug: 20881595
    # Verify that extended blocks are really zeroed out.
    if self.tgt.extended:
      ranges_str = self.tgt.extended.to_string_raw()
      script.AppendExtra(
          'if range_sha1(%s, "%s") == "%s" then' % (
              self.device, ranges_str,
              self._HashZeroBlocks(self.tgt.extended.size())))
      script.Print('Verified the updated %s image.' % (partition,))
      if partition == "system":
        code = ErrorCode.SYSTEM_NONZERO_CONTENTS
      else:
        code = ErrorCode.VENDOR_NONZERO_CONTENTS
      script.AppendExtra(
          'else\n'
          '  abort("E%d: %s partition has unexpected non-zero contents after '
          'OTA update");\n'
          'endif;' % (code, partition))
    else:
      script.Print('Verified the updated %s image.' % (partition,))

    if partition == "system":
      code = ErrorCode.SYSTEM_UNEXPECTED_CONTENTS
    else:
      code = ErrorCode.VENDOR_UNEXPECTED_CONTENTS

    script.AppendExtra(
        'else\n'
        '  abort("E%d: %s partition has unexpected contents after OTA '
        'update");\n'
        'endif;' % (code, partition))

  def _WriteUpdate(self, script, output_zip):
    ZipWrite(output_zip,
             '{}.transfer.list'.format(self.path),
             '{}.transfer.list'.format(self.partition))

    # For full OTA, compress the new.dat with brotli with quality 6 to reduce
    # its size. Quailty 9 almost triples the compression time but doesn't
    # further reduce the size too much. For a typical 1.8G system.new.dat
    #                       zip  | brotli(quality 6)  | brotli(quality 9)
    #   compressed_size:    942M | 869M (~8% reduced) | 854M
    #   compression_time:   75s  | 265s               | 719s
    #   decompression_time: 15s  | 25s                | 25s

    if not self.src:
      brotli_cmd = ['brotli', '--quality=6',
                    '--output={}.new.dat.br'.format(self.path),
                    '{}.new.dat'.format(self.path)]
      print("Compressing {}.new.dat with brotli".format(self.partition))
      RunAndCheckOutput(brotli_cmd)

      new_data_name = '{}.new.dat.br'.format(self.partition)
      ZipWrite(output_zip,
               '{}.new.dat.br'.format(self.path),
               new_data_name,
               compress_type=zipfile.ZIP_STORED)
    else:
      new_data_name = '{}.new.dat'.format(self.partition)
      ZipWrite(output_zip, '{}.new.dat'.format(self.path), new_data_name)

    ZipWrite(output_zip,
             '{}.patch.dat'.format(self.path),
             '{}.patch.dat'.format(self.partition),
             compress_type=zipfile.ZIP_STORED)

    if self.partition == "system":
      code = ErrorCode.SYSTEM_UPDATE_FAILURE
    else:
      code = ErrorCode.VENDOR_UPDATE_FAILURE

    call = ('block_image_update({device}, '
            'package_extract_file("{partition}.transfer.list"), '
            '"{new_data_name}", "{partition}.patch.dat") ||\n'
            '  abort("E{code}: Failed to update {partition} image.");'.format(
                device=self.device, partition=self.partition,
                new_data_name=new_data_name, code=code))
    script.AppendExtra(script.WordWrap(call))

  def _HashBlocks(self, source, ranges):  # pylint: disable=no-self-use
    data = source.ReadRangeSet(ranges)
    ctx = sha1()

    for p in data:
      ctx.update(p)

    return ctx.hexdigest()

  def _HashZeroBlocks(self, num_blocks):  # pylint: disable=no-self-use
    """Return the hash value for all zero blocks."""
    zero_block = '\x00' * 4096
    ctx = sha1()
    for _ in range(num_blocks):
      ctx.update(zero_block)

    return ctx.hexdigest()


def MakeRecoveryPatch(input_dir, output_sink, recovery_img, boot_img,
                      info_dict=None):
  """Generates the recovery-from-boot patch and writes the script to output.

  Most of the space in the boot and recovery images is just the kernel, which is
  identical for the two, so the resulting patch should be efficient. Add it to
  the output zip, along with a shell script that is run from init.rc on first
  boot to actually do the patching and install the new recovery image.

  Args:
    input_dir: The top-level input directory of the target-files.zip.
    output_sink: The callback function that writes the result.
    recovery_img: File object for the recovery image.
    boot_img: File objects for the boot image.
    info_dict: A dict returned by common.LoadInfoDict() on the input
        target_files. Will use OPTIONS.info_dict if None has been given.
  """
  if info_dict is None:
    info_dict = OPTIONS.info_dict

  full_recovery_image = info_dict.get("full_recovery_image") == "true"
  board_uses_vendorimage = info_dict.get("board_uses_vendorimage") == "true"

  if board_uses_vendorimage:
    # In this case, the output sink is rooted at VENDOR
    recovery_img_path = "etc/recovery.img"
    recovery_resource_dat_path = "VENDOR/etc/recovery-resource.dat"
    sh_dir = "bin"
  else:
    # In this case the output sink is rooted at SYSTEM
    recovery_img_path = "vendor/etc/recovery.img"
    recovery_resource_dat_path = "SYSTEM/vendor/etc/recovery-resource.dat"
    sh_dir = "vendor/bin"

  if full_recovery_image:
    output_sink(recovery_img_path, recovery_img.data)

  else:
    system_root_image = info_dict.get("system_root_image") == "true"
    include_recovery_dtbo = info_dict.get("include_recovery_dtbo") == "true"
    include_recovery_acpio = info_dict.get("include_recovery_acpio") == "true"
    path = os.path.join(input_dir, recovery_resource_dat_path)
    # With system-root-image, boot and recovery images will have mismatching
    # entries (only recovery has the ramdisk entry) (Bug: 72731506). Use bsdiff
    # to handle such a case.
    if system_root_image or include_recovery_dtbo or include_recovery_acpio:
      diff_program = ["bsdiff"]
      bonus_args = ""
      assert not os.path.exists(path)
    else:
      diff_program = ["imgdiff"]
      if os.path.exists(path):
        diff_program.append("-b")
        diff_program.append(path)
        bonus_args = "--bonus /vendor/etc/recovery-resource.dat"
      else:
        bonus_args = ""

    d = Difference(recovery_img, boot_img, diff_program=diff_program)
    _, _, patch = d.ComputePatch()
    output_sink("recovery-from-boot.p", patch)

  try:
    # The following GetTypeAndDevice()s need to use the path in the target
    # info_dict instead of source_info_dict.
    boot_type, boot_device = GetTypeAndDevice("/boot", info_dict,
                                              check_no_slot=False)
    recovery_type, recovery_device = GetTypeAndDevice("/recovery", info_dict,
                                                      check_no_slot=False)
  except KeyError:
    return

  if full_recovery_image:

    # Note that we use /vendor to refer to the recovery resources. This will
    # work for a separate vendor partition mounted at /vendor or a
    # /system/vendor subdirectory on the system partition, for which init will
    # create a symlink from /vendor to /system/vendor.

    sh = """#!/vendor/bin/sh
if ! applypatch --check %(type)s:%(device)s:%(size)d:%(sha1)s; then
  applypatch \\
          --flash /vendor/etc/recovery.img \\
          --target %(type)s:%(device)s:%(size)d:%(sha1)s && \\
      log -t recovery "Installing new recovery image: succeeded" || \\
      log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
""" % {'type': recovery_type,
       'device': recovery_device,
       'sha1': recovery_img.sha1,
       'size': recovery_img.size}
  else:
    sh = """#!/vendor/bin/sh
if ! applypatch --check %(recovery_type)s:%(recovery_device)s:%(recovery_size)d:%(recovery_sha1)s; then
  applypatch %(bonus_args)s \\
          --patch /vendor/recovery-from-boot.p \\
          --source %(boot_type)s:%(boot_device)s:%(boot_size)d:%(boot_sha1)s \\
          --target %(recovery_type)s:%(recovery_device)s:%(recovery_size)d:%(recovery_sha1)s && \\
      log -t recovery "Installing new recovery image: succeeded" || \\
      log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
""" % {'boot_size': boot_img.size,
       'boot_sha1': boot_img.sha1,
       'recovery_size': recovery_img.size,
       'recovery_sha1': recovery_img.sha1,
       'boot_type': boot_type,
       'boot_device': boot_device + '$(getprop ro.boot.slot_suffix)',
       'recovery_type': recovery_type,
       'recovery_device': recovery_device + '$(getprop ro.boot.slot_suffix)',
       'bonus_args': bonus_args}

  # The install script location moved from /system/etc to /system/bin in the L
  # release. In the R release it is in VENDOR/bin or SYSTEM/vendor/bin.
  sh_location = os.path.join(sh_dir, "install-recovery.sh")

  logger.info("putting script in %s", sh_location)

  output_sink(sh_location, sh.encode())


class DynamicPartitionUpdate(object):
  def __init__(self, src_group=None, tgt_group=None, progress=None,
               block_difference=None):
    self.src_group = src_group
    self.tgt_group = tgt_group
    self.progress = progress
    self.block_difference = block_difference

  @property
  def src_size(self):
    if not self.block_difference:
      return 0
    return DynamicPartitionUpdate._GetSparseImageSize(self.block_difference.src)

  @property
  def tgt_size(self):
    if not self.block_difference:
      return 0
    return DynamicPartitionUpdate._GetSparseImageSize(self.block_difference.tgt)

  @staticmethod
  def _GetSparseImageSize(img):
    if not img:
      return 0
    return img.blocksize * img.total_blocks


class DynamicGroupUpdate(object):
  def __init__(self, src_size=None, tgt_size=None):
    # None: group does not exist. 0: no size limits.
    self.src_size = src_size
    self.tgt_size = tgt_size


class DynamicPartitionsDifference(object):
  def __init__(self, info_dict, block_diffs, progress_dict=None,
               source_info_dict=None):
    if progress_dict is None:
      progress_dict = {}

    self._remove_all_before_apply = False
    if source_info_dict is None:
      self._remove_all_before_apply = True
      source_info_dict = {}

    block_diff_dict = collections.OrderedDict(
        [(e.partition, e) for e in block_diffs])

    assert len(block_diff_dict) == len(block_diffs), \
        "Duplicated BlockDifference object for {}".format(
            [partition for partition, count in
             collections.Counter(e.partition for e in block_diffs).items()
             if count > 1])

    self._partition_updates = collections.OrderedDict()

    for p, block_diff in block_diff_dict.items():
      self._partition_updates[p] = DynamicPartitionUpdate()
      self._partition_updates[p].block_difference = block_diff

    for p, progress in progress_dict.items():
      if p in self._partition_updates:
        self._partition_updates[p].progress = progress

    tgt_groups = shlex.split(info_dict.get(
        "super_partition_groups", "").strip())
    src_groups = shlex.split(source_info_dict.get(
        "super_partition_groups", "").strip())

    for g in tgt_groups:
      for p in shlex.split(info_dict.get(
              "super_%s_partition_list" % g, "").strip()):
        assert p in self._partition_updates, \
            "{} is in target super_{}_partition_list but no BlockDifference " \
            "object is provided.".format(p, g)
        self._partition_updates[p].tgt_group = g

    for g in src_groups:
      for p in shlex.split(source_info_dict.get(
              "super_%s_partition_list" % g, "").strip()):
        assert p in self._partition_updates, \
            "{} is in source super_{}_partition_list but no BlockDifference " \
            "object is provided.".format(p, g)
        self._partition_updates[p].src_group = g

    target_dynamic_partitions = set(shlex.split(info_dict.get(
        "dynamic_partition_list", "").strip()))
    block_diffs_with_target = set(p for p, u in self._partition_updates.items()
                                  if u.tgt_size)
    assert block_diffs_with_target == target_dynamic_partitions, \
        "Target Dynamic partitions: {}, BlockDifference with target: {}".format(
            list(target_dynamic_partitions), list(block_diffs_with_target))

    source_dynamic_partitions = set(shlex.split(source_info_dict.get(
        "dynamic_partition_list", "").strip()))
    block_diffs_with_source = set(p for p, u in self._partition_updates.items()
                                  if u.src_size)
    assert block_diffs_with_source == source_dynamic_partitions, \
        "Source Dynamic partitions: {}, BlockDifference with source: {}".format(
            list(source_dynamic_partitions), list(block_diffs_with_source))

    if self._partition_updates:
      logger.info("Updating dynamic partitions %s",
                  self._partition_updates.keys())

    self._group_updates = collections.OrderedDict()

    for g in tgt_groups:
      self._group_updates[g] = DynamicGroupUpdate()
      self._group_updates[g].tgt_size = int(info_dict.get(
          "super_%s_group_size" % g, "0").strip())

    for g in src_groups:
      if g not in self._group_updates:
        self._group_updates[g] = DynamicGroupUpdate()
      self._group_updates[g].src_size = int(source_info_dict.get(
          "super_%s_group_size" % g, "0").strip())

    self._Compute()

  def WriteScript(self, script, output_zip, write_verify_script=False):
    script.Comment('--- Start patching dynamic partitions ---')
    for p, u in self._partition_updates.items():
      if u.src_size and u.tgt_size and u.src_size > u.tgt_size:
        script.Comment('Patch partition %s' % p)
        u.block_difference.WriteScript(script, output_zip, progress=u.progress,
                                       write_verify_script=False)

    op_list_path = MakeTempFile()
    with open(op_list_path, 'w') as f:
      for line in self._op_list:
        f.write('{}\n'.format(line))

    ZipWrite(output_zip, op_list_path, "dynamic_partitions_op_list")

    script.Comment('Update dynamic partition metadata')
    script.AppendExtra('assert(update_dynamic_partitions('
                       'package_extract_file("dynamic_partitions_op_list")));')

    if write_verify_script:
      for p, u in self._partition_updates.items():
        if u.src_size and u.tgt_size and u.src_size > u.tgt_size:
          u.block_difference.WritePostInstallVerifyScript(script)
          script.AppendExtra('unmap_partition("%s");' % p)  # ignore errors

    for p, u in self._partition_updates.items():
      if u.tgt_size and u.src_size <= u.tgt_size:
        script.Comment('Patch partition %s' % p)
        u.block_difference.WriteScript(script, output_zip, progress=u.progress,
                                       write_verify_script=write_verify_script)
        if write_verify_script:
          script.AppendExtra('unmap_partition("%s");' % p)  # ignore errors

    script.Comment('--- End patching dynamic partitions ---')

  def _Compute(self):
    self._op_list = list()

    def append(line):
      self._op_list.append(line)

    def comment(line):
      self._op_list.append("# %s" % line)

    if self._remove_all_before_apply:
      comment('Remove all existing dynamic partitions and groups before '
              'applying full OTA')
      append('remove_all_groups')

    for p, u in self._partition_updates.items():
      if u.src_group and not u.tgt_group:
        append('remove %s' % p)

    for p, u in self._partition_updates.items():
      if u.src_group and u.tgt_group and u.src_group != u.tgt_group:
        comment('Move partition %s from %s to default' % (p, u.src_group))
        append('move %s default' % p)

    for p, u in self._partition_updates.items():
      if u.src_size and u.tgt_size and u.src_size > u.tgt_size:
        comment('Shrink partition %s from %d to %d' %
                (p, u.src_size, u.tgt_size))
        append('resize %s %s' % (p, u.tgt_size))

    for g, u in self._group_updates.items():
      if u.src_size is not None and u.tgt_size is None:
        append('remove_group %s' % g)
      if (u.src_size is not None and u.tgt_size is not None and
              u.src_size > u.tgt_size):
        comment('Shrink group %s from %d to %d' % (g, u.src_size, u.tgt_size))
        append('resize_group %s %d' % (g, u.tgt_size))

    for g, u in self._group_updates.items():
      if u.src_size is None and u.tgt_size is not None:
        comment('Add group %s with maximum size %d' % (g, u.tgt_size))
        append('add_group %s %d' % (g, u.tgt_size))
      if (u.src_size is not None and u.tgt_size is not None and
              u.src_size < u.tgt_size):
        comment('Grow group %s from %d to %d' % (g, u.src_size, u.tgt_size))
        append('resize_group %s %d' % (g, u.tgt_size))

    for p, u in self._partition_updates.items():
      if u.tgt_group and not u.src_group:
        comment('Add partition %s to group %s' % (p, u.tgt_group))
        append('add %s %s' % (p, u.tgt_group))

    for p, u in self._partition_updates.items():
      if u.tgt_size and u.src_size < u.tgt_size:
        comment('Grow partition %s from %d to %d' %
                (p, u.src_size, u.tgt_size))
        append('resize %s %d' % (p, u.tgt_size))

    for p, u in self._partition_updates.items():
      if u.src_group and u.tgt_group and u.src_group != u.tgt_group:
        comment('Move partition %s from default to %s' %
                (p, u.tgt_group))
        append('move %s %s' % (p, u.tgt_group))


# map recovery.fstab's fs_types to mount/format "partition types"
PARTITION_TYPES = {
    "ext4": "EMMC",
    "emmc": "EMMC",
    "f2fs": "EMMC",
    "squashfs": "EMMC",
    "erofs": "EMMC"
}


def GetTypeAndDevice(mount_point, info, check_no_slot=True):
  """
  Use GetTypeAndDeviceExpr whenever possible. This function is kept for
  backwards compatibility. It aborts if the fstab entry has slotselect option
  (unless check_no_slot is explicitly set to False).
  """
  fstab = info["fstab"]
  if fstab:
    if check_no_slot:
      assert not fstab[mount_point].slotselect, \
          "Use GetTypeAndDeviceExpr instead"
    return (PARTITION_TYPES[fstab[mount_point].fs_type],
            fstab[mount_point].device)
  raise KeyError


def GetTypeAndDeviceExpr(mount_point, info):
  """
  Return the filesystem of the partition, and an edify expression that evaluates
  to the device at runtime.
  """
  fstab = info["fstab"]
  if fstab:
    p = fstab[mount_point]
    device_expr = '"%s"' % fstab[mount_point].device
    if p.slotselect:
      device_expr = 'add_slot_suffix(%s)' % device_expr
    return (PARTITION_TYPES[fstab[mount_point].fs_type], device_expr)
  raise KeyError
