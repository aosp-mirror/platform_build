# Copyright (C) 2022 The Android Open Source Project
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

import argparse
import logging
import struct
import sys
import update_payload
import tempfile
import zipfile
import os
import care_map_pb2

import common
from typing import BinaryIO, List
from update_metadata_pb2 import DeltaArchiveManifest, DynamicPartitionMetadata, DynamicPartitionGroup
from ota_metadata_pb2 import OtaMetadata
from update_payload import Payload

from payload_signer import PayloadSigner
from ota_utils import PayloadGenerator, METADATA_PROTO_NAME, FinalizeMetadata
from ota_signing_utils import AddSigningArgumentParse

logger = logging.getLogger(__name__)

CARE_MAP_ENTRY = "care_map.pb"
APEX_INFO_ENTRY = "apex_info.pb"


def WriteDataBlob(payload: Payload, outfp: BinaryIO, read_size=1024*64):
  for i in range(0, payload.total_data_length, read_size):
    blob = payload.ReadDataBlob(
        i, min(i+read_size, payload.total_data_length)-i)
    outfp.write(blob)


def ConcatBlobs(payloads: List[Payload], outfp: BinaryIO):
  for payload in payloads:
    WriteDataBlob(payload, outfp)


def TotalDataLength(partitions):
  for partition in reversed(partitions):
    for op in reversed(partition.operations):
      if op.data_length > 0:
        return op.data_offset + op.data_length
  return 0


def ExtendPartitionUpdates(partitions, new_partitions):
  prefix_blob_length = TotalDataLength(partitions)
  partitions.extend(new_partitions)
  for part in partitions[-len(new_partitions):]:
    for op in part.operations:
      if op.HasField("data_length") and op.data_length != 0:
        op.data_offset += prefix_blob_length


class DuplicatePartitionError(ValueError):
  pass


def MergeDynamicPartitionGroups(groups: List[DynamicPartitionGroup], new_groups: List[DynamicPartitionGroup]):
  new_groups = {new_group.name: new_group for new_group in new_groups}
  for group in groups:
    if group.name not in new_groups:
      continue
    new_group = new_groups[group.name]
    common_partitions = set(group.partition_names).intersection(
        set(new_group.partition_names))
    if len(common_partitions) != 0:
      raise DuplicatePartitionError(
          f"Old group and new group should not have any intersections, {group.partition_names}, {new_group.partition_names}, common partitions: {common_partitions}")
    group.partition_names.extend(new_group.partition_names)
    group.size = max(new_group.size, group.size)
    del new_groups[group.name]
  for new_group in new_groups.values():
    groups.append(new_group)


def MergeDynamicPartitionMetadata(metadata: DynamicPartitionMetadata, new_metadata: DynamicPartitionMetadata):
  MergeDynamicPartitionGroups(metadata.groups, new_metadata.groups)
  metadata.snapshot_enabled &= new_metadata.snapshot_enabled
  metadata.vabc_enabled &= new_metadata.vabc_enabled
  assert metadata.vabc_compression_param == new_metadata.vabc_compression_param, f"{metadata.vabc_compression_param} vs. {new_metadata.vabc_compression_param}"
  metadata.cow_version = max(metadata.cow_version, new_metadata.cow_version)


def MergeManifests(payloads: List[Payload]) -> DeltaArchiveManifest:
  if len(payloads) == 0:
    return None
  if len(payloads) == 1:
    return payloads[0].manifest

  output_manifest = DeltaArchiveManifest()
  output_manifest.block_size = payloads[0].manifest.block_size
  output_manifest.partial_update = True
  output_manifest.dynamic_partition_metadata.snapshot_enabled = payloads[
      0].manifest.dynamic_partition_metadata.snapshot_enabled
  output_manifest.dynamic_partition_metadata.vabc_enabled = payloads[
      0].manifest.dynamic_partition_metadata.vabc_enabled
  output_manifest.dynamic_partition_metadata.vabc_compression_param = payloads[
      0].manifest.dynamic_partition_metadata.vabc_compression_param
  apex_info = {}
  for payload in payloads:
    manifest = payload.manifest
    assert manifest.block_size == output_manifest.block_size
    output_manifest.minor_version = max(
        output_manifest.minor_version, manifest.minor_version)
    output_manifest.max_timestamp = max(
        output_manifest.max_timestamp, manifest.max_timestamp)
    output_manifest.apex_info.extend(manifest.apex_info)
    for apex in manifest.apex_info:
      apex_info[apex.package_name] = apex
    ExtendPartitionUpdates(output_manifest.partitions, manifest.partitions)
    try:
      MergeDynamicPartitionMetadata(
          output_manifest.dynamic_partition_metadata, manifest.dynamic_partition_metadata)
    except DuplicatePartitionError:
      logger.error(
          "OTA %s has duplicate partition with some of the previous OTAs", payload.name)
      raise

  for apex_name in sorted(apex_info.keys()):
    output_manifest.apex_info.extend(apex_info[apex_name])

  return output_manifest


def MergePayloads(payloads: List[Payload]):
  with tempfile.NamedTemporaryFile(prefix="payload_blob") as tmpfile:
    ConcatBlobs(payloads, tmpfile)


def MergeCareMap(paths: List[str]):
  care_map = care_map_pb2.CareMap()
  for path in paths:
    with zipfile.ZipFile(path, "r", allowZip64=True) as zfp:
      if CARE_MAP_ENTRY in zfp.namelist():
        care_map_bytes = zfp.read(CARE_MAP_ENTRY)
        partial_care_map = care_map_pb2.CareMap()
        partial_care_map.ParseFromString(care_map_bytes)
        care_map.partitions.extend(partial_care_map.partitions)
  if len(care_map.partitions) == 0:
    return b""
  return care_map.SerializeToString()


