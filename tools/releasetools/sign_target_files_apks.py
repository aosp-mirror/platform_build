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

  --extra_apex_payload_key <name=key>
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
      key file replaces the one at BOOT/RAMDISK/verity_key (or ROOT/verity_key
      for devices using system_root_image). It expects the key filename WITH
      the extension (e.g. verity_key.pub).

  --replace_verity_keyid <path_to_X509_PEM_cert_file>
      Replace the veritykeyid in BOOT/cmdline of input_target_file_zip
      with keyid of the cert pointed by <path_to_X509_PEM_cert_file>.

  --avb_{boot,system,system_other,vendor,dtbo,vbmeta,vbmeta_system,
         vbmeta_vendor}_algorithm <algorithm>
  --avb_{boot,system,system_other,vendor,dtbo,vbmeta,vbmeta_system,
         vbmeta_vendor}_key <key>
      Use the specified algorithm (e.g. SHA256_RSA4096) and the key to AVB-sign
      the specified image. Otherwise it uses the existing values in info dict.

  --avb_{apex,boot,system,system_other,vendor,dtbo,vbmeta,vbmeta_system,
         vbmeta_vendor}_extra_args <args>
      Specify any additional args that are needed to AVB-sign the image
      (e.g. "--signing_helper /path/to/helper"). The args will be appended to
      the existing ones in info dict.
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
import subprocess
import sys
import tempfile
import zipfile
from xml.etree import ElementTree

import add_img_to_target_files
import apex_utils
import common


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
OPTIONS.replace_verity_public_key = False
OPTIONS.replace_verity_private_key = False
OPTIONS.replace_verity_keyid = False
OPTIONS.tag_changes = ("-test-keys", "-dev-keys", "+release-keys")
OPTIONS.avb_keys = {}
OPTIONS.avb_algorithms = {}
OPTIONS.avb_extra_args = {}


AVB_FOOTER_ARGS_BY_PARTITION = {
    'boot' : 'avb_boot_add_hash_footer_args',
    'dtbo' : 'avb_dtbo_add_hash_footer_args',
    'recovery' : 'avb_recovery_add_hash_footer_args',
    'system' : 'avb_system_add_hashtree_footer_args',
    'system_other' : 'avb_system_other_add_hashtree_footer_args',
    'vendor' : 'avb_vendor_add_hashtree_footer_args',
    'vendor_boot' : 'avb_vendor_boot_add_hash_footer_args',
    'vbmeta' : 'avb_vbmeta_args',
    'vbmeta_system' : 'avb_vbmeta_system_args',
    'vbmeta_vendor' : 'avb_vbmeta_vendor_args',
}


def GetApkCerts(certmap):
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
        container_key).
    key_map: A dict that overrides the keys, specified via command-line input.

  Returns:
    A dict that contains the updated APEX key mapping, which should be used for
    the current signing.

  Raises:
    AssertionError: On invalid container / payload key overrides.
  """
  # Apply all the --extra_apex_payload_key options to override the payload
  # signing keys in the given keys_info.
  for apex, key in OPTIONS.extra_apex_payload_keys.items():
    if not key:
      key = 'PRESIGNED'
    if apex not in keys_info:
      logger.warning('Failed to find %s in target_files; Ignored', apex)
      continue
    keys_info[apex] = (key, keys_info[apex][1])

  # Apply the key remapping to container keys.
  for apex, (payload_key, container_key) in keys_info.items():
    keys_info[apex] = (payload_key, key_map.get(container_key, container_key))

  # Apply all the --extra_apks options to override the container keys.
  for apex, key in OPTIONS.extra_apks.items():
    # Skip non-APEX containers.
    if apex not in keys_info:
      continue
    if not key:
      key = 'PRESIGNED'
    keys_info[apex] = (keys_info[apex][0], key_map.get(key, key))

  # A PRESIGNED container entails a PRESIGNED payload. Apply this to all the
  # APEX key pairs. However, a PRESIGNED container with non-PRESIGNED payload
  # (overridden via commandline) indicates a config error, which should not be
  # allowed.
  for apex, (payload_key, container_key) in keys_info.items():
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
    keys_info[apex] = ('PRESIGNED', 'PRESIGNED')

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
        (payload_key, container_key).

  Raises:
    AssertionError: On finding unknown APKs and APEXes.
  """
  unknown_files = []
  for info in input_tf_zip.infolist():
    # Handle APEXes first, e.g. SYSTEM/apex/com.android.tzdata.apex.
    if (info.filename.startswith('SYSTEM/apex') and
        info.filename.endswith('.apex')):
      name = os.path.basename(info.filename)
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
    if (not info.filename.startswith('SYSTEM/apex') or
        not info.filename.endswith('.apex')):
      continue

    name = os.path.basename(info.filename)
    (payload_key, container_key) = apex_keys[name]
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
            is_compressed):
  unsigned = tempfile.NamedTemporaryFile()
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

  signed = tempfile.NamedTemporaryFile()

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


