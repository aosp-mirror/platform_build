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

  --verify
      Remount and verify the checksums of the files written to the system and
      vendor (if used) partitions. Non-A/B incremental OTAs only.

  -o  (--oem_settings)  <main_file[,additional_files...]>
      Comma seperated list of files used to specify the expected OEM-specific
      properties on the OEM partition of the intended device. Multiple expected
      values can be used by providing multiple files. Only the first dict will
      be used to compute fingerprint, while the rest will be used to assert
      OEM-specific properties.

  --oem_no_mount
      For devices with OEM-specific properties but without an OEM partition,
      do not mount the OEM partition in the updater-script. This should be
      very rarely used, since it's expected to have a dedicated OEM partition
      for OEM-specific properties. Only meaningful when -o is specified.

  --wipe_user_data
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

import multiprocessing
import os.path
import shlex
import subprocess
import sys
import tempfile
import zipfile

import common
import edify_generator

if sys.hexversion < 0x02070000:
  print("Python 2.7 or newer is required.", file=sys.stderr)
  sys.exit(1)


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
OPTIONS.include_secondary = False
OPTIONS.no_signing = False
OPTIONS.block_based = True
OPTIONS.updater_binary = None
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
OPTIONS.extracted_input = None
OPTIONS.key_passwords = []

METADATA_NAME = 'META-INF/com/android/metadata'
UNZIP_PATTERN = ['IMAGES/*', 'META/*']


