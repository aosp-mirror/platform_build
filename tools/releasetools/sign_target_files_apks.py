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
Signs all the APK files in a target-files zipfile, producing a new
target-files zip.

Usage:  sign_target_files_apks [flags] input_target_files output_target_files

  -e  (--extra_apks)  <name,name,...=key>
      Add extra APK/APEX name/key pairs as though they appeared in apkcerts.txt
      or apexkeys.txt (so mappings specified by -k and -d are applied). Keys
      specified in -e override any value for that app contained in the
      apkcerts.txt file, or the container key for an APEX. Option may be
      repeated to give multiple extra packages.

  --extra_apex_payload_key <name,name,...=key>
      Add a mapping for APEX package name to payload signing key, which will
      override the default payload signing key in apexkeys.txt. Note that the
      container key should be overridden via the `--extra_apks` flag above.
      Option may be repeated for multiple APEXes.

  --skip_apks_with_path_prefix  <prefix>
      Skip signing an APK if it has the matching prefix in its path. The prefix
      should be matching the entry name, which has partition names in upper
      case, e.g. "VENDOR/app/", or "SYSTEM_OTHER/preloads/". Option may be
      repeated to give multiple prefixes.

  -k  (--key_mapping)  <src_key=dest_key>
      Add a mapping from the key name as specified in apkcerts.txt (the
      src_key) to the real key you wish to sign the package with
      (dest_key).  Option may be repeated to give multiple key
      mappings.

  -d  (--default_key_mappings)  <dir>
      Set up the following key mappings:

        $devkey/devkey    ==>  $dir/releasekey
        $devkey/testkey   ==>  $dir/releasekey
        $devkey/media     ==>  $dir/media
        $devkey/shared    ==>  $dir/shared
        $devkey/platform  ==>  $dir/platform

      where $devkey is the directory part of the value of
      default_system_dev_certificate from the input target-files's
      META/misc_info.txt.  (Defaulting to "build/make/target/product/security"
      if the value is not present in misc_info.

      -d and -k options are added to the set of mappings in the order
      in which they appear on the command line.

  -o  (--replace_ota_keys)
      Replace the certificate (public key) used by OTA package verification
      with the ones specified in the input target_files zip (in the
      META/otakeys.txt file). Key remapping (-k and -d) is performed on the
      keys. For A/B devices, the payload verification key will be replaced
      as well. If there're multiple OTA keys, only the first one will be used
      for payload verification.

  -t  (--tag_changes)  <+tag>,<-tag>,...
      Comma-separated list of changes to make to the set of tags (in
      the last component of the build fingerprint).  Prefix each with
      '+' or '-' to indicate whether that tag should be added or
      removed.  Changes are processed in the order they appear.
      Default value is "-test-keys,-dev-keys,+release-keys".

  --replace_verity_private_key <key>
      Replace the private key used for verity signing. It expects a filename
      WITHOUT the extension (e.g. verity_key).

  --replace_verity_public_key <key>
      Replace the certificate (public key) used for verity verification. The
      key file replaces the one at BOOT/RAMDISK/verity_key. It expects the key
      filename WITH the extension (e.g. verity_key.pub).

  --replace_verity_keyid <path_to_X509_PEM_cert_file>
      Replace the veritykeyid in BOOT/cmdline of input_target_file_zip
      with keyid of the cert pointed by <path_to_X509_PEM_cert_file>.

  --remove_avb_public_keys <key1>,<key2>,...
      Remove AVB public keys from the first-stage ramdisk. The key file to
      remove is located at either of the following dirs:
        - BOOT/RAMDISK/avb/ or
        - BOOT/RAMDISK/first_stage_ramdisk/avb/
      The second dir will be used for lookup if BOARD_USES_RECOVERY_AS_BOOT is
      set to true.

  --avb_{boot,init_boot,recovery,system,system_other,vendor,dtbo,vbmeta,
         vbmeta_system,vbmeta_vendor}_algorithm <algorithm>
  --avb_{boot,init_boot,recovery,system,system_other,vendor,dtbo,vbmeta,
         vbmeta_system,vbmeta_vendor}_key <key>
      Use the specified algorithm (e.g. SHA256_RSA4096) and the key to AVB-sign
      the specified image. Otherwise it uses the existing values in info dict.

  --avb_{apex,init_boot,boot,recovery,system,system_other,vendor,dtbo,vbmeta,
         vbmeta_system,vbmeta_vendor}_extra_args <args>
      Specify any additional args that are needed to AVB-sign the image
      (e.g. "--signing_helper /path/to/helper"). The args will be appended to
      the existing ones in info dict.

  --avb_extra_custom_image_key <partition=key>
  --avb_extra_custom_image_algorithm <partition=algorithm>
      Use the specified algorithm (e.g. SHA256_RSA4096) and the key to AVB-sign
      the specified custom images mounted on the partition. Otherwise it uses
      the existing values in info dict.

  --avb_extra_custom_image_extra_args <partition=extra_args>
      Specify any additional args that are needed to AVB-sign the custom images
      mounted on the partition (e.g. "--signing_helper /path/to/helper"). The
      args will be appended to the existing ones in info dict.

  --gki_signing_algorithm <algorithm>
  --gki_signing_key <key>
  --gki_signing_extra_args <args>
      DEPRECATED Does nothing.

  --android_jar_path <path>
      Path to the android.jar to repack the apex file.

  --allow_gsi_debug_sepolicy
      Allow the existence of the file 'userdebug_plat_sepolicy.cil' under
      (/system/system_ext|/system_ext)/etc/selinux.
      If not set, error out when the file exists.

  --override_apk_keys <path>
      Replace all APK keys with this private key

  --override_apex_keys <path>
      Replace all APEX keys with this private key

  -k  (--package_key) <key>
      Key to use to sign the package (default is the value of
      default_system_dev_certificate from the input target-files's
      META/misc_info.txt, or "build/make/target/product/security/testkey" if
      that value is not specified).

      For incremental OTAs, the default value is based on the source
      target-file, not the target build.

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
"""

from __future__ import print_function

import base64
import copy
import errno
import gzip
import io
import itertools
import logging
import os
import re
import shutil
import stat
import sys
import shlex
import tempfile
import zipfile
from xml.etree import ElementTree

import add_img_to_target_files
import ota_from_raw_img
import apex_utils
import common
import payload_signer
import update_payload
from payload_signer import SignOtaPackage, PAYLOAD_BIN


if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)


logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS

OPTIONS.extra_apks = {}
OPTIONS.extra_apex_payload_keys = {}
OPTIONS.skip_apks_with_path_prefix = set()
OPTIONS.key_map = {}
OPTIONS.rebuild_recovery = False
OPTIONS.replace_ota_keys = False
OPTIONS.remove_avb_public_keys = None
OPTIONS.tag_changes = ("-test-keys", "-dev-keys", "+release-keys")
OPTIONS.avb_keys = {}
OPTIONS.avb_algorithms = {}
OPTIONS.avb_extra_args = {}
OPTIONS.android_jar_path = None
OPTIONS.vendor_partitions = set()
OPTIONS.vendor_otatools = None
OPTIONS.allow_gsi_debug_sepolicy = False
OPTIONS.override_apk_keys = None
OPTIONS.override_apex_keys = None
OPTIONS.input_tmp = None


AVB_FOOTER_ARGS_BY_PARTITION = {
    'boot': 'avb_boot_add_hash_footer_args',
    'init_boot': 'avb_init_boot_add_hash_footer_args',
    'dtbo': 'avb_dtbo_add_hash_footer_args',
    'product': 'avb_product_add_hashtree_footer_args',
    'recovery': 'avb_recovery_add_hash_footer_args',
    'system': 'avb_system_add_hashtree_footer_args',
    'system_dlkm': "avb_system_dlkm_add_hashtree_footer_args",
    'system_ext': 'avb_system_ext_add_hashtree_footer_args',
    'system_other': 'avb_system_other_add_hashtree_footer_args',
    'odm': 'avb_odm_add_hashtree_footer_args',
    'odm_dlkm': 'avb_odm_dlkm_add_hashtree_footer_args',
    'pvmfw': 'avb_pvmfw_add_hash_footer_args',
    'vendor': 'avb_vendor_add_hashtree_footer_args',
    'vendor_boot': 'avb_vendor_boot_add_hash_footer_args',
    'vendor_kernel_boot': 'avb_vendor_kernel_boot_add_hash_footer_args',
    'vendor_dlkm': "avb_vendor_dlkm_add_hashtree_footer_args",
    'vbmeta': 'avb_vbmeta_args',
    'vbmeta_system': 'avb_vbmeta_system_args',
    'vbmeta_vendor': 'avb_vbmeta_vendor_args',
}


# Check that AVB_FOOTER_ARGS_BY_PARTITION is in sync with AVB_PARTITIONS.
for partition in common.AVB_PARTITIONS:
  if partition not in AVB_FOOTER_ARGS_BY_PARTITION:
    raise RuntimeError("Missing {} in AVB_FOOTER_ARGS".format(partition))

# Partitions that can be regenerated after signing using a separate
# vendor otatools package.
ALLOWED_VENDOR_PARTITIONS = set(["vendor", "odm"])


def IsApexFile(filename):
  return filename.endswith(".apex") or filename.endswith(".capex")


def IsOtaPackage(fp):
  with zipfile.ZipFile(fp) as zfp:
    if not PAYLOAD_BIN in zfp.namelist():
      return False
    with zfp.open(PAYLOAD_BIN, "r") as payload:
      magic = payload.read(4)
      return magic == b"CrAU"


def IsEntryOtaPackage(input_zip, filename):
  with input_zip.open(filename, "r") as fp:
    external_attr = input_zip.getinfo(filename).external_attr
    if stat.S_ISLNK(external_attr >> 16):
      return IsEntryOtaPackage(input_zip,
          os.path.join(os.path.dirname(filename), fp.read().decode()))
    return IsOtaPackage(fp)


def GetApexFilename(filename):
  name = os.path.basename(filename)
  # Replace the suffix for compressed apex
  if name.endswith(".capex"):
    return name.replace(".capex", ".apex")
  return name


def GetApkCerts(certmap):
  if OPTIONS.override_apk_keys is not None:
    for apk in certmap.keys():
      certmap[apk] = OPTIONS.override_apk_keys

  # apply the key remapping to the contents of the file
  for apk, cert in certmap.items():
    certmap[apk] = OPTIONS.key_map.get(cert, cert)

  # apply all the -e options, overriding anything in the file
  for apk, cert in OPTIONS.extra_apks.items():
    if not cert:
      cert = "PRESIGNED"
    certmap[apk] = OPTIONS.key_map.get(cert, cert)

  return certmap


def GetApexKeys(keys_info, key_map):
  """Gets APEX payload and container signing keys by applying the mapping rules.

  Presigned payload / container keys will be set accordingly.

  Args:
    keys_info: A dict that maps from APEX filenames to a tuple of (payload_key,
        container_key, sign_tool).
    key_map: A dict that overrides the keys, specified via command-line input.

  Returns:
    A dict that contains the updated APEX key mapping, which should be used for
    the current signing.

  Raises:
    AssertionError: On invalid container / payload key overrides.
  """
  if OPTIONS.override_apex_keys is not None:
    for apex in keys_info.keys():
      keys_info[apex] = (OPTIONS.override_apex_keys, keys_info[apex][1], keys_info[apex][2])

  if OPTIONS.override_apk_keys is not None:
    key = key_map.get(OPTIONS.override_apk_keys, OPTIONS.override_apk_keys)
    for apex in keys_info.keys():
      keys_info[apex] = (keys_info[apex][0], key, keys_info[apex][2])

  # Apply all the --extra_apex_payload_key options to override the payload
  # signing keys in the given keys_info.
  for apex, key in OPTIONS.extra_apex_payload_keys.items():
    if not key:
      key = 'PRESIGNED'
    if apex not in keys_info:
      logger.warning('Failed to find %s in target_files; Ignored', apex)
      continue
    keys_info[apex] = (key, keys_info[apex][1], keys_info[apex][2])

  # Apply the key remapping to container keys.
  for apex, (payload_key, container_key, sign_tool) in keys_info.items():
    keys_info[apex] = (payload_key, key_map.get(container_key, container_key), sign_tool)

  # Apply all the --extra_apks options to override the container keys.
  for apex, key in OPTIONS.extra_apks.items():
    # Skip non-APEX containers.
    if apex not in keys_info:
      continue
    if not key:
      key = 'PRESIGNED'
    keys_info[apex] = (keys_info[apex][0], key_map.get(key, key), keys_info[apex][2])

  # A PRESIGNED container entails a PRESIGNED payload. Apply this to all the
  # APEX key pairs. However, a PRESIGNED container with non-PRESIGNED payload
  # (overridden via commandline) indicates a config error, which should not be
  # allowed.
  for apex, (payload_key, container_key, sign_tool) in keys_info.items():
    if container_key != 'PRESIGNED':
      continue
    if apex in OPTIONS.extra_apex_payload_keys:
      payload_override = OPTIONS.extra_apex_payload_keys[apex]
      assert payload_override == '', \
          ("Invalid APEX key overrides: {} has PRESIGNED container but "
           "non-PRESIGNED payload key {}").format(apex, payload_override)
    if payload_key != 'PRESIGNED':
      print(
          "Setting {} payload as PRESIGNED due to PRESIGNED container".format(
              apex))
    keys_info[apex] = ('PRESIGNED', 'PRESIGNED', None)

  return keys_info


def GetApkFileInfo(filename, compressed_extension, skipped_prefixes):
  """Returns the APK info based on the given filename.

  Checks if the given filename (with path) looks like an APK file, by taking the
  compressed extension into consideration. If it appears to be an APK file,
  further checks if the APK file should be skipped when signing, based on the
  given path prefixes.

  Args:
    filename: Path to the file.
    compressed_extension: The extension string of compressed APKs (e.g. ".gz"),
        or None if there's no compressed APKs.
    skipped_prefixes: A set/list/tuple of the path prefixes to be skipped.

  Returns:
    (is_apk, is_compressed, should_be_skipped): is_apk indicates whether the
    given filename is an APK file. is_compressed indicates whether the APK file
    is compressed (only meaningful when is_apk is True). should_be_skipped
    indicates whether the filename matches any of the given prefixes to be
    skipped.

  Raises:
    AssertionError: On invalid compressed_extension or skipped_prefixes inputs.
  """
  assert compressed_extension is None or compressed_extension.startswith('.'), \
      "Invalid compressed_extension arg: '{}'".format(compressed_extension)

  # skipped_prefixes should be one of set/list/tuple types. Other types such as
  # str shouldn't be accepted.
  assert isinstance(skipped_prefixes, (set, list, tuple)), \
      "Invalid skipped_prefixes input type: {}".format(type(skipped_prefixes))

  compressed_apk_extension = (
      ".apk" + compressed_extension if compressed_extension else None)
  is_apk = (filename.endswith(".apk") or
            (compressed_apk_extension and
             filename.endswith(compressed_apk_extension)))
  if not is_apk:
    return (False, False, False)

  is_compressed = (compressed_apk_extension and
                   filename.endswith(compressed_apk_extension))
  should_be_skipped = filename.startswith(tuple(skipped_prefixes))
  return (True, is_compressed, should_be_skipped)


def CheckApkAndApexKeysAvailable(input_tf_zip, known_keys,
                                 compressed_extension, apex_keys):
  """Checks that all the APKs and APEXes have keys specified.

  Args:
    input_tf_zip: An open target_files zip file.
    known_keys: A set of APKs and APEXes that have known signing keys.
    compressed_extension: The extension string of compressed APKs, such as
        '.gz', or None if there's no compressed APKs.
    apex_keys: A dict that contains the key mapping from APEX name to
        (payload_key, container_key, sign_tool).

  Raises:
    AssertionError: On finding unknown APKs and APEXes.
  """
  unknown_files = []
  for info in input_tf_zip.infolist():
    # Handle APEXes on all partitions
    if IsApexFile(info.filename):
      name = GetApexFilename(info.filename)
      if name not in known_keys:
        unknown_files.append(name)
      continue

    # And APKs.
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        info.filename, compressed_extension, OPTIONS.skip_apks_with_path_prefix)
    if not is_apk or should_be_skipped:
      continue

    name = os.path.basename(info.filename)
    if is_compressed:
      name = name[:-len(compressed_extension)]
    if name not in known_keys:
      unknown_files.append(name)

  assert not unknown_files, \
      ("No key specified for:\n  {}\n"
       "Use '-e <apkname>=' to specify a key (which may be an empty string to "
       "not sign this apk).".format("\n  ".join(unknown_files)))

  # For all the APEXes, double check that we won't have an APEX that has only
  # one of the payload / container keys set. Note that non-PRESIGNED container
  # with PRESIGNED payload could be allowed but currently unsupported. It would
  # require changing SignApex implementation.
  if not apex_keys:
    return

  invalid_apexes = []
  for info in input_tf_zip.infolist():
    if not IsApexFile(info.filename):
      continue

    name = GetApexFilename(info.filename)

    (payload_key, container_key, _) = apex_keys[name]
    if ((payload_key in common.SPECIAL_CERT_STRINGS and
         container_key not in common.SPECIAL_CERT_STRINGS) or
        (payload_key not in common.SPECIAL_CERT_STRINGS and
         container_key in common.SPECIAL_CERT_STRINGS)):
      invalid_apexes.append(
          "{}: payload_key {}, container_key {}".format(
              name, payload_key, container_key))

  assert not invalid_apexes, \
      "Invalid APEX keys specified:\n  {}\n".format(
          "\n  ".join(invalid_apexes))


def SignApk(data, keyname, pw, platform_api_level, codename_to_api_level_map,
            is_compressed, apk_name):
  unsigned = tempfile.NamedTemporaryFile(suffix='_' + apk_name)
  unsigned.write(data)
  unsigned.flush()

  if is_compressed:
    uncompressed = tempfile.NamedTemporaryFile()
    with gzip.open(unsigned.name, "rb") as in_file, \
            open(uncompressed.name, "wb") as out_file:
      shutil.copyfileobj(in_file, out_file)

    # Finally, close the "unsigned" file (which is gzip compressed), and then
    # replace it with the uncompressed version.
    #
    # TODO(narayan): All this nastiness can be avoided if python 3.2 is in use,
    # we could just gzip / gunzip in-memory buffers instead.
    unsigned.close()
    unsigned = uncompressed

  signed = tempfile.NamedTemporaryFile(suffix='_' + apk_name)

  # For pre-N builds, don't upgrade to SHA-256 JAR signatures based on the APK's
  # minSdkVersion to avoid increasing incremental OTA update sizes. If an APK
  # didn't change, we don't want its signature to change due to the switch
  # from SHA-1 to SHA-256.
  # By default, APK signer chooses SHA-256 signatures if the APK's minSdkVersion
  # is 18 or higher. For pre-N builds we disable this mechanism by pretending
  # that the APK's minSdkVersion is 1.
  # For N+ builds, we let APK signer rely on the APK's minSdkVersion to
  # determine whether to use SHA-256.
  min_api_level = None
  if platform_api_level > 23:
    # Let APK signer choose whether to use SHA-1 or SHA-256, based on the APK's
    # minSdkVersion attribute
    min_api_level = None
  else:
    # Force APK signer to use SHA-1
    min_api_level = 1

  common.SignFile(unsigned.name, signed.name, keyname, pw,
                  min_api_level=min_api_level,
                  codename_to_api_level_map=codename_to_api_level_map)

  data = None
  if is_compressed:
    # Recompress the file after it has been signed.
    compressed = tempfile.NamedTemporaryFile()
    with open(signed.name, "rb") as in_file, \
            gzip.open(compressed.name, "wb") as out_file:
      shutil.copyfileobj(in_file, out_file)

    data = compressed.read()
    compressed.close()
  else:
    data = signed.read()

  unsigned.close()
  signed.close()

  return data



def IsBuildPropFile(filename):
  return filename in (
      "SYSTEM/etc/prop.default",
      "BOOT/RAMDISK/prop.default",
      "RECOVERY/RAMDISK/prop.default",

      "VENDOR_BOOT/RAMDISK/default.prop",
      "VENDOR_BOOT/RAMDISK/prop.default",

      # ROOT/default.prop is a legacy path, but may still exist for upgrading
      # devices that don't support `property_overrides_split_enabled`.
      "ROOT/default.prop",

      # RECOVERY/RAMDISK/default.prop is a legacy path, but will always exist
      # as a symlink in the current code. So it's a no-op here. Keeping the
      # path here for clarity.
      # Some build props might be stored under path
      # VENDOR_BOOT/RAMDISK_FRAGMENTS/recovery/RAMDISK/default.prop, and
      # default.prop can be a symbolic link to prop.default, so overwrite all
      # files that ends with build.prop, default.prop or prop.default
      "RECOVERY/RAMDISK/default.prop") or \
        filename.endswith("build.prop") or \
        filename.endswith("/default.prop") or \
        filename.endswith("/prop.default")


def GetOtaSigningArgs():
  args = []
  if OPTIONS.package_key:
    args.extend(["--package_key", OPTIONS.package_key])
  if OPTIONS.payload_signer:
    args.extend(["--payload_signer=" + OPTIONS.payload_signer])
  if OPTIONS.payload_signer_args:
    args.extend(["--payload_signer_args=" + shlex.join(OPTIONS.payload_signer_args)])
  if OPTIONS.search_path:
    args.extend(["--search_path", OPTIONS.search_path])
  if OPTIONS.payload_signer_maximum_signature_size:
    args.extend(["--payload_signer_maximum_signature_size",
                OPTIONS.payload_signer_maximum_signature_size])
  if OPTIONS.private_key_suffix:
    args.extend(["--private_key_suffix", OPTIONS.private_key_suffix])
  return args


def RegenerateKernelPartitions(input_tf_zip: zipfile.ZipFile, output_tf_zip: zipfile.ZipFile, misc_info):
  """Re-generate boot and dtbo partitions using new signing configuration"""
  files_to_unzip = [
      "PREBUILT_IMAGES/*", "BOOTABLE_IMAGES/*.img", "*/boot_16k.img", "*/dtbo_16k.img"]
  if OPTIONS.input_tmp is None:
    OPTIONS.input_tmp = common.UnzipTemp(input_tf_zip.filename, files_to_unzip)
  else:
    common.UnzipToDir(input_tf_zip.filename, OPTIONS.input_tmp, files_to_unzip)
  unzip_dir = OPTIONS.input_tmp
  os.makedirs(os.path.join(unzip_dir, "IMAGES"), exist_ok=True)

  boot_image = common.GetBootableImage(
      "IMAGES/boot.img", "boot.img", unzip_dir, "BOOT", misc_info)
  if boot_image:
    boot_image.WriteToDir(unzip_dir)
    boot_image = os.path.join(unzip_dir, boot_image.name)
    common.ZipWrite(output_tf_zip, boot_image, "IMAGES/boot.img",
                    compress_type=zipfile.ZIP_STORED)
  if misc_info.get("has_dtbo") == "true":
    add_img_to_target_files.AddDtbo(output_tf_zip)
  return unzip_dir


def RegenerateBootOTA(input_tf_zip: zipfile.ZipFile, filename, input_ota):
  with input_tf_zip.open(filename, "r") as in_fp:
    payload = update_payload.Payload(in_fp)
  is_incremental = any([part.HasField('old_partition_info')
                        for part in payload.manifest.partitions])
  is_boot_ota = filename.startswith(
      "VENDOR/boot_otas/") or filename.startswith("SYSTEM/boot_otas/")
  if not is_boot_ota:
    return
  is_4k_boot_ota = filename in [
      "VENDOR/boot_otas/boot_ota_4k.zip", "SYSTEM/boot_otas/boot_ota_4k.zip"]
  # Only 4K boot image is re-generated, so if 16K boot ota isn't incremental,
  # we do not need to re-generate
  if not is_4k_boot_ota and not is_incremental:
    return

  timestamp = str(payload.manifest.max_timestamp)
  partitions = [part.partition_name for part in payload.manifest.partitions]
  unzip_dir = OPTIONS.input_tmp
  signed_boot_image = os.path.join(unzip_dir, "IMAGES", "boot.img")
  if not os.path.exists(signed_boot_image):
    logger.warn("Need to re-generate boot OTA {} but failed to get signed boot image. 16K dev option will be impacted, after rolling back to 4K user would need to sideload/flash their device to continue receiving OTAs.")
    return
  signed_dtbo_image = os.path.join(unzip_dir, "IMAGES", "dtbo.img")
  if "dtbo" in partitions and not os.path.exists(signed_dtbo_image):
    raise ValueError(
        "Boot OTA {} has dtbo partition, but no dtbo image found in target files.".format(filename))
  if is_incremental:
    signed_16k_boot_image = os.path.join(
        unzip_dir, "IMAGES", "boot_16k.img")
    signed_16k_dtbo_image = os.path.join(
        unzip_dir, "IMAGES", "dtbo_16k.img")
    if is_4k_boot_ota:
      if os.path.exists(signed_16k_boot_image):
        signed_boot_image = signed_16k_boot_image + ":" + signed_boot_image
      if os.path.exists(signed_16k_dtbo_image):
        signed_dtbo_image = signed_16k_dtbo_image + ":" + signed_dtbo_image
    else:
      if os.path.exists(signed_16k_boot_image):
        signed_boot_image += ":" + signed_16k_boot_image
      if os.path.exists(signed_16k_dtbo_image):
        signed_dtbo_image += ":" + signed_16k_dtbo_image

  args = ["ota_from_raw_img",
          "--max_timestamp", timestamp, "--output", input_ota.name]
  args.extend(GetOtaSigningArgs())
  if "dtbo" in partitions:
    args.extend(["--partition_name", "boot,dtbo",
                signed_boot_image, signed_dtbo_image])
  else:
    args.extend(["--partition_name", "boot", signed_boot_image])
  logger.info(
      "Re-generating boot OTA {} using cmd {}".format(filename, args))
  ota_from_raw_img.main(args)


def ProcessTargetFiles(input_tf_zip: zipfile.ZipFile, output_tf_zip: zipfile.ZipFile, misc_info,
                       apk_keys, apex_keys, key_passwords,
                       platform_api_level, codename_to_api_level_map,
                       compressed_extension):
  # maxsize measures the maximum filename length, including the ones to be
  # skipped.
  try:
    maxsize = max(
        [len(os.path.basename(i.filename)) for i in input_tf_zip.infolist()
         if GetApkFileInfo(i.filename, compressed_extension, [])[0]])
  except ValueError:
    # Sets this to zero for targets without APK files.
    maxsize = 0

  # Replace the AVB signing keys, if any.
  ReplaceAvbSigningKeys(misc_info)
  OPTIONS.info_dict = misc_info

  # Rewrite the props in AVB signing args.
  if misc_info.get('avb_enable') == 'true':
    RewriteAvbProps(misc_info)

  RegenerateKernelPartitions(input_tf_zip, output_tf_zip, misc_info)

  for info in input_tf_zip.infolist():
    filename = info.filename
    if filename.startswith("IMAGES/"):
      continue

    # Skip OTA-specific images (e.g. split super images), which will be
    # re-generated during signing.
    if filename.startswith("OTA/") and filename.endswith(".img"):
      continue

    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        filename, compressed_extension, OPTIONS.skip_apks_with_path_prefix)
    data = input_tf_zip.read(filename)
    out_info = copy.copy(info)

    if is_apk and should_be_skipped:
      # Copy skipped APKs verbatim.
      print(
          "NOT signing: %s\n"
          "        (skipped due to matching prefix)" % (filename,))
      common.ZipWriteStr(output_tf_zip, out_info, data)

    # Sign APKs.
    elif is_apk:
      name = os.path.basename(filename)
      if is_compressed:
        name = name[:-len(compressed_extension)]

      key = apk_keys[name]
      if key not in common.SPECIAL_CERT_STRINGS:
        print("    signing: %-*s (%s)" % (maxsize, name, key))
        signed_data = SignApk(data, key, key_passwords[key], platform_api_level,
                              codename_to_api_level_map, is_compressed, name)
        common.ZipWriteStr(output_tf_zip, out_info, signed_data)
      else:
        # an APK we're not supposed to sign.
        print(
            "NOT signing: %s\n"
            "        (skipped due to special cert string)" % (name,))
        common.ZipWriteStr(output_tf_zip, out_info, data)

    # Sign bundled APEX files on all partitions
    elif IsApexFile(filename):
      name = GetApexFilename(filename)

      payload_key, container_key, sign_tool = apex_keys[name]

      # We've asserted not having a case with only one of them PRESIGNED.
      if (payload_key not in common.SPECIAL_CERT_STRINGS and
              container_key not in common.SPECIAL_CERT_STRINGS):
        print("    signing: %-*s container (%s)" % (
            maxsize, name, container_key))
        print("           : %-*s payload   (%s)" % (
            maxsize, name, payload_key))

        signed_apex = apex_utils.SignApex(
            misc_info['avb_avbtool'],
            data,
            payload_key,
            container_key,
            key_passwords,
            apk_keys,
            codename_to_api_level_map,
            no_hashtree=None,  # Let apex_util determine if hash tree is needed
            signing_args=OPTIONS.avb_extra_args.get('apex'),
            sign_tool=sign_tool)
        common.ZipWrite(output_tf_zip, signed_apex, filename)

      else:
        print(
            "NOT signing: %s\n"
            "        (skipped due to special cert string)" % (name,))
        common.ZipWriteStr(output_tf_zip, out_info, data)

    elif filename.endswith(".zip") and IsEntryOtaPackage(input_tf_zip, filename):
      logger.info("Re-signing OTA package {}".format(filename))
      with tempfile.NamedTemporaryFile() as input_ota, tempfile.NamedTemporaryFile() as output_ota:
        RegenerateBootOTA(input_tf_zip, filename, input_ota)

        SignOtaPackage(input_ota.name, output_ota.name)
        common.ZipWrite(output_tf_zip, output_ota.name, filename,
                        compress_type=zipfile.ZIP_STORED)
    # System properties.
    elif IsBuildPropFile(filename):
      print("Rewriting %s:" % (filename,))
      if stat.S_ISLNK(info.external_attr >> 16):
        new_data = data
      else:
        new_data = RewriteProps(data.decode())
      common.ZipWriteStr(output_tf_zip, out_info, new_data)

    # Replace the certs in *mac_permissions.xml (there could be multiple, such
    # as {system,vendor}/etc/selinux/{plat,vendor}_mac_permissions.xml).
    elif filename.endswith("mac_permissions.xml"):
      print("Rewriting %s with new keys." % (filename,))
      new_data = ReplaceCerts(data.decode())
      common.ZipWriteStr(output_tf_zip, out_info, new_data)

    # Ask add_img_to_target_files to rebuild the recovery patch if needed.
    elif filename in ("SYSTEM/recovery-from-boot.p",
                      "VENDOR/recovery-from-boot.p",

                      "SYSTEM/etc/recovery.img",
                      "VENDOR/etc/recovery.img",

                      "SYSTEM/bin/install-recovery.sh",
                      "VENDOR/bin/install-recovery.sh"):
      OPTIONS.rebuild_recovery = True

    # Don't copy OTA certs if we're replacing them.
    # Replacement of update-payload-key.pub.pem was removed in b/116660991.
    elif OPTIONS.replace_ota_keys and filename.endswith("/otacerts.zip"):
      pass

    # Skip META/misc_info.txt since we will write back the new values later.
    elif filename == "META/misc_info.txt":
      pass

    elif (OPTIONS.remove_avb_public_keys and
          (filename.startswith("BOOT/RAMDISK/avb/") or
           filename.startswith("BOOT/RAMDISK/first_stage_ramdisk/avb/"))):
      matched_removal = False
      for key_to_remove in OPTIONS.remove_avb_public_keys:
        if filename.endswith(key_to_remove):
          matched_removal = True
          print("Removing AVB public key from ramdisk: %s" % filename)
          break
      if not matched_removal:
        # Copy it verbatim if we don't want to remove it.
        common.ZipWriteStr(output_tf_zip, out_info, data)

    # Skip the vbmeta digest as we will recalculate it.
    elif filename == "META/vbmeta_digest.txt":
      pass

    # Skip the care_map as we will regenerate the system/vendor images.
    elif filename in ["META/care_map.pb", "META/care_map.txt"]:
      pass

    # Skip apex_info.pb because we sign/modify apexes
    elif filename == "META/apex_info.pb":
      pass

    # Updates system_other.avbpubkey in /product/etc/.
    elif filename in (
        "PRODUCT/etc/security/avb/system_other.avbpubkey",
        "SYSTEM/product/etc/security/avb/system_other.avbpubkey"):
      # Only update system_other's public key, if the corresponding signing
      # key is specified via --avb_system_other_key.
      signing_key = OPTIONS.avb_keys.get("system_other")
      if signing_key:
        public_key = common.ExtractAvbPublicKey(
            misc_info['avb_avbtool'], signing_key)
        print("    Rewriting AVB public key of system_other in /product")
        common.ZipWrite(output_tf_zip, public_key, filename)

    # Updates pvmfw embedded public key with the virt APEX payload key.
    elif filename == "PREBUILT_IMAGES/pvmfw.img":
      # Find the name of the virt APEX in the target files.
      namelist = input_tf_zip.namelist()
      apex_gen = (GetApexFilename(f) for f in namelist if IsApexFile(f))
      virt_apex_re = re.compile("^com\.([^\.]+\.)?android\.virt\.apex$")
      virt_apex = next((a for a in apex_gen if virt_apex_re.match(a)), None)
      if not virt_apex:
        print("Removing %s from ramdisk: virt APEX not found" % filename)
      else:
        print("Replacing %s embedded key with %s key" % (filename, virt_apex))
        # Get the current and new embedded keys.
        payload_key, container_key, sign_tool = apex_keys[virt_apex]
        new_pubkey_path = common.ExtractAvbPublicKey(
            misc_info['avb_avbtool'], payload_key)
        with open(new_pubkey_path, 'rb') as f:
          new_pubkey = f.read()
        pubkey_info = copy.copy(
            input_tf_zip.getinfo("PREBUILT_IMAGES/pvmfw_embedded.avbpubkey"))
        old_pubkey = input_tf_zip.read(pubkey_info.filename)
        # Validate the keys and image.
        if len(old_pubkey) != len(new_pubkey):
          raise common.ExternalError("pvmfw embedded public key size mismatch")
        pos = data.find(old_pubkey)
        if pos == -1:
          raise common.ExternalError("pvmfw embedded public key not found")
        # Replace the key and copy new files.
        new_data = data[:pos] + new_pubkey + data[pos+len(old_pubkey):]
        common.ZipWriteStr(output_tf_zip, out_info, new_data)
        common.ZipWriteStr(output_tf_zip, pubkey_info, new_pubkey)
    elif filename == "PREBUILT_IMAGES/pvmfw_embedded.avbpubkey":
      pass

    # Should NOT sign boot-debug.img.
    elif filename in (
        "BOOT/RAMDISK/force_debuggable",
        "BOOT/RAMDISK/first_stage_ramdisk/force_debuggable"):
      raise common.ExternalError("debuggable boot.img cannot be signed")

    # Should NOT sign userdebug sepolicy file.
    elif filename in (
        "SYSTEM_EXT/etc/selinux/userdebug_plat_sepolicy.cil",
        "SYSTEM/system_ext/etc/selinux/userdebug_plat_sepolicy.cil"):
      if not OPTIONS.allow_gsi_debug_sepolicy:
        raise common.ExternalError("debug sepolicy shouldn't be included")
      else:
        # Copy it verbatim if we allow the file to exist.
        common.ZipWriteStr(output_tf_zip, out_info, data)

    # Sign microdroid_vendor.img.
    elif filename == "VENDOR/etc/avf/microdroid/microdroid_vendor.img":
      vendor_key = OPTIONS.avb_keys.get("vendor")
      vendor_algorithm = OPTIONS.avb_algorithms.get("vendor")
      with tempfile.NamedTemporaryFile() as image:
        image.write(data)
        image.flush()
        ReplaceKeyInAvbHashtreeFooter(image, vendor_key, vendor_algorithm,
            misc_info)
        common.ZipWrite(output_tf_zip, image.name, filename)
    # A non-APK file; copy it verbatim.
    else:
      try:
        entry = output_tf_zip.getinfo(filename)
        if output_tf_zip.read(entry) != data:
          logger.warn(
              "Output zip contains duplicate entries for %s with different contents", filename)
        continue
      except KeyError:
        common.ZipWriteStr(output_tf_zip, out_info, data)

  if OPTIONS.replace_ota_keys:
    ReplaceOtaKeys(input_tf_zip, output_tf_zip, misc_info)


  # Write back misc_info with the latest values.
  ReplaceMiscInfoTxt(input_tf_zip, output_tf_zip, misc_info)

# Parse string output of `avbtool info_image`.
def ParseAvbInfo(info_raw):
  # line_matcher is for parsing each output line of `avbtool info_image`.
  # example string input: "      Hash Algorithm:        sha1"
  # example matched input: ("      ", "Hash Algorithm", "sha1")
  line_matcher = re.compile(r'^(\s*)([^:]+):\s*(.*)$')
  # prop_matcher is for parsing value part of 'Prop' in `avbtool info_image`.
  # example string input: "example_prop_key -> 'example_prop_value'"
  # example matched output: ("example_prop_key", "example_prop_value")
  prop_matcher = re.compile(r"(.+)\s->\s'(.+)'")
  info = {}
  indent_stack = [[-1, info]]
  for line_info_raw in info_raw.split('\n'):
    # Parse the line
    line_info_parsed = line_matcher.match(line_info_raw)
    if not line_info_parsed:
      continue
    indent = len(line_info_parsed.group(1))
    key = line_info_parsed.group(2).strip()
    value = line_info_parsed.group(3).strip()

    # Pop indentation stack
    while indent <= indent_stack[-1][0]:
      del indent_stack[-1]

    # Insert information into 'info'.
    cur_info = indent_stack[-1][1]
    if value == "":
      if key == "Descriptors":
        empty_list = []
        cur_info[key] = empty_list
        indent_stack.append([indent, empty_list])
      else:
        empty_dict = {}
        cur_info.append({key:empty_dict})
        indent_stack.append([indent, empty_dict])
    elif key == "Prop":
      prop_parsed = prop_matcher.match(value)
      if not prop_parsed:
        raise ValueError(
            "Failed to parse prop while getting avb information.")
      cur_info.append({key:{prop_parsed.group(1):prop_parsed.group(2)}})
    else:
      cur_info[key] = value
  return info

def ReplaceKeyInAvbHashtreeFooter(image, new_key, new_algorithm, misc_info):
  # Get avb information about the image by parsing avbtool info_image.
  def GetAvbInfo(avbtool, image_name):
    # Get information with raw string by `avbtool info_image`.
    info_raw = common.RunAndCheckOutput([
      avbtool, 'info_image',
      '--image', image_name
    ])
    return ParseAvbInfo(info_raw)

  # Get hashtree descriptor from info
  def GetAvbHashtreeDescriptor(avb_info):
    hashtree_descriptors = tuple(filter(lambda x: "Hashtree descriptor" in x,
        info.get('Descriptors')))
    if len(hashtree_descriptors) != 1:
      raise ValueError("The number of hashtree descriptor is not 1.")
    return hashtree_descriptors[0]["Hashtree descriptor"]

  # Get avb info
  avbtool = misc_info['avb_avbtool']
  info = GetAvbInfo(avbtool, image.name)
  hashtree_descriptor = GetAvbHashtreeDescriptor(info)

  # Generate command
  cmd = [avbtool, 'add_hashtree_footer',
    '--key', new_key,
    '--algorithm', new_algorithm,
    '--partition_name', hashtree_descriptor.get("Partition Name"),
    '--partition_size', info.get("Image size").removesuffix(" bytes"),
    '--hash_algorithm', hashtree_descriptor.get("Hash Algorithm"),
    '--salt', hashtree_descriptor.get("Salt"),
    '--do_not_generate_fec',
    '--image', image.name
  ]

  # Append properties into command
  props = map(lambda x: x.get("Prop"), filter(lambda x: "Prop" in x,
      info.get('Descriptors')))
  for prop_wrapped in props:
    prop = tuple(prop_wrapped.items())
    if len(prop) != 1:
      raise ValueError("The number of property is not 1.")
    cmd.append('--prop')
    cmd.append(prop[0][0] + ':' + prop[0][1])

  # Replace Hashtree Footer with new key
  common.RunAndCheckOutput(cmd)

  # Check root digest is not changed
  new_info = GetAvbInfo(avbtool, image.name)
  new_hashtree_descriptor = GetAvbHashtreeDescriptor(info)
  root_digest = hashtree_descriptor.get("Root Digest")
  new_root_digest = new_hashtree_descriptor.get("Root Digest")
  assert root_digest == new_root_digest, \
      ("Root digest in hashtree descriptor shouldn't be changed. Old: {}, New: "
       "{}").format(root_digest, new_root_digest)

def ReplaceCerts(data):
  """Replaces all the occurences of X.509 certs with the new ones.

  The mapping info is read from OPTIONS.key_map. Non-existent certificate will
  be skipped. After the replacement, it additionally checks for duplicate
  entries, which would otherwise fail the policy loading code in
  frameworks/base/services/core/java/com/android/server/pm/SELinuxMMAC.java.

  Args:
    data: Input string that contains a set of X.509 certs.

  Returns:
    A string after the replacement.

  Raises:
    AssertionError: On finding duplicate entries.
  """
  for old, new in OPTIONS.key_map.items():
    if OPTIONS.verbose:
      print("    Replacing %s.x509.pem with %s.x509.pem" % (old, new))

    try:
      with open(old + ".x509.pem") as old_fp:
        old_cert16 = base64.b16encode(
            common.ParseCertificate(old_fp.read())).decode().lower()
      with open(new + ".x509.pem") as new_fp:
        new_cert16 = base64.b16encode(
            common.ParseCertificate(new_fp.read())).decode().lower()
    except IOError as e:
      if OPTIONS.verbose or e.errno != errno.ENOENT:
        print("    Error accessing %s: %s.\nSkip replacing %s.x509.pem with "
              "%s.x509.pem." % (e.filename, e.strerror, old, new))
      continue

    # Only match entire certs.
    pattern = "\\b" + old_cert16 + "\\b"
    (data, num) = re.subn(pattern, new_cert16, data, flags=re.IGNORECASE)

    if OPTIONS.verbose:
      print("    Replaced %d occurence(s) of %s.x509.pem with %s.x509.pem" % (
          num, old, new))

  # Verify that there're no duplicate entries after the replacement. Note that
  # it's only checking entries with global seinfo at the moment (i.e. ignoring
  # the ones with inner packages). (Bug: 69479366)
  root = ElementTree.fromstring(data)
  signatures = [signer.attrib['signature']
                for signer in root.findall('signer')]
  assert len(signatures) == len(set(signatures)), \
      "Found duplicate entries after cert replacement: {}".format(data)

  return data


def EditTags(tags):
  """Applies the edits to the tag string as specified in OPTIONS.tag_changes.

  Args:
    tags: The input string that contains comma-separated tags.

  Returns:
    The updated tags (comma-separated and sorted).
  """
  tags = set(tags.split(","))
  for ch in OPTIONS.tag_changes:
    if ch[0] == "-":
      tags.discard(ch[1:])
    elif ch[0] == "+":
      tags.add(ch[1:])
  return ",".join(sorted(tags))


def RewriteProps(data):
  """Rewrites the system properties in the given string.

  Each property is expected in 'key=value' format. The properties that contain
  build tags (i.e. test-keys, dev-keys) will be updated accordingly by calling
  EditTags().

  Args:
    data: Input string, separated by newlines.

  Returns:
    The string with modified properties.
  """
  output = []
  for line in data.split("\n"):
    line = line.strip()
    original_line = line
    if line and line[0] != '#' and "=" in line:
      key, value = line.split("=", 1)
      if (key.startswith("ro.") and
              key.endswith((".build.fingerprint", ".build.thumbprint"))):
        pieces = value.split("/")
        pieces[-1] = EditTags(pieces[-1])
        value = "/".join(pieces)
      elif key == "ro.bootimage.build.fingerprint":
        pieces = value.split("/")
        pieces[-1] = EditTags(pieces[-1])
        value = "/".join(pieces)
      elif key == "ro.build.description":
        pieces = value.split()
        assert pieces[-1].endswith("-keys")
        pieces[-1] = EditTags(pieces[-1])
        value = " ".join(pieces)
      elif key.startswith("ro.") and key.endswith(".build.tags"):
        value = EditTags(value)
      elif key == "ro.build.display.id":
        # change, eg, "JWR66N dev-keys" to "JWR66N"
        value = value.split()
        if len(value) > 1 and value[-1].endswith("-keys"):
          value.pop()
        value = " ".join(value)
      line = key + "=" + value
    if line != original_line:
      print("  replace: ", original_line)
      print("     with: ", line)
    output.append(line)
  return "\n".join(output) + "\n"


def WriteOtacerts(output_zip, filename, keys):
  """Constructs a zipfile from given keys; and writes it to output_zip.

  Args:
    output_zip: The output target_files zip.
    filename: The archive name in the output zip.
    keys: A list of public keys to use during OTA package verification.
  """
  temp_file = io.BytesIO()
  certs_zip = zipfile.ZipFile(temp_file, "w", allowZip64=True)
  for k in keys:
    common.ZipWrite(certs_zip, k)
  common.ZipClose(certs_zip)
  common.ZipWriteStr(output_zip, filename, temp_file.getvalue())


def ReplaceOtaKeys(input_tf_zip: zipfile.ZipFile, output_tf_zip, misc_info):
  try:
    keylist = input_tf_zip.read("META/otakeys.txt").decode().split()
  except KeyError:
    raise common.ExternalError("can't read META/otakeys.txt from input")

  extra_ota_keys_info = misc_info.get("extra_ota_keys")
  if extra_ota_keys_info:
    extra_ota_keys = [OPTIONS.key_map.get(k, k) + ".x509.pem"
                      for k in extra_ota_keys_info.split()]
    print("extra ota key(s): " + ", ".join(extra_ota_keys))
  else:
    extra_ota_keys = []
  for k in extra_ota_keys:
    if not os.path.isfile(k):
      raise common.ExternalError(k + " does not exist or is not a file")

  extra_recovery_keys_info = misc_info.get("extra_recovery_keys")
  if extra_recovery_keys_info:
    extra_recovery_keys = [OPTIONS.key_map.get(k, k) + ".x509.pem"
                           for k in extra_recovery_keys_info.split()]
    print("extra recovery-only key(s): " + ", ".join(extra_recovery_keys))
  else:
    extra_recovery_keys = []
  for k in extra_recovery_keys:
    if not os.path.isfile(k):
      raise common.ExternalError(k + " does not exist or is not a file")

  mapped_keys = []
  for k in keylist:
    m = re.match(r"^(.*)\.x509\.pem$", k)
    if not m:
      raise common.ExternalError(
          "can't parse \"%s\" from META/otakeys.txt" % (k,))
    k = m.group(1)
    mapped_keys.append(OPTIONS.key_map.get(k, k) + ".x509.pem")

  if mapped_keys:
    print("using:\n   ", "\n   ".join(mapped_keys))
    print("for OTA package verification")
  else:
    devkey = misc_info.get("default_system_dev_certificate",
                           "build/make/target/product/security/testkey")
    mapped_devkey = OPTIONS.key_map.get(devkey, devkey)
    if mapped_devkey != devkey:
      misc_info["default_system_dev_certificate"] = mapped_devkey
    mapped_keys.append(mapped_devkey + ".x509.pem")
    print("META/otakeys.txt has no keys; using %s for OTA package"
          " verification." % (mapped_keys[0],))
  for k in mapped_keys:
    if not os.path.isfile(k):
      raise common.ExternalError(k + " does not exist or is not a file")

  otacerts = [info
              for info in input_tf_zip.infolist()
              if info.filename.endswith("/otacerts.zip")]
  for info in otacerts:
    if info.filename.startswith(("BOOT/", "RECOVERY/", "VENDOR_BOOT/")):
      extra_keys = extra_recovery_keys
    else:
      extra_keys = extra_ota_keys
    print("Rewriting OTA key:", info.filename, mapped_keys + extra_keys)
    WriteOtacerts(output_tf_zip, info.filename, mapped_keys + extra_keys)


def ReplaceMiscInfoTxt(input_zip, output_zip, misc_info):
  """Replaces META/misc_info.txt.

  Only writes back the ones in the original META/misc_info.txt. Because the
  current in-memory dict contains additional items computed at runtime.
  """
  misc_info_old = common.LoadDictionaryFromLines(
      input_zip.read('META/misc_info.txt').decode().split('\n'))
  items = []
  for key in sorted(misc_info):
    if key in misc_info_old:
      items.append('%s=%s' % (key, misc_info[key]))
  common.ZipWriteStr(output_zip, "META/misc_info.txt", '\n'.join(items))


def ReplaceAvbSigningKeys(misc_info):
  """Replaces the AVB signing keys."""

  def ReplaceAvbPartitionSigningKey(partition):
    key = OPTIONS.avb_keys.get(partition)
    if not key:
      return

    algorithm = OPTIONS.avb_algorithms.get(partition)
    assert algorithm, 'Missing AVB signing algorithm for %s' % (partition,)

    print('Replacing AVB signing key for %s with "%s" (%s)' % (
        partition, key, algorithm))
    misc_info['avb_' + partition + '_algorithm'] = algorithm
    misc_info['avb_' + partition + '_key_path'] = key

    extra_args = OPTIONS.avb_extra_args.get(partition)
    if extra_args:
      print('Setting extra AVB signing args for %s to "%s"' % (
          partition, extra_args))
      args_key = AVB_FOOTER_ARGS_BY_PARTITION.get(
          partition,
          # custom partition
          "avb_{}_add_hashtree_footer_args".format(partition))
      misc_info[args_key] = (misc_info.get(args_key, '') + ' ' + extra_args)

  for partition in AVB_FOOTER_ARGS_BY_PARTITION:
    ReplaceAvbPartitionSigningKey(partition)

  for custom_partition in misc_info.get(
          "avb_custom_images_partition_list", "").strip().split():
    ReplaceAvbPartitionSigningKey(custom_partition)


def RewriteAvbProps(misc_info):
  """Rewrites the props in AVB signing args."""
  for partition, args_key in AVB_FOOTER_ARGS_BY_PARTITION.items():
    args = misc_info.get(args_key)
    if not args:
      continue

    tokens = []
    changed = False
    for token in args.split():
      fingerprint_key = 'com.android.build.{}.fingerprint'.format(partition)
      if not token.startswith(fingerprint_key):
        tokens.append(token)
        continue
      prefix, tag = token.rsplit('/', 1)
      tokens.append('{}/{}'.format(prefix, EditTags(tag)))
      changed = True

    if changed:
      result = ' '.join(tokens)
      print('Rewriting AVB prop for {}:\n'.format(partition))
      print('  replace: {}'.format(args))
      print('     with: {}'.format(result))
      misc_info[args_key] = result


def BuildKeyMap(misc_info, key_mapping_options):
  for s, d in key_mapping_options:
    if s is None:   # -d option
      devkey = misc_info.get("default_system_dev_certificate",
                             "build/make/target/product/security/testkey")
      devkeydir = os.path.dirname(devkey)

      OPTIONS.key_map.update({
          devkeydir + "/testkey":  d + "/releasekey",
          devkeydir + "/devkey":   d + "/releasekey",
          devkeydir + "/media":    d + "/media",
          devkeydir + "/shared":   d + "/shared",
          devkeydir + "/platform": d + "/platform",
          devkeydir + "/networkstack": d + "/networkstack",
          devkeydir + "/sdk_sandbox": d + "/sdk_sandbox",
      })
    else:
      OPTIONS.key_map[s] = d


def GetApiLevelAndCodename(input_tf_zip):
  data = input_tf_zip.read("SYSTEM/build.prop").decode()
  api_level = None
  codename = None
  for line in data.split("\n"):
    line = line.strip()
    if line and line[0] != '#' and "=" in line:
      key, value = line.split("=", 1)
      key = key.strip()
      if key == "ro.build.version.sdk":
        api_level = int(value.strip())
      elif key == "ro.build.version.codename":
        codename = value.strip()

  if api_level is None:
    raise ValueError("No ro.build.version.sdk in SYSTEM/build.prop")
  if codename is None:
    raise ValueError("No ro.build.version.codename in SYSTEM/build.prop")

  return (api_level, codename)


def GetCodenameToApiLevelMap(input_tf_zip):
  data = input_tf_zip.read("SYSTEM/build.prop").decode()
  api_level = None
  codenames = None
  for line in data.split("\n"):
    line = line.strip()
    if line and line[0] != '#' and "=" in line:
      key, value = line.split("=", 1)
      key = key.strip()
      if key == "ro.build.version.sdk":
        api_level = int(value.strip())
      elif key == "ro.build.version.all_codenames":
        codenames = value.strip().split(",")

  if api_level is None:
    raise ValueError("No ro.build.version.sdk in SYSTEM/build.prop")
  if codenames is None:
    raise ValueError("No ro.build.version.all_codenames in SYSTEM/build.prop")

  result = {}
  for codename in codenames:
    codename = codename.strip()
    if codename:
      result[codename] = api_level
  return result


def ReadApexKeysInfo(tf_zip):
  """Parses the APEX keys info from a given target-files zip.

  Given a target-files ZipFile, parses the META/apexkeys.txt entry and returns a
  dict that contains the mapping from APEX names (e.g. com.android.tzdata) to a
  tuple of (payload_key, container_key, sign_tool).

  Args:
    tf_zip: The input target_files ZipFile (already open).

  Returns:
    (payload_key, container_key, sign_tool):
      - payload_key contains the path to the payload signing key
      - container_key contains the path to the container signing key
      - sign_tool is an apex-specific signing tool for its payload contents
  """
  keys = {}
  for line in tf_zip.read('META/apexkeys.txt').decode().split('\n'):
    line = line.strip()
    if not line:
      continue
    matches = re.match(
        r'^name="(?P<NAME>.*)"\s+'
        r'public_key="(?P<PAYLOAD_PUBLIC_KEY>.*)"\s+'
        r'private_key="(?P<PAYLOAD_PRIVATE_KEY>.*)"\s+'
        r'container_certificate="(?P<CONTAINER_CERT>.*)"\s+'
        r'container_private_key="(?P<CONTAINER_PRIVATE_KEY>.*?)"'
        r'(\s+partition="(?P<PARTITION>.*?)")?'
        r'(\s+sign_tool="(?P<SIGN_TOOL>.*?)")?$',
        line)
    if not matches:
      continue

    name = matches.group('NAME')
    payload_private_key = matches.group("PAYLOAD_PRIVATE_KEY")

    def CompareKeys(pubkey, pubkey_suffix, privkey, privkey_suffix):
      pubkey_suffix_len = len(pubkey_suffix)
      privkey_suffix_len = len(privkey_suffix)
      return (pubkey.endswith(pubkey_suffix) and
              privkey.endswith(privkey_suffix) and
              pubkey[:-pubkey_suffix_len] == privkey[:-privkey_suffix_len])

    # Check the container key names, as we'll carry them without the
    # extensions. This doesn't apply to payload keys though, which we will use
    # full names only.
    container_cert = matches.group("CONTAINER_CERT")
    container_private_key = matches.group("CONTAINER_PRIVATE_KEY")
    if container_cert == 'PRESIGNED' and container_private_key == 'PRESIGNED':
      container_key = 'PRESIGNED'
    elif CompareKeys(
            container_cert, OPTIONS.public_key_suffix,
            container_private_key, OPTIONS.private_key_suffix):
      container_key = container_cert[:-len(OPTIONS.public_key_suffix)]
    else:
      raise ValueError("Failed to parse container keys: \n{}".format(line))

    sign_tool = matches.group("SIGN_TOOL")
    keys[name] = (payload_private_key, container_key, sign_tool)

  return keys


def BuildVendorPartitions(output_zip_path):
  """Builds OPTIONS.vendor_partitions using OPTIONS.vendor_otatools."""
  if OPTIONS.vendor_partitions.difference(ALLOWED_VENDOR_PARTITIONS):
    logger.warning("Allowed --vendor_partitions: %s",
                   ",".join(ALLOWED_VENDOR_PARTITIONS))
    OPTIONS.vendor_partitions = ALLOWED_VENDOR_PARTITIONS.intersection(
        OPTIONS.vendor_partitions)

  logger.info("Building vendor partitions using vendor otatools.")
  vendor_tempdir = common.UnzipTemp(output_zip_path, [
      "META/*",
      "SYSTEM/build.prop",
      "RECOVERY/*",
      "BOOT/*",
      "OTA/",
  ] + ["{}/*".format(p.upper()) for p in OPTIONS.vendor_partitions])

  # Disable various partitions that build based on misc_info fields.
  # Only partitions in ALLOWED_VENDOR_PARTITIONS can be rebuilt using
  # vendor otatools. These other partitions will be rebuilt using the main
  # otatools if necessary.
  vendor_misc_info_path = os.path.join(vendor_tempdir, "META/misc_info.txt")
  vendor_misc_info = common.LoadDictionaryFromFile(vendor_misc_info_path)
  # Ignore if not rebuilding recovery
  if not OPTIONS.rebuild_recovery:
    vendor_misc_info["no_boot"] = "true"  # boot
    vendor_misc_info["vendor_boot"] = "false"  # vendor_boot
    vendor_misc_info["no_recovery"] = "true"  # recovery
    vendor_misc_info["avb_enable"] = "false"  # vbmeta

  vendor_misc_info["has_dtbo"] = "false"  # dtbo
  vendor_misc_info["has_pvmfw"] = "false"  # pvmfw
  vendor_misc_info["avb_custom_images_partition_list"] = ""  # avb custom images
  vendor_misc_info["avb_building_vbmeta_image"] = "false" # skip building vbmeta
  vendor_misc_info["custom_images_partition_list"] = ""  # custom images
  vendor_misc_info["use_dynamic_partitions"] = "false"  # super_empty
  vendor_misc_info["build_super_partition"] = "false"  # super split
  vendor_misc_info["avb_vbmeta_system"] = ""  # skip building vbmeta_system
  with open(vendor_misc_info_path, "w") as output:
    for key in sorted(vendor_misc_info):
      output.write("{}={}\n".format(key, vendor_misc_info[key]))

  # Disable system partition by a placeholder of IMAGES/system.img,
  # instead of removing SYSTEM folder.
  # Because SYSTEM/build.prop is still needed for:
  #   add_img_to_target_files.CreateImage ->
  #   common.BuildInfo ->
  #   common.BuildInfo.CalculateFingerprint
  vendor_images_path = os.path.join(vendor_tempdir, "IMAGES")
  if not os.path.exists(vendor_images_path):
    os.makedirs(vendor_images_path)
  with open(os.path.join(vendor_images_path, "system.img"), "w") as output:
    pass

  # Disable care_map.pb as not all ab_partitions are available when
  # vendor otatools regenerates vendor images.
  if os.path.exists(os.path.join(vendor_tempdir, "META/ab_partitions.txt")):
    os.remove(os.path.join(vendor_tempdir, "META/ab_partitions.txt"))
  # Disable RADIO images
  if os.path.exists(os.path.join(vendor_tempdir, "META/pack_radioimages.txt")):
    os.remove(os.path.join(vendor_tempdir, "META/pack_radioimages.txt"))

  # Build vendor images using vendor otatools.
  # Accept either a zip file or extracted directory.
  if os.path.isfile(OPTIONS.vendor_otatools):
    vendor_otatools_dir = common.MakeTempDir(prefix="vendor_otatools_")
    common.UnzipToDir(OPTIONS.vendor_otatools, vendor_otatools_dir)
  else:
    vendor_otatools_dir = OPTIONS.vendor_otatools
  cmd = [
      os.path.join(vendor_otatools_dir, "bin", "add_img_to_target_files"),
      "--is_signing",
      "--add_missing",
      "--verbose",
      vendor_tempdir,
  ]
  if OPTIONS.rebuild_recovery:
    cmd.insert(4, "--rebuild_recovery")

  common.RunAndCheckOutput(cmd, verbose=True)

  logger.info("Writing vendor partitions to output archive.")
  with zipfile.ZipFile(
      output_zip_path, "a", compression=zipfile.ZIP_DEFLATED,
      allowZip64=True) as output_zip:
    for p in OPTIONS.vendor_partitions:
      img_file_path = "IMAGES/{}.img".format(p)
      map_file_path = "IMAGES/{}.map".format(p)
      common.ZipWrite(output_zip, os.path.join(vendor_tempdir, img_file_path), img_file_path)
      if os.path.exists(os.path.join(vendor_tempdir, map_file_path)):
        common.ZipWrite(output_zip, os.path.join(vendor_tempdir, map_file_path), map_file_path)
    # copy recovery.img, boot.img, recovery patch & install.sh
    if OPTIONS.rebuild_recovery:
      recovery_img = "IMAGES/recovery.img"
      boot_img = "IMAGES/boot.img"
      common.ZipWrite(output_zip, os.path.join(vendor_tempdir, recovery_img), recovery_img)
      common.ZipWrite(output_zip, os.path.join(vendor_tempdir, boot_img), boot_img)
      recovery_patch_path = "VENDOR/recovery-from-boot.p"
      recovery_sh_path = "VENDOR/bin/install-recovery.sh"
      common.ZipWrite(output_zip, os.path.join(vendor_tempdir, recovery_patch_path), recovery_patch_path)
      common.ZipWrite(output_zip, os.path.join(vendor_tempdir, recovery_sh_path), recovery_sh_path)


def main(argv):

  key_mapping_options = []

  def option_handler(o, a):
    if o in ("-e", "--extra_apks"):
      names, key = a.split("=")
      names = names.split(",")
      for n in names:
        OPTIONS.extra_apks[n] = key
    elif o == "--extra_apex_payload_key":
      apex_names, key = a.split("=")
      for name in apex_names.split(","):
        OPTIONS.extra_apex_payload_keys[name] = key
    elif o == "--skip_apks_with_path_prefix":
      # Check the prefix, which must be in all upper case.
      prefix = a.split('/')[0]
      if not prefix or prefix != prefix.upper():
        raise ValueError("Invalid path prefix '%s'" % (a,))
      OPTIONS.skip_apks_with_path_prefix.add(a)
    elif o in ("-d", "--default_key_mappings"):
      key_mapping_options.append((None, a))
    elif o in ("-k", "--key_mapping"):
      key_mapping_options.append(a.split("=", 1))
    elif o in ("-o", "--replace_ota_keys"):
      OPTIONS.replace_ota_keys = True
    elif o in ("-t", "--tag_changes"):
      new = []
      for i in a.split(","):
        i = i.strip()
        if not i or i[0] not in "-+":
          raise ValueError("Bad tag change '%s'" % (i,))
        new.append(i[0] + i[1:].strip())
      OPTIONS.tag_changes = tuple(new)
    elif o == "--replace_verity_public_key":
      raise ValueError("--replace_verity_public_key is no longer supported,"
                       " please switch to AVB")
    elif o == "--replace_verity_private_key":
      raise ValueError("--replace_verity_private_key is no longer supported,"
                       " please switch to AVB")
    elif o == "--replace_verity_keyid":
      raise ValueError("--replace_verity_keyid is no longer supported, please"
                       " switch to AVB")
    elif o == "--remove_avb_public_keys":
      OPTIONS.remove_avb_public_keys = a.split(",")
    elif o == "--avb_vbmeta_key":
      OPTIONS.avb_keys['vbmeta'] = a
    elif o == "--avb_vbmeta_algorithm":
      OPTIONS.avb_algorithms['vbmeta'] = a
    elif o == "--avb_vbmeta_extra_args":
      OPTIONS.avb_extra_args['vbmeta'] = a
    elif o == "--avb_boot_key":
      OPTIONS.avb_keys['boot'] = a
    elif o == "--avb_boot_algorithm":
      OPTIONS.avb_algorithms['boot'] = a
    elif o == "--avb_boot_extra_args":
      OPTIONS.avb_extra_args['boot'] = a
    elif o == "--avb_dtbo_key":
      OPTIONS.avb_keys['dtbo'] = a
    elif o == "--avb_dtbo_algorithm":
      OPTIONS.avb_algorithms['dtbo'] = a
    elif o == "--avb_dtbo_extra_args":
      OPTIONS.avb_extra_args['dtbo'] = a
    elif o == "--avb_init_boot_key":
      OPTIONS.avb_keys['init_boot'] = a
    elif o == "--avb_init_boot_algorithm":
      OPTIONS.avb_algorithms['init_boot'] = a
    elif o == "--avb_init_boot_extra_args":
      OPTIONS.avb_extra_args['init_boot'] = a
    elif o == "--avb_recovery_key":
      OPTIONS.avb_keys['recovery'] = a
    elif o == "--avb_recovery_algorithm":
      OPTIONS.avb_algorithms['recovery'] = a
    elif o == "--avb_recovery_extra_args":
      OPTIONS.avb_extra_args['recovery'] = a
    elif o == "--avb_system_key":
      OPTIONS.avb_keys['system'] = a
    elif o == "--avb_system_algorithm":
      OPTIONS.avb_algorithms['system'] = a
    elif o == "--avb_system_extra_args":
      OPTIONS.avb_extra_args['system'] = a
    elif o == "--avb_system_other_key":
      OPTIONS.avb_keys['system_other'] = a
    elif o == "--avb_system_other_algorithm":
      OPTIONS.avb_algorithms['system_other'] = a
    elif o == "--avb_system_other_extra_args":
      OPTIONS.avb_extra_args['system_other'] = a
    elif o == "--avb_vendor_key":
      OPTIONS.avb_keys['vendor'] = a
    elif o == "--avb_vendor_algorithm":
      OPTIONS.avb_algorithms['vendor'] = a
    elif o == "--avb_vendor_extra_args":
      OPTIONS.avb_extra_args['vendor'] = a
    elif o == "--avb_vbmeta_system_key":
      OPTIONS.avb_keys['vbmeta_system'] = a
    elif o == "--avb_vbmeta_system_algorithm":
      OPTIONS.avb_algorithms['vbmeta_system'] = a
    elif o == "--avb_vbmeta_system_extra_args":
      OPTIONS.avb_extra_args['vbmeta_system'] = a
    elif o == "--avb_vbmeta_vendor_key":
      OPTIONS.avb_keys['vbmeta_vendor'] = a
    elif o == "--avb_vbmeta_vendor_algorithm":
      OPTIONS.avb_algorithms['vbmeta_vendor'] = a
    elif o == "--avb_vbmeta_vendor_extra_args":
      OPTIONS.avb_extra_args['vbmeta_vendor'] = a
    elif o == "--avb_apex_extra_args":
      OPTIONS.avb_extra_args['apex'] = a
    elif o == "--avb_extra_custom_image_key":
      partition, key = a.split("=")
      OPTIONS.avb_keys[partition] = key
    elif o == "--avb_extra_custom_image_algorithm":
      partition, algorithm = a.split("=")
      OPTIONS.avb_algorithms[partition] = algorithm
    elif o == "--avb_extra_custom_image_extra_args":
      # Setting the maxsplit parameter to one, which will return a list with
      # two elements. e.g., the second '=' should not be splitted for
      # 'oem=--signing_helper_with_files=/tmp/avbsigner.sh'.
      partition, extra_args = a.split("=", 1)
      OPTIONS.avb_extra_args[partition] = extra_args
    elif o == "--vendor_otatools":
      OPTIONS.vendor_otatools = a
    elif o == "--vendor_partitions":
      OPTIONS.vendor_partitions = set(a.split(","))
    elif o == "--allow_gsi_debug_sepolicy":
      OPTIONS.allow_gsi_debug_sepolicy = True
    elif o == "--override_apk_keys":
      OPTIONS.override_apk_keys = a
    elif o == "--override_apex_keys":
      OPTIONS.override_apex_keys = a
    elif o in ("--gki_signing_key",  "--gki_signing_algorithm",  "--gki_signing_extra_args"):
      print(f"{o} is deprecated and does nothing")
    else:
      return False
    return True

  args = common.ParseOptions(
      argv, __doc__,
      extra_opts="e:d:k:ot:",
      extra_long_opts=[
          "extra_apks=",
          "extra_apex_payload_key=",
          "skip_apks_with_path_prefix=",
          "default_key_mappings=",
          "key_mapping=",
          "replace_ota_keys",
          "tag_changes=",
          "replace_verity_public_key=",
          "replace_verity_private_key=",
          "replace_verity_keyid=",
          "remove_avb_public_keys=",
          "avb_apex_extra_args=",
          "avb_vbmeta_algorithm=",
          "avb_vbmeta_key=",
          "avb_vbmeta_extra_args=",
          "avb_boot_algorithm=",
          "avb_boot_key=",
          "avb_boot_extra_args=",
          "avb_dtbo_algorithm=",
          "avb_dtbo_key=",
          "avb_dtbo_extra_args=",
          "avb_init_boot_algorithm=",
          "avb_init_boot_key=",
          "avb_init_boot_extra_args=",
          "avb_recovery_algorithm=",
          "avb_recovery_key=",
          "avb_recovery_extra_args=",
          "avb_system_algorithm=",
          "avb_system_key=",
          "avb_system_extra_args=",
          "avb_system_other_algorithm=",
          "avb_system_other_key=",
          "avb_system_other_extra_args=",
          "avb_vendor_algorithm=",
          "avb_vendor_key=",
          "avb_vendor_extra_args=",
          "avb_vbmeta_system_algorithm=",
          "avb_vbmeta_system_key=",
          "avb_vbmeta_system_extra_args=",
          "avb_vbmeta_vendor_algorithm=",
          "avb_vbmeta_vendor_key=",
          "avb_vbmeta_vendor_extra_args=",
          "avb_extra_custom_image_key=",
          "avb_extra_custom_image_algorithm=",
          "avb_extra_custom_image_extra_args=",
          "gki_signing_key=",
          "gki_signing_algorithm=",
          "gki_signing_extra_args=",
          "vendor_partitions=",
          "vendor_otatools=",
          "allow_gsi_debug_sepolicy",
          "override_apk_keys=",
          "override_apex_keys=",
      ],
      extra_option_handler=[option_handler, payload_signer.signer_options])

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  input_zip = zipfile.ZipFile(args[0], "r", allowZip64=True)
  output_zip = zipfile.ZipFile(args[1], "w",
                               compression=zipfile.ZIP_DEFLATED,
                               allowZip64=True)

  misc_info = common.LoadInfoDict(input_zip)
  if OPTIONS.package_key is None:
      OPTIONS.package_key = misc_info.get(
          "default_system_dev_certificate",
          "build/make/target/product/security/testkey")

  BuildKeyMap(misc_info, key_mapping_options)

  apk_keys_info, compressed_extension = common.ReadApkCerts(input_zip)
  apk_keys = GetApkCerts(apk_keys_info)

  apex_keys_info = ReadApexKeysInfo(input_zip)
  apex_keys = GetApexKeys(apex_keys_info, apk_keys)

  # TODO(xunchang) check for the apks inside the apex files, and abort early if
  # the keys are not available.
  CheckApkAndApexKeysAvailable(
      input_zip,
      set(apk_keys.keys()) | set(apex_keys.keys()),
      compressed_extension,
      apex_keys)

  key_passwords = common.GetKeyPasswords(
      set(apk_keys.values()) | set(itertools.chain(*apex_keys.values())))
  platform_api_level, _ = GetApiLevelAndCodename(input_zip)
  codename_to_api_level_map = GetCodenameToApiLevelMap(input_zip)

  ProcessTargetFiles(input_zip, output_zip, misc_info,
                     apk_keys, apex_keys, key_passwords,
                     platform_api_level, codename_to_api_level_map,
                     compressed_extension)

  common.ZipClose(input_zip)
  common.ZipClose(output_zip)

  if OPTIONS.vendor_partitions and OPTIONS.vendor_otatools:
    BuildVendorPartitions(args[1])

  # Skip building userdata.img and cache.img when signing the target files.
  new_args = ["--is_signing", "--add_missing", "--verbose"]
  # add_img_to_target_files builds the system image from scratch, so the
  # recovery patch is guaranteed to be regenerated there.
  if OPTIONS.rebuild_recovery:
    new_args.append("--rebuild_recovery")
  new_args.append(args[1])
  add_img_to_target_files.main(new_args)

  print("done.")


if __name__ == '__main__':
  try:
    main(sys.argv[1:])
  finally:
    common.Cleanup()
