#!/usr/bin/env python
# Copyright (C) 2017 The Android Open Source Project
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
import sys
import traceback
import zipfile

from rangelib import RangeSet

class Stash(object):
  """Build a map to track stashed blocks during update simulation."""

  def __init__(self):
    self.blocks_stashed = 0
    self.overlap_blocks_stashed = 0
    self.max_stash_needed = 0
    self.current_stash_size = 0
    self.stash_map = {}

  def StashBlocks(self, SHA1, blocks):
    if SHA1 in self.stash_map:
      logging.info("already stashed {}: {}".format(SHA1, blocks))
      return
    self.blocks_stashed += blocks.size()
    self.current_stash_size += blocks.size()
    self.max_stash_needed = max(self.current_stash_size, self.max_stash_needed)
    self.stash_map[SHA1] = blocks

  def FreeBlocks(self, SHA1):
    assert self.stash_map.has_key(SHA1), "stash {} not found".format(SHA1)
    self.current_stash_size -= self.stash_map[SHA1].size()
    del self.stash_map[SHA1]

  def HandleOverlapBlocks(self, SHA1, blocks):
    self.StashBlocks(SHA1, blocks)
    self.overlap_blocks_stashed += blocks.size()
    self.FreeBlocks(SHA1)


class OtaPackageParser(object):
  """Parse a block-based OTA package."""

  def __init__(self, package):
    self.package = package
    self.new_data_size = 0
    self.patch_data_size = 0
    self.block_written = 0
    self.block_stashed = 0

  @staticmethod
  def GetSizeString(size):
    assert size >= 0
    base = 1024.0
    if size <= base:
      return "{} bytes".format(size)
    for units in ['K', 'M', 'G']:
      if size <= base * 1024 or units == 'G':
        return "{:.1f}{}".format(size / base, units)
      base *= 1024

  def ParseTransferList(self, name):
    """Simulate the transfer commands and calculate the amout of I/O."""

    logging.info("\nSimulating commands in '{}':".format(name))
    lines = self.package.read(name).strip().splitlines()
    assert len(lines) >= 4, "{} is too short; Transfer list expects at least" \
        "4 lines, it has {}".format(name, len(lines))
    assert int(lines[0]) >= 3
    logging.info("(version: {})".format(lines[0]))

    blocks_written = 0
    my_stash = Stash()
    for line in lines[4:]:
      cmd_list = line.strip().split(" ")
      cmd_name = cmd_list[0]
      try:
        if cmd_name == "new" or cmd_name == "zero":
          assert len(cmd_list) == 2, "command format error: {}".format(line)
          target_range = RangeSet.parse_raw(cmd_list[1])
          blocks_written += target_range.size()
        elif cmd_name == "move":
          # Example:  move <onehash> <tgt_range> <src_blk_count> <src_range>
          # [<loc_range> <stashed_blocks>]
          assert len(cmd_list) >= 5, "command format error: {}".format(line)
          target_range = RangeSet.parse_raw(cmd_list[2])
          blocks_written += target_range.size()
          if cmd_list[4] == '-':
            continue
          SHA1 = cmd_list[1]
          source_range = RangeSet.parse_raw(cmd_list[4])
          if target_range.overlaps(source_range):
            my_stash.HandleOverlapBlocks(SHA1, source_range)
        elif cmd_name == "bsdiff" or cmd_name == "imgdiff":
          # Example:  bsdiff <offset> <len> <src_hash> <tgt_hash> <tgt_range>
          # <src_blk_count> <src_range> [<loc_range> <stashed_blocks>]
          assert len(cmd_list) >= 8, "command format error: {}".format(line)
          target_range = RangeSet.parse_raw(cmd_list[5])
          blocks_written += target_range.size()
          if cmd_list[7] == '-':
            continue
          source_SHA1 = cmd_list[3]
          source_range = RangeSet.parse_raw(cmd_list[7])
          if target_range.overlaps(source_range):
            my_stash.HandleOverlapBlocks(source_SHA1, source_range)
        elif cmd_name == "stash":
          assert len(cmd_list) == 3, "command format error: {}".format(line)
          SHA1 = cmd_list[1]
          source_range = RangeSet.parse_raw(cmd_list[2])
          my_stash.StashBlocks(SHA1, source_range)
        elif cmd_name == "free":
          assert len(cmd_list) == 2, "command format error: {}".format(line)
          SHA1 = cmd_list[1]
          my_stash.FreeBlocks(SHA1)
      except:
        logging.error("failed to parse command in: " + line)
        raise

    self.block_written += blocks_written
    self.block_stashed += my_stash.blocks_stashed

    logging.info("blocks written: {}  (expected: {})".format(
        blocks_written, lines[1]))
    logging.info("max blocks stashed simultaneously: {}  (expected: {})".
        format(my_stash.max_stash_needed, lines[3]))
    logging.info("total blocks stashed: {}".format(my_stash.blocks_stashed))
    logging.info("blocks stashed implicitly: {}".format(
        my_stash.overlap_blocks_stashed))

  def PrintDataInfo(self, partition):
    logging.info("\nReading data info for {} partition:".format(partition))
    new_data = self.package.getinfo(partition + ".new.dat")
    patch_data = self.package.getinfo(partition + ".patch.dat")
    logging.info("{:<40}{:<40}".format(new_data.filename, patch_data.filename))
    logging.info("{:<40}{:<40}".format(
          "compress_type: " + str(new_data.compress_type),
          "compress_type: " + str(patch_data.compress_type)))
    logging.info("{:<40}{:<40}".format(
          "compressed_size: " + OtaPackageParser.GetSizeString(
              new_data.compress_size),
          "compressed_size: " + OtaPackageParser.GetSizeString(
              patch_data.compress_size)))
    logging.info("{:<40}{:<40}".format(
        "file_size: " + OtaPackageParser.GetSizeString(new_data.file_size),
        "file_size: " + OtaPackageParser.GetSizeString(patch_data.file_size)))

    self.new_data_size += new_data.file_size
    self.patch_data_size += patch_data.file_size

  def AnalyzePartition(self, partition):
    assert partition in ("system", "vendor")
    assert partition + ".new.dat" in self.package.namelist()
    assert partition + ".patch.dat" in self.package.namelist()
    assert partition + ".transfer.list" in self.package.namelist()

    self.PrintDataInfo(partition)
    self.ParseTransferList(partition + ".transfer.list")

  def PrintMetadata(self):
    metadata_path = "META-INF/com/android/metadata"
    logging.info("\nMetadata info:")
    metadata_info = {}
    for line in self.package.read(metadata_path).strip().splitlines():
      index = line.find("=")
      metadata_info[line[0 : index].strip()] = line[index + 1:].strip()
    assert metadata_info.get("ota-type") == "BLOCK"
    assert "pre-device" in metadata_info
    logging.info("device: {}".format(metadata_info["pre-device"]))
    if "pre-build" in metadata_info:
      logging.info("pre-build: {}".format(metadata_info["pre-build"]))
    assert "post-build" in metadata_info
    logging.info("post-build: {}".format(metadata_info["post-build"]))

  def Analyze(self):
    logging.info("Analyzing ota package: " + self.package.filename)
    self.PrintMetadata()
    assert "system.new.dat" in self.package.namelist()
    self.AnalyzePartition("system")
    if "vendor.new.dat" in self.package.namelist():
      self.AnalyzePartition("vendor")

    #TODO Add analysis of other partitions(e.g. bootloader, boot, radio)

    BLOCK_SIZE = 4096
    logging.info("\nOTA package analyzed:")
    logging.info("new data size (uncompressed): " +
        OtaPackageParser.GetSizeString(self.new_data_size))
    logging.info("patch data size (uncompressed): " +
        OtaPackageParser.GetSizeString(self.patch_data_size))
    logging.info("total data written: " +
        OtaPackageParser.GetSizeString(self.block_written * BLOCK_SIZE))
    logging.info("total data stashed: " +
        OtaPackageParser.GetSizeString(self.block_stashed * BLOCK_SIZE))


def main(argv):
  parser = argparse.ArgumentParser(description='Analyze an OTA package.')
  parser.add_argument("ota_package", help='Path of the OTA package.')
  args = parser.parse_args(argv)

  logging_format = '%(message)s'
  logging.basicConfig(level=logging.INFO, format=logging_format)

  try:
    with zipfile.ZipFile(args.ota_package, 'r') as package:
      package_parser = OtaPackageParser(package)
      package_parser.Analyze()
  except:
    logging.error("Failed to read " + args.ota_package)
    traceback.print_exc()
    sys.exit(1)


if __name__ == '__main__':
  main(sys.argv[1:])