class BuildInfo(object):
  """A class that holds the information for a given build.

  This class wraps up the property querying for a given source or target build.
  It abstracts away the logic of handling OEM-specific properties, and caches
  the commonly used properties such as fingerprint.

  There are two types of info dicts: a) build-time info dict, which is generated
  at build time (i.e. included in a target_files zip); b) OEM info dict that is
  specified at package generation time (via command line argument
  '--oem_settings'). If a build doesn't use OEM-specific properties (i.e. not
  having "oem_fingerprint_properties" in build-time info dict), all the queries
  would be answered based on build-time info dict only. Otherwise if using
  OEM-specific properties, some of them will be calculated from two info dicts.

  Users can query properties similarly as using a dict() (e.g. info['fstab']),
  or to query build properties via GetBuildProp() or GetVendorBuildProp().

  Attributes:
    info_dict: The build-time info dict.
    is_ab: Whether it's a build that uses A/B OTA.
    oem_dicts: A list of OEM dicts.
    oem_props: A list of OEM properties that should be read from OEM dicts; None
        if the build doesn't use any OEM-specific property.
    fingerprint: The fingerprint of the build, which would be calculated based
        on OEM properties if applicable.
    device: The device name, which could come from OEM dicts if applicable.
  """

  def __init__(self, info_dict, oem_dicts):
    """Initializes a BuildInfo instance with the given dicts.

    Arguments:
      info_dict: The build-time info dict.
      oem_dicts: A list of OEM dicts (which is parsed from --oem_settings). Note
          that it always uses the first dict to calculate the fingerprint or the
          device name. The rest would be used for asserting OEM properties only
          (e.g.  one package can be installed on one of these devices).
    """
    self.info_dict = info_dict
    self.oem_dicts = oem_dicts

    self._is_ab = info_dict.get("ab_update") == "true"
    self._oem_props = info_dict.get("oem_fingerprint_properties")

    if self._oem_props:
      assert oem_dicts, "OEM source required for this build"

    # These two should be computed only after setting self._oem_props.
    self._device = self.GetOemProperty("ro.product.device")
    self._fingerprint = self.CalculateFingerprint()

  @property
  def is_ab(self):
    return self._is_ab

  @property
  def device(self):
    return self._device

  @property
  def fingerprint(self):
    return self._fingerprint

  @property
  def oem_props(self):
    return self._oem_props

  def __getitem__(self, key):
    return self.info_dict[key]

  def get(self, key, default=None):
    return self.info_dict.get(key, default)

  def GetBuildProp(self, prop):
    """Returns the inquired build property."""
    try:
      return self.info_dict.get("build.prop", {})[prop]
    except KeyError:
      raise common.ExternalError("couldn't find %s in build.prop" % (prop,))

  def GetVendorBuildProp(self, prop):
    """Returns the inquired vendor build property."""
    try:
      return self.info_dict.get("vendor.build.prop", {})[prop]
    except KeyError:
      raise common.ExternalError(
          "couldn't find %s in vendor.build.prop" % (prop,))

  def GetOemProperty(self, key):
    if self.oem_props is not None and key in self.oem_props:
      return self.oem_dicts[0][key]
    return self.GetBuildProp(key)

  def CalculateFingerprint(self):
    if self.oem_props is None:
      return self.GetBuildProp("ro.build.fingerprint")
    return "%s/%s/%s:%s" % (
        self.GetOemProperty("ro.product.brand"),
        self.GetOemProperty("ro.product.name"),
        self.GetOemProperty("ro.product.device"),
        self.GetBuildProp("ro.build.thumbprint"))

  def WriteMountOemScript(self, script):
    assert self.oem_props is not None
    recovery_mount_options = self.info_dict.get("recovery_mount_options")
    script.Mount("/oem", recovery_mount_options)

  def WriteDeviceAssertions(self, script, oem_no_mount):
    # Read the property directly if not using OEM properties.
    if not self.oem_props:
      script.AssertDevice(self.device)
      return

    # Otherwise assert OEM properties.
    if not self.oem_dicts:
      raise common.ExternalError(
          "No OEM file provided to answer expected assertions")

    for prop in self.oem_props.split():
      values = []
      for oem_dict in self.oem_dicts:
        if prop in oem_dict:
          values.append(oem_dict[prop])
      if not values:
        raise common.ExternalError(
            "The OEM file is missing the property %s" % (prop,))
      script.AssertOemProperty(prop, values, oem_no_mount)


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

      get_signing_key = common.Run(cmd, verbose=False, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT)
      stdoutdata, _ = get_signing_key.communicate()
      assert get_signing_key.returncode == 0, \
          "Failed to get signing key: {}".format(stdoutdata)

      self.signer = "openssl"
      self.signer_args = ["pkeyutl", "-sign", "-inkey", signing_key,
                          "-pkeyopt", "digest:sha256"]
    else:
      self.signer = OPTIONS.payload_signer
      self.signer_args = OPTIONS.payload_signer_args

  def Sign(self, in_file):
    """Signs the given input file. Returns the output filename."""
    out_file = common.MakeTempFile(prefix="signed-", suffix=".bin")
    cmd = [self.signer] + self.signer_args + ['-in', in_file, '-out', out_file]
    signing = common.Run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    stdoutdata, _ = signing.communicate()
    assert signing.returncode == 0, \
        "Failed to sign the input file: {}".format(stdoutdata)
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
    # The place where the output from the subprocess should go.
    self._log_file = sys.stdout if OPTIONS.verbose else subprocess.PIPE
    self.payload_file = None
    self.payload_properties = None
    self.secondary = secondary

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
    cmd.extend(additional_args)
    p = common.Run(cmd, stdout=self._log_file, stderr=subprocess.STDOUT)
    stdoutdata, _ = p.communicate()
    assert p.returncode == 0, \
        "brillo_update_payload generate failed: {}".format(stdoutdata)

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
           "--signature_size", "256",
           "--metadata_hash_file", metadata_sig_file,
           "--payload_hash_file", payload_sig_file]
    p1 = common.Run(cmd, stdout=self._log_file, stderr=subprocess.STDOUT)
    p1.communicate()
    assert p1.returncode == 0, "brillo_update_payload hash failed"

    # 2. Sign the hashes.
    signed_payload_sig_file = payload_signer.Sign(payload_sig_file)
    signed_metadata_sig_file = payload_signer.Sign(metadata_sig_file)

    # 3. Insert the signatures back into the payload file.
    signed_payload_file = common.MakeTempFile(prefix="signed-payload-",
                                              suffix=".bin")
    cmd = ["brillo_update_payload", "sign",
           "--unsigned_payload", self.payload_file,
           "--payload", signed_payload_file,
           "--signature_size", "256",
           "--metadata_signature_file", signed_metadata_sig_file,
           "--payload_signature_file", signed_payload_sig_file]
    p1 = common.Run(cmd, stdout=self._log_file, stderr=subprocess.STDOUT)
    p1.communicate()
    assert p1.returncode == 0, "brillo_update_payload sign failed"

    # 4. Dump the signed payload properties.
    properties_file = common.MakeTempFile(prefix="payload-properties-",
                                          suffix=".txt")
    cmd = ["brillo_update_payload", "properties",
           "--payload", signed_payload_file,
           "--properties_file", properties_file]
    p1 = common.Run(cmd, stdout=self._log_file, stderr=subprocess.STDOUT)
    p1.communicate()
    assert p1.returncode == 0, "brillo_update_payload properties failed"

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