def WriteHeaderAndManifest(manifest: DeltaArchiveManifest, fp: BinaryIO):
  __MAGIC = b"CrAU"
  __MAJOR_VERSION = 2
  manifest_bytes = manifest.SerializeToString()
  fp.write(struct.pack(f">4sQQL", __MAGIC,
           __MAJOR_VERSION, len(manifest_bytes), 0))
  fp.write(manifest_bytes)


def AddOtaMetadata(input_ota, metadata_ota, output_ota, package_key, pw):
  with zipfile.ZipFile(metadata_ota, 'r') as zfp:
    metadata = OtaMetadata()
    metadata.ParseFromString(zfp.read(METADATA_PROTO_NAME))
    FinalizeMetadata(metadata, input_ota, output_ota,
                     package_key=package_key, pw=pw)
    return output_ota


def CheckOutput(output_ota):
  payload = update_payload.Payload(output_ota)
  payload.CheckOpDataHash()


def CheckDuplicatePartitions(payloads: List[Payload]):
  partition_to_ota = {}
  for payload in payloads:
    for group in payload.manifest.dynamic_partition_metadata.groups:
      for part in group.partition_names:
        if part in partition_to_ota:
          raise DuplicatePartitionError(
              f"OTA {partition_to_ota[part].name} and {payload.name} have duplicating partition {part}")
        partition_to_ota[part] = payload


def ApexInfo(file_paths):
  if len(file_paths) > 1:
    logger.info("More than one target file specified, will ignore "
                "apex_info.pb (if any)")
    return None
  with zipfile.ZipFile(file_paths[0], "r", allowZip64=True) as zfp:
    if APEX_INFO_ENTRY in zfp.namelist():
      apex_info_bytes = zfp.read(APEX_INFO_ENTRY)
      return apex_info_bytes
  return None


def main(argv):
  parser = argparse.ArgumentParser(description='Merge multiple partial OTAs')
  parser.add_argument('packages', type=str, nargs='+',
                      help='Paths to OTA packages to merge')
  parser.add_argument('--output', type=str,
                      help='Paths to output merged ota', required=True)
  parser.add_argument('--metadata_ota', type=str,
                      help='Output zip will use build metadata from this OTA package, if unspecified, use the last OTA package in merge list')
  parser.add_argument('-v', action="store_true",
                      help="Enable verbose logging", dest="verbose")
  AddSigningArgumentParse(parser)

  parser.epilog = ('This tool can also be used to resign a regular OTA. For a single regular OTA, '
                   'apex_info.pb will be written to output. When merging multiple OTAs, '
                   'apex_info.pb will not be written.')
  args = parser.parse_args(argv[1:])
  file_paths = args.packages

  common.OPTIONS.verbose = args.verbose
  if args.verbose:
    logger.setLevel(logging.INFO)

  logger.info(args)
  if args.search_path:
    common.OPTIONS.search_path = args.search_path

  metadata_ota = args.packages[-1]
  if args.metadata_ota is not None:
    metadata_ota = args.metadata_ota
    assert os.path.exists(metadata_ota)

  payloads = [Payload(path) for path in file_paths]

  CheckDuplicatePartitions(payloads)

  merged_manifest = MergeManifests(payloads)

  # Get signing keys
  key_passwords = common.GetKeyPasswords([args.package_key])

  apex_info_bytes = ApexInfo(file_paths)

  with tempfile.NamedTemporaryFile() as unsigned_payload:
    WriteHeaderAndManifest(merged_manifest, unsigned_payload)
    ConcatBlobs(payloads, unsigned_payload)
    unsigned_payload.flush()

    generator = PayloadGenerator()
    generator.payload_file = unsigned_payload.name
    logger.info("Payload size: %d", os.path.getsize(generator.payload_file))

    if args.package_key:
      logger.info("Signing payload...")
      # TODO: remove OPTIONS when no longer used as fallback in payload_signer
      common.OPTIONS.payload_signer_args = None
      common.OPTIONS.payload_signer_maximum_signature_size = None
      signer = PayloadSigner(args.package_key, args.private_key_suffix,
                             key_passwords[args.package_key],
                             payload_signer=args.payload_signer,
                             payload_signer_args=args.payload_signer_args,
                             payload_signer_maximum_signature_size=args.payload_signer_maximum_signature_size)
      generator.payload_file = unsigned_payload.name
      generator.Sign(signer)

    logger.info("Payload size: %d", os.path.getsize(generator.payload_file))

    logger.info("Writing to %s", args.output)

    key_passwords = common.GetKeyPasswords([args.package_key])
    with tempfile.NamedTemporaryFile(prefix="signed_ota", suffix=".zip") as signed_ota:
      with zipfile.ZipFile(signed_ota, "w") as zfp:
        generator.WriteToZip(zfp)
        care_map_bytes = MergeCareMap(args.packages)
        if care_map_bytes:
          common.ZipWriteStr(zfp, CARE_MAP_ENTRY, care_map_bytes)
        if apex_info_bytes:
          logger.info("Writing %s", APEX_INFO_ENTRY)
          common.ZipWriteStr(zfp, APEX_INFO_ENTRY, apex_info_bytes)
      AddOtaMetadata(signed_ota.name, metadata_ota,
                     args.output, args.package_key, key_passwords[args.package_key])
  return 0


if __name__ == '__main__':
  logging.basicConfig()
  sys.exit(main(sys.argv))
