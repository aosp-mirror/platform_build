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
Given a target-files zipfile, produces an OTA package that installs that build.
An incremental OTA is produced if -i is given, otherwise a full OTA is produced.

Usage:  ota_from_target_files [options] input_target_files output_ota_package

Common options that apply to both of non-A/B and A/B OTAs

  --downgrade
      Intentionally generate an incremental OTA that updates from a newer build
      to an older one (e.g. downgrading from P preview back to O MR1).
      "ota-downgrade=yes" will be set in the package metadata file. A data wipe
      will always be enforced when using this flag, so "ota-wipe=yes" will also
      be included in the metadata file. The update-binary in the source build
      will be used in the OTA package, unless --binary flag is specified. Please
      also check the comment for --override_timestamp below.

  -i  (--incremental_from) <file>
      Generate an incremental OTA using the given target-files zip as the
      starting build.

  -k  (--package_key) <key>
      Key to use to sign the package (default is the value of
      default_system_dev_certificate from the input target-files's
      META/misc_info.txt, or "build/make/target/product/security/testkey" if
      that value is not specified).

      For incremental OTAs, the default value is based on the source
      target-file, not the target build.

  --override_timestamp
      Intentionally generate an incremental OTA that updates from a newer build
      to an older one (based on timestamp comparison), by setting the downgrade
      flag in the package metadata. This differs from --downgrade flag, as we
      don't enforce a data wipe with this flag. Because we know for sure this is
      NOT an actual downgrade case, but two builds happen to be cut in a reverse
      order (e.g. from two branches). A legit use case is that we cut a new
      build C (after having A and B), but want to enfore an update path of A ->
      C -> B. Specifying --downgrade may not help since that would enforce a
      data wipe for C -> B update.

      We used to set a fake timestamp in the package metadata for this flow. But
      now we consolidate the two cases (i.e. an actual downgrade, or a downgrade
      based on timestamp) with the same "ota-downgrade=yes" flag, with the
      difference being whether "ota-wipe=yes" is set.

  --wipe_user_data
      Generate an OTA package that will wipe the user data partition when
      installed.

  --retrofit_dynamic_partitions
      Generates an OTA package that updates a device to support dynamic
      partitions (default False). This flag is implied when generating
      an incremental OTA where the base build does not support dynamic
      partitions but the target build does. For A/B, when this flag is set,
      --skip_postinstall is implied.

  --skip_compatibility_check
      Skip checking compatibility of the input target files package.

  --output_metadata_path
      Write a copy of the metadata to a separate file. Therefore, users can
      read the post build fingerprint without extracting the OTA package.

  --force_non_ab
      This flag can only be set on an A/B device that also supports non-A/B
      updates. Implies --two_step.
      If set, generate that non-A/B update package.
      If not set, generates A/B package for A/B device and non-A/B package for
      non-A/B device.

  -o  (--oem_settings) <main_file[,additional_files...]>
      Comma separated list of files used to specify the expected OEM-specific
      properties on the OEM partition of the intended device. Multiple expected
      values can be used by providing multiple files. Only the first dict will
      be used to compute fingerprint, while the rest will be used to assert
      OEM-specific properties.

Non-A/B OTA specific options

  -b  (--binary) <file>
      Use the given binary as the update-binary in the output package, instead
      of the binary in the build's target_files. Use for development only.

  --block
      Generate a block-based OTA for non-A/B device. We have deprecated the
      support for file-based OTA since O. Block-based OTA will be used by
      default for all non-A/B devices. Keeping this flag here to not break
      existing callers.

  -e  (--extra_script) <file>
      Insert the contents of file at the end of the update script.

  --full_bootloader
      Similar to --full_radio. When generating an incremental OTA, always
      include a full copy of bootloader image.

  --full_radio
      When generating an incremental OTA, always include a full copy of radio
      image. This option is only meaningful when -i is specified, because a full
      radio is always included in a full OTA if applicable.

  --log_diff <file>
      Generate a log file that shows the differences in the source and target
      builds for an incremental package. This option is only meaningful when -i
      is specified.

  --oem_no_mount
      For devices with OEM-specific properties but without an OEM partition, do
      not mount the OEM partition in the updater-script. This should be very
      rarely used, since it's expected to have a dedicated OEM partition for
      OEM-specific properties. Only meaningful when -o is specified.

  --stash_threshold <float>
      Specify the threshold that will be used to compute the maximum allowed
      stash size (defaults to 0.8).

  -t  (--worker_threads) <int>
      Specify the number of worker-threads that will be used when generating
      patches for incremental updates (defaults to 3).

  --verify
      Verify the checksums of the updated system and vendor (if any) partitions.
      Non-A/B incremental OTAs only.

  -2  (--two_step)
      Generate a 'two-step' OTA package, where recovery is updated first, so
      that any changes made to the system partition are done using the new
      recovery (new kernel, etc.).

A/B OTA specific options

  --disable_fec_computation
      Disable the on device FEC data computation for incremental updates. OTA will be larger but installation will be faster.

  --include_secondary
      Additionally include the payload for secondary slot images (default:
      False). Only meaningful when generating A/B OTAs.

      By default, an A/B OTA package doesn't contain the images for the
      secondary slot (e.g. system_other.img). Specifying this flag allows
      generating a separate payload that will install secondary slot images.

      Such a package needs to be applied in a two-stage manner, with a reboot
      in-between. During the first stage, the updater applies the primary
      payload only. Upon finishing, it reboots the device into the newly updated
      slot. It then continues to install the secondary payload to the inactive
      slot, but without switching the active slot at the end (needs the matching
      support in update_engine, i.e. SWITCH_SLOT_ON_REBOOT flag).

      Due to the special install procedure, the secondary payload will be always
      generated as a full payload.

  --payload_signer <signer>
      Specify the signer when signing the payload and metadata for A/B OTAs.
      By default (i.e. without this flag), it calls 'openssl pkeyutl' to sign
      with the package private key. If the private key cannot be accessed
      directly, a payload signer that knows how to do that should be specified.
      The signer will be supplied with "-inkey <path_to_key>",
      "-in <input_file>" and "-out <output_file>" parameters.

  --payload_signer_args <args>
      Specify the arguments needed for payload signer.

  --payload_signer_maximum_signature_size <signature_size>
      The maximum signature size (in bytes) that would be generated by the given
      payload signer. Only meaningful when custom payload signer is specified
      via '--payload_signer'.
      If the signer uses a RSA key, this should be the number of bytes to
      represent the modulus. If it uses an EC key, this is the size of a
      DER-encoded ECDSA signature.

  --payload_signer_key_size <key_size>
      Deprecated. Use the '--payload_signer_maximum_signature_size' instead.

  --boot_variable_file <path>
      A file that contains the possible values of ro.boot.* properties. It's
      used to calculate the possible runtime fingerprints when some
      ro.product.* properties are overridden by the 'import' statement.
      The file expects one property per line, and each line has the following
      format: 'prop_name=value1,value2'. e.g. 'ro.boot.product.sku=std,pro'

  --skip_postinstall
      Skip the postinstall hooks when generating an A/B OTA package (default:
      False). Note that this discards ALL the hooks, including non-optional
      ones. Should only be used if caller knows it's safe to do so (e.g. all the
      postinstall work is to dexopt apps and a data wipe will happen immediately
      after). Only meaningful when generating A/B OTAs.

  --partial "<PARTITION> [<PARTITION>[...]]"
      Generate partial updates, overriding ab_partitions list with the given
      list. Specify --partial= without partition list to let tooling auto detect
      partial partition list.

  --custom_image <custom_partition=custom_image>
      Use the specified custom_image to update custom_partition when generating
      an A/B OTA package. e.g. "--custom_image oem=oem.img --custom_image
      cus=cus_test.img"

  --disable_vabc
      Disable Virtual A/B Compression, for builds that have compression enabled
      by default.

  --vabc_downgrade
      Don't disable Virtual A/B Compression for downgrading OTAs.
      For VABC downgrades, we must finish merging before doing data wipe, and
      since data wipe is required for downgrading OTA, this might cause long
      wait time in recovery.

  --enable_vabc_xor
      Enable the VABC xor feature. Will reduce space requirements for OTA, but OTA installation will be slower.

  --force_minor_version
      Override the update_engine minor version for delta generation.

  --compressor_types
      A colon ':' separated list of compressors. Allowed values are bz2 and brotli.

  --enable_zucchini
      Whether to enable to zucchini feature. Will generate smaller OTA but uses more memory, OTA generation will take longer.

  --enable_puffdiff
      Whether to enable to puffdiff feature. Will generate smaller OTA but uses more memory, OTA generation will take longer.

  --enable_lz4diff
      Whether to enable lz4diff feature. Will generate smaller OTA for EROFS but
      uses more memory.

  --spl_downgrade
      Force generate an SPL downgrade OTA. Only needed if target build has an
      older SPL.

  --vabc_compression_param
      Compression algorithm to be used for VABC. Available options: gz, lz4, zstd, brotli, none. 
      Compression level can be specified by appending ",$LEVEL" to option. 
      e.g. --vabc_compression_param=gz,9 specifies level 9 compression with gz algorithm

  --security_patch_level
      Override the security patch level in target files

  --max_threads
      Specify max number of threads allowed when generating A/B OTA

  --vabc_cow_version
      Specify the VABC cow version to be used