def SignOutput(temp_zip_name, output_zip_name):
  pw = OPTIONS.key_passwords[OPTIONS.package_key]

  common.SignFile(temp_zip_name, output_zip_name, OPTIONS.package_key, pw,
                  whole_file=True)


def _LoadOemDicts(oem_source):
  """Returns the list of loaded OEM properties dict."""
  if not oem_source:
    return None

  oem_dicts = []
  for oem_file in oem_source:
    with open(oem_file) as fp:
      oem_dicts.append(common.LoadDictionaryFromLines(fp.readlines()))
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


def HasTrebleEnabled(target_files_zip, target_info):
  return (HasVendorPartition(target_files_zip) and
          target_info.GetBuildProp("ro.treble.enabled") == "true")


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


def AddCompatibilityArchiveIfTrebleEnabled(target_zip, output_zip, target_info,
                                           source_info=None):
  """Adds compatibility info into the output zip if it's Treble-enabled target.

  Metadata used for on-device compatibility verification is retrieved from
  target_zip then added to compatibility.zip which is added to the output_zip
  archive.

  Compatibility archive should only be included for devices that have enabled
  Treble support.

  Args:
    target_zip: Zip file containing the source files to be included for OTA.
    output_zip: Zip file that will be sent for OTA.
    target_info: The BuildInfo instance that holds the target build info.
    source_info: The BuildInfo instance that holds the source build info, if
        generating an incremental OTA; None otherwise.
  """

  def AddCompatibilityArchive(system_updated, vendor_updated):
    """Adds compatibility info based on system/vendor update status.

    Args:
      system_updated: If True, the system image will be updated and therefore
          its metadata should be included.
      vendor_updated: If True, the vendor image will be updated and therefore
          its metadata should be included.
    """
    # Determine what metadata we need. Files are names relative to META/.
    compatibility_files = []
    vendor_metadata = ("vendor_manifest.xml", "vendor_matrix.xml")
    system_metadata = ("system_manifest.xml", "system_matrix.xml")
    if vendor_updated:
      compatibility_files += vendor_metadata
    if system_updated:
      compatibility_files += system_metadata

    # Create new archive.
    compatibility_archive = tempfile.NamedTemporaryFile()
    compatibility_archive_zip = zipfile.ZipFile(
        compatibility_archive, "w", compression=zipfile.ZIP_DEFLATED)

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

  # Will only proceed if the target has enabled the Treble support (as well as
  # having a /vendor partition).
  if not HasTrebleEnabled(target_zip, target_info):
    return

  # We don't support OEM thumbprint in Treble world (which calculates
  # fingerprints in a different way as shown in CalculateFingerprint()).
  assert not target_info.oem_props

  # Full OTA carries the info for system/vendor both.
  if source_info is None:
    AddCompatibilityArchive(True, True)
    return

  assert not source_info.oem_props

  source_fp = source_info.fingerprint
  target_fp = target_info.fingerprint
  system_updated = source_fp != target_fp

  source_fp_vendor = source_info.GetVendorBuildProp(
      "ro.vendor.build.fingerprint")
  target_fp_vendor = target_info.GetVendorBuildProp(
      "ro.vendor.build.fingerprint")
  vendor_updated = source_fp_vendor != target_fp_vendor

  AddCompatibilityArchive(system_updated, vendor_updated)


