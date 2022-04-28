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
#

import os
import yaml


def parse_hierarchy(build_top):
  """Parse build hierarchy file from given build top directory, and returns a dict from child targets to parent targets.

  Example of hierarchy file:
  ==========
  aosp_arm64:
  - armv8
  - aosp_cf_arm64_phone

  armv8:
  - aosp_oriole
  - aosp_sunfish

  aosp_oriole:
  - oriole

  aosp_sunfish:
  - sunfish

  oriole:
  # leaf

  sunfish:
  # leaf
  ==========

  If we parse this yaml, we get a dict looking like:

  {
      "sunfish": "aosp_sunfish",
      "oriole": "aosp_oriole",
      "aosp_oriole": "armv8",
      "aosp_sunfish": "armv8",
      "armv8": "aosp_arm64",
      "aosp_cf_arm64_phone": "aosp_arm64",
      "aosp_arm64": None, # no parent
  }
  """
  metadata_path = os.path.join(build_top, 'tools', 'build', 'hierarchy.yaml')
  if not os.path.isfile(metadata_path):
    raise RuntimeError("target metadata file %s doesn't exist" % metadata_path)

  with open(metadata_path, 'r') as f:
    hierarchy_yaml = yaml.load(f, Loader=yaml.SafeLoader)

  hierarchy_map = dict()

  for parent_target, child_targets in hierarchy_yaml.items():
    if not child_targets:
      # leaf
      continue
    for child_target in child_targets:
      hierarchy_map[child_target] = parent_target

  for parent_target in hierarchy_yaml:
    # targets with no parent
    if parent_target not in hierarchy_map:
      hierarchy_map[parent_target] = None

  return hierarchy_map
