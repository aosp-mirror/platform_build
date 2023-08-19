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

import copy
import itertools
import logging
import os
import shutil
import struct
import zipfile

import ota_metadata_pb2
import common
import fnmatch
from common import (ZipDelete, DoesInputFileContain, ReadBytesFromInputFile, OPTIONS, MakeTempFile,
                    ZipWriteStr, BuildInfo, LoadDictionaryFromFile,
                    SignFile, PARTITIONS_WITH_BUILD_PROP, PartitionBuildProps,
                    GetRamdiskFormat, ParseUpdateEngineConfig)
from payload_signer import PayloadSigner


logger = logging.getLogger(__name__)

OPTIONS.no_signing = False
OPTIONS.force_non_ab = False
OPTIONS.wipe_user_data = False
OPTIONS.downgrade = False
OPTIONS.key_passwords = {}
OPTIONS.package_key = None
OPTIONS.incremental_source = None
OPTIONS.retrofit_dynamic_partitions = False
OPTIONS.output_metadata_path = None
OPTIONS.boot_variable_file = None

METADATA_NAME = 'META-INF/com/android/metadata'
METADATA_PROTO_NAME = 'META-INF/com/android/metadata.pb'
UNZIP_PATTERN = ['IMAGES/*', 'META/*', 'OTA/*',
                 'RADIO/*', '*/build.prop', '*/default.prop', '*/build.default', "*/etc/vintf/*"]
SECURITY_PATCH_LEVEL_PROP_NAME = "ro.build.version.security_patch"


# Key is the compression algorithm, value is minimum API level required to
# use this compression algorithm for VABC OTA on device.
VABC_COMPRESSION_PARAM_SUPPORT = {
    "gz": 31,
    "brotli": 31,
    "none": 31,
    # lz4 support is added in Android U
    "lz4": 34,
    # zstd support is added in Android V
    "zstd": 35,
}


def FinalizeMetadata(metadata, input_file, output_file, needed_property_files=None, package_key=None, pw=None):
  """Finalizes the metadata and signs an A/B OTA package.

  In order to stream an A/B OTA package, we need 'ota-streaming-property-files'
  that contains the offsets and sizes for the ZIP entries. An example
  property-files string is as follows.

    "payload.bin:679:343,payload_properties.txt:378:45,metadata:69:379"

  OTA server can pass down this string, in addition to the package URL, to the
  system update client. System update client can then fetch individual ZIP
  entries (ZIP_STORED) directly at the given offset of the URL.

  Args:
    metadata: The metadata dict for the package.
    input_file: The input ZIP filename that doesn't contain the package METADATA
        entry yet.
    output_file: The final output ZIP filename.
    needed_property_files: The list of PropertyFiles' to be generated. Default is [AbOtaPropertyFiles(), StreamingPropertyFiles()]
    package_key: The key used to sign this OTA package
    pw: Password for the package_key
  """
  no_signing = package_key is None

  if needed_property_files is None:
    # AbOtaPropertyFiles intends to replace StreamingPropertyFiles, as it covers
    # all the info of the latter. However, system updaters and OTA servers need to
    # take time to switch to the new flag. We keep both of the flags for
    # P-timeframe, and will remove StreamingPropertyFiles in later release.
    needed_property_files = (
        AbOtaPropertyFiles(),
        StreamingPropertyFiles(),
    )

  def ComputeAllPropertyFiles(input_file, needed_property_files):
    # Write the current metadata entry with placeholders.
    with zipfile.ZipFile(input_file, 'r', allowZip64=True) as input_zip:
      for property_files in needed_property_files:
        metadata.property_files[property_files.name] = property_files.Compute(
            input_zip)

    ZipDelete(input_file, [METADATA_NAME, METADATA_PROTO_NAME], True)
    with zipfile.ZipFile(input_file, 'a', allowZip64=True) as output_zip:
      WriteMetadata(metadata, output_zip)

    if no_signing:
      return input_file

    prelim_signing = MakeTempFile(suffix='.zip')
    SignOutput(input_file, prelim_signing, package_key, pw)
    return prelim_signing

  def FinalizeAllPropertyFiles(prelim_signing, needed_property_files):
    with zipfile.ZipFile(prelim_signing, 'r', allowZip64=True) as prelim_signing_zip:
      for property_files in needed_property_files:
        metadata.property_files[property_files.name] = property_files.Finalize(
            prelim_signing_zip,
            len(metadata.property_files[property_files.name]))

  # SignOutput(), which in turn calls signapk.jar, will possibly reorder the ZIP
  # entries, as well as padding the entry headers. We do a preliminary signing
  # (with an incomplete metadata entry) to allow that to happen. Then compute
  # the ZIP entry offsets, write back the final metadata and do the final
  # signing.
  prelim_signing = ComputeAllPropertyFiles(input_file, needed_property_files)
  try:
    FinalizeAllPropertyFiles(prelim_signing, needed_property_files)
  except PropertyFiles.InsufficientSpaceException:
    # Even with the preliminary signing, the entry orders may change
    # dramatically, which leads to insufficiently reserved space during the
    # first call to ComputeAllPropertyFiles(). In that case, we redo all the
    # preliminary signing works, based on the already ordered ZIP entries, to
    # address the issue.
    prelim_signing = ComputeAllPropertyFiles(
        prelim_signing, needed_property_files)
    FinalizeAllPropertyFiles(prelim_signing, needed_property_files)

  # Replace the METADATA entry.
  ZipDelete(prelim_signing, [METADATA_NAME, METADATA_PROTO_NAME])
  with zipfile.ZipFile(prelim_signing, 'a', allowZip64=True) as output_zip:
    WriteMetadata(metadata, output_zip)

  # Re-sign the package after updating the metadata entry.
  if no_signing:
    logger.info(f"Signing disabled for output file {output_file}")
    shutil.copy(prelim_signing, output_file)
  else:
    logger.info(
        f"Signing the output file {output_file} with key {package_key}")
    SignOutput(prelim_signing, output_file, package_key, pw)

  # Reopen the final signed zip to double check the streaming metadata.
  with zipfile.ZipFile(output_file, allowZip64=True) as output_zip:
    for property_files in needed_property_files:
      property_files.Verify(
          output_zip, metadata.property_files[property_files.name].strip())

  # If requested, dump the metadata to a separate file.
  output_metadata_path = OPTIONS.output_metadata_path
  if output_metadata_path:
    WriteMetadata(metadata, output_metadata_path)


