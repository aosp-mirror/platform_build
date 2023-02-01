#!/bin/bash

set -ex

function finalize_main() {
    local top="$(dirname "$0")"/../..

    # default target to modify tree and build SDK
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # Build finalization artifacts.
    source $top/build/make/finalize-aidl-vndk-sdk-resources.sh

    # This command tests:
    #   The release state for AIDL.
    #   ABI difference between user and userdebug builds.
    #   Resource/SDK finalization.
    # In the future, we would want to actually turn the branch into the REL
    # state and test with that.
    AIDL_FROZEN_REL=true $m

    # Build SDK (TODO)
    # lunch sdk...
    # m ...
}

finalize_main

