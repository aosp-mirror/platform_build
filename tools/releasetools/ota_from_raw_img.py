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
Given a series of .img files, produces an OTA package that installs thoese images
"""

import sys
import os
import argparse
import subprocess
import tempfile
import logging
import zipfile

import common
from payload_signer import PayloadSigner
from ota_utils import PayloadGenerator
from ota_signing_utils import AddSigningArgumentParse


logger = logging.getLogger(__name__)


def ResolveBinaryPath(filename, search_path):
  if not search_path:
    return filename
  if not os.path.exists(search_path):
    return filename
  path = os.path.join(search_path, "bin", filename)
  if os.path.exists(path):
    return path
  path = os.path.join(search_path, filename)
  if os.path.exists(path):
    return path
  return path


def main(argv):
  parser = argparse.ArgumentParser(
      prog=argv[0], description="Given a series of .img files, produces a full OTA package that installs thoese images")
  parser.add_argument("images", nargs="+", type=str,
                      help="List of images to generate OTA")
  parser.add_argument("--partition_names", nargs='+', type=str,
                      help="Partition names to install the images, default to basename of the image(no file name extension)")
  parser.add_argument('--output', type=str,
                      help='Paths to output merged ota', required=True)
  parser.add_argument('--max_timestamp', type=int,
                      help='Maximum build timestamp allowed to install this OTA')
  parser.add_argument("-v", action="store_true",
                      help="Enable verbose logging", dest="verbose")
  AddSigningArgumentParse(parser)

  args = parser.parse_args(argv[1:])
  if args.verbose:
    logger.setLevel(logging.INFO)
  logger.info(args)
  old_imgs = [""] * len(args.images)
  for (i, img) in enumerate(args.images):
    if ":" in img:
      old_imgs[i], args.images[i] = img.split(":", maxsplit=1)

  if not args.partition_names:
    args.partition_names = [os.path.os.path.splitext(os.path.basename(path))[
        0] for path in args.images]
  with tempfile.NamedTemporaryFile() as unsigned_payload, tempfile.NamedTemporaryFile() as dynamic_partition_info_file:
    dynamic_partition_info_file.writelines(
        [b"virtual_ab=true\n", b"super_partition_groups=\n"])
    dynamic_partition_info_file.flush()
    cmd = [ResolveBinaryPath("delta_generator", args.search_path)]
    cmd.append("--partition_names=" + ",".join(args.partition_names))
    cmd.append("--dynamic_partition_info_file=" +
               dynamic_partition_info_file.name)
    cmd.append("--old_partitions=" + ",".join(old_imgs))
    cmd.append("--new_partitions=" + ",".join(args.images))
    cmd.append("--out_file=" + unsigned_payload.name)
    cmd.append("--is_partial_update")
    if args.max_timestamp:
      cmd.append("--max_timestamp=" + str(args.max_timestamp))
      cmd.append("--partition_timestamps=boot:" + str(args.max_timestamp))
    logger.info("Running %s", cmd)

    subprocess.check_call(cmd)
    generator = PayloadGenerator()
    generator.payload_file = unsigned_payload.name
    logger.info("Payload size: %d", os.path.getsize(generator.payload_file))

    # Get signing keys
    key_passwords = common.GetKeyPasswords([args.package_key])

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
    with zipfile.ZipFile(args.output, "w") as zfp:
      generator.WriteToZip(zfp)


if __name__ == "__main__":
  logging.basicConfig()
  main(sys.argv)