def ProcessTargetFiles(input_tf_zip, output_tf_zip, misc_info,
                       apk_keys, apex_keys, key_passwords,
                       platform_api_level, codename_to_api_level_map,
                       compressed_extension):
  # maxsize measures the maximum filename length, including the ones to be
  # skipped.
  maxsize = max(
      [len(os.path.basename(i.filename)) for i in input_tf_zip.infolist()
       if GetApkFileInfo(i.filename, compressed_extension, [])[0]])
  system_root_image = misc_info.get("system_root_image") == "true"

  for info in input_tf_zip.infolist():
    filename = info.filename
    if filename.startswith("IMAGES/"):
      continue

    # Skip OTA-specific images (e.g. split super images), which will be
    # re-generated during signing.
    if filename.startswith("OTA/") and filename.endswith(".img"):
      continue

    data = input_tf_zip.read(filename)
    out_info = copy.copy(info)
    (is_apk, is_compressed, should_be_skipped) = GetApkFileInfo(
        filename, compressed_extension, OPTIONS.skip_apks_with_path_prefix)

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
                              codename_to_api_level_map, is_compressed)
        common.ZipWriteStr(output_tf_zip, out_info, signed_data)
      else:
        # an APK we're not supposed to sign.
        print(
            "NOT signing: %s\n"
            "        (skipped due to special cert string)" % (name,))
        common.ZipWriteStr(output_tf_zip, out_info, data)

    # Sign bundled APEX files.
    elif filename.startswith("SYSTEM/apex") and filename.endswith(".apex"):
      name = os.path.basename(filename)
      payload_key, container_key = apex_keys[name]

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
            key_passwords[container_key],
            codename_to_api_level_map,
            no_hashtree=True,
            signing_args=OPTIONS.avb_extra_args.get('apex'))
        common.ZipWrite(output_tf_zip, signed_apex, filename)

      else:
        print(
            "NOT signing: %s\n"
            "        (skipped due to special cert string)" % (name,))
        common.ZipWriteStr(output_tf_zip, out_info, data)

    # AVB public keys for the installed APEXes, which will be updated later.
    elif (os.path.dirname(filename) == 'SYSTEM/etc/security/apex' and
          filename != 'SYSTEM/etc/security/apex/'):
      continue

    # System properties.
    elif filename in (
        "SYSTEM/build.prop",

        "VENDOR/build.prop",
        "SYSTEM/vendor/build.prop",

        "ODM/etc/build.prop",
        "VENDOR/odm/etc/build.prop",

        "PRODUCT/build.prop",
        "SYSTEM/product/build.prop",

        "SYSTEM_EXT/build.prop",
        "SYSTEM/system_ext/build.prop",

        "SYSTEM/etc/prop.default",
        "BOOT/RAMDISK/prop.default",
        "RECOVERY/RAMDISK/prop.default",

        # ROOT/default.prop is a legacy path, but may still exist for upgrading
        # devices that don't support `property_overrides_split_enabled`.
        "ROOT/default.prop",

        # RECOVERY/RAMDISK/default.prop is a legacy path, but will always exist
        # as a symlink in the current code. So it's a no-op here. Keeping the
        # path here for clarity.
        "RECOVERY/RAMDISK/default.prop"):
      print("Rewriting %s:" % (filename,))
      if stat.S_ISLNK(info.external_attr >> 16):
        new_data = data
      else:
        new_data = RewriteProps(data.decode())
      common.ZipWriteStr(output_tf_zip, out_info, new_data)

    # Replace the certs in *mac_permissions.xml (there could be multiple, such
    # as {system,vendor}/etc/selinux/{plat,nonplat}_mac_permissions.xml).
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
    elif (
        OPTIONS.replace_ota_keys and
        filename in (
            "BOOT/RAMDISK/system/etc/security/otacerts.zip",
            "RECOVERY/RAMDISK/system/etc/security/otacerts.zip",
            "SYSTEM/etc/security/otacerts.zip")):
      pass

    # Skip META/misc_info.txt since we will write back the new values later.
    elif filename == "META/misc_info.txt":
      pass

    # Skip verity public key if we will replace it.
    elif (OPTIONS.replace_verity_public_key and
          filename in ("BOOT/RAMDISK/verity_key",
                       "ROOT/verity_key")):
      pass

    # Skip verity keyid (for system_root_image use) if we will replace it.
    elif OPTIONS.replace_verity_keyid and filename == "BOOT/cmdline":
      pass

    # Skip the care_map as we will regenerate the system/vendor images.
    elif filename == "META/care_map.pb" or filename == "META/care_map.txt":
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

    # Should NOT sign boot-debug.img.
    elif filename in (
        "BOOT/RAMDISK/force_debuggable",
        "RECOVERY/RAMDISK/force_debuggable"
        "RECOVERY/RAMDISK/first_stage_ramdisk/force_debuggable"):
      raise common.ExternalError("debuggable boot.img cannot be signed")

    # A non-APK file; copy it verbatim.
    else:
      common.ZipWriteStr(output_tf_zip, out_info, data)

  if OPTIONS.replace_ota_keys:
    ReplaceOtaKeys(input_tf_zip, output_tf_zip, misc_info)

  # Replace the keyid string in misc_info dict.
  if OPTIONS.replace_verity_private_key:
    ReplaceVerityPrivateKey(misc_info, OPTIONS.replace_verity_private_key[1])

  if OPTIONS.replace_verity_public_key:
    # Replace the one in root dir in system.img.
    ReplaceVerityPublicKey(
        output_tf_zip, 'ROOT/verity_key', OPTIONS.replace_verity_public_key[1])

    if not system_root_image:
      # Additionally replace the copy in ramdisk if not using system-as-root.
      ReplaceVerityPublicKey(
          output_tf_zip,
          'BOOT/RAMDISK/verity_key',
          OPTIONS.replace_verity_public_key[1])

  # Replace the keyid string in BOOT/cmdline.
  if OPTIONS.replace_verity_keyid:
    ReplaceVerityKeyId(input_tf_zip, output_tf_zip,
                       OPTIONS.replace_verity_keyid[1])

  # Replace the AVB signing keys, if any.
  ReplaceAvbSigningKeys(misc_info)

  # Rewrite the props in AVB signing args.
  if misc_info.get('avb_enable') == 'true':
    RewriteAvbProps(misc_info)

  # Write back misc_info with the latest values.
  ReplaceMiscInfoTxt(input_tf_zip, output_tf_zip, misc_info)


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
  signatures = [signer.attrib['signature'] for signer in root.findall('signer')]
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
        pieces = value.split(" ")
        assert len(pieces) == 5
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
  certs_zip = zipfile.ZipFile(temp_file, "w")
  for k in keys:
    common.ZipWrite(certs_zip, k)
  common.ZipClose(certs_zip)
  common.ZipWriteStr(output_zip, filename, temp_file.getvalue())