def WriteMetadata(metadata_proto, output):
  """Writes the metadata to the zip archive or a file.

  Args:
    metadata_proto: The metadata protobuf for the package.
    output: A ZipFile object or a string of the output file path. If a string
      path is given, the metadata in the protobuf format will be written to
      {output}.pb, e.g. ota_metadata.pb
  """

  metadata_dict = BuildLegacyOtaMetadata(metadata_proto)
  legacy_metadata = "".join(["%s=%s\n" % kv for kv in
                             sorted(metadata_dict.items())])
  if isinstance(output, zipfile.ZipFile):
    ZipWriteStr(output, METADATA_PROTO_NAME, metadata_proto.SerializeToString(),
                compress_type=zipfile.ZIP_STORED)
    ZipWriteStr(output, METADATA_NAME, legacy_metadata,
                compress_type=zipfile.ZIP_STORED)
    return

  with open('{}.pb'.format(output), 'wb') as f:
    f.write(metadata_proto.SerializeToString())
  with open(output, 'w') as f:
    f.write(legacy_metadata)


def UpdateDeviceState(device_state, build_info, boot_variable_values,
                      is_post_build):
  """Update the fields of the DeviceState proto with build info."""

  def UpdatePartitionStates(partition_states):
    """Update the per-partition state according to its build.prop"""
    if not build_info.is_ab:
      return
    build_info_set = ComputeRuntimeBuildInfos(build_info,
                                              boot_variable_values)
    assert "ab_partitions" in build_info.info_dict,\
        "ab_partitions property required for ab update."
    ab_partitions = set(build_info.info_dict.get("ab_partitions"))

    # delta_generator will error out on unused timestamps,
    # so only generate timestamps for dynamic partitions
    # used in OTA update.
    for partition in sorted(set(PARTITIONS_WITH_BUILD_PROP) & ab_partitions):
      partition_prop = build_info.info_dict.get(
          '{}.build.prop'.format(partition))
      # Skip if the partition is missing, or it doesn't have a build.prop
      if not partition_prop or not partition_prop.build_props:
        continue

      partition_state = partition_states.add()
      partition_state.partition_name = partition
      # Update the partition's runtime device names and fingerprints
      partition_devices = set()
      partition_fingerprints = set()
      for runtime_build_info in build_info_set:
        partition_devices.add(
            runtime_build_info.GetPartitionBuildProp('ro.product.device',
                                                     partition))
        partition_fingerprints.add(
            runtime_build_info.GetPartitionFingerprint(partition))

      partition_state.device.extend(sorted(partition_devices))
      partition_state.build.extend(sorted(partition_fingerprints))

      # TODO(xunchang) set the boot image's version with kmi. Note the boot
      # image doesn't have a file map.
      partition_state.version = build_info.GetPartitionBuildProp(
          'ro.build.date.utc', partition)

  # TODO(xunchang), we can save a call to ComputeRuntimeBuildInfos.
  build_devices, build_fingerprints = \
      CalculateRuntimeDevicesAndFingerprints(build_info, boot_variable_values)
  device_state.device.extend(sorted(build_devices))
  device_state.build.extend(sorted(build_fingerprints))
  device_state.build_incremental = build_info.GetBuildProp(
      'ro.build.version.incremental')

  UpdatePartitionStates(device_state.partition_state)

  if is_post_build:
    device_state.sdk_level = build_info.GetBuildProp(
        'ro.build.version.sdk')
    device_state.security_patch_level = build_info.GetBuildProp(
        'ro.build.version.security_patch')
    # Use the actual post-timestamp, even for a downgrade case.
    device_state.timestamp = int(build_info.GetBuildProp('ro.build.date.utc'))