"""

from __future__ import print_function

import logging
import multiprocessing
import os
import os.path
import re
import shutil
import subprocess
import sys
import zipfile

import care_map_pb2
import common
import ota_utils
import payload_signer
from ota_utils import (VABC_COMPRESSION_PARAM_SUPPORT, FinalizeMetadata, GetPackageMetadata,
                       PayloadGenerator, SECURITY_PATCH_LEVEL_PROP_NAME, ExtractTargetFiles, CopyTargetFilesDir)
from common import DoesInputFileContain, IsSparseImage
import target_files_diff
from non_ab_ota import GenerateNonAbOtaPackage
from payload_signer import PayloadSigner

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)

logger = logging.getLogger(__name__)

OPTIONS = ota_utils.OPTIONS
OPTIONS.verify = False
OPTIONS.patch_threshold = 0.95
OPTIONS.wipe_user_data = False
OPTIONS.extra_script = None
OPTIONS.worker_threads = multiprocessing.cpu_count() // 2
if OPTIONS.worker_threads == 0:
  OPTIONS.worker_threads = 1
OPTIONS.two_step = False
OPTIONS.include_secondary = False
OPTIONS.block_based = True
OPTIONS.updater_binary = None
OPTIONS.oem_dicts = None
OPTIONS.oem_source = None
OPTIONS.oem_no_mount = False
OPTIONS.full_radio = False
OPTIONS.full_bootloader = False
# Stash size cannot exceed cache_size * threshold.
OPTIONS.cache_size = None
OPTIONS.stash_threshold = 0.8
OPTIONS.log_diff = None
OPTIONS.extracted_input = None
OPTIONS.skip_postinstall = False
OPTIONS.skip_compatibility_check = False
OPTIONS.disable_fec_computation = False
OPTIONS.disable_verity_computation = False
OPTIONS.partial = None
OPTIONS.custom_images = {}
OPTIONS.disable_vabc = False
OPTIONS.spl_downgrade = False
OPTIONS.vabc_downgrade = False
OPTIONS.enable_vabc_xor = True
OPTIONS.force_minor_version = None
OPTIONS.compressor_types = None
OPTIONS.enable_zucchini = True
OPTIONS.enable_puffdiff = None
OPTIONS.enable_lz4diff = False
OPTIONS.vabc_compression_param = None
OPTIONS.security_patch_level = None
OPTIONS.max_threads = None
OPTIONS.vabc_cow_version = None


POSTINSTALL_CONFIG = 'META/postinstall_config.txt'
DYNAMIC_PARTITION_INFO = 'META/dynamic_partitions_info.txt'
MISC_INFO = 'META/misc_info.txt'
AB_PARTITIONS = 'META/ab_partitions.txt'

# Files to be unzipped for target diffing purpose.
TARGET_DIFFING_UNZIP_PATTERN = ['BOOT', 'RECOVERY', 'SYSTEM/*', 'VENDOR/*',
                                'PRODUCT/*', 'SYSTEM_EXT/*', 'ODM/*',
                                'VENDOR_DLKM/*', 'ODM_DLKM/*', 'SYSTEM_DLKM/*']
RETROFIT_DAP_UNZIP_PATTERN = ['OTA/super_*.img', AB_PARTITIONS]

# Images to be excluded from secondary payload. We essentially only keep
# 'system_other' and bootloader partitions.
SECONDARY_PAYLOAD_SKIPPED_IMAGES = [
    'boot', 'dtbo', 'modem', 'odm', 'odm_dlkm', 'product', 'radio', 'recovery',
    'system_dlkm', 'system_ext', 'vbmeta', 'vbmeta_system', 'vbmeta_vendor',
    'vendor', 'vendor_boot']


def _LoadOemDicts(oem_source):
  """Returns the list of loaded OEM properties dict."""
  if not oem_source:
    return None

  oem_dicts = []
  for oem_file in oem_source:
    oem_dicts.append(common.LoadDictionaryFromFile(oem_file))
  return oem_dicts

def ModifyKeyvalueList(content: str, key: str, value: str):
  """ Update update the key value list with specified key and value
  Args:
    content: The string content of dynamic_partitions_info.txt. Each line
      should be a key valur pair, where string before the first '=' are keys,
      remaining parts are values.
    key: the key of the key value pair to modify
    value: the new value to replace with

  Returns:
    Updated content of the key value list
  """
  output_list = []
  for line in content.splitlines():
    if line.startswith(key+"="):
      continue
    output_list.append(line)
  output_list.append("{}={}".format(key, value))
  return "\n".join(output_list)

def ModifyVABCCompressionParam(content, algo):
  """ Update update VABC Compression Param in dynamic_partitions_info.txt
  Args:
    content: The string content of dynamic_partitions_info.txt
    algo: The compression algorithm should be used for VABC. See
          https://cs.android.com/android/platform/superproject/+/master:system/core/fs_mgr/libsnapshot/cow_writer.cpp;l=127;bpv=1;bpt=1?q=CowWriter::ParseOptions&sq=
  Returns:
    Updated content of dynamic_partitions_info.txt , with custom compression algo
  """
  return ModifyKeyvalueList(content, "virtual_ab_compression_method", algo)

def SetVABCCowVersion(content, cow_version):
  """ Update virtual_ab_cow_version in dynamic_partitions_info.txt
  Args:
    content: The string content of dynamic_partitions_info.txt
    algo: The cow version be used for VABC. See
          https://cs.android.com/android/platform/superproject/main/+/main:system/core/fs_mgr/libsnapshot/include/libsnapshot/cow_format.h;l=36
  Returns:
    Updated content of dynamic_partitions_info.txt , updated cow version
  """
  return ModifyKeyvalueList(content, "virtual_ab_cow_version", cow_version)


def UpdatesInfoForSpecialUpdates(content, partitions_filter,
                                 delete_keys=None):
  """ Updates info file for secondary payload generation, partial update, etc.

    Scan each line in the info file, and remove the unwanted partitions from
    the dynamic partition list in the related properties. e.g.
    "super_google_dynamic_partitions_partition_list=system vendor product"
    will become "super_google_dynamic_partitions_partition_list=system".

  Args:
    content: The content of the input info file. e.g. misc_info.txt.
    partitions_filter: A function to filter the desired partitions from a given
      list
    delete_keys: A list of keys to delete in the info file

  Returns:
    A string of the updated info content.
  """

  output_list = []
  # The suffix in partition_list variables that follows the name of the
  # partition group.
  list_suffix = 'partition_list'
  for line in content.splitlines():
    if line.startswith('#') or '=' not in line:
      output_list.append(line)
      continue
    key, value = line.strip().split('=', 1)

    if delete_keys and key in delete_keys:
      pass
    elif key.endswith(list_suffix):
      partitions = value.split()
      # TODO for partial update, partitions in the same group must be all
      # updated or all omitted
      partitions = filter(partitions_filter, partitions)
      output_list.append('{}={}'.format(key, ' '.join(partitions)))
    else:
      output_list.append(line)
  return '\n'.join(output_list)


def GetTargetFilesZipForSecondaryImages(input_file, skip_postinstall=False):
  """Returns a target-files.zip file for generating secondary payload.

  Although the original target-files.zip already contains secondary slot
  images (i.e. IMAGES/system_other.img), we need to rename the files to the
  ones without _other suffix. Note that we cannot instead modify the names in
  META/ab_partitions.txt, because there are no matching partitions on device.

  For the partitions that don't have secondary images, the ones for primary
  slot will be used. This is to ensure that we always have valid boot, vbmeta,
  bootloader images in the inactive slot.

  After writing system_other to inactive slot's system partiiton,
  PackageManagerService will read `ro.cp_system_other_odex`, and set
  `sys.cppreopt` to "requested". Then, according to
  system/extras/cppreopts/cppreopts.rc , init will mount system_other at
  /postinstall, and execute `cppreopts` to copy optimized APKs from
  /postinstall to /data .

  Args:
    input_file: The input target-files.zip file.
    skip_postinstall: Whether to skip copying the postinstall config file.

  Returns:
    The filename of the target-files.zip for generating secondary payload.
  """

  def GetInfoForSecondaryImages(info_file):
    """Updates info file for secondary payload generation."""
    with open(info_file) as f:
      content = f.read()
    # Remove virtual_ab flag from secondary payload so that OTA client
    # don't use snapshots for secondary update
    delete_keys = ['virtual_ab', "virtual_ab_retrofit"]
    return UpdatesInfoForSpecialUpdates(
        content, lambda p: p not in SECONDARY_PAYLOAD_SKIPPED_IMAGES,
        delete_keys)

  target_file = common.MakeTempFile(prefix="targetfiles-", suffix=".zip")
  target_zip = zipfile.ZipFile(target_file, 'w', allowZip64=True)

  fileslist = []
  for (root, dirs, files) in os.walk(input_file):
    root = root.lstrip(input_file).lstrip("/")
    fileslist.extend([os.path.join(root, d) for d in dirs])
    fileslist.extend([os.path.join(root, d) for d in files])

  input_tmp = input_file
  for filename in fileslist:
    unzipped_file = os.path.join(input_tmp, *filename.split('/'))
    if filename == 'IMAGES/system_other.img':
      common.ZipWrite(target_zip, unzipped_file, arcname='IMAGES/system.img')

    # Primary images and friends need to be skipped explicitly.
    elif filename in ('IMAGES/system.img',
                      'IMAGES/system.map'):
      pass

    # Copy images that are not in SECONDARY_PAYLOAD_SKIPPED_IMAGES.
    elif filename.startswith(('IMAGES/', 'RADIO/')):
      image_name = os.path.basename(filename)
      if image_name not in ['{}.img'.format(partition) for partition in
                            SECONDARY_PAYLOAD_SKIPPED_IMAGES]:
        common.ZipWrite(target_zip, unzipped_file, arcname=filename)

    # Skip copying the postinstall config if requested.
    elif skip_postinstall and filename == POSTINSTALL_CONFIG:
      pass

    elif filename.startswith('META/'):
      # Remove the unnecessary partitions for secondary images from the
      # ab_partitions file.
      if filename == AB_PARTITIONS:
        with open(unzipped_file) as f:
          partition_list = f.read().splitlines()
        partition_list = [partition for partition in partition_list if partition
                          and partition not in SECONDARY_PAYLOAD_SKIPPED_IMAGES]
        common.ZipWriteStr(target_zip, filename,
                           '\n'.join(partition_list))
      # Remove the unnecessary partitions from the dynamic partitions list.
      elif (filename == 'META/misc_info.txt' or
            filename == DYNAMIC_PARTITION_INFO):
        modified_info = GetInfoForSecondaryImages(unzipped_file)
        common.ZipWriteStr(target_zip, filename, modified_info)
      else:
        common.ZipWrite(target_zip, unzipped_file, arcname=filename)

  common.ZipClose(target_zip)

  return target_file


def GetTargetFilesZipWithoutPostinstallConfig(input_file):
  """Returns a target-files.zip that's not containing postinstall_config.txt.

  This allows brillo_update_payload script to skip writing all the postinstall
  hooks in the generated payload. The input target-files.zip file will be
  duplicated, with 'META/postinstall_config.txt' skipped. If input_file doesn't
  contain the postinstall_config.txt entry, the input file will be returned.

  Args:
    input_file: The input target-files.zip filename.

  Returns:
    The filename of target-files.zip that doesn't contain postinstall config.
  """
  config_path = os.path.join(input_file, POSTINSTALL_CONFIG)
  if os.path.exists(config_path):
    os.unlink(config_path)
  return input_file


def ParseInfoDict(target_file_path):
  return common.LoadInfoDict(target_file_path)

def ModifyTargetFilesDynamicPartitionInfo(input_file, key, value):
  """Returns a target-files.zip with a custom VABC compression param.
  Args:
    input_file: The input target-files.zip path
    vabc_compression_param: Custom Virtual AB Compression algorithm

  Returns:
    The path to modified target-files.zip
  """
  if os.path.isdir(input_file):
    dynamic_partition_info_path = os.path.join(
        input_file, *DYNAMIC_PARTITION_INFO.split("/"))
    with open(dynamic_partition_info_path, "r") as fp:
      dynamic_partition_info = fp.read()
    dynamic_partition_info = ModifyKeyvalueList(
        dynamic_partition_info, key, value)
    with open(dynamic_partition_info_path, "w") as fp:
      fp.write(dynamic_partition_info)
    return input_file

  target_file = common.MakeTempFile(prefix="targetfiles-", suffix=".zip")
  shutil.copyfile(input_file, target_file)
  common.ZipDelete(target_file, DYNAMIC_PARTITION_INFO)
  with zipfile.ZipFile(input_file, 'r', allowZip64=True) as zfp:
    dynamic_partition_info = zfp.read(DYNAMIC_PARTITION_INFO).decode()
    dynamic_partition_info = ModifyKeyvalueList(
        dynamic_partition_info, key, value)
    with zipfile.ZipFile(target_file, "a", allowZip64=True) as output_zip:
      output_zip.writestr(DYNAMIC_PARTITION_INFO, dynamic_partition_info)
  return target_file

def GetTargetFilesZipForCustomVABCCompression(input_file, vabc_compression_param):
  """Returns a target-files.zip with a custom VABC compression param.
  Args:
    input_file: The input target-files.zip path
    vabc_compression_param: Custom Virtual AB Compression algorithm

  Returns:
    The path to modified target-files.zip
  """
  return ModifyTargetFilesDynamicPartitionInfo(input_file, "virtual_ab_compression_method", vabc_compression_param)


def GetTargetFilesZipForPartialUpdates(input_file, ab_partitions):
  """Returns a target-files.zip for partial ota update package generation.

  This function modifies ab_partitions list with the desired partitions before
  calling the brillo_update_payload script. It also cleans up the reference to
  the excluded partitions in the info file, e.g misc_info.txt.

  Args:
    input_file: The input target-files.zip filename.
    ab_partitions: A list of partitions to include in the partial update

  Returns:
    The filename of target-files.zip used for partial ota update.
  """

  original_ab_partitions = common.ReadFromInputFile(input_file, AB_PARTITIONS)

  unrecognized_partitions = [partition for partition in ab_partitions if
                             partition not in original_ab_partitions]
  if unrecognized_partitions:
    raise ValueError("Unrecognized partitions when generating partial updates",
                     unrecognized_partitions)

  logger.info("Generating partial updates for %s", ab_partitions)
  for subdir in ["IMAGES", "RADIO", "PREBUILT_IMAGES"]:
    image_dir = os.path.join(subdir)
    if not os.path.exists(image_dir):
      continue
    for filename in os.listdir(image_dir):
      filepath = os.path.join(image_dir, filename)
      if filename.endswith(".img"):
        partition_name = filename.removesuffix(".img")
        if partition_name not in ab_partitions:
          os.unlink(filepath)

  common.WriteToInputFile(input_file, 'META/ab_partitions.txt',
                          '\n'.join(ab_partitions))
  CARE_MAP_ENTRY = "META/care_map.pb"
  if DoesInputFileContain(input_file, CARE_MAP_ENTRY):
    caremap = care_map_pb2.CareMap()
    caremap.ParseFromString(
        common.ReadBytesFromInputFile(input_file, CARE_MAP_ENTRY))
    filtered = [
        part for part in caremap.partitions if part.name in ab_partitions]
    del caremap.partitions[:]
    caremap.partitions.extend(filtered)
    common.WriteBytesToInputFile(input_file, CARE_MAP_ENTRY,
                                 caremap.SerializeToString())

  for info_file in ['META/misc_info.txt', DYNAMIC_PARTITION_INFO]:
    if not DoesInputFileContain(input_file, info_file):
      logger.warning('Cannot find %s in input zipfile', info_file)
      continue

    content = common.ReadFromInputFile(input_file, info_file)
    modified_info = UpdatesInfoForSpecialUpdates(
        content, lambda p: p in ab_partitions)
    if OPTIONS.vabc_compression_param and info_file == DYNAMIC_PARTITION_INFO:
      modified_info = ModifyVABCCompressionParam(
          modified_info, OPTIONS.vabc_compression_param)
    common.WriteToInputFile(input_file, info_file, modified_info)

  def IsInPartialList(postinstall_line: str):
    idx = postinstall_line.find("=")
    if idx < 0:
      return False
    key = postinstall_line[:idx]
    logger.info("%s %s", key, ab_partitions)
    for part in ab_partitions:
      if key.endswith("_" + part):
        return True
    return False

  if common.DoesInputFileContain(input_file, POSTINSTALL_CONFIG):
    postinstall_config = common.ReadFromInputFile(
        input_file, POSTINSTALL_CONFIG)
    postinstall_config = [
        line for line in postinstall_config.splitlines() if IsInPartialList(line)]
    if postinstall_config:
      postinstall_config = "\n".join(postinstall_config)
      common.WriteToInputFile(
          input_file, POSTINSTALL_CONFIG, postinstall_config)
    else:
      os.unlink(os.path.join(input_file, POSTINSTALL_CONFIG))

  return input_file


def GetTargetFilesZipForRetrofitDynamicPartitions(input_file,
                                                  super_block_devices,
                                                  dynamic_partition_list):
  """Returns a target-files.zip for retrofitting dynamic partitions.

  This allows brillo_update_payload to generate an OTA based on the exact
  bits on the block devices. Postinstall is disabled.

  Args:
    input_file: The input target-files.zip filename.
    super_block_devices: The list of super block devices
    dynamic_partition_list: The list of dynamic partitions

  Returns:
    The filename of target-files.zip with *.img replaced with super_*.img for
    each block device in super_block_devices.
  """
  assert super_block_devices, "No super_block_devices are specified."

  replace = {'OTA/super_{}.img'.format(dev): 'IMAGES/{}.img'.format(dev)
             for dev in super_block_devices}

  # Remove partitions from META/ab_partitions.txt that is in
  # dynamic_partition_list but not in super_block_devices so that
  # brillo_update_payload won't generate update for those logical partitions.
  ab_partitions_lines = common.ReadFromInputFile(
      input_file, AB_PARTITIONS).split("\n")
  ab_partitions = [line.strip() for line in ab_partitions_lines]
  # Assert that all super_block_devices are in ab_partitions
  super_device_not_updated = [partition for partition in super_block_devices
                              if partition not in ab_partitions]
  assert not super_device_not_updated, \
      "{} is in super_block_devices but not in {}".format(
          super_device_not_updated, AB_PARTITIONS)
  # ab_partitions -= (dynamic_partition_list - super_block_devices)
  to_delete = [AB_PARTITIONS]

  # Always skip postinstall for a retrofit update.
  to_delete += [POSTINSTALL_CONFIG]

  # Delete dynamic_partitions_info.txt so that brillo_update_payload thinks this
  # is a regular update on devices without dynamic partitions support.
  to_delete += [DYNAMIC_PARTITION_INFO]

  # Remove the existing partition images as well as the map files.
  to_delete += list(replace.values())
  to_delete += ['IMAGES/{}.map'.format(dev) for dev in super_block_devices]
  for item in to_delete:
    os.unlink(os.path.join(input_file, item))

  # Write super_{foo}.img as {foo}.img.
  for src, dst in replace.items():
    assert DoesInputFileContain(input_file, src), \
        'Missing {} in {}; {} cannot be written'.format(src, input_file, dst)
    source_path = os.path.join(input_file, *src.split("/"))
    target_path = os.path.join(input_file, *dst.split("/"))
    os.rename(source_path, target_path)

  # Write new ab_partitions.txt file
  new_ab_partitions = os.paht.join(input_file, AB_PARTITIONS)
  with open(new_ab_partitions, 'w') as f:
    for partition in ab_partitions:
      if (partition in dynamic_partition_list and
              partition not in super_block_devices):
        logger.info("Dropping %s from ab_partitions.txt", partition)
        continue
      f.write(partition + "\n")

  return input_file


def GetTargetFilesZipForCustomImagesUpdates(input_file, custom_images: dict):
  """Returns a target-files.zip for custom partitions update.

  This function modifies ab_partitions list with the desired custom partitions
  and puts the custom images into the target target-files.zip.

  Args:
    input_file: The input target-files extracted directory
    custom_images: A map of custom partitions and custom images.

  Returns:
    The extracted dir of a target-files.zip which has renamed the custom images
    in the IMAGES/ to their partition names.
  """
  for custom_image in custom_images.values():
    if not os.path.exists(os.path.join(input_file, "IMAGES", custom_image)):
      raise ValueError("Specified custom image {} not found in target files {}, available images are {}",
                       custom_image, input_file, os.listdir(os.path.join(input_file, "IMAGES")))

  for custom_partition, custom_image in custom_images.items():
    default_custom_image = '{}.img'.format(custom_partition)
    if default_custom_image != custom_image:
      src = os.path.join(input_file, 'IMAGES', custom_image)
      dst = os.path.join(input_file, 'IMAGES', default_custom_image)
      os.rename(src, dst)

  return input_file


def GeneratePartitionTimestampFlags(partition_state):
  partition_timestamps = [
      part.partition_name + ":" + part.version
      for part in partition_state]
  return ["--partition_timestamps", ",".join(partition_timestamps)]


def GeneratePartitionTimestampFlagsDowngrade(
        pre_partition_state, post_partition_state):
  assert pre_partition_state is not None
  partition_timestamps = {}
  for part in post_partition_state:
    partition_timestamps[part.partition_name] = part.version
  for part in pre_partition_state:
    if part.partition_name in partition_timestamps:
      partition_timestamps[part.partition_name] = \
          max(part.version, partition_timestamps[part.partition_name])
  return [
      "--partition_timestamps",
      ",".join([key + ":" + val for (key, val)
                in partition_timestamps.items()])
  ]


def SupportsMainlineGkiUpdates(target_file):
  """Return True if the build supports MainlineGKIUpdates.

  This function scans the product.img file in IMAGES/ directory for
  pattern |*/apex/com.android.gki.*.apex|. If there are files
  matching this pattern, conclude that build supports mainline
  GKI and return True

  Args:
    target_file: Path to a target_file.zip, or an extracted directory
  Return:
    True if thisb uild supports Mainline GKI Updates.
  """
  if target_file is None:
    return False
  if os.path.isfile(target_file):
    target_file = common.UnzipTemp(target_file, ["IMAGES/product.img"])
  if not os.path.isdir(target_file):
    assert os.path.isdir(target_file), \
        "{} must be a path to zip archive or dir containing extracted"\
        " target_files".format(target_file)
  image_file = os.path.join(target_file, "IMAGES", "product.img")

  if not os.path.isfile(image_file):
    return False

  if IsSparseImage(image_file):
    # Unsparse the image
    tmp_img = common.MakeTempFile(suffix=".img")
    subprocess.check_output(["simg2img", image_file, tmp_img])
    image_file = tmp_img

  cmd = ["debugfs_static", "-R", "ls -p /apex", image_file]
  output = subprocess.check_output(cmd).decode()

  pattern = re.compile(r"com\.android\.gki\..*\.apex")
  return pattern.search(output) is not None


def ExtractOrCopyTargetFiles(target_file):
  if os.path.isdir(target_file):
    return CopyTargetFilesDir(target_file)
  else:
    return ExtractTargetFiles(target_file)


def ValidateCompressinParam(target_info):
  vabc_compression_param = OPTIONS.vabc_compression_param
  if vabc_compression_param:
    minimum_api_level_required = VABC_COMPRESSION_PARAM_SUPPORT[vabc_compression_param]
    if target_info.vendor_api_level < minimum_api_level_required:
      raise ValueError("Specified VABC compression param {} is only supported for API level >= {}, device is on API level {}".format(
          vabc_compression_param, minimum_api_level_required, target_info.vendor_api_level))


def GenerateAbOtaPackage(target_file, output_file, source_file=None):
  """Generates an Android OTA package that has A/B update payload."""
  # If input target_files are directories, create a copy so that we can modify
  # them directly
  target_info = common.BuildInfo(OPTIONS.info_dict, OPTIONS.oem_dicts)
  if OPTIONS.disable_vabc and target_info.is_release_key:
    raise ValueError("Disabling VABC on release-key builds is not supported.")
  ValidateCompressinParam(target_info)
  vabc_compression_param = target_info.vabc_compression_param

  target_file = ExtractOrCopyTargetFiles(target_file)
  if source_file is not None:
    source_file = ExtractOrCopyTargetFiles(source_file)
  # Stage the output zip package for package signing.
  if not OPTIONS.no_signing:
    staging_file = common.MakeTempFile(suffix='.zip')
  else:
    staging_file = output_file
  output_zip = zipfile.ZipFile(staging_file, "w",
                               compression=zipfile.ZIP_DEFLATED,
                               allowZip64=True)

  if source_file is not None:
    source_file = ExtractTargetFiles(source_file)
    assert "ab_partitions" in OPTIONS.source_info_dict, \
        "META/ab_partitions.txt is required for ab_update."
    assert "ab_partitions" in OPTIONS.target_info_dict, \
        "META/ab_partitions.txt is required for ab_update."
    target_info = common.BuildInfo(OPTIONS.target_info_dict, OPTIONS.oem_dicts)
    source_info = common.BuildInfo(OPTIONS.source_info_dict, OPTIONS.oem_dicts)
    # If source supports VABC, delta_generator/update_engine will attempt to
    # use VABC. This dangerous, as the target build won't have snapuserd to
    # serve I/O request when device boots. Therefore, disable VABC if source
    # build doesn't supports it.
    if not source_info.is_vabc or not target_info.is_vabc:
      logger.info("Either source or target does not support VABC, disabling.")
      OPTIONS.disable_vabc = True
    if OPTIONS.vabc_compression_param is None and \
            source_info.vabc_compression_param != target_info.vabc_compression_param:
      logger.info("Source build and target build use different compression methods {} vs {}, default to source builds parameter {}".format(
          source_info.vabc_compression_param, target_info.vabc_compression_param, source_info.vabc_compression_param))
      vabc_compression_param = source_info.vabc_compression_param

    # Virtual AB Compression was introduced in Androd S.
    # Later, we backported VABC to Android R. But verity support was not
    # backported, so if VABC is used and we are on Android R, disable
    # verity computation.
    if not OPTIONS.disable_vabc and source_info.is_android_r:
      OPTIONS.disable_verity_computation = True
      OPTIONS.disable_fec_computation = True

  else:
    assert "ab_partitions" in OPTIONS.info_dict, \
        "META/ab_partitions.txt is required for ab_update."
    source_info = None
    if OPTIONS.vabc_compression_param is None and vabc_compression_param:
      minimum_api_level_required = VABC_COMPRESSION_PARAM_SUPPORT[
          vabc_compression_param]
      if target_info.vendor_api_level < minimum_api_level_required:
        logger.warning(
            "This full OTA is configured to use VABC compression algorithm"
            " {}, which is supported since"
            " Android API level {}, but device is "
            "launched with {} . If this full OTA is"
            " served to a device running old build, OTA might fail due to "
            "unsupported compression parameter. For safety, gz is used because "
            "it's supported since day 1.".format(
                vabc_compression_param,
                minimum_api_level_required,
                target_info.vendor_api_level))
        vabc_compression_param = "gz"

  if OPTIONS.partial == []:
    logger.info(
        "Automatically detecting partial partition list from input target files.")
    OPTIONS.partial = target_info.get(
        "partial_ota_update_partitions_list").split()
    assert OPTIONS.partial, "Input target_file does not have"
    " partial_ota_update_partitions_list defined, failed to auto detect partial"
    " partition list. Please specify list of partitions to update manually via"
    " --partial=a,b,c , or generate a complete OTA by removing the --partial"
    " option"
    OPTIONS.partial.sort()
    if source_info:
      source_partial_list = source_info.get(
          "partial_ota_update_partitions_list").split()
      if source_partial_list:
        source_partial_list.sort()
        if source_partial_list != OPTIONS.partial:
          logger.warning("Source build and target build have different partial partition lists. Source: %s, target: %s, taking the intersection.",
                         source_partial_list, OPTIONS.partial)
          OPTIONS.partial = list(
              set(OPTIONS.partial) and set(source_partial_list))
          OPTIONS.partial.sort()
    logger.info("Automatically deduced partial partition list: %s",
                OPTIONS.partial)

  if target_info.vendor_suppressed_vabc:
    logger.info("Vendor suppressed VABC. Disabling")
    OPTIONS.disable_vabc = True

  # Both source and target build need to support VABC XOR for us to use it.
  # Source build's update_engine must be able to write XOR ops, and target
  # build's snapuserd must be able to interpret XOR ops.
  if not target_info.is_vabc_xor or OPTIONS.disable_vabc or \
          (source_info is not None and not source_info.is_vabc_xor):
    logger.info("VABC XOR Not supported, disabling")
    OPTIONS.enable_vabc_xor = False

  if OPTIONS.vabc_compression_param == "none":
    logger.info(
        "VABC Compression algorithm is set to 'none', disabling VABC xor")
    OPTIONS.enable_vabc_xor = False

  if OPTIONS.enable_vabc_xor:
    api_level = -1
    if source_info is not None:
      api_level = source_info.vendor_api_level
    if api_level == -1:
      api_level = target_info.vendor_api_level

    # XOR is only supported on T and higher.
    if api_level < 33:
      logger.error("VABC XOR not supported on this vendor, disabling")
      OPTIONS.enable_vabc_xor = False

  if OPTIONS.vabc_compression_param:
    vabc_compression_param = OPTIONS.vabc_compression_param

  additional_args = []

  # Prepare custom images.
  if OPTIONS.custom_images:
    target_file = GetTargetFilesZipForCustomImagesUpdates(
        target_file, OPTIONS.custom_images)

  if OPTIONS.retrofit_dynamic_partitions:
    target_file = GetTargetFilesZipForRetrofitDynamicPartitions(
        target_file, target_info.get("super_block_devices").strip().split(),
        target_info.get("dynamic_partition_list").strip().split())
  elif OPTIONS.partial:
    target_file = GetTargetFilesZipForPartialUpdates(target_file,
                                                     OPTIONS.partial)
  if vabc_compression_param != target_info.vabc_compression_param:
    target_file = GetTargetFilesZipForCustomVABCCompression(
        target_file, vabc_compression_param)
  if OPTIONS.vabc_cow_version:
    target_file = ModifyTargetFilesDynamicPartitionInfo(target_file, "virtual_ab_cow_version", OPTIONS.vabc_cow_version)
  if OPTIONS.skip_postinstall:
    target_file = GetTargetFilesZipWithoutPostinstallConfig(target_file)
  # Target_file may have been modified, reparse ab_partitions
  target_info.info_dict['ab_partitions'] = common.ReadFromInputFile(target_file,
                                                                    AB_PARTITIONS).strip().split("\n")

  from check_target_files_vintf import CheckVintfIfTrebleEnabled
  CheckVintfIfTrebleEnabled(target_file, target_info)

  # Metadata to comply with Android OTA package format.
  metadata = GetPackageMetadata(target_info, source_info)
  # Generate payload.
  payload = PayloadGenerator(
      wipe_user_data=OPTIONS.wipe_user_data, minor_version=OPTIONS.force_minor_version, is_partial_update=OPTIONS.partial, spl_downgrade=OPTIONS.spl_downgrade)

  partition_timestamps_flags = []
  # Enforce a max timestamp this payload can be applied on top of.
  if OPTIONS.downgrade:
    max_timestamp = source_info.GetBuildProp("ro.build.date.utc")
    partition_timestamps_flags = GeneratePartitionTimestampFlagsDowngrade(
        metadata.precondition.partition_state,
        metadata.postcondition.partition_state
    )
  else:
    max_timestamp = str(metadata.postcondition.timestamp)
    partition_timestamps_flags = GeneratePartitionTimestampFlags(
        metadata.postcondition.partition_state)

  if not ota_utils.IsZucchiniCompatible(source_file, target_file):
    logger.warning(
        "Builds doesn't support zucchini, or source/target don't have compatible zucchini versions. Disabling zucchini.")
    OPTIONS.enable_zucchini = False

  security_patch_level = target_info.GetBuildProp(
      "ro.build.version.security_patch")
  if OPTIONS.security_patch_level is not None:
    security_patch_level = OPTIONS.security_patch_level

  additional_args += ["--security_patch_level", security_patch_level]

  if OPTIONS.max_threads:
    additional_args += ["--max_threads", OPTIONS.max_threads]

  additional_args += ["--enable_zucchini=" +
                      str(OPTIONS.enable_zucchini).lower()]
  if OPTIONS.enable_puffdiff is not None:
    additional_args += ["--enable_puffdiff=" +
                        str(OPTIONS.enable_puffdiff).lower()]

  if not ota_utils.IsLz4diffCompatible(source_file, target_file):
    logger.warning(
        "Source build doesn't support lz4diff, or source/target don't have compatible lz4diff versions. Disabling lz4diff.")
    OPTIONS.enable_lz4diff = False

  additional_args += ["--enable_lz4diff=" +
                      str(OPTIONS.enable_lz4diff).lower()]

  if source_file and OPTIONS.enable_lz4diff:
    input_tmp = common.UnzipTemp(source_file, ["META/liblz4.so"])
    liblz4_path = os.path.join(input_tmp, "META", "liblz4.so")
    assert os.path.exists(
        liblz4_path), "liblz4.so not found in META/ dir of target file {}".format(liblz4_path)
    logger.info("Enabling lz4diff %s", liblz4_path)
    additional_args += ["--liblz4_path", liblz4_path]
    erofs_compression_param = OPTIONS.target_info_dict.get(
        "erofs_default_compressor")
    assert erofs_compression_param is not None, "'erofs_default_compressor' not found in META/misc_info.txt of target build. This is required to enable lz4diff."
    additional_args += ["--erofs_compression_param", erofs_compression_param]

  if OPTIONS.disable_vabc:
    additional_args += ["--disable_vabc=true"]
  if OPTIONS.enable_vabc_xor:
    additional_args += ["--enable_vabc_xor=true"]
  if OPTIONS.compressor_types:
    additional_args += ["--compressor_types", OPTIONS.compressor_types]
  additional_args += ["--max_timestamp", max_timestamp]

  payload.Generate(
      target_file,
      source_file,
      additional_args + partition_timestamps_flags
  )

  # Sign the payload.
  pw = OPTIONS.key_passwords[OPTIONS.package_key]
  payload_signer = PayloadSigner(
      OPTIONS.package_key, OPTIONS.private_key_suffix,
      pw, OPTIONS.payload_signer)
  payload.Sign(payload_signer)

  # Write the payload into output zip.
  payload.WriteToZip(output_zip)

  # Generate and include the secondary payload that installs secondary images
  # (e.g. system_other.img).
  if OPTIONS.include_secondary:
    # We always include a full payload for the secondary slot, even when
    # building an incremental OTA. See the comments for "--include_secondary".
    secondary_target_file = GetTargetFilesZipForSecondaryImages(
        target_file, OPTIONS.skip_postinstall)
    secondary_payload = PayloadGenerator(secondary=True)
    secondary_payload.Generate(secondary_target_file,
                               additional_args=["--max_timestamp",
                                                max_timestamp])
    secondary_payload.Sign(payload_signer)
    secondary_payload.WriteToZip(output_zip)

  # If dm-verity is supported for the device, copy contents of care_map
  # into A/B OTA package.
  if target_info.get("avb_enable") == "true":
    # Adds care_map if either the protobuf format or the plain text one exists.
    for care_map_name in ["care_map.pb", "care_map.txt"]:
      if not DoesInputFileContain(target_file, "META/" + care_map_name):
        continue
      care_map_data = common.ReadBytesFromInputFile(
          target_file, "META/" + care_map_name)
      # In order to support streaming, care_map needs to be packed as
      # ZIP_STORED.
      common.ZipWriteStr(output_zip, care_map_name, care_map_data,
                         compress_type=zipfile.ZIP_STORED)
      # break here to avoid going into else when care map has been handled
      break
    else:
      logger.warning("Cannot find care map file in target_file package")

  # Add the source apex version for incremental ota updates, and write the
  # result apex info to the ota package.
  ota_apex_info = ota_utils.ConstructOtaApexInfo(target_file, source_file)
  if ota_apex_info is not None:
    common.ZipWriteStr(output_zip, "apex_info.pb", ota_apex_info,
                       compress_type=zipfile.ZIP_STORED)

  # We haven't written the metadata entry yet, which will be handled in
  # FinalizeMetadata().
  common.ZipClose(output_zip)

  FinalizeMetadata(metadata, staging_file, output_file,
                   package_key=OPTIONS.package_key)


def main(argv):

  def option_handler(o, a):
    if o in ("-i", "--incremental_from"):
      OPTIONS.incremental_source = a
    elif o == "--full_radio":
      OPTIONS.full_radio = True
    elif o == "--full_bootloader":
      OPTIONS.full_bootloader = True
    elif o == "--wipe_user_data":
      OPTIONS.wipe_user_data = True
    elif o == "--downgrade":
      OPTIONS.downgrade = True
      OPTIONS.wipe_user_data = True
    elif o == "--override_timestamp":
      OPTIONS.downgrade = True
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
    elif o == "--include_secondary":
      OPTIONS.include_secondary = True
    elif o == "--no_signing":
      OPTIONS.no_signing = True
    elif o == "--verify":
      OPTIONS.verify = True
    elif o == "--block":
      OPTIONS.block_based = True
    elif o in ("-b", "--binary"):
      OPTIONS.updater_binary = a
    elif o == "--stash_threshold":
      try:
        OPTIONS.stash_threshold = float(a)
      except ValueError:
        raise ValueError("Cannot parse value %r for option %r - expecting "
                         "a float" % (a, o))
    elif o == "--log_diff":
      OPTIONS.log_diff = a
    elif o == "--extracted_input_target_files":
      OPTIONS.extracted_input = a
    elif o == "--skip_postinstall":
      OPTIONS.skip_postinstall = True
    elif o == "--retrofit_dynamic_partitions":
      OPTIONS.retrofit_dynamic_partitions = True
    elif o == "--skip_compatibility_check":
      OPTIONS.skip_compatibility_check = True
    elif o == "--output_metadata_path":
      OPTIONS.output_metadata_path = a
    elif o == "--disable_fec_computation":
      OPTIONS.disable_fec_computation = True
    elif o == "--disable_verity_computation":
      OPTIONS.disable_verity_computation = True
    elif o == "--force_non_ab":
      OPTIONS.force_non_ab = True
    elif o == "--boot_variable_file":
      OPTIONS.boot_variable_file = a
    elif o == "--partial":
      if a:
        partitions = a.split()
        if not partitions:
          raise ValueError("Cannot parse partitions in {}".format(a))
      else:
        partitions = []
      OPTIONS.partial = partitions
    elif o == "--custom_image":
      custom_partition, custom_image = a.split("=")
      OPTIONS.custom_images[custom_partition] = custom_image
    elif o == "--disable_vabc":
      OPTIONS.disable_vabc = True
    elif o == "--spl_downgrade":
      OPTIONS.spl_downgrade = True
      OPTIONS.wipe_user_data = True
    elif o == "--vabc_downgrade":
      OPTIONS.vabc_downgrade = True
    elif o == "--enable_vabc_xor":
      assert a.lower() in ["true", "false"]
      OPTIONS.enable_vabc_xor = a.lower() != "false"
    elif o == "--force_minor_version":
      OPTIONS.force_minor_version = a
    elif o == "--compressor_types":
      OPTIONS.compressor_types = a
    elif o == "--enable_zucchini":
      assert a.lower() in ["true", "false"]
      OPTIONS.enable_zucchini = a.lower() != "false"
    elif o == "--enable_puffdiff":
      assert a.lower() in ["true", "false"]
      OPTIONS.enable_puffdiff = a.lower() != "false"
    elif o == "--enable_lz4diff":
      assert a.lower() in ["true", "false"]
      OPTIONS.enable_lz4diff = a.lower() != "false"
    elif o == "--vabc_compression_param":
      words = a.split(",")
      assert len(words) >= 1 and len(words) <= 2
      OPTIONS.vabc_compression_param = a.lower()
      if len(words) == 2:
        if not words[1].isdigit():
          raise ValueError("Cannot parse value %r for option $COMPRESSION_LEVEL - only "
                           "integers are allowed." % words[1])
    elif o == "--security_patch_level":
      OPTIONS.security_patch_level = a
    elif o in ("--max_threads"):
      if a.isdigit():
        OPTIONS.max_threads = a
      else:
        raise ValueError("Cannot parse value %r for option %r - only "
                         "integers are allowed." % (a, o))
    elif o == "--vabc_cow_version":
      if a.isdigit():
        OPTIONS.vabc_cow_version = a
      else:
        raise ValueError("Cannot parse value %r for option %r - only "
                         "integers are allowed." % (a, o))
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts="b:k:i:d:e:t:2o:",
                             extra_long_opts=[
                                 "incremental_from=",
                                 "full_radio",
                                 "full_bootloader",
                                 "wipe_user_data",
                                 "downgrade",
                                 "override_timestamp",
                                 "extra_script=",
                                 "worker_threads=",
                                 "two_step",
                                 "include_secondary",
                                 "no_signing",
                                 "block",
                                 "binary=",
                                 "oem_settings=",
                                 "oem_no_mount",
                                 "verify",
                                 "stash_threshold=",
                                 "log_diff=",
                                 "extracted_input_target_files=",
                                 "skip_postinstall",
                                 "retrofit_dynamic_partitions",
                                 "skip_compatibility_check",
                                 "output_metadata_path=",
                                 "disable_fec_computation",
                                 "disable_verity_computation",
                                 "force_non_ab",
                                 "boot_variable_file=",
                                 "partial=",
                                 "custom_image=",
                                 "disable_vabc",
                                 "spl_downgrade",
                                 "vabc_downgrade",
                                 "enable_vabc_xor=",
                                 "force_minor_version=",
                                 "compressor_types=",
                                 "enable_zucchini=",
                                 "enable_puffdiff=",
                                 "enable_lz4diff=",
                                 "vabc_compression_param=",
                                 "security_patch_level=",
                                 "max_threads=",
                                 "vabc_cow_version=",
                             ], extra_option_handler=[option_handler, payload_signer.signer_options])
  common.InitLogging()

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  # Load the build info dicts from the zip directly or the extracted input
  # directory. We don't need to unzip the entire target-files zips, because they
  # won't be needed for A/B OTAs (brillo_update_payload does that on its own).
  # When loading the info dicts, we don't need to provide the second parameter
  # to common.LoadInfoDict(). Specifying the second parameter allows replacing
  # some properties with their actual paths, such as 'selinux_fc',
  # 'ramdisk_dir', which won't be used during OTA generation.
  if OPTIONS.extracted_input is not None:
    OPTIONS.info_dict = common.LoadInfoDict(OPTIONS.extracted_input)
  else:
    OPTIONS.info_dict = common.LoadInfoDict(args[0])

  if OPTIONS.wipe_user_data:
    if not OPTIONS.vabc_downgrade:
      logger.info("Detected downgrade/datawipe OTA."
                  "When wiping userdata, VABC OTA makes the user "
                  "wait in recovery mode for merge to finish. Disable VABC by "
                  "default. If you really want to do VABC downgrade, pass "
                  "--vabc_downgrade")
      OPTIONS.disable_vabc = True
    # We should only allow downgrading incrementals (as opposed to full).
    # Otherwise the device may go back from arbitrary build with this full
    # OTA package.
  if OPTIONS.incremental_source is None and OPTIONS.downgrade:
    raise ValueError("Cannot generate downgradable full OTAs")

  # TODO(xunchang) for retrofit and partial updates, maybe we should rebuild the
  # target-file and reload the info_dict. So the info will be consistent with
  # the modified target-file.

  logger.info("--- target info ---")
  common.DumpInfoDict(OPTIONS.info_dict)

  # Load the source build dict if applicable.
  if OPTIONS.incremental_source is not None:
    OPTIONS.target_info_dict = OPTIONS.info_dict
    OPTIONS.source_info_dict = ParseInfoDict(OPTIONS.incremental_source)

    logger.info("--- source info ---")
    common.DumpInfoDict(OPTIONS.source_info_dict)

  if OPTIONS.partial:
    OPTIONS.info_dict['ab_partitions'] = \
        list(
        set(OPTIONS.info_dict['ab_partitions']) & set(OPTIONS.partial)
    )
    if OPTIONS.source_info_dict:
      OPTIONS.source_info_dict['ab_partitions'] = \
          list(
          set(OPTIONS.source_info_dict['ab_partitions']) &
          set(OPTIONS.partial)
      )

  # Load OEM dicts if provided.
  OPTIONS.oem_dicts = _LoadOemDicts(OPTIONS.oem_source)

  # Assume retrofitting dynamic partitions when base build does not set
  # use_dynamic_partitions but target build does.
  if (OPTIONS.source_info_dict and
      OPTIONS.source_info_dict.get("use_dynamic_partitions") != "true" and
          OPTIONS.target_info_dict.get("use_dynamic_partitions") == "true"):
    if OPTIONS.target_info_dict.get("dynamic_partition_retrofit") != "true":
      raise common.ExternalError(
          "Expect to generate incremental OTA for retrofitting dynamic "
          "partitions, but dynamic_partition_retrofit is not set in target "
          "build.")
    logger.info("Implicitly generating retrofit incremental OTA.")
    OPTIONS.retrofit_dynamic_partitions = True

  # Skip postinstall for retrofitting dynamic partitions.
  if OPTIONS.retrofit_dynamic_partitions:
    OPTIONS.skip_postinstall = True

  ab_update = OPTIONS.info_dict.get("ab_update") == "true"
  allow_non_ab = OPTIONS.info_dict.get("allow_non_ab") == "true"
  if OPTIONS.force_non_ab:
    assert allow_non_ab,\
        "--force_non_ab only allowed on devices that supports non-A/B"
    assert ab_update, "--force_non_ab only allowed on A/B devices"

  generate_ab = not OPTIONS.force_non_ab and ab_update

  # Use the default key to sign the package if not specified with package_key.
  # package_keys are needed on ab_updates, so always define them if an
  # A/B update is getting created.
  if not OPTIONS.no_signing or generate_ab:
    if OPTIONS.package_key is None:
      OPTIONS.package_key = OPTIONS.info_dict.get(
          "default_system_dev_certificate",
          "build/make/target/product/security/testkey")
    # Get signing keys
    OPTIONS.key_passwords = common.GetKeyPasswords([OPTIONS.package_key])

    # Only check for existence of key file if using the default signer.
    # Because the custom signer might not need the key file AT all.
    # b/191704641
    if not OPTIONS.payload_signer:
      private_key_path = OPTIONS.package_key + OPTIONS.private_key_suffix
      if not os.path.exists(private_key_path):
        raise common.ExternalError(
            "Private key {} doesn't exist. Make sure you passed the"
            " correct key path through -k option".format(
                private_key_path)
        )
      signapk_abs_path = os.path.join(
          OPTIONS.search_path, OPTIONS.signapk_path)
      if not os.path.exists(signapk_abs_path):
        raise common.ExternalError(
            "Failed to find sign apk binary {} in search path {}. Make sure the correct search path is passed via -p".format(OPTIONS.signapk_path, OPTIONS.search_path))

  if OPTIONS.source_info_dict:
    source_build_prop = OPTIONS.source_info_dict["build.prop"]
    target_build_prop = OPTIONS.target_info_dict["build.prop"]
    source_spl = source_build_prop.GetProp(SECURITY_PATCH_LEVEL_PROP_NAME)
    target_spl = target_build_prop.GetProp(SECURITY_PATCH_LEVEL_PROP_NAME)
    is_spl_downgrade = target_spl < source_spl
    if is_spl_downgrade and target_build_prop.GetProp("ro.build.tags") == "release-keys":
      raise common.ExternalError(
          "Target security patch level {} is older than source SPL {} "
          "A locked bootloader will reject SPL downgrade no matter "
          "what(even if data wipe is done), so SPL downgrade on any "
          "release-keys build is not allowed.".format(target_spl, source_spl))

    logger.info("SPL downgrade on %s",
                target_build_prop.GetProp("ro.build.tags"))
    if is_spl_downgrade and not OPTIONS.spl_downgrade and not OPTIONS.downgrade:
      raise common.ExternalError(
          "Target security patch level {} is older than source SPL {} applying "
          "such OTA will likely cause device fail to boot. Pass --spl_downgrade "
          "to override this check. This script expects security patch level to "
          "be in format yyyy-mm-dd (e.x. 2021-02-05). It's possible to use "
          "separators other than -, so as long as it's used consistenly across "
          "all SPL dates".format(target_spl, source_spl))
    elif not is_spl_downgrade and OPTIONS.spl_downgrade:
      raise ValueError("--spl_downgrade specified but no actual SPL downgrade"
                       " detected. Please only pass in this flag if you want a"
                       " SPL downgrade. Target SPL: {} Source SPL: {}"
                       .format(target_spl, source_spl))
  if generate_ab:
    GenerateAbOtaPackage(
        target_file=args[0],
        output_file=args[1],
        source_file=OPTIONS.incremental_source)

  else:
    GenerateNonAbOtaPackage(
        target_file=args[0],
        output_file=args[1],
        source_file=OPTIONS.incremental_source)

  # Post OTA generation works.
  if OPTIONS.incremental_source is not None and OPTIONS.log_diff:
    logger.info("Generating diff logs...")
    logger.info("Unzipping target-files for diffing...")
    target_dir = common.UnzipTemp(args[0], TARGET_DIFFING_UNZIP_PATTERN)
    source_dir = common.UnzipTemp(
        OPTIONS.incremental_source, TARGET_DIFFING_UNZIP_PATTERN)

    with open(OPTIONS.log_diff, 'w') as out_file:
      target_files_diff.recursiveDiff(
          '', source_dir, target_dir, out_file)

  logger.info("done.")


if __name__ == '__main__':
  try:
    common.CloseInheritedPipes()
    main(sys.argv[1:])
  finally:
    common.Cleanup()