def WriteFullOTAPackage(input_zip, output_zip):
  target_info = BuildInfo(OPTIONS.info_dict, OPTIONS.oem_dicts)

  # We don't know what version it will be installed on top of. We expect the API
  # just won't change very often. Similarly for fstab, it might have changed in
  # the target build.
  target_api_version = target_info["recovery_api_version"]
  script = edify_generator.EdifyGenerator(target_api_version, target_info)

  if target_info.oem_props and not OPTIONS.oem_no_mount:
    target_info.WriteMountOemScript(script)

  metadata = GetPackageMetadata(target_info)

  device_specific = common.DeviceSpecificParams(
      input_zip=input_zip,
      input_version=target_api_version,
      output_zip=output_zip,
      script=script,
      input_tmp=OPTIONS.input_tmp,
      metadata=metadata,
      info_dict=OPTIONS.info_dict)

  assert HasRecoveryPatch(input_zip)

  # Assertions (e.g. downgrade check, device properties check).
  ts = target_info.GetBuildProp("ro.build.date.utc")
  ts_text = target_info.GetBuildProp("ro.build.date")
  script.AssertOlderBuild(ts, ts_text)

  target_info.WriteDeviceAssertions(script, OPTIONS.oem_no_mount)
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

  system_progress = 0.75

  if OPTIONS.wipe_user_data:
    system_progress -= 0.1
  if HasVendorPartition(input_zip):
    system_progress -= 0.1

  script.ShowProgress(system_progress, 0)

  # See the notes in WriteBlockIncrementalOTAPackage().
  allow_shared_blocks = target_info.get('ext4_share_dup_blocks') == "true"

  # Full OTA is done as an "incremental" against an empty source image. This
  # has the effect of writing new data from the package to the entire
  # partition, but lets us reuse the updater code that writes incrementals to
  # do it.
  system_tgt = common.GetSparseImage("system", OPTIONS.input_tmp, input_zip,
                                     allow_shared_blocks)
  system_tgt.ResetFileMap()
  system_diff = common.BlockDifference("system", system_tgt, src=None)
  system_diff.WriteScript(script, output_zip)

  boot_img = common.GetBootableImage(
      "boot.img", "boot.img", OPTIONS.input_tmp, "BOOT")

  if HasVendorPartition(input_zip):
    script.ShowProgress(0.1, 0)

    vendor_tgt = common.GetSparseImage("vendor", OPTIONS.input_tmp, input_zip,
                                       allow_shared_blocks)
    vendor_tgt.ResetFileMap()
    vendor_diff = common.BlockDifference("vendor", vendor_tgt)
    vendor_diff.WriteScript(script, output_zip)

  AddCompatibilityArchiveIfTrebleEnabled(input_zip, output_zip, target_info)

  common.CheckSize(boot_img.data, "boot.img", target_info)
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


def WriteMetadata(metadata, output_zip):
  value = "".join(["%s=%s\n" % kv for kv in sorted(metadata.iteritems())])
  common.ZipWriteStr(output_zip, METADATA_NAME, value,
                     compress_type=zipfile.ZIP_STORED)