def GetPackageMetadata(target_info, source_info=None):
  """Generates and returns the metadata proto.

  It generates a ota_metadata protobuf that contains the info to be written
  into an OTA package (META-INF/com/android/metadata.pb). It also handles the
  detection of downgrade / data wipe based on the global options.

  Args:
    target_info: The BuildInfo instance that holds the target build info.
    source_info: The BuildInfo instance that holds the source build info, or
        None if generating full OTA.

  Returns:
    A protobuf to be written into package metadata entry.
  """
  assert isinstance(target_info, BuildInfo)
  assert source_info is None or isinstance(source_info, BuildInfo)

  boot_variable_values = {}
  if OPTIONS.boot_variable_file:
    d = LoadDictionaryFromFile(OPTIONS.boot_variable_file)
    for key, values in d.items():
      boot_variable_values[key] = [val.strip() for val in values.split(',')]

  metadata_proto = ota_metadata_pb2.OtaMetadata()
  # TODO(xunchang) some fields, e.g. post-device isn't necessary. We can
  # consider skipping them if they aren't used by clients.
  UpdateDeviceState(metadata_proto.postcondition, target_info,
                    boot_variable_values, True)

  if target_info.is_ab and not OPTIONS.force_non_ab:
    metadata_proto.type = ota_metadata_pb2.OtaMetadata.AB
    metadata_proto.required_cache = 0
  else:
    metadata_proto.type = ota_metadata_pb2.OtaMetadata.BLOCK
    # cache requirement will be updated by the non-A/B codes.

  if OPTIONS.wipe_user_data:
    metadata_proto.wipe = True

  if OPTIONS.retrofit_dynamic_partitions:
    metadata_proto.retrofit_dynamic_partitions = True

  is_incremental = source_info is not None
  if is_incremental:
    UpdateDeviceState(metadata_proto.precondition, source_info,
                      boot_variable_values, False)
  else:
    metadata_proto.precondition.device.extend(
        metadata_proto.postcondition.device)

  # Detect downgrades and set up downgrade flags accordingly.
  if is_incremental:
    HandleDowngradeMetadata(metadata_proto, target_info, source_info)

  return metadata_proto


def BuildLegacyOtaMetadata(metadata_proto):
  """Converts the metadata proto to a legacy metadata dict.

  This metadata dict is used to build the legacy metadata text file for
  backward compatibility. We won't add new keys to the legacy metadata format.
  If new information is needed, we should add it as a new field in OtaMetadata
  proto definition.
  """

  separator = '|'

  metadata_dict = {}
  if metadata_proto.type == ota_metadata_pb2.OtaMetadata.AB:
    metadata_dict['ota-type'] = 'AB'
  elif metadata_proto.type == ota_metadata_pb2.OtaMetadata.BLOCK:
    metadata_dict['ota-type'] = 'BLOCK'
  if metadata_proto.wipe:
    metadata_dict['ota-wipe'] = 'yes'
  if metadata_proto.retrofit_dynamic_partitions:
    metadata_dict['ota-retrofit-dynamic-partitions'] = 'yes'
  if metadata_proto.downgrade:
    metadata_dict['ota-downgrade'] = 'yes'

  metadata_dict['ota-required-cache'] = str(metadata_proto.required_cache)

  post_build = metadata_proto.postcondition
  metadata_dict['post-build'] = separator.join(post_build.build)
  metadata_dict['post-build-incremental'] = post_build.build_incremental
  metadata_dict['post-sdk-level'] = post_build.sdk_level
  metadata_dict['post-security-patch-level'] = post_build.security_patch_level
  metadata_dict['post-timestamp'] = str(post_build.timestamp)

  pre_build = metadata_proto.precondition
  metadata_dict['pre-device'] = separator.join(pre_build.device)
  # incremental updates
  if len(pre_build.build) != 0:
    metadata_dict['pre-build'] = separator.join(pre_build.build)
    metadata_dict['pre-build-incremental'] = pre_build.build_incremental

  if metadata_proto.spl_downgrade:
    metadata_dict['spl-downgrade'] = 'yes'
  metadata_dict.update(metadata_proto.property_files)

  return metadata_dict


