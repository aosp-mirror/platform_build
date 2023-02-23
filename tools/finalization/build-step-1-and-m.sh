#!/bin/bash

set -ex

function finalize_main_step1_and_m() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/build-step-1.sh

    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # This command tests:
    #   The release state for AIDL.
    #   ABI difference between user and userdebug builds.
    #   Resource/SDK finalization.
    AIDL_FROZEN_REL=true $m
}

finalize_main_step1_and_m

