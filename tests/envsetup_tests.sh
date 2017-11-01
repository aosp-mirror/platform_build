#!/bin/bash -e

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

default_version=$(get_build_var DEFAULT_PLATFORM_VERSION)
valid_version=PPR1

# lunch tests
check_lunch "aosp_arm64"                                "aosp_arm64" "eng"       ""
check_lunch "aosp_arm64-userdebug"                      "aosp_arm64" "userdebug" ""
check_lunch "aosp_arm64-userdebug-$default_version"     "aosp_arm64" "userdebug" "$default_version"
check_lunch "aosp_arm64-userdebug-$valid_version"       "aosp_arm64" "userdebug" "$valid_version"
check_lunch "abc"                                       "" "" ""
check_lunch "aosp_arm64-abc"                            "" "" ""
check_lunch "aosp_arm64-userdebug-abc"                  "" "" ""
check_lunch "aosp_arm64-abc-$valid_version"             "" "" ""
check_lunch "abc-userdebug-$valid_version"              "" "" ""
check_lunch "-"                                         "" "" ""
check_lunch "--"                                        "" "" ""
check_lunch "-userdebug"                                "" "" ""
check_lunch "-userdebug-"                               "" "" ""
check_lunch "-userdebug-$valid_version"                 "" "" ""
check_lunch "aosp_arm64-userdebug-$valid_version-"      "" "" ""
check_lunch "aosp_arm64-userdebug-$valid_version-abc"   "" "" ""