def HandleDowngradeMetadata(metadata_proto, target_info, source_info):
  # Only incremental OTAs are allowed to reach here.
  assert OPTIONS.incremental_source is not None

  post_timestamp = target_info.GetBuildProp("ro.build.date.utc")
  pre_timestamp = source_info.GetBuildProp("ro.build.date.utc")
  is_downgrade = int(post_timestamp) < int(pre_timestamp)

  if OPTIONS.spl_downgrade:
    metadata_proto.spl_downgrade = True

  if OPTIONS.downgrade:
    if not is_downgrade:
      raise RuntimeError(
          "--downgrade or --override_timestamp specified but no downgrade "
          "detected: pre: %s, post: %s" % (pre_timestamp, post_timestamp))
    metadata_proto.downgrade = True
  else:
    if is_downgrade:
      raise RuntimeError(
          "Downgrade detected based on timestamp check: pre: %s, post: %s. "
          "Need to specify --override_timestamp OR --downgrade to allow "
          "building the incremental." % (pre_timestamp, post_timestamp))


def ComputeRuntimeBuildInfos(default_build_info, boot_variable_values):
  """Returns a set of build info objects that may exist during runtime."""

  build_info_set = {default_build_info}
  if not boot_variable_values:
    return build_info_set

  # Calculate all possible combinations of the values for the boot variables.
  keys = boot_variable_values.keys()
  value_list = boot_variable_values.values()
  combinations = [dict(zip(keys, values))
                  for values in itertools.product(*value_list)]
  for placeholder_values in combinations:
    # Reload the info_dict as some build properties may change their values
    # based on the value of ro.boot* properties.
    info_dict = copy.deepcopy(default_build_info.info_dict)
    for partition in PARTITIONS_WITH_BUILD_PROP:
      partition_prop_key = "{}.build.prop".format(partition)
      input_file = info_dict[partition_prop_key].input_file
      ramdisk = GetRamdiskFormat(info_dict)
      if isinstance(input_file, zipfile.ZipFile):
        with zipfile.ZipFile(input_file.filename, allowZip64=True) as input_zip:
          info_dict[partition_prop_key] = \
              PartitionBuildProps.FromInputFile(input_zip, partition,
                                                placeholder_values,
                                                ramdisk)
      else:
        info_dict[partition_prop_key] = \
            PartitionBuildProps.FromInputFile(input_file, partition,
                                              placeholder_values,
                                              ramdisk)
    info_dict["build.prop"] = info_dict["system.build.prop"]
    build_info_set.add(BuildInfo(info_dict, default_build_info.oem_dicts))

  return build_info_set


def CalculateRuntimeDevicesAndFingerprints(default_build_info,
                                           boot_variable_values):
  """Returns a tuple of sets for runtime devices and fingerprints"""

  device_names = set()
  fingerprints = set()
  build_info_set = ComputeRuntimeBuildInfos(default_build_info,
                                            boot_variable_values)
  for runtime_build_info in build_info_set:
    device_names.add(runtime_build_info.device)
    fingerprints.add(runtime_build_info.fingerprint)
  return device_names, fingerprints


def GetZipEntryOffset(zfp, entry_info):
  """Get offset to a beginning of a particular zip entry
  Args:
    fp: zipfile.ZipFile
    entry_info: zipfile.ZipInfo

  Returns:
    (offset, size) tuple
  """
  # Don't use len(entry_info.extra). Because that returns size of extra
  # fields in central directory. We need to look at local file directory,
  # as these two might have different sizes.

  # We cannot work with zipfile.ZipFile instances, we need a |fp| for the underlying file.
  zfp = zfp.fp
  zfp.seek(entry_info.header_offset)
  data = zfp.read(zipfile.sizeFileHeader)
  fheader = struct.unpack(zipfile.structFileHeader, data)
  # Last two fields of local file header are filename length and
  # extra length
  filename_len = fheader[-2]
  extra_len = fheader[-1]
  offset = entry_info.header_offset
  offset += zipfile.sizeFileHeader
  offset += filename_len + extra_len
  size = entry_info.file_size
  return (offset, size)


