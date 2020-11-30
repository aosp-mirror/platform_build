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
import zipfile

import ota_metadata_pb2
from common import (ZipDelete, ZipClose, OPTIONS, MakeTempFile,
                    ZipWriteStr, BuildInfo, LoadDictionaryFromFile,
                    SignFile, PARTITIONS_WITH_CARE_MAP, PartitionBuildProps,
                    MakeTempDir, RunAndCheckOutput, ExternalError)

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
UNZIP_PATTERN = ['IMAGES/*', 'META/*', 'OTA/*', 'RADIO/*']

# See sysprop.mk. If file is moved, add new search paths here; don't remove
# existing search paths.
RAMDISK_BUILD_PROP_REL_PATHS = ['system/etc/ramdisk/build.prop']

def FinalizeMetadata(metadata, input_file, output_file, needed_property_files):
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
    needed_property_files: The list of PropertyFiles' to be generated.
  """

  def ComputeAllPropertyFiles(input_file, needed_property_files):
    # Write the current metadata entry with placeholders.
    with zipfile.ZipFile(input_file, allowZip64=True) as input_zip:
      for property_files in needed_property_files:
        metadata.property_files[property_files.name] = property_files.Compute(
            input_zip)
      namelist = input_zip.namelist()

    if METADATA_NAME in namelist or METADATA_PROTO_NAME in namelist:
      ZipDelete(input_file, [METADATA_NAME, METADATA_PROTO_NAME])
    output_zip = zipfile.ZipFile(input_file, 'a', allowZip64=True)
    WriteMetadata(metadata, output_zip)
    ZipClose(output_zip)

    if OPTIONS.no_signing:
      return input_file

    prelim_signing = MakeTempFile(suffix='.zip')
    SignOutput(input_file, prelim_signing)
    return prelim_signing

  def FinalizeAllPropertyFiles(prelim_signing, needed_property_files):
    with zipfile.ZipFile(prelim_signing, allowZip64=True) as prelim_signing_zip:
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
  output_zip = zipfile.ZipFile(prelim_signing, 'a', allowZip64=True)
  WriteMetadata(metadata, output_zip)
  ZipClose(output_zip)

  # Re-sign the package after updating the metadata entry.
  if OPTIONS.no_signing:
    output_file = prelim_signing
  else:
    SignOutput(prelim_signing, output_file)

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

  with open('{}.pb'.format(output), 'w') as f:
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
    for partition in sorted(set(PARTITIONS_WITH_CARE_MAP) & ab_partitions):
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

  metadata_dict.update(metadata_proto.property_files)

  return metadata_dict


def HandleDowngradeMetadata(metadata_proto, target_info, source_info):
  # Only incremental OTAs are allowed to reach here.
  assert OPTIONS.incremental_source is not None

  post_timestamp = target_info.GetBuildProp("ro.build.date.utc")
  pre_timestamp = source_info.GetBuildProp("ro.build.date.utc")
  is_downgrade = int(post_timestamp) < int(pre_timestamp)

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
    for partition in PARTITIONS_WITH_CARE_MAP:
      partition_prop_key = "{}.build.prop".format(partition)
      input_file = info_dict[partition_prop_key].input_file
      if isinstance(input_file, zipfile.ZipFile):
        with zipfile.ZipFile(input_file.filename, allowZip64=True) as input_zip:
          info_dict[partition_prop_key] = \
              PartitionBuildProps.FromInputFile(input_zip, partition,
                                                placeholder_values)
      else:
        info_dict[partition_prop_key] = \
            PartitionBuildProps.FromInputFile(input_file, partition,
                                              placeholder_values)
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
      offset = info.header_offset
      offset += zipfile.sizeFileHeader
      offset += len(info.extra) + len(info.filename)
      size = info.file_size
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


def SignOutput(temp_zip_name, output_zip_name):
  pw = OPTIONS.key_passwords[OPTIONS.package_key]

  SignFile(temp_zip_name, output_zip_name, OPTIONS.package_key, pw,
           whole_file=True)


def GetBootImageTimestamp(boot_img):
  """
  Get timestamp from ramdisk within the boot image

  Args:
    boot_img: the boot image file. Ramdisk must be compressed with lz4 format.

  Return:
    An integer that corresponds to the timestamp of the boot image, or None
    if file has unknown format. Raise exception if an unexpected error has
    occurred.
  """

  tmp_dir = MakeTempDir('boot_', suffix='.img')
  try:
    RunAndCheckOutput(['unpack_bootimg', '--boot_img', boot_img, '--out', tmp_dir])
    ramdisk = os.path.join(tmp_dir, 'ramdisk')
    if not os.path.isfile(ramdisk):
      logger.warning('Unable to get boot image timestamp: no ramdisk in boot')
      return None
    uncompressed_ramdisk = os.path.join(tmp_dir, 'uncompressed_ramdisk')
    RunAndCheckOutput(['lz4', '-d', ramdisk, uncompressed_ramdisk])

    abs_uncompressed_ramdisk = os.path.abspath(uncompressed_ramdisk)
    extracted_ramdisk = MakeTempDir('extracted_ramdisk')
    # Use "toybox cpio" instead of "cpio" because the latter invokes cpio from
    # the host environment.
    RunAndCheckOutput(['toybox', 'cpio', '-F', abs_uncompressed_ramdisk, '-i'],
               cwd=extracted_ramdisk)

    prop_file = None
    for search_path in RAMDISK_BUILD_PROP_REL_PATHS:
      prop_file = os.path.join(extracted_ramdisk, search_path)
      if os.path.isfile(prop_file):
        break
      logger.warning('Unable to get boot image timestamp: no %s in ramdisk', search_path)

    if not prop_file:
      return None

    props = PartitionBuildProps.FromBuildPropFile('boot', prop_file)
    timestamp = props.GetProp('ro.bootimage.build.date.utc')
    if timestamp:
      return int(timestamp)
    logger.warning('Unable to get boot image timestamp: ro.bootimage.build.date.utc is undefined')
    return None

  except ExternalError as e:
    logger.warning('Unable to get boot image timestamp: %s', e)
    return None
