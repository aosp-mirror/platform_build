#!/bin/bash

set -ex

function finalize_main_step1() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # default target to modify tree and build SDK
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # Build finalization artifacts.
    source $top/build/make/tools/finalization/finalize-aidl-vndk-sdk-resources.sh
}

finalize_main_step1

