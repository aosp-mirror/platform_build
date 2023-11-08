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
import logging
import os
import zipfile

import common
import edify_generator
import verity_utils
from check_target_files_vintf import CheckVintfIfTrebleEnabled, HasPartition
from common import OPTIONS
from ota_utils import UNZIP_PATTERN, FinalizeMetadata, GetPackageMetadata, PropertyFiles
import subprocess

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
    return common.BlockDifference(name, partition_tgt, partition_src,
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
      block_diff_dict[partition] = common.BlockDifference(partition, tgt,
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
    assert all(isinstance(diff, common.BlockDifference)
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

  device_specific = common.DeviceSpecificParams(
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
    dynamic_partitions_diff = common.DynamicPartitionsDifference(
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

  device_specific = common.DeviceSpecificParams(
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
    boot_type, boot_device_expr = common.GetTypeAndDeviceExpr("/boot",
                                                              source_info)
    d = common.Difference(target_boot, source_boot, "bsdiff")
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
    dynamic_partitions_diff = common.DynamicPartitionsDifference(
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
