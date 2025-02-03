#!/usr/bin/env python3
#
# Copyright (C) 2024 The Android Open Source Project
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

import collections
import sys
import os

from io import TextIOWrapper
from protos import aconfig_internal_pb2
from typing import Dict, List, Set

def extract_finalized_flags(flag_file: TextIOWrapper):
  finalized_flags_for_sdk = list()

  for line in f:
    flag_name = line.strip()
    if flag_name:
      finalized_flags_for_sdk.append(flag_name)

  return finalized_flags_for_sdk

def remove_duplicate_flags(all_flags_with_duplicates: Dict[int, List]):
  result_flags = collections.defaultdict(set)

  for api_level in sorted(all_flags_with_duplicates.keys(), key=int):
    for flag in all_flags_with_duplicates[api_level]:
      if not any(flag in value_set for value_set in result_flags.values()):
        result_flags[api_level].add(flag)

  return result_flags

def build_proto(all_flags: Set):
  finalized_flags = aconfig_internal_pb2.finalized_flags()
  for api_level, qualified_name_list in all_flags.items():
    for qualified_name in qualified_name_list:
      package_name, flag_name = qualified_name.rsplit('.', 1)
      finalized_flag = aconfig_internal_pb2.finalized_flag()
      finalized_flag.name = flag_name
      finalized_flag.package = package_name
      finalized_flag.min_sdk = api_level
      finalized_flags.finalized_flag.append(finalized_flag)
  return finalized_flags

if __name__ == '__main__':
  if len(sys.argv) == 1:
    sys.exit('No prebuilts/sdk directory provided.')
  all_api_info_dir = sys.argv[1]

  all_flags_with_duplicates = {}
  for sdk_dir in os.listdir(all_api_info_dir):
    api_level = sdk_dir.rsplit('/', 1)[0].rstrip('0').rstrip('.')

    # No support for minor versions yet. This also removes non-numeric dirs.
    # Update once floats are acceptable.
    if not api_level.isdigit():
      continue

    flag_file_path = os.path.join(all_api_info_dir, sdk_dir, 'finalized-flags.txt')
    try:
      with open(flag_file_path, 'r') as f:
        finalized_flags_for_sdk = extract_finalized_flags(f)
        all_flags_with_duplicates[int(api_level)] = finalized_flags_for_sdk
    except FileNotFoundError:
      # Either this version is not finalized yet or looking at a
      # /prebuilts/sdk/version before finalized-flags.txt was introduced.
      continue

  all_flags = remove_duplicate_flags(all_flags_with_duplicates)
  finalized_flags = build_proto(all_flags)
  sys.stdout.buffer.write(finalized_flags.SerializeToString())