class PropertyFiles(object):
  """A class that computes the property-files string for an OTA package.

  A property-files string is a comma-separated string that contains the
  offset/size info for an OTA package. The entries, which must be ZIP_STORED,
  can be fetched directly with the package URL along with the offset/size info.
  These strings can be used for streaming A/B OTAs, or allowing an updater to
  download package metadata entry directly, without paying the cost of
  downloading entire package.

  Computing the final property-files string requires two passes. Because doing
  the whole package signing (with signapk.jar) will possibly reorder the ZIP
  entries, which may in turn invalidate earlier computed ZIP entry offset/size
  values.

  This class provides functions to be called for each pass. The general flow is
  as follows.

    property_files = PropertyFiles()
    # The first pass, which writes placeholders before doing initial signing.
    property_files.Compute()
    SignOutput()

    # The second pass, by replacing the placeholders with actual data.
    property_files.Finalize()
    SignOutput()

  And the caller can additionally verify the final result.

    property_files.Verify()
  """

  def __init__(self):
    self.name = None
    self.required = ()
    self.optional = ()

  def Compute(self, input_zip):
    """Computes and returns a property-files string with placeholders.

    We reserve extra space for the offset and size of the metadata entry itself,
    although we don't know the final values until the package gets signed.

    Args:
      input_zip: The input ZIP file.

    Returns:
      A string with placeholders for the metadata offset/size info, e.g.
      "payload.bin:679:343,payload_properties.txt:378:45,metadata:        ".
    """
    return self.GetPropertyFilesString(input_zip, reserve_space=True)

  class InsufficientSpaceException(Exception):
    pass

  def Finalize(self, input_zip, reserved_length):
    """Finalizes a property-files string with actual METADATA offset/size info.

    The input ZIP file has been signed, with the ZIP entries in the desired
    place (signapk.jar will possibly reorder the ZIP entries). Now we compute
    the ZIP entry offsets and construct the property-files string with actual
    data. Note that during this process, we must pad the property-files string
    to the reserved length, so that the METADATA entry size remains the same.
    Otherwise the entries' offsets and sizes may change again.

    Args:
      input_zip: The input ZIP file.
      reserved_length: The reserved length of the property-files string during
          the call to Compute(). The final string must be no more than this
          size.

    Returns:
      A property-files string including the metadata offset/size info, e.g.
      "payload.bin:679:343,payload_properties.txt:378:45,metadata:69:379  ".

    Raises:
      InsufficientSpaceException: If the reserved length is insufficient to hold
          the final string.
    """
    result = self.GetPropertyFilesString(input_zip, reserve_space=False)
    if len(result) > reserved_length:
      raise self.InsufficientSpaceException(
          'Insufficient reserved space: reserved={}, actual={}'.format(
              reserved_length, len(result)))

    result += ' ' * (reserved_length - len(result))
    return result

  def Verify(self, input_zip, expected):
    """Verifies the input ZIP file contains the expected property-files string.

    Args:
      input_zip: The input ZIP file.
      expected: The property-files string that's computed from Finalize().

    Raises:
      AssertionError: On finding a mismatch.
    """
    actual = self.GetPropertyFilesString(input_zip)
    assert actual == expected, \
        "Mismatching streaming metadata: {} vs {}.".format(actual, expected)

  def GetPropertyFilesString(self, zip_file, reserve_space=False):
    """
    Constructs the property-files string per request.

    Args:
      zip_file: The input ZIP file.
      reserved_length: The reserved length of the property-files string.

    Returns:
      A property-files string including the metadata offset/size info, e.g.
      "payload.bin:679:343,payload_properties.txt:378:45,metadata:     ".
    """

    def ComputeEntryOffsetSize(name):
      """Computes the zip entry offset and size."""
      info = zip_file.getinfo(name)
      (offset, size) = GetZipEntryOffset(zip_file, info)
      return '%s:%d:%d' % (os.path.basename(name), offset, size)

    tokens = []
    tokens.extend(self._GetPrecomputed(zip_file))
    for entry in self.required:
      tokens.append(ComputeEntryOffsetSize(entry))
    for entry in self.optional:
      if entry in zip_file.namelist():
        tokens.append(ComputeEntryOffsetSize(entry))

    # 'META-INF/com/android/metadata' is required. We don't know its actual
    # offset and length (as well as the values for other entries). So we reserve
    # 15-byte as a placeholder ('offset:length'), which is sufficient to cover
    # the space for metadata entry. Because 'offset' allows a max of 10-digit
    # (i.e. ~9 GiB), with a max of 4-digit for the length. Note that all the
    # reserved space serves the metadata entry only.
    if reserve_space:
      tokens.append('metadata:' + ' ' * 15)
      tokens.append('metadata.pb:' + ' ' * 15)
    else:
      tokens.append(ComputeEntryOffsetSize(METADATA_NAME))
      if METADATA_PROTO_NAME in zip_file.namelist():
        tokens.append(ComputeEntryOffsetSize(METADATA_PROTO_NAME))

    return ','.join(tokens)

  def _GetPrecomputed(self, input_zip):
    """Computes the additional tokens to be included into the property-files.

    This applies to tokens without actual ZIP entries, such as
    payload_metadata.bin. We want to expose the offset/size to updaters, so
    that they can download the payload metadata directly with the info.

    Args:
      input_zip: The input zip file.

    Returns:
      A list of strings (tokens) to be added to the property-files string.
    """
    # pylint: disable=no-self-use
    # pylint: disable=unused-argument
    return []