def ReplaceOtaKeys(input_tf_zip, output_tf_zip, misc_info):
  try:
    keylist = input_tf_zip.read("META/otakeys.txt").split()
  except KeyError:
    raise common.ExternalError("can't read META/otakeys.txt from input")

  extra_recovery_keys = misc_info.get("extra_recovery_keys")
  if extra_recovery_keys:
    extra_recovery_keys = [OPTIONS.key_map.get(k, k) + ".x509.pem"
                           for k in extra_recovery_keys.split()]
    if extra_recovery_keys:
      print("extra recovery-only key(s): " + ", ".join(extra_recovery_keys))
  else:
    extra_recovery_keys = []

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

  # recovery now uses the same x509.pem version of the keys.
  # extra_recovery_keys are used only in recovery.
  if misc_info.get("recovery_as_boot") == "true":
    recovery_keys_location = "BOOT/RAMDISK/system/etc/security/otacerts.zip"
  else:
    recovery_keys_location = "RECOVERY/RAMDISK/system/etc/security/otacerts.zip"

  WriteOtacerts(output_tf_zip, recovery_keys_location,
                mapped_keys + extra_recovery_keys)

  # SystemUpdateActivity uses the x509.pem version of the keys, but
  # put into a zipfile system/etc/security/otacerts.zip.
  # We DO NOT include the extra_recovery_keys (if any) here.
  WriteOtacerts(output_tf_zip, "SYSTEM/etc/security/otacerts.zip", mapped_keys)



def ReplaceVerityPublicKey(output_zip, filename, key_path):
  """Replaces the verity public key at the given path in the given zip.

  Args:
    output_zip: The output target_files zip.
    filename: The archive name in the output zip.
    key_path: The path to the public key.
  """
  print("Replacing verity public key with %s" % (key_path,))
  common.ZipWrite(output_zip, key_path, arcname=filename)


