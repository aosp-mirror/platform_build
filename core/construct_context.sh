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

set -e

# target_sdk_version: parsed from manifest
#
# outputs
# class_loader_context_arg: final class loader conext arg
# stored_class_loader_context_arg: final stored class loader context arg

# The hidl.manager shared library has a dependency on hidl.base. We'll manually
# add that information to the class loader context if we see those libraries.
hidl_manager="android.hidl.manager-V1.0-java"
hidl_base="android.hidl.base-V1.0-java"

function add_to_contexts {
  for i in $1; do
    if [[ -z "${class_loader_context}" ]]; then
      export class_loader_context="PCL[$i]"
    else
      export class_loader_context+="#PCL[$i]"
    fi
    if [[ $i == *"$hidl_manager"* ]]; then
      export class_loader_context+="{PCL[${i/$hidl_manager/$hidl_base}]}"
    fi
  done

  for i in $2; do
    if [[ -z "${stored_class_loader_context}" ]]; then
      export stored_class_loader_context="PCL[$i]"
    else
      export stored_class_loader_context+="#PCL[$i]"
    fi
    if [[ $i == *"$hidl_manager"* ]]; then
      export stored_class_loader_context+="{PCL[${i/$hidl_manager/$hidl_base}]}"
    fi
  done
}

# The order below must match what the package manager also computes for
# class loader context.

if [[ "${target_sdk_version}" -lt "28" ]]; then
  add_to_contexts "${conditional_host_libs_28}" "${conditional_target_libs_28}"
fi

if [[ "${target_sdk_version}" -lt "29" ]]; then
  add_to_contexts "${conditional_host_libs_29}" "${conditional_target_libs_29}"
fi

add_to_contexts "${dex_preopt_host_libraries}" "${dex_preopt_target_libraries}"

# Generate the actual context string.
export class_loader_context_arg="--class-loader-context=PCL[]{${class_loader_context}}"
export stored_class_loader_context_arg="--stored-class-loader-context=PCL[]{${stored_class_loader_context}}"
