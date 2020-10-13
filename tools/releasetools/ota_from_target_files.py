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

  -o  (--oem_settings) <main_file[,additional_files...]>
      Comma seperated list of files used to specify the expected OEM-specific
      properties on the OEM partition of the intended device. Multiple expected
      values can be used by providing multiple files. Only the first dict will
      be used to compute fingerprint, while the rest will be used to assert
      OEM-specific properties.

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
      Disable the on device FEC data computation for incremental updates.

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
"""

from __future__ import print_function

import logging
import multiprocessing
import os.path
import shlex
import shutil
import struct
import sys
import zipfile

import common
import ota_utils
import target_files_diff
from check_target_files_vintf import CheckVintfIfTrebleEnabled
from non_ab_ota import GenerateNonAbOtaPackage
from ota_utils import (UNZIP_PATTERN, FinalizeMetadata, GetPackageMetadata,
                       PropertyFiles)

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
OPTIONS.payload_signer = None
OPTIONS.payload_signer_args = []
OPTIONS.payload_signer_maximum_signature_size = None
OPTIONS.extracted_input = None
OPTIONS.skip_postinstall = False
OPTIONS.skip_compatibility_check = False
OPTIONS.disable_fec_computation = False


POSTINSTALL_CONFIG = 'META/postinstall_config.txt'
DYNAMIC_PARTITION_INFO = 'META/dynamic_partitions_info.txt'
AB_PARTITIONS = 'META/ab_partitions.txt'

# Files to be unzipped for target diffing purpose.
TARGET_DIFFING_UNZIP_PATTERN = ['BOOT', 'RECOVERY', 'SYSTEM/*', 'VENDOR/*',
                                'PRODUCT/*', 'SYSTEM_EXT/*', 'ODM/*',
                                'VENDOR_DLKM/*', 'ODM_DLKM/*']
RETROFIT_DAP_UNZIP_PATTERN = ['OTA/super_*.img', AB_PARTITIONS]

# Images to be excluded from secondary payload. We essentially only keep
# 'system_other' and bootloader partitions.
SECONDARY_PAYLOAD_SKIPPED_IMAGES = [
    'boot', 'dtbo', 'modem', 'odm', 'odm_dlkm', 'product', 'radio', 'recovery',
    'system_ext', 'vbmeta', 'vbmeta_system', 'vbmeta_vendor', 'vendor',
    'vendor_boot']


class PayloadSigner(object):
  """A class that wraps the payload signing works.

  When generating a Payload, hashes of the payload and metadata files will be
  signed with the device key, either by calling an external payload signer or
  by calling openssl with the package key. This class provides a unified
  interface, so that callers can just call PayloadSigner.Sign().

  If an external payload signer has been specified (OPTIONS.payload_signer), it
  calls the signer with the provided args (OPTIONS.payload_signer_args). Note
  that the signing key should be provided as part of the payload_signer_args.
  Otherwise without an external signer, it uses the package key
  (OPTIONS.package_key) and calls openssl for the signing works.
  """

  def __init__(self):
    if OPTIONS.payload_signer is None:
      # Prepare the payload signing key.
      private_key = OPTIONS.package_key + OPTIONS.private_key_suffix
      pw = OPTIONS.key_passwords[OPTIONS.package_key]

      cmd = ["openssl", "pkcs8", "-in", private_key, "-inform", "DER"]
      cmd.extend(["-passin", "pass:" + pw] if pw else ["-nocrypt"])
      signing_key = common.MakeTempFile(prefix="key-", suffix=".key")
      cmd.extend(["-out", signing_key])
      common.RunAndCheckOutput(cmd, verbose=False)

      self.signer = "openssl"
      self.signer_args = ["pkeyutl", "-sign", "-inkey", signing_key,
                          "-pkeyopt", "digest:sha256"]
      self.maximum_signature_size = self._GetMaximumSignatureSizeInBytes(
          signing_key)
    else:
      self.signer = OPTIONS.payload_signer
      self.signer_args = OPTIONS.payload_signer_args
      if OPTIONS.payload_signer_maximum_signature_size:
        self.maximum_signature_size = int(
            OPTIONS.payload_signer_maximum_signature_size)
      else:
        # The legacy config uses RSA2048 keys.
        logger.warning("The maximum signature size for payload signer is not"
                       " set, default to 256 bytes.")
        self.maximum_signature_size = 256

  @staticmethod
  def _GetMaximumSignatureSizeInBytes(signing_key):
    out_signature_size_file = common.MakeTempFile("signature_size")
    cmd = ["delta_generator", "--out_maximum_signature_size_file={}".format(
        out_signature_size_file), "--private_key={}".format(signing_key)]
    common.RunAndCheckOutput(cmd)
    with open(out_signature_size_file) as f:
      signature_size = f.read().rstrip()
    logger.info("%s outputs the maximum signature size: %s", cmd[0],
                signature_size)
    return int(signature_size)

  def Sign(self, in_file):
    """Signs the given input file. Returns the output filename."""
    out_file = common.MakeTempFile(prefix="signed-", suffix=".bin")
    cmd = [self.signer] + self.signer_args + ['-in', in_file, '-out', out_file]
    common.RunAndCheckOutput(cmd)
    return out_file


class Payload(object):
  """Manages the creation and the signing of an A/B OTA Payload."""

  PAYLOAD_BIN = 'payload.bin'
  PAYLOAD_PROPERTIES_TXT = 'payload_properties.txt'
  SECONDARY_PAYLOAD_BIN = 'secondary/payload.bin'
  SECONDARY_PAYLOAD_PROPERTIES_TXT = 'secondary/payload_properties.txt'

  def __init__(self, secondary=False):
    """Initializes a Payload instance.

    Args:
      secondary: Whether it's generating a secondary payload (default: False).
    """
    self.payload_file = None
    self.payload_properties = None
    self.secondary = secondary

  def _Run(self, cmd):  # pylint: disable=no-self-use
    # Don't pipe (buffer) the output if verbose is set. Let
    # brillo_update_payload write to stdout/stderr directly, so its progress can
    # be monitored.
    if OPTIONS.verbose:
      common.RunAndCheckOutput(cmd, stdout=None, stderr=None)
    else:
      common.RunAndCheckOutput(cmd)

  def Generate(self, target_file, source_file=None, additional_args=None):
    """Generates a payload from the given target-files zip(s).

    Args:
      target_file: The filename of the target build target-files zip.
      source_file: The filename of the source build target-files zip; or None if
          generating a full OTA.
      additional_args: A list of additional args that should be passed to
          brillo_update_payload script; or None.
    """
    if additional_args is None:
      additional_args = []

    payload_file = common.MakeTempFile(prefix="payload-", suffix=".bin")
    cmd = ["brillo_update_payload", "generate",
           "--payload", payload_file,
           "--target_image", target_file]
    if source_file is not None:
      cmd.extend(["--source_image", source_file])
      if OPTIONS.disable_fec_computation:
        cmd.extend(["--disable_fec_computation", "true"])
    cmd.extend(additional_args)
    self._Run(cmd)

    self.payload_file = payload_file
    self.payload_properties = None

  def Sign(self, payload_signer):
    """Generates and signs the hashes of the payload and metadata.

    Args:
      payload_signer: A PayloadSigner() instance that serves the signing work.

    Raises:
      AssertionError: On any failure when calling brillo_update_payload script.
    """
    assert isinstance(payload_signer, PayloadSigner)

    # 1. Generate hashes of the payload and metadata files.
    payload_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
    metadata_sig_file = common.MakeTempFile(prefix="sig-", suffix=".bin")
    cmd = ["brillo_update_payload", "hash",
           "--unsigned_payload", self.payload_file,
           "--signature_size", str(payload_signer.maximum_signature_size),
           "--metadata_hash_file", metadata_sig_file,
           "--payload_hash_file", payload_sig_file]
    self._Run(cmd)

    # 2. Sign the hashes.
    signed_payload_sig_file = payload_signer.Sign(payload_sig_file)
    signed_metadata_sig_file = payload_signer.Sign(metadata_sig_file)

    # 3. Insert the signatures back into the payload file.
    signed_payload_file = common.MakeTempFile(prefix="signed-payload-",
                                              suffix=".bin")
    cmd = ["brillo_update_payload", "sign",
           "--unsigned_payload", self.payload_file,
           "--payload", signed_payload_file,
           "--signature_size", str(payload_signer.maximum_signature_size),
           "--metadata_signature_file", signed_metadata_sig_file,
           "--payload_signature_file", signed_payload_sig_file]
    self._Run(cmd)

    # 4. Dump the signed payload properties.
    properties_file = common.MakeTempFile(prefix="payload-properties-",
                                          suffix=".txt")
    cmd = ["brillo_update_payload", "properties",
           "--payload", signed_payload_file,
           "--properties_file", properties_file]
    self._Run(cmd)

    if self.secondary:
      with open(properties_file, "a") as f:
        f.write("SWITCH_SLOT_ON_REBOOT=0\n")

    if OPTIONS.wipe_user_data:
      with open(properties_file, "a") as f:
        f.write("POWERWASH=1\n")

    self.payload_file = signed_payload_file
    self.payload_properties = properties_file

  def WriteToZip(self, output_zip):
    """Writes the payload to the given zip.

    Args:
      output_zip: The output ZipFile instance.
    """
    assert self.payload_file is not None
    assert self.payload_properties is not None

    if self.secondary:
      payload_arcname = Payload.SECONDARY_PAYLOAD_BIN
      payload_properties_arcname = Payload.SECONDARY_PAYLOAD_PROPERTIES_TXT
    else:
      payload_arcname = Payload.PAYLOAD_BIN
      payload_properties_arcname = Payload.PAYLOAD_PROPERTIES_TXT

    # Add the signed payload file and properties into the zip. In order to
    # support streaming, we pack them as ZIP_STORED. So these entries can be
    # read directly with the offset and length pairs.
    common.ZipWrite(output_zip, self.payload_file, arcname=payload_arcname,
                    compress_type=zipfile.ZIP_STORED)
    common.ZipWrite(output_zip, self.payload_properties,
                    arcname=payload_properties_arcname,
                    compress_type=zipfile.ZIP_STORED)


def _LoadOemDicts(oem_source):
  """Returns the list of loaded OEM properties dict."""
  if not oem_source:
    return None

  oem_dicts = []
  for oem_file in oem_source:
    with open(oem_file) as fp:
      oem_dicts.append(common.LoadDictionaryFromLines(fp.readlines()))
  return oem_dicts


class StreamingPropertyFiles(PropertyFiles):
  """A subclass for computing the property-files for streaming A/B OTAs."""

  def __init__(self):
    super(StreamingPropertyFiles, self).__init__()
    self.name = 'ota-streaming-property-files'
    self.required = (
        # payload.bin and payload_properties.txt must exist.
        'payload.bin',
        'payload_properties.txt',
    )
    self.optional = (
        # care_map is available only if dm-verity is enabled.
        'care_map.pb',
        'care_map.txt',
        # compatibility.zip is available only if target supports Treble.
        'compatibility.zip',
    )


class AbOtaPropertyFiles(StreamingPropertyFiles):
  """The property-files for A/B OTA that includes payload_metadata.bin info.

  Since P, we expose one more token (aka property-file), in addition to the ones
  for streaming A/B OTA, for a virtual entry of 'payload_metadata.bin'.
  'payload_metadata.bin' is the header part of a payload ('payload.bin'), which
  doesn't exist as a separate ZIP entry, but can be used to verify if the
  payload can be applied on the given device.

  For backward compatibility, we keep both of the 'ota-streaming-property-files'
  and the newly added 'ota-property-files' in P. The new token will only be
  available in 'ota-property-files'.
  """

  def __init__(self):
    super(AbOtaPropertyFiles, self).__init__()
    self.name = 'ota-property-files'

  def _GetPrecomputed(self, input_zip):
    offset, size = self._GetPayloadMetadataOffsetAndSize(input_zip)
    return ['payload_metadata.bin:{}:{}'.format(offset, size)]

  @staticmethod
  def _GetPayloadMetadataOffsetAndSize(input_zip):
    """Computes the offset and size of the payload metadata for a given package.

    (From system/update_engine/update_metadata.proto)
    A delta update file contains all the deltas needed to update a system from
    one specific version to another specific version. The update format is
    represented by this struct pseudocode:

    struct delta_update_file {
      char magic[4] = "CrAU";
      uint64 file_format_version;
      uint64 manifest_size;  // Size of protobuf DeltaArchiveManifest

      // Only present if format_version > 1:
      uint32 metadata_signature_size;

      // The Bzip2 compressed DeltaArchiveManifest
      char manifest[metadata_signature_size];

      // The signature of the metadata (from the beginning of the payload up to
      // this location, not including the signature itself). This is a
      // serialized Signatures message.
      char medatada_signature_message[metadata_signature_size];

      // Data blobs for files, no specific format. The specific offset
      // and length of each data blob is recorded in the DeltaArchiveManifest.
      struct {
        char data[];
      } blobs[];

      // These two are not signed:
      uint64 payload_signatures_message_size;
      char payload_signatures_message[];
    };

    'payload-metadata.bin' contains all the bytes from the beginning of the
    payload, till the end of 'medatada_signature_message'.
    """
    payload_info = input_zip.getinfo('payload.bin')
    payload_offset = payload_info.header_offset
    payload_offset += zipfile.sizeFileHeader
    payload_offset += len(payload_info.extra) + len(payload_info.filename)
    payload_size = payload_info.file_size

    with input_zip.open('payload.bin') as payload_fp:
      header_bin = payload_fp.read(24)

    # network byte order (big-endian)
    header = struct.unpack("!IQQL", header_bin)

    # 'CrAU'
    magic = header[0]
    assert magic == 0x43724155, "Invalid magic: {:x}".format(magic)

    manifest_size = header[2]
    metadata_signature_size = header[3]
    metadata_total = 24 + manifest_size + metadata_signature_size
    assert metadata_total < payload_size

    return (payload_offset, metadata_total)


def GetTargetFilesZipForSecondaryImages(input_file, skip_postinstall=False):
  """Returns a target-files.zip file for generating secondary payload.

  Although the original target-files.zip already contains secondary slot
  images (i.e. IMAGES/system_other.img), we need to rename the files to the
  ones without _other suffix. Note that we cannot instead modify the names in
  META/ab_partitions.txt, because there are no matching partitions on device.

  For the partitions that don't have secondary images, the ones for primary
  slot will be used. This is to ensure that we always have valid boot, vbmeta,
  bootloader images in the inactive slot.

  Args:
    input_file: The input target-files.zip file.
    skip_postinstall: Whether to skip copying the postinstall config file.

  Returns:
    The filename of the target-files.zip for generating secondary payload.
  """

  def GetInfoForSecondaryImages(info_file):
    """Updates info file for secondary payload generation.

    Scan each line in the info file, and remove the unwanted partitions from
    the dynamic partition list in the related properties. e.g.
    "super_google_dynamic_partitions_partition_list=system vendor product"
    will become "super_google_dynamic_partitions_partition_list=system".

    Args:
      info_file: The input info file. e.g. misc_info.txt.

    Returns:
      A string of the updated info content.
    """

    output_list = []
    with open(info_file) as f:
      lines = f.read().splitlines()

    # The suffix in partition_list variables that follows the name of the
    # partition group.
    LIST_SUFFIX = 'partition_list'
    for line in lines:
      if line.startswith('#') or '=' not in line:
        output_list.append(line)
        continue
      key, value = line.strip().split('=', 1)
      if key == 'dynamic_partition_list' or key.endswith(LIST_SUFFIX):
        partitions = value.split()
        partitions = [partition for partition in partitions if partition
                      not in SECONDARY_PAYLOAD_SKIPPED_IMAGES]
        output_list.append('{}={}'.format(key, ' '.join(partitions)))
      elif key in ['virtual_ab', "virtual_ab_retrofit"]:
        # Remove virtual_ab flag from secondary payload so that OTA client
        # don't use snapshots for secondary update
        pass
      else:
        output_list.append(line)
    return '\n'.join(output_list)

  target_file = common.MakeTempFile(prefix="targetfiles-", suffix=".zip")
  target_zip = zipfile.ZipFile(target_file, 'w', allowZip64=True)

  with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
    infolist = input_zip.infolist()

  input_tmp = common.UnzipTemp(input_file, UNZIP_PATTERN)
  for info in infolist:
    unzipped_file = os.path.join(input_tmp, *info.filename.split('/'))
    if info.filename == 'IMAGES/system_other.img':
      common.ZipWrite(target_zip, unzipped_file, arcname='IMAGES/system.img')

    # Primary images and friends need to be skipped explicitly.
    elif info.filename in ('IMAGES/system.img',
                           'IMAGES/system.map'):
      pass

    # Copy images that are not in SECONDARY_PAYLOAD_SKIPPED_IMAGES.
    elif info.filename.startswith(('IMAGES/', 'RADIO/')):
      image_name = os.path.basename(info.filename)
      if image_name not in ['{}.img'.format(partition) for partition in
                            SECONDARY_PAYLOAD_SKIPPED_IMAGES]:
        common.ZipWrite(target_zip, unzipped_file, arcname=info.filename)

    # Skip copying the postinstall config if requested.
    elif skip_postinstall and info.filename == POSTINSTALL_CONFIG:
      pass

    elif info.filename.startswith('META/'):
      # Remove the unnecessary partitions for secondary images from the
      # ab_partitions file.
      if info.filename == AB_PARTITIONS:
        with open(unzipped_file) as f:
          partition_list = f.read().splitlines()
        partition_list = [partition for partition in partition_list if partition
                          and partition not in SECONDARY_PAYLOAD_SKIPPED_IMAGES]
        common.ZipWriteStr(target_zip, info.filename,
                           '\n'.join(partition_list))
      # Remove the unnecessary partitions from the dynamic partitions list.
      elif (info.filename == 'META/misc_info.txt' or
            info.filename == DYNAMIC_PARTITION_INFO):
        modified_info = GetInfoForSecondaryImages(unzipped_file)
        common.ZipWriteStr(target_zip, info.filename, modified_info)
      else:
        common.ZipWrite(target_zip, unzipped_file, arcname=info.filename)

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
  # We should only make a copy if postinstall_config entry exists.
  with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
    if POSTINSTALL_CONFIG not in input_zip.namelist():
      return input_file

  target_file = common.MakeTempFile(prefix="targetfiles-", suffix=".zip")
  shutil.copyfile(input_file, target_file)
  common.ZipDelete(target_file, POSTINSTALL_CONFIG)
  return target_file


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

  target_file = common.MakeTempFile(prefix="targetfiles-", suffix=".zip")
  shutil.copyfile(input_file, target_file)

  with zipfile.ZipFile(input_file, allowZip64=True) as input_zip:
    namelist = input_zip.namelist()

  input_tmp = common.UnzipTemp(input_file, RETROFIT_DAP_UNZIP_PATTERN)

  # Remove partitions from META/ab_partitions.txt that is in
  # dynamic_partition_list but not in super_block_devices so that
  # brillo_update_payload won't generate update for those logical partitions.
  ab_partitions_file = os.path.join(input_tmp, *AB_PARTITIONS.split('/'))
  with open(ab_partitions_file) as f:
    ab_partitions_lines = f.readlines()
    ab_partitions = [line.strip() for line in ab_partitions_lines]
  # Assert that all super_block_devices are in ab_partitions
  super_device_not_updated = [partition for partition in super_block_devices
                              if partition not in ab_partitions]
  assert not super_device_not_updated, \
      "{} is in super_block_devices but not in {}".format(
          super_device_not_updated, AB_PARTITIONS)
  # ab_partitions -= (dynamic_partition_list - super_block_devices)
  new_ab_partitions = common.MakeTempFile(
      prefix="ab_partitions", suffix=".txt")
  with open(new_ab_partitions, 'w') as f:
    for partition in ab_partitions:
      if (partition in dynamic_partition_list and
              partition not in super_block_devices):
        logger.info("Dropping %s from ab_partitions.txt", partition)
        continue
      f.write(partition + "\n")
  to_delete = [AB_PARTITIONS]

  # Always skip postinstall for a retrofit update.
  to_delete += [POSTINSTALL_CONFIG]

  # Delete dynamic_partitions_info.txt so that brillo_update_payload thinks this
  # is a regular update on devices without dynamic partitions support.
  to_delete += [DYNAMIC_PARTITION_INFO]

  # Remove the existing partition images as well as the map files.
  to_delete += list(replace.values())
  to_delete += ['IMAGES/{}.map'.format(dev) for dev in super_block_devices]

  common.ZipDelete(target_file, to_delete)

  target_zip = zipfile.ZipFile(target_file, 'a', allowZip64=True)

  # Write super_{foo}.img as {foo}.img.
  for src, dst in replace.items():
    assert src in namelist, \
        'Missing {} in {}; {} cannot be written'.format(src, input_file, dst)
    unzipped_file = os.path.join(input_tmp, *src.split('/'))
    common.ZipWrite(target_zip, unzipped_file, arcname=dst)

  # Write new ab_partitions.txt file
  common.ZipWrite(target_zip, new_ab_partitions, arcname=AB_PARTITIONS)

  common.ZipClose(target_zip)

  return target_file


def GenerateAbOtaPackage(target_file, output_file, source_file=None):
  """Generates an Android OTA package that has A/B update payload."""
  # Stage the output zip package for package signing.
  if not OPTIONS.no_signing:
    staging_file = common.MakeTempFile(suffix='.zip')
  else:
    staging_file = output_file
  output_zip = zipfile.ZipFile(staging_file, "w",
                               compression=zipfile.ZIP_DEFLATED, allowZip64=True)

  if source_file is not None:
    assert "ab_partitions" in OPTIONS.source_info_dict, \
        "META/ab_partitions.txt is required for ab_update."
    assert "ab_partitions" in OPTIONS.target_info_dict, \
        "META/ab_partitions.txt is required for ab_update."
    target_info = common.BuildInfo(OPTIONS.target_info_dict, OPTIONS.oem_dicts)
    source_info = common.BuildInfo(OPTIONS.source_info_dict, OPTIONS.oem_dicts)
  else:
    assert "ab_partitions" in OPTIONS.info_dict, \
        "META/ab_partitions.txt is required for ab_update."
    target_info = common.BuildInfo(OPTIONS.info_dict, OPTIONS.oem_dicts)
    source_info = None

  if OPTIONS.retrofit_dynamic_partitions:
    target_file = GetTargetFilesZipForRetrofitDynamicPartitions(
        target_file, target_info.get("super_block_devices").strip().split(),
        target_info.get("dynamic_partition_list").strip().split())
  elif OPTIONS.skip_postinstall:
    target_file = GetTargetFilesZipWithoutPostinstallConfig(target_file)
  # Target_file may have been modified, reparse ab_partitions
  with zipfile.ZipFile(target_file, allowZip64=True) as zfp:
    target_info.info_dict['ab_partitions'] = zfp.read(
        AB_PARTITIONS).strip().split("\n")

  # Metadata to comply with Android OTA package format.
  metadata = GetPackageMetadata(target_info, source_info)
  # Generate payload.
  payload = Payload()

  partition_timestamps = []
  # Enforce a max timestamp this payload can be applied on top of.
  if OPTIONS.downgrade:
    max_timestamp = source_info.GetBuildProp("ro.build.date.utc")
  else:
    max_timestamp = str(metadata.postcondition.timestamp)
    partition_timestamps = [
        part.partition_name + ":" + part.version
        for part in metadata.postcondition.partition_state]
  additional_args = ["--max_timestamp", max_timestamp]
  if partition_timestamps:
    additional_args.extend(
        ["--partition_timestamps", ",".join(
            partition_timestamps)]
    )

  payload.Generate(target_file, source_file, additional_args)

  # Sign the payload.
  payload_signer = PayloadSigner()
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
    secondary_payload = Payload(secondary=True)
    secondary_payload.Generate(secondary_target_file,
                               additional_args=additional_args)
    secondary_payload.Sign(payload_signer)
    secondary_payload.WriteToZip(output_zip)

  # If dm-verity is supported for the device, copy contents of care_map
  # into A/B OTA package.
  target_zip = zipfile.ZipFile(target_file, "r", allowZip64=True)
  if (target_info.get("verity") == "true" or
          target_info.get("avb_enable") == "true"):
    care_map_list = [x for x in ["care_map.pb", "care_map.txt"] if
                     "META/" + x in target_zip.namelist()]

    # Adds care_map if either the protobuf format or the plain text one exists.
    if care_map_list:
      care_map_name = care_map_list[0]
      care_map_data = target_zip.read("META/" + care_map_name)
      # In order to support streaming, care_map needs to be packed as
      # ZIP_STORED.
      common.ZipWriteStr(output_zip, care_map_name, care_map_data,
                         compress_type=zipfile.ZIP_STORED)
    else:
      logger.warning("Cannot find care map file in target_file package")

  common.ZipClose(target_zip)

  CheckVintfIfTrebleEnabled(target_file, target_info)

  # We haven't written the metadata entry yet, which will be handled in
  # FinalizeMetadata().
  common.ZipClose(output_zip)

  # AbOtaPropertyFiles intends to replace StreamingPropertyFiles, as it covers
  # all the info of the latter. However, system updaters and OTA servers need to
  # take time to switch to the new flag. We keep both of the flags for
  # P-timeframe, and will remove StreamingPropertyFiles in later release.
  needed_property_files = (
      AbOtaPropertyFiles(),
      StreamingPropertyFiles(),
  )
  FinalizeMetadata(metadata, staging_file, output_file, needed_property_files)


def main(argv):

  def option_handler(o, a):
    if o in ("-k", "--package_key"):
      OPTIONS.package_key = a
    elif o in ("-i", "--incremental_from"):
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
    elif o == "--payload_signer":
      OPTIONS.payload_signer = a
    elif o == "--payload_signer_args":
      OPTIONS.payload_signer_args = shlex.split(a)
    elif o == "--payload_signer_maximum_signature_size":
      OPTIONS.payload_signer_maximum_signature_size = a
    elif o == "--payload_signer_key_size":
      # TODO(Xunchang) remove this option after cleaning up the callers.
      logger.warning("The option '--payload_signer_key_size' is deprecated."
                     " Use '--payload_signer_maximum_signature_size' instead.")
      OPTIONS.payload_signer_maximum_signature_size = a
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
    elif o == "--force_non_ab":
      OPTIONS.force_non_ab = True
    elif o == "--boot_variable_file":
      OPTIONS.boot_variable_file = a
    else:
      return False
    return True

  args = common.ParseOptions(argv, __doc__,
                             extra_opts="b:k:i:d:e:t:2o:",
                             extra_long_opts=[
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
                                 "include_secondary",
                                 "no_signing",
                                 "block",
                                 "binary=",
                                 "oem_settings=",
                                 "oem_no_mount",
                                 "verify",
                                 "stash_threshold=",
                                 "log_diff=",
                                 "payload_signer=",
                                 "payload_signer_args=",
                                 "payload_signer_maximum_signature_size=",
                                 "payload_signer_key_size=",
                                 "extracted_input_target_files=",
                                 "skip_postinstall",
                                 "retrofit_dynamic_partitions",
                                 "skip_compatibility_check",
                                 "output_metadata_path=",
                                 "disable_fec_computation",
                                 "force_non_ab",
                                 "boot_variable_file=",
                             ], extra_option_handler=option_handler)

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  if OPTIONS.downgrade:
    # We should only allow downgrading incrementals (as opposed to full).
    # Otherwise the device may go back from arbitrary build with this full
    # OTA package.
    if OPTIONS.incremental_source is None:
      raise ValueError("Cannot generate downgradable full OTAs")

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
    with zipfile.ZipFile(args[0], 'r', allowZip64=True) as input_zip:
      OPTIONS.info_dict = common.LoadInfoDict(input_zip)

  logger.info("--- target info ---")
  common.DumpInfoDict(OPTIONS.info_dict)

  # Load the source build dict if applicable.
  if OPTIONS.incremental_source is not None:
    OPTIONS.target_info_dict = OPTIONS.info_dict
    with zipfile.ZipFile(OPTIONS.incremental_source, 'r', allowZip64=True) as source_zip:
      OPTIONS.source_info_dict = common.LoadInfoDict(source_zip)

    logger.info("--- source info ---")
    common.DumpInfoDict(OPTIONS.source_info_dict)

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
    assert allow_non_ab, "--force_non_ab only allowed on devices that supports non-A/B"
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
  except common.ExternalError:
    logger.exception("\n   ERROR:\n")
    sys.exit(1)
  finally:
    common.Cleanup()
