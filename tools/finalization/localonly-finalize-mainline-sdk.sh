#!/bin/bash

set -ex

function finalize_locally_mainline_sdk() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # Build Platform SDKs.
    $top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=sdk TARGET_BUILD_VARIANT=userdebug sdk dist sdk_repo DIST_DIR=out/dist

    # Build Modules SDKs.
    TARGET_BUILD_VARIANT=userdebug UNBUNDLED_BUILD_SDKS_FROM_SOURCE=true DIST_DIR=out/dist "$top/vendor/google/build/mainline_modules_sdks.sh"

    # Update prebuilts.
    "$top/prebuilts/build-tools/path/linux-x86/python3" -W ignore::DeprecationWarning "$top/prebuilts/sdk/update_prebuilts.py" --local_mode -f ${FINAL_PLATFORM_SDK_VERSION} -e ${FINAL_MAINLINE_EXTENSION} --bug 1 1
}

finalize_locally_mainline_sdk