def HandleDowngradeMetadata(metadata, target_info, source_info):
  # Only incremental OTAs are allowed to reach here.
  assert OPTIONS.incremental_source is not None

  post_timestamp = target_info.GetBuildProp("ro.build.date.utc")
  pre_timestamp = source_info.GetBuildProp("ro.build.date.utc")
  is_downgrade = long(post_timestamp) < long(pre_timestamp)

  if OPTIONS.downgrade:
    if not is_downgrade:
      raise RuntimeError("--downgrade specified but no downgrade detected: "
                         "pre: %s, post: %s" % (pre_timestamp, post_timestamp))
    metadata["ota-downgrade"] = "yes"
  elif OPTIONS.timestamp:
    if not is_downgrade:
      raise RuntimeError("--override_timestamp specified but no timestamp hack "
                         "needed: pre: %s, post: %s" % (pre_timestamp,
                                                        post_timestamp))
    metadata["post-timestamp"] = str(long(pre_timestamp) + 1)
  else:
    if is_downgrade:
      raise RuntimeError("Downgrade detected based on timestamp check: "
                         "pre: %s, post: %s. Need to specify "
                         "--override_timestamp OR --downgrade to allow "
                         "building the incremental." % (pre_timestamp,
                                                        post_timestamp))
    metadata["post-timestamp"] = post_timestamp


def GetPackageMetadata(target_info, source_info=None):
  """Generates and returns the metadata dict.

  It generates a dict() that contains the info to be written into an OTA
  package (META-INF/com/android/metadata). It also handles the detection of
  downgrade / timestamp override / data wipe based on the global options.

  Args:
    target_info: The BuildInfo instance that holds the target build info.
    source_info: The BuildInfo instance that holds the source build info, or
        None if generating full OTA.

  Returns:
    A dict to be written into package metadata entry.
  """
  assert isinstance(target_info, BuildInfo)
  assert source_info is None or isinstance(source_info, BuildInfo)

  metadata = {
      'post-build' : target_info.fingerprint,
      'post-build-incremental' : target_info.GetBuildProp(
          'ro.build.version.incremental'),
      'post-sdk-level' : target_info.GetBuildProp(
          'ro.build.version.sdk'),
      'post-security-patch-level' : target_info.GetBuildProp(
          'ro.build.version.security_patch'),
  }

  if target_info.is_ab:
    metadata['ota-type'] = 'AB'
    metadata['ota-required-cache'] = '0'
  else:
    metadata['ota-type'] = 'BLOCK'

  if OPTIONS.wipe_user_data:
    metadata['ota-wipe'] = 'yes'

  is_incremental = source_info is not None
  if is_incremental:
    metadata['pre-build'] = source_info.fingerprint
    metadata['pre-build-incremental'] = source_info.GetBuildProp(
        'ro.build.version.incremental')
    metadata['pre-device'] = source_info.device
  else:
    metadata['pre-device'] = target_info.device

  # Detect downgrades, or fill in the post-timestamp.
  if is_incremental:
    HandleDowngradeMetadata(metadata, target_info, source_info)
  else:
    metadata['post-timestamp'] = target_info.GetBuildProp('ro.build.date.utc')

  return metadata


