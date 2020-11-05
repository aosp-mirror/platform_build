#!/usr/bin/env python
#
# Copyright (C) 2019 The Android Open Source Project
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
"""Find APK sharedUserId violators.

Usage: find_shareduid_violation [args]

  --product_out
    PRODUCT_OUT directory

  --aapt
    Path to aapt or aapt2

  --copy_out_system
    TARGET_COPY_OUT_SYSTEM

  --copy_out_vendor_
    TARGET_COPY_OUT_VENDOR

  --copy_out_product
    TARGET_COPY_OUT_PRODUCT

  --copy_out_system_ext
    TARGET_COPY_OUT_SYSTEM_EXT
"""

import json
import logging
import os
import re
import subprocess
import sys

from collections import defaultdict
from glob import glob

import common

logger = logging.getLogger(__name__)

OPTIONS = common.OPTIONS
OPTIONS.product_out = os.environ.get("PRODUCT_OUT")
OPTIONS.aapt = "aapt2"
OPTIONS.copy_out_system = "system"
OPTIONS.copy_out_vendor = "vendor"
OPTIONS.copy_out_product = "product"
OPTIONS.copy_out_system_ext = "system_ext"


def execute(cmd):
  p = subprocess.Popen(
      cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  out, err = map(lambda b: b.decode("utf-8"), p.communicate())
  return p.returncode == 0, out, err


def make_aapt_cmds(aapt, apk):
  return [
      aapt + " dump " + apk + " --file AndroidManifest.xml",
      aapt + " dump xmltree " + apk + " --file AndroidManifest.xml"
  ]


def extract_shared_uid(aapt, apk):
  for cmd in make_aapt_cmds(aapt, apk):
    success, manifest, error_msg = execute(cmd)
    if success:
      break
  else:
    logger.error(error_msg)
    sys.exit()

  pattern = re.compile(r"sharedUserId.*=\"([^\"]*)")

  for line in manifest.split("\n"):
    match = pattern.search(line)
    if match:
      return match.group(1)
  return None


def FindShareduidViolation(product_out, partition_map, aapt="aapt2"):
  """Find sharedUserId violators in the given partitions.

  Args:
    product_out: The base directory containing the partition directories.
    partition_map: A map of partition name -> directory name.
    aapt: The name of the aapt binary. Defaults to aapt2.

  Returns:
    A string containing a JSON object describing the shared UIDs.
  """
  shareduid_app_dict = defaultdict(lambda: defaultdict(list))

  for part, location in partition_map.items():
    for f in glob(os.path.join(product_out, location, "*", "*", "*.apk")):
      apk_file = os.path.basename(f)
      shared_uid = extract_shared_uid(aapt, f)

      if shared_uid is None:
        continue
      shareduid_app_dict[shared_uid][part].append(apk_file)

  # Only output sharedUserId values that appear in >1 partition.
  output = {}
  for uid, partitions in shareduid_app_dict.items():
    if len(partitions) > 1:
      output[uid] = shareduid_app_dict[uid]

  return json.dumps(output, indent=2, sort_keys=True)


def main():
  common.InitLogging()

  def option_handler(o, a):
    if o == "--product_out":
      OPTIONS.product_out = a
    elif o == "--aapt":
      OPTIONS.aapt = a
    elif o == "--copy_out_system":
      OPTIONS.copy_out_system = a
    elif o == "--copy_out_vendor":
      OPTIONS.copy_out_vendor = a
    elif o == "--copy_out_product":
      OPTIONS.copy_out_product = a
    elif o == "--copy_out_system_ext":
      OPTIONS.copy_out_system_ext = a
    else:
      return False
    return True

  args = common.ParseOptions(
      sys.argv[1:],
      __doc__,
      extra_long_opts=[
          "product_out=",
          "aapt=",
          "copy_out_system=",
          "copy_out_vendor=",
          "copy_out_product=",
          "copy_out_system_ext=",
      ],
      extra_option_handler=option_handler)

  if args:
    common.Usage(__doc__)
    sys.exit(1)

  partition_map = {
      "system": OPTIONS.copy_out_system,
      "vendor": OPTIONS.copy_out_vendor,
      "product": OPTIONS.copy_out_product,
      "system_ext": OPTIONS.copy_out_system_ext,
  }

  print(
      FindShareduidViolation(OPTIONS.product_out, partition_map, OPTIONS.aapt))


if __name__ == "__main__":
  main()
