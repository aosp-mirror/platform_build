# Copyright 2024, The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import hashlib
import logging
import os


def is_feature_enabled(
    feature_name: str,
    user_name: str,
    enable_flag: str = None,
    rollout_flag: str = None,
) -> bool:
  """Determine whether the given feature is enabled.

  Whether a given feature is enabled or not depends on two flags: 1) the
  enable_flag that explicitly enable/disable the feature and 2) the rollout_flag
  that controls the rollout percentage.

  Args:
    feature_name: name of the feature.
    user_name: system user name.
    enable_flag: name of the env var that enables/disables the feature
      explicitly.
    rollout_flg: name of the env var that controls the rollout percentage, the
      value stored in the env var should be an int between 0 and 100 string
  """
  if enable_flag:
    if os.environ.get(enable_flag, "") == "false":
      logging.info("feature: %s is disabled", feature_name)
      return False

    if os.environ.get(enable_flag, "") == "true":
      logging.info("feature: %s is enabled", feature_name)
      return True

  if not rollout_flag:
    return True

  hash_object = hashlib.sha256()
  hash_object.update((user_name + feature_name).encode("utf-8"))
  hash_number = int(hash_object.hexdigest(), 16) % 100

  roll_out_percentage = os.environ.get(rollout_flag, "0")
  try:
    percentage = int(roll_out_percentage)
    if percentage < 0 or percentage > 100:
      logging.warning(
          "Rollout percentage: %s out of range, disable the feature.",
          roll_out_percentage,
      )
      return False
    return hash_number < percentage
  except ValueError:
    logging.warning(
        "Invalid rollout percentage: %s, disable the feature.",
        roll_out_percentage,
    )
    return False
