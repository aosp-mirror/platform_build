#!/bin/bash
#
# Copyright (C) 2018 The Android Open Source Project
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


# Parse sdk, targetSdk, and uses librares in the APK, then cross reference against build specified ones.

set -e
local_apk=$1
badging=$(aapt dump badging "${local_apk}")
export sdk_version=$(echo "${badging}" | grep "sdkVersion" | sed -n "s/sdkVersion:'\(.*\)'/\1/p")
# Export target_sdk_version to the caller.
export target_sdk_version=$(echo "${badging}" | grep "targetSdkVersion" | sed -n "s/targetSdkVersion:'\(.*\)'/\1/p")
uses_libraries=$(echo "${badging}" | grep "uses-library" | sed -n "s/uses-library:'\(.*\)'/\1/p")
optional_uses_libraries=$(echo "${badging}" | grep "uses-library-not-required" | sed -n "s/uses-library-not-required:'\(.*\)'/\1/p")

# Verify that the uses libraries match exactly.
# Currently we validate the ordering of the libraries since it matters for resolution.
single_line_libs=$(echo "${uses_libraries}" | tr '\n' ' ' | awk '{$1=$1}1')
if [[ "${single_line_libs}" != "${uses_library_names}" ]]; then
  echo "LOCAL_USES_LIBRARIES (${uses_library_names})" \
       "do not match (${single_line_libs}) in manifest for ${local_apk}"
  exit 1
fi

# Verify that the optional uses libraries match exactly.
single_line_optional_libs=$(echo "${optional_uses_libraries}" | tr '\n' ' ' | awk '{$1=$1}1')
if [[ "${single_line_optional_libs}" != "${optional_uses_library_names}" ]]; then
  echo "LOCAL_OPTIONAL_USES_LIBRARIES (${optional_uses_library_names}) " \
       "do not match (${single_line_optional_libs}) in manifest for ${local_apk}"
  exit 1
fi