def ReplaceVerityPrivateKey(misc_info, key_path):
  """Replaces the verity private key in misc_info dict.

  Args:
    misc_info: The info dict.
    key_path: The path to the private key in PKCS#8 format.
  """
  print("Replacing verity private key with %s" % (key_path,))
  misc_info["verity_key"] = key_path


def ReplaceVerityKeyId(input_zip, output_zip, key_path):
  """Replaces the veritykeyid parameter in BOOT/cmdline.

  Args:
    input_zip: The input target_files zip, which should be already open.
    output_zip: The output target_files zip, which should be already open and
        writable.
    key_path: The path to the PEM encoded X.509 certificate.
  """
  in_cmdline = input_zip.read("BOOT/cmdline").decode()
  # Copy in_cmdline to output_zip if veritykeyid is not present.
  if "veritykeyid" not in in_cmdline:
    common.ZipWriteStr(output_zip, "BOOT/cmdline", in_cmdline)
    return

  out_buffer = []
  for param in in_cmdline.split():
    if "veritykeyid" not in param:
      out_buffer.append(param)
      continue

    # Extract keyid using openssl command.
    p = common.Run(["openssl", "x509", "-in", key_path, "-text"],
                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    keyid, stderr = p.communicate()
    assert p.returncode == 0, "Failed to dump certificate: {}".format(stderr)
    keyid = re.search(
        r'keyid:([0-9a-fA-F:]*)', keyid).group(1).replace(':', '').lower()
    print("Replacing verity keyid with {}".format(keyid))
    out_buffer.append("veritykeyid=id:%s" % (keyid,))

  out_cmdline = ' '.join(out_buffer).strip() + '\n'
  common.ZipWriteStr(output_zip, "BOOT/cmdline", out_cmdline)


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
      args_key = AVB_FOOTER_ARGS_BY_PARTITION[partition]
      misc_info[args_key] = (misc_info.get(args_key, '') + ' ' + extra_args)

  for partition in AVB_FOOTER_ARGS_BY_PARTITION:
    ReplaceAvbPartitionSigningKey(partition)


def RewriteAvbProps(misc_info):
  """Rewrites the props in AVB signing args."""
  for partition, args_key in AVB_FOOTER_ARGS_BY_PARTITION.items():
    args = misc_info.get(args_key)
    if not args:
      continue

    tokens = []
    changed = False
    for token in args.split(' '):
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
  tuple of (payload_key, container_key).

  Args:
    tf_zip: The input target_files ZipFile (already open).

  Returns:
    (payload_key, container_key): payload_key contains the path to the payload
        signing key; container_key contains the path to the container signing
        key.
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
        r'container_private_key="(?P<CONTAINER_PRIVATE_KEY>.*)"$',
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

    # Sanity check on the container key names, as we'll carry them without the
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

    keys[name] = (payload_private_key, container_key)

  return keys


def main(argv):

  key_mapping_options = []

  def option_handler(o, a):
    if o in ("-e", "--extra_apks"):
      names, key = a.split("=")
      names = names.split(",")
      for n in names:
        OPTIONS.extra_apks[n] = key
    elif o == "--extra_apex_payload_key":
      apex_name, key = a.split("=")
      OPTIONS.extra_apex_payload_keys[apex_name] = key
    elif o == "--skip_apks_with_path_prefix":
      # Sanity check the prefix, which must be in all upper case.
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
      OPTIONS.replace_verity_public_key = (True, a)
    elif o == "--replace_verity_private_key":
      OPTIONS.replace_verity_private_key = (True, a)
    elif o == "--replace_verity_keyid":
      OPTIONS.replace_verity_keyid = (True, a)
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
      ],
      extra_option_handler=option_handler)

  if len(args) != 2:
    common.Usage(__doc__)
    sys.exit(1)

  common.InitLogging()

  input_zip = zipfile.ZipFile(args[0], "r")
  output_zip = zipfile.ZipFile(args[1], "w",
                               compression=zipfile.ZIP_DEFLATED,
                               allowZip64=True)

  misc_info = common.LoadInfoDict(input_zip)

  BuildKeyMap(misc_info, key_mapping_options)

  apk_keys_info, compressed_extension = common.ReadApkCerts(input_zip)
  apk_keys = GetApkCerts(apk_keys_info)

  apex_keys_info = ReadApexKeysInfo(input_zip)
  apex_keys = GetApexKeys(apex_keys_info, apk_keys)

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

  # Skip building userdata.img and cache.img when signing the target files.
  new_args = ["--is_signing"]
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
  except common.ExternalError as e:
    print("\n   ERROR: %s\n" % (e,))
    sys.exit(1)
  finally:
    common.Cleanup()
