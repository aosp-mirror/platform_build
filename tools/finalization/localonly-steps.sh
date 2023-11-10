#!/bin/bash

set -ex

function finalize_locally() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # default target to modify tree and build SDK
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_RELEASE=fina_1 TARGET_BUILD_VARIANT=userdebug DIST_DIR=out/dist"

    # adb keys
    $m adb
    LOGNAME=android-eng HOSTNAME=google.com "$top/out/host/linux-x86/bin/adb" keygen "$top/vendor/google/security/adb/${FINAL_PLATFORM_VERSION}.adb_key"

    # Build Platform SDKs.
    $top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=sdk TARGET_RELEASE=fina_1 TARGET_BUILD_VARIANT=userdebug sdk dist sdk_repo DIST_DIR=out/dist

    # Build Modules SDKs.
    TARGET_RELEASE=fina_1 TARGET_BUILD_VARIANT=userdebug UNBUNDLED_BUILD_SDKS_FROM_SOURCE=true DIST_DIR=out/dist "$top/vendor/google/build/mainline_modules_sdks.sh" --build-release=latest

    # Update prebuilts.
    "$top/prebuilts/build-tools/path/linux-x86/python3" -W ignore::DeprecationWarning "$top/prebuilts/sdk/update_prebuilts.py" --local_mode -f ${FINAL_PLATFORM_SDK_VERSION} -e ${FINAL_MAINLINE_EXTENSION} --bug 1 1
}

finalize_locally
