#!/usr/bin/env python3
#
# Copyright (C) 2023 The Android Open Source Project
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
#

import argparse
from pathlib import Path
import zipfile
from typing import List
import common
import tempfile
import shutil

PARTITIONS_TO_WIPE = ["/dev/block/by-name/vbmeta",
                      "/dev/block/by-name/vbmeta_a",
                      "/dev/block/by-name/vbmeta_b",
                      "/dev/block/by-name/vbmeta_system_a",
                      "/dev/block/by-name/vbmeta_system_b",
                      "/dev/block/by-name/boot",
                      "/dev/block/by-name/boot_a",
                      "/dev/block/by-name/boot_b",
                      "/dev/block/by-name/vendor_boot",
                      "/dev/block/by-name/vendor_boot_a",
                      "/dev/block/by-name/vendor_boot_b",
                      "/dev/block/by-name/init_boot_a",
                      "/dev/block/by-name/init_boot_b",
                      "/dev/block/by-name/metadata",
                      "/dev/block/by-name/super",
                      "/dev/block/by-name/userdata"]


def CreateBrickOta(product_name: str, output_path: Path, extra_wipe_partitions: str, serialno: str):
  partitions_to_wipe = PARTITIONS_TO_WIPE
  if extra_wipe_partitions is not None:
    partitions_to_wipe = PARTITIONS_TO_WIPE + extra_wipe_partitions.split(",")
  # recovery requiers product name to be a | separated list
  product_name = product_name.replace(",", "|")
  with zipfile.ZipFile(output_path, "w") as zfp:
    zfp.writestr("recovery.wipe", "\n".join(partitions_to_wipe))
    zfp.writestr("payload.bin", "")
    zfp.writestr("META-INF/com/android/metadata", "\n".join(
        ["ota-type=BRICK", "post-timestamp=9999999999", "pre-device=" + product_name, "serialno=" + serialno]))


def main(argv):
  parser = argparse.ArgumentParser(description='Android Brick OTA generator')
  parser.add_argument('otafile', metavar='PAYLOAD', type=str,
                      help='The output OTA package file.')
  parser.add_argument('--product', type=str,
                      help='The product name of the device, for example, bramble, redfin.', required=True)
  parser.add_argument('--serialno', type=str,
                      help='The serial number of devices that are allowed to install this OTA package. This can be a | separated list.')
  parser.add_argument('--extra_wipe_partitions', type=str,
                      help='Additional partitions on device which should be wiped.')
  parser.add_argument('-v', action="store_true",
                      help="Enable verbose logging", dest="verbose")
  parser.add_argument('--package_key', type=str,
                      help='Paths to private key for signing payload')
  parser.add_argument('--search_path', type=str,
                      help='Search path for framework/signapk.jar')
  parser.add_argument('--private_key_suffix', type=str,
                      help='Suffix to be appended to package_key path', default=".pk8")
  args = parser.parse_args(argv[1:])
  if args.search_path:
    common.OPTIONS.search_path = args.search_path
  if args.verbose:
    common.OPTIONS.verbose = args.verbose
  CreateBrickOta(args.product, args.otafile,
                 args.extra_wipe_partitions, args.serialno)
  if args.package_key:
    common.OPTIONS.private_key_suffix = args.private_key_suffix
    with tempfile.NamedTemporaryFile() as tmpfile:
      common.SignFile(args.otafile, tmpfile.name,
                      args.package_key, None, whole_file=True)
      shutil.copy(tmpfile.name, args.otafile)


if __name__ == "__main__":
  import sys
  main(sys.argv)