def SignOutput(temp_zip_name, output_zip_name, package_key=None, pw=None):
  if package_key is None:
    package_key = OPTIONS.package_key
  if pw is None and OPTIONS.key_passwords:
    pw = OPTIONS.key_passwords[package_key]

  SignFile(temp_zip_name, output_zip_name, package_key, pw,
           whole_file=True)


def ConstructOtaApexInfo(target_zip, source_file=None):
  """If applicable, add the source version to the apex info."""

  def _ReadApexInfo(input_zip):
    if not DoesInputFileContain(input_zip, "META/apex_info.pb"):
      logger.warning("target_file doesn't contain apex_info.pb %s", input_zip)
      return None
    return ReadBytesFromInputFile(input_zip, "META/apex_info.pb")

  target_apex_string = _ReadApexInfo(target_zip)
  # Return early if the target apex info doesn't exist or is empty.
  if not target_apex_string:
    return target_apex_string

  # If the source apex info isn't available, just return the target info
  if not source_file:
    return target_apex_string

  source_apex_string = _ReadApexInfo(source_file)
  if not source_apex_string:
    return target_apex_string

  source_apex_proto = ota_metadata_pb2.ApexMetadata()
  source_apex_proto.ParseFromString(source_apex_string)
  source_apex_versions = {apex.package_name: apex.version for apex in
                          source_apex_proto.apex_info}

  # If the apex package is available in the source build, initialize the source
  # apex version.
  target_apex_proto = ota_metadata_pb2.ApexMetadata()
  target_apex_proto.ParseFromString(target_apex_string)
  for target_apex in target_apex_proto.apex_info:
    name = target_apex.package_name
    if name in source_apex_versions:
      target_apex.source_version = source_apex_versions[name]

  return target_apex_proto.SerializeToString()


def IsLz4diffCompatible(source_file: str, target_file: str):
  """Check whether lz4diff versions in two builds are compatible

  Args:
    source_file: Path to source build's target_file.zip
    target_file: Path to target build's target_file.zip

  Returns:
    bool true if and only if lz4diff versions are compatible
  """
  if source_file is None or target_file is None:
    return False
  # Right now we enable lz4diff as long as source build has liblz4.so.
  # In the future we might introduce version system to lz4diff as well.
  if zipfile.is_zipfile(source_file):
    with zipfile.ZipFile(source_file, "r") as zfp:
      return "META/liblz4.so" in zfp.namelist()
  else:
    assert os.path.isdir(source_file)
    return os.path.exists(os.path.join(source_file, "META", "liblz4.so"))


