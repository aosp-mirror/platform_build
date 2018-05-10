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

# inputs:
# $1 is PRIVATE_CONDITIONAL_USES_LIBRARIES_HOST
# $2 is PRIVATE_CONDITIONAL_USES_LIBRARIES_TARGET

# class_loader_context: library paths on the host
# stored_class_loader_context_libs: library paths on device
# these are both comma separated paths, example: lib1.jar:lib2.jar or /system/framework/lib1.jar:/system/framework/lib2.jar

# target_sdk_version: parsed from manifest
# my_conditional_host_libs: libraries conditionally added for non P
# my_conditional_target_libs: target libraries conditionally added for non P
#
# outputs
# class_loader_context_arg: final class loader conext arg
# stored_class_loader_context_arg: final stored class loader context arg

my_conditional_host_libs=$1
my_conditional_target_libs=$2

# Note that SDK 28 is P.
if [[ "${target_sdk_version}" -lt "28" ]]; then
  if [[ -z "${class_loader_context}" ]]; then
    export class_loader_context="${my_conditional_host_libs}"
  else
    export class_loader_context="${my_conditional_host_libs}:${class_loader_context}"
  fi
  if [[ -z "${stored_class_loader_context_libs}" ]]; then
    export stored_class_loader_context_libs="${my_conditional_target_libs}";
  else
    export stored_class_loader_context_libs="${my_conditional_target_libs}:${stored_class_loader_context_libs}";
  fi
fi

# Generate the actual context string.
export class_loader_context_arg="--class-loader-context=PCL[${class_loader_context}]"
export stored_class_loader_context_arg="--stored-class-loader-context=PCL[${stored_class_loader_context_libs}]"