def WriteBlockIncrementalOTAPackage(target_zip, source_zip, output_zip):
  target_info = BuildInfo(OPTIONS.target_info_dict, OPTIONS.oem_dicts)
  source_info = BuildInfo(OPTIONS.source_info_dict, OPTIONS.oem_dicts)

  target_api_version = target_info["recovery_api_version"]
  source_api_version = source_info["recovery_api_version"]
  if source_api_version == 0:
    print("WARNING: generating edify script for a source that "
          "can't install it.")

  script = edify_generator.EdifyGenerator(
      source_api_version, target_info, fstab=source_info["fstab"])

  if target_info.oem_props or source_info.oem_props:
    if not OPTIONS.oem_no_mount:
      source_info.WriteMountOemScript(script)

  metadata = GetPackageMetadata(target_info, source_info)

  device_specific = common.DeviceSpecificParams(
      source_zip=source_zip,
      source_version=source_api_version,
      target_zip=target_zip,
      target_version=target_api_version,
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

  # When target uses 'BOARD_EXT4_SHARE_DUP_BLOCKS := true', images may contain
  # shared blocks (i.e. some blocks will show up in multiple files' block
  # list). We can only allocate such shared blocks to the first "owner", and
  # disable imgdiff for all later occurrences.
  allow_shared_blocks = (source_info.get('ext4_share_dup_blocks') == "true" or
                         target_info.get('ext4_share_dup_blocks') == "true")
  system_src = common.GetSparseImage("system", OPTIONS.source_tmp, source_zip,
                                     allow_shared_blocks)
  system_tgt = common.GetSparseImage("system", OPTIONS.target_tmp, target_zip,
                                     allow_shared_blocks)

  blockimgdiff_version = max(
      int(i) for i in target_info.get("blockimgdiff_versions", "1").split(","))
  assert blockimgdiff_version >= 3

  # Check the first block of the source system partition for remount R/W only
  # if the filesystem is ext4.
  system_src_partition = source_info["fstab"]["/system"]
  check_first_block = system_src_partition.fs_type == "ext4"
  # Disable using imgdiff for squashfs. 'imgdiff -z' expects input files to be
  # in zip formats. However with squashfs, a) all files are compressed in LZ4;
  # b) the blocks listed in block map may not contain all the bytes for a given
  # file (because they're rounded to be 4K-aligned).
  system_tgt_partition = target_info["fstab"]["/system"]
  disable_imgdiff = (system_src_partition.fs_type == "squashfs" or
                     system_tgt_partition.fs_type == "squashfs")
  system_diff = common.BlockDifference("system", system_tgt, system_src,
                                       check_first_block,
                                       version=blockimgdiff_version,
                                       disable_imgdiff=disable_imgdiff)

  if HasVendorPartition(target_zip):
    if not HasVendorPartition(source_zip):
      raise RuntimeError("can't generate incremental that adds /vendor")
    vendor_src = common.GetSparseImage("vendor", OPTIONS.source_tmp, source_zip,
                                       allow_shared_blocks)
    vendor_tgt = common.GetSparseImage("vendor", OPTIONS.target_tmp, target_zip,
                                       allow_shared_blocks)

    # Check first block of vendor partition for remount R/W only if
    # disk type is ext4
    vendor_partition = source_info["fstab"]["/vendor"]
    check_first_block = vendor_partition.fs_type == "ext4"
    disable_imgdiff = vendor_partition.fs_type == "squashfs"
    vendor_diff = common.BlockDifference("vendor", vendor_tgt, vendor_src,
                                         check_first_block,
                                         version=blockimgdiff_version,
                                         disable_imgdiff=disable_imgdiff)
  else:
    vendor_diff = None

  AddCompatibilityArchiveIfTrebleEnabled(
      target_zip, output_zip, target_info, source_info)

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
    bcb_dev = {"bcb_dev" : fs.device}
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
  size = []
  if system_diff:
    size.append(system_diff.required_cache)
  if vendor_diff:
    size.append(vendor_diff.required_cache)

  if updating_boot:
    boot_type, boot_device = common.GetTypeAndDevice("/boot", source_info)
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


def GetTargetFilesZipForSecondaryImages(input_file):
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

  Returns:
    The filename of the target-files.zip for generating secondary payload.
  """
  target_file = common.MakeTempFile(prefix="targetfiles-", suffix=".zip")
  target_zip = zipfile.ZipFile(target_file, 'w', allowZip64=True)

  input_tmp, input_zip = common.UnzipTemp(input_file, UNZIP_PATTERN)
  for info in input_zip.infolist():
    unzipped_file = os.path.join(input_tmp, *info.filename.split('/'))
    if info.filename == 'IMAGES/system_other.img':
      common.ZipWrite(target_zip, unzipped_file, arcname='IMAGES/system.img')

    # Primary images and friends need to be skipped explicitly.
    elif info.filename in ('IMAGES/system.img',
                           'IMAGES/system.map'):
      pass

    elif info.filename.startswith(('META/', 'IMAGES/')):
      common.ZipWrite(target_zip, unzipped_file, arcname=info.filename)

  common.ZipClose(input_zip)
  common.ZipClose(target_zip)

  return target_file


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

  # Stage the output zip package for package signing.
  temp_zip_file = tempfile.NamedTemporaryFile()
  output_zip = zipfile.ZipFile(temp_zip_file, "w",
                               compression=zipfile.ZIP_DEFLATED)

  if source_file is not None:
    target_info = BuildInfo(OPTIONS.target_info_dict, OPTIONS.oem_dicts)
    source_info = BuildInfo(OPTIONS.source_info_dict, OPTIONS.oem_dicts)
  else:
    target_info = BuildInfo(OPTIONS.info_dict, OPTIONS.oem_dicts)
    source_info = None

  # Metadata to comply with Android OTA package format.
  metadata = GetPackageMetadata(target_info, source_info)

  # Generate payload.
  payload = Payload()
  payload.Generate(target_file, source_file)

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
    secondary_target_file = GetTargetFilesZipForSecondaryImages(target_file)
    secondary_payload = Payload(secondary=True)
    secondary_payload.Generate(secondary_target_file)
    secondary_payload.Sign(payload_signer)
    secondary_payload.WriteToZip(output_zip)

  # If dm-verity is supported for the device, copy contents of care_map
  # into A/B OTA package.
  target_zip = zipfile.ZipFile(target_file, "r")
  if (target_info.get("verity") == "true" or
      target_info.get("avb_enable") == "true"):
    care_map_path = "META/care_map.txt"
    namelist = target_zip.namelist()
    if care_map_path in namelist:
      care_map_data = target_zip.read(care_map_path)
      # In order to support streaming, care_map.txt needs to be packed as
      # ZIP_STORED.
      common.ZipWriteStr(output_zip, "care_map.txt", care_map_data,
                         compress_type=zipfile.ZIP_STORED)
    else:
      print("Warning: cannot find care map file in target_file package")

  # source_info must be None for full OTAs.
  if source_file is None:
    assert source_info is None

  AddCompatibilityArchiveIfTrebleEnabled(
      target_zip, output_zip, target_info, source_info)

  common.ZipClose(target_zip)

  # Write the current metadata entry with placeholders.
  metadata['ota-streaming-property-files'] = ComputeStreamingMetadata(
      output_zip, reserve_space=True)
  WriteMetadata(metadata, output_zip)
  common.ZipClose(output_zip)

  # SignOutput(), which in turn calls signapk.jar, will possibly reorder the
  # ZIP entries, as well as padding the entry headers. We do a preliminary
  # signing (with an incomplete metadata entry) to allow that to happen. Then
  # compute the ZIP entry offsets, write back the final metadata and do the
  # final signing.
  prelim_signing = common.MakeTempFile(suffix='.zip')
  SignOutput(temp_zip_file.name, prelim_signing)
  common.ZipClose(temp_zip_file)

  # Open the signed zip. Compute the final metadata that's needed for streaming.
  prelim_signing_zip = zipfile.ZipFile(prelim_signing, 'r')
  expected_length = len(metadata['ota-streaming-property-files'])
  metadata['ota-streaming-property-files'] = ComputeStreamingMetadata(
      prelim_signing_zip, reserve_space=False, expected_length=expected_length)
  common.ZipClose(prelim_signing_zip)

  # Replace the METADATA entry.
  common.ZipDelete(prelim_signing, METADATA_NAME)
  output_zip = zipfile.ZipFile(prelim_signing, 'a',
                               compression=zipfile.ZIP_DEFLATED)
  WriteMetadata(metadata, output_zip)
  common.ZipClose(output_zip)

  # Re-sign the package after updating the metadata entry.
  SignOutput(prelim_signing, output_file)

  # Reopen the final signed zip to double check the streaming metadata.
  output_zip = zipfile.ZipFile(output_file, 'r')
  actual = metadata['ota-streaming-property-files'].strip()
  expected = ComputeStreamingMetadata(output_zip)
  assert actual == expected, \
      "Mismatching streaming metadata: %s vs %s." % (actual, expected)
  common.ZipClose(output_zip)


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
    elif o == "--extracted_input_target_files":
      OPTIONS.extracted_input = a
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
    with zipfile.ZipFile(args[0], 'r') as input_zip:
      OPTIONS.info_dict = common.LoadInfoDict(input_zip)

  if OPTIONS.verbose:
    print("--- target info ---")
    common.DumpInfoDict(OPTIONS.info_dict)

  # Load the source build dict if applicable.
  if OPTIONS.incremental_source is not None:
    OPTIONS.target_info_dict = OPTIONS.info_dict
    with zipfile.ZipFile(OPTIONS.incremental_source, 'r') as source_zip:
      OPTIONS.source_info_dict = common.LoadInfoDict(source_zip)

    if OPTIONS.verbose:
      print("--- source info ---")
      common.DumpInfoDict(OPTIONS.source_info_dict)

  # Load OEM dicts if provided.
  OPTIONS.oem_dicts = _LoadOemDicts(OPTIONS.oem_source)

  ab_update = OPTIONS.info_dict.get("ab_update") == "true"

  # Use the default key to sign the package if not specified with package_key.
  # package_keys are needed on ab_updates, so always define them if an
  # ab_update is getting created.
  if not OPTIONS.no_signing or ab_update:
    if OPTIONS.package_key is None:
      OPTIONS.package_key = OPTIONS.info_dict.get(
          "default_system_dev_certificate",
          "build/target/product/security/testkey")
    # Get signing keys
    OPTIONS.key_passwords = common.GetKeyPasswords([OPTIONS.package_key])

  if ab_update:
    WriteABOTAPackageWithBrilloScript(
        target_file=args[0],
        output_file=args[1],
        source_file=OPTIONS.incremental_source)

    print("done.")
    return

  # Sanity check the loaded info dicts first.
  if OPTIONS.info_dict.get("no_recovery") == "true":
    raise common.ExternalError(
        "--- target build has specified no recovery ---")

  # Non-A/B OTAs rely on /cache partition to store temporary files.
  cache_size = OPTIONS.info_dict.get("cache_size")
  if cache_size is None:
    print("--- can't determine the cache partition size ---")
  OPTIONS.cache_size = cache_size

  if OPTIONS.extra_script is not None:
    OPTIONS.extra_script = open(OPTIONS.extra_script).read()

  if OPTIONS.extracted_input is not None:
    OPTIONS.input_tmp = OPTIONS.extracted_input
    input_zip = zipfile.ZipFile(args[0], "r")
  else:
    print("unzipping target target-files...")
    OPTIONS.input_tmp, input_zip = common.UnzipTemp(
        args[0], UNZIP_PATTERN)
  OPTIONS.target_tmp = OPTIONS.input_tmp

  # If the caller explicitly specified the device-specific extensions path via
  # -s / --device_specific, use that. Otherwise, use META/releasetools.py if it
  # is present in the target target_files. Otherwise, take the path of the file
  # from 'tool_extensions' in the info dict and look for that in the local
  # filesystem, relative to the current directory.
  if OPTIONS.device_specific is None:
    from_input = os.path.join(OPTIONS.input_tmp, "META", "releasetools.py")
    if os.path.exists(from_input):
      print("(using device-specific extensions from target_files)")
      OPTIONS.device_specific = from_input
    else:
      OPTIONS.device_specific = OPTIONS.info_dict.get("tool_extensions")

  if OPTIONS.device_specific is not None:
    OPTIONS.device_specific = os.path.abspath(OPTIONS.device_specific)

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

  # Generate a full OTA.
  if OPTIONS.incremental_source is None:
    WriteFullOTAPackage(input_zip, output_zip)

  # Generate an incremental OTA.
  else:
    print("unzipping source target-files...")
    OPTIONS.source_tmp, source_zip = common.UnzipTemp(
        OPTIONS.incremental_source,
        UNZIP_PATTERN)

    WriteBlockIncrementalOTAPackage(input_zip, source_zip, output_zip)

    if OPTIONS.log_diff:
      with open(OPTIONS.log_diff, 'w') as out_file:
        import target_files_diff
        target_files_diff.recursiveDiff(
            '', OPTIONS.source_tmp, OPTIONS.input_tmp, out_file)

  common.ZipClose(input_zip)
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