def IsZucchiniCompatible(source_file: str, target_file: str):
  """Check whether zucchini versions in two builds are compatible

  Args:
    source_file: Path to source build's target_file.zip
    target_file: Path to target build's target_file.zip

  Returns:
    bool true if and only if zucchini versions are compatible
  """
  if source_file is None or target_file is None:
    return False
  assert os.path.exists(source_file)
  assert os.path.exists(target_file)

  assert zipfile.is_zipfile(source_file) or os.path.isdir(source_file)
  assert zipfile.is_zipfile(target_file) or os.path.isdir(target_file)
  _ZUCCHINI_CONFIG_ENTRY_NAME = "META/zucchini_config.txt"

  def ReadEntry(path, entry):
    # Read an entry inside a .zip file or extracted dir of .zip file
    if zipfile.is_zipfile(path):
      with zipfile.ZipFile(path, "r", allowZip64=True) as zfp:
        if entry in zfp.namelist():
          return zfp.read(entry).decode()
    else:
      entry_path = os.path.join(path, entry)
      if os.path.exists(entry_path):
        with open(entry_path, "r") as fp:
          return fp.read()
    return False
  sourceEntry = ReadEntry(source_file, _ZUCCHINI_CONFIG_ENTRY_NAME)
  targetEntry = ReadEntry(target_file, _ZUCCHINI_CONFIG_ENTRY_NAME)
  return sourceEntry and targetEntry and sourceEntry == targetEntry


def ExtractTargetFiles(path: str):
  if os.path.isdir(path):
    logger.info("target files %s is already extracted", path)
    return path
  extracted_dir = common.MakeTempDir("target_files")
  common.UnzipToDir(path, extracted_dir, UNZIP_PATTERN + [""])
  return extracted_dir


def LocatePartitionPath(target_files_dir: str, partition: str, allow_empty):
  path = os.path.join(target_files_dir, "RADIO", partition + ".img")
  if os.path.exists(path):
    return path
  path = os.path.join(target_files_dir, "IMAGES", partition + ".img")
  if os.path.exists(path):
    return path
  if allow_empty:
    return ""
  raise common.ExternalError(
      "Partition {} not found in target files {}".format(partition, target_files_dir))


def GetPartitionImages(target_files_dir: str, ab_partitions, allow_empty=True):
  assert os.path.isdir(target_files_dir)
  return ":".join([LocatePartitionPath(target_files_dir, partition, allow_empty) for partition in ab_partitions])


def LocatePartitionMap(target_files_dir: str, partition: str):
  path = os.path.join(target_files_dir, "RADIO", partition + ".map")
  if os.path.exists(path):
    return path
  return ""


def GetPartitionMaps(target_files_dir: str, ab_partitions):
  assert os.path.isdir(target_files_dir)
  return ":".join([LocatePartitionMap(target_files_dir, partition) for partition in ab_partitions])


