#!/bin/bash
# Continuous Integration script for *-finalization-1 branches.
# Reverts previous finalization script commits and runs local build.

set -ex

function finalize_step_1_main() {
    local top="$(dirname "$0")"/../..
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # vndk etc finalization
    source $top/build/make/finalize-aidl-vndk-sdk-resources.sh

    # build to confirm everything is OK
    AIDL_FROZEN_REL=true $m
}

finalize_step_1_main
