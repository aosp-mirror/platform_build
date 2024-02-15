#!/usr/bin/env bash
# Copyright (C) 2022 The Android Open Source Project
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

source $(dirname $0)/../envsetup.sh

unset TARGET_PRODUCT TARGET_BUILD_VARIANT TARGET_PLATFORM_VERSION

function check_lunch
(
    echo lunch $1
    set +e
    lunch $1 > /dev/null 2> /dev/null
    set -e
    [ "$TARGET_PRODUCT" = "$2" ] || ( echo "lunch $1: expected TARGET_PRODUCT='$2', got '$TARGET_PRODUCT'" && exit 1 )
    [ "$TARGET_BUILD_VARIANT" = "$3" ] || ( echo "lunch $1: expected TARGET_BUILD_VARIANT='$3', got '$TARGET_BUILD_VARIANT'" && exit 1 )
    [ "$TARGET_PLATFORM_VERSION" = "$4" ] || ( echo "lunch $1: expected TARGET_PLATFORM_VERSION='$4', got '$TARGET_PLATFORM_VERSION'" && exit 1 )
)

default_version=$(get_build_var RELEASE_PLATFORM_VERSION)

# lunch tests
check_lunch "aosp_arm64"                                "aosp_arm64" "eng"       ""
check_lunch "aosp_arm64-userdebug"                      "aosp_arm64" "userdebug" ""
check_lunch "aosp_arm64-userdebug-$default_version"     "aosp_arm64" "userdebug" "$default_version"
check_lunch "abc"                                       "" "" ""
check_lunch "aosp_arm64-abc"                            "" "" ""
check_lunch "aosp_arm64-userdebug-abc"                  "" "" ""
check_lunch "aosp_arm64-abc-$default_version"             "" "" ""
check_lunch "abc-userdebug-$default_version"              "" "" ""
check_lunch "-"                                         "" "" ""
check_lunch "--"                                        "" "" ""
check_lunch "-userdebug"                                "" "" ""
check_lunch "-userdebug-"                               "" "" ""
check_lunch "-userdebug-$default_version"                 "" "" ""
check_lunch "aosp_arm64-userdebug-$default_version-"      "" "" ""
check_lunch "aosp_arm64-userdebug-$default_version-abc"   "" "" ""