class PayloadGenerator(object):
  """Manages the creation and the signing of an A/B OTA Payload."""

  PAYLOAD_BIN = 'payload.bin'
  PAYLOAD_PROPERTIES_TXT = 'payload_properties.txt'
  SECONDARY_PAYLOAD_BIN = 'secondary/payload.bin'
  SECONDARY_PAYLOAD_PROPERTIES_TXT = 'secondary/payload_properties.txt'

  def __init__(self, secondary=False, wipe_user_data=False, minor_version=None, is_partial_update=False):
    """Initializes a Payload instance.

    Args:
      secondary: Whether it's generating a secondary payload (default: False).
    """
    self.payload_file = None
    self.payload_properties = None
    self.secondary = secondary
    self.wipe_user_data = wipe_user_data
    self.minor_version = minor_version
    self.is_partial_update = is_partial_update

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
          delta_generator binary; or None.
    """
    if additional_args is None:
      additional_args = []

    payload_file = common.MakeTempFile(prefix="payload-", suffix=".bin")
    target_dir = ExtractTargetFiles(target_file)
    cmd = ["delta_generator",
           "--out_file", payload_file]
    with open(os.path.join(target_dir, "META", "ab_partitions.txt")) as fp:
      ab_partitions = fp.read().strip().split("\n")
    cmd.extend(["--partition_names", ":".join(ab_partitions)])
    cmd.extend(
        ["--new_partitions", GetPartitionImages(target_dir, ab_partitions, False)])
    cmd.extend(
        ["--new_mapfiles", GetPartitionMaps(target_dir, ab_partitions)])
    if source_file is not None:
      source_dir = ExtractTargetFiles(source_file)
      cmd.extend(
          ["--old_partitions", GetPartitionImages(source_dir, ab_partitions, True)])
      cmd.extend(
          ["--old_mapfiles", GetPartitionMaps(source_dir, ab_partitions)])

      if OPTIONS.disable_fec_computation:
        cmd.extend(["--disable_fec_computation=true"])
      if OPTIONS.disable_verity_computation:
        cmd.extend(["--disable_verity_computation=true"])
    postinstall_config = os.path.join(
        target_dir, "META", "postinstall_config.txt")

    if os.path.exists(postinstall_config):
      cmd.extend(["--new_postinstall_config_file", postinstall_config])
    dynamic_partition_info = os.path.join(
        target_dir, "META", "dynamic_partitions_info.txt")

    if os.path.exists(dynamic_partition_info):
      cmd.extend(["--dynamic_partition_info_file", dynamic_partition_info])

    major_version, minor_version = ParseUpdateEngineConfig(
        os.path.join(target_dir, "META", "update_engine_config.txt"))
    if source_file:
      major_version, minor_version = ParseUpdateEngineConfig(
          os.path.join(source_dir, "META", "update_engine_config.txt"))
    if self.minor_version:
      minor_version = self.minor_version
    cmd.extend(["--major_version", str(major_version)])
    if source_file is not None or self.is_partial_update:
      cmd.extend(["--minor_version", str(minor_version)])
    if self.is_partial_update:
      cmd.extend(["--is_partial_update=true"])
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
    signed_payload_sig_file = payload_signer.SignHashFile(payload_sig_file)
    signed_metadata_sig_file = payload_signer.SignHashFile(metadata_sig_file)

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

    self.payload_file = signed_payload_file

  def WriteToZip(self, output_zip):
    """Writes the payload to the given zip.

    Args:
      output_zip: The output ZipFile instance.
    """
    assert self.payload_file is not None
    # 4. Dump the signed payload properties.
    properties_file = common.MakeTempFile(prefix="payload-properties-",
                                          suffix=".txt")
    cmd = ["brillo_update_payload", "properties",
           "--payload", self.payload_file,
           "--properties_file", properties_file]
    self._Run(cmd)

    if self.secondary:
      with open(properties_file, "a") as f:
        f.write("SWITCH_SLOT_ON_REBOOT=0\n")

    if self.wipe_user_data:
      with open(properties_file, "a") as f:
        f.write("POWERWASH=1\n")

    self.payload_properties = properties_file

    if self.secondary:
      payload_arcname = PayloadGenerator.SECONDARY_PAYLOAD_BIN
      payload_properties_arcname = PayloadGenerator.SECONDARY_PAYLOAD_PROPERTIES_TXT
    else:
      payload_arcname = PayloadGenerator.PAYLOAD_BIN
      payload_properties_arcname = PayloadGenerator.PAYLOAD_PROPERTIES_TXT

    # Add the signed payload file and properties into the zip. In order to
    # support streaming, we pack them as ZIP_STORED. So these entries can be
    # read directly with the offset and length pairs.
    common.ZipWrite(output_zip, self.payload_file, arcname=payload_arcname,
                    compress_type=zipfile.ZIP_STORED)
    common.ZipWrite(output_zip, self.payload_properties,
                    arcname=payload_properties_arcname,
                    compress_type=zipfile.ZIP_STORED)


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
        # apex_info.pb isn't directly used in the update flow
        'apex_info.pb',
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
    (payload_offset, payload_size) = GetZipEntryOffset(input_zip, payload_info)

    # Read the underlying raw zipfile at specified offset
    payload_fp = input_zip.fp
    payload_fp.seek(payload_offset)
    header_bin = payload_fp.read(24)

    # network byte order (big-endian)
    header = struct.unpack("!IQQL", header_bin)

    # 'CrAU'
    magic = header[0]
    assert magic == 0x43724155, "Invalid magic: {:x}, computed offset {}" \
        .format(magic, payload_offset)

    manifest_size = header[2]
    metadata_signature_size = header[3]
    metadata_total = 24 + manifest_size + metadata_signature_size
    assert metadata_total <= payload_size

    return (payload_offset, metadata_total)


def Fnmatch(filename, pattersn):
  return any([fnmatch.fnmatch(filename, pat) for pat in pattersn])


def CopyTargetFilesDir(input_dir):
  output_dir = common.MakeTempDir("target_files")
  shutil.copytree(os.path.join(input_dir, "IMAGES"), os.path.join(
      output_dir, "IMAGES"), dirs_exist_ok=True)
  shutil.copytree(os.path.join(input_dir, "META"), os.path.join(
      output_dir, "META"), dirs_exist_ok=True)
  for (dirpath, _, filenames) in os.walk(input_dir):
    for filename in filenames:
      path = os.path.join(dirpath, filename)
      relative_path = path.removeprefix(input_dir).removeprefix("/")
      if not Fnmatch(relative_path, UNZIP_PATTERN):
        continue
      if filename.endswith(".prop") or filename == "prop.default" or "/etc/vintf/" in relative_path:
        target_path = os.path.join(
            output_dir, relative_path)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        shutil.copy(path, target_path)
  return output_dir
