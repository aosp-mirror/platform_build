#!/bin/bash

set -ex

function finalize_main() {
    local top="$(dirname "$0")"/../..

    # default target to modify tree and build SDK
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # This script is WIP and only finalizes part of the Android branch for release.
    # The full process can be found at (INTERNAL) go/android-sdk-finalization.

    # VNDK snapshot (TODO)
    # SDK snapshots (TODO)
    # Update references in the codebase to new API version (TODO)
    # ...

    AIDL_TRANSITIVE_FREEZE=true $m aidl-freeze-api create_reference_dumps

    # Generate ABI dumps
    ANDROID_BUILD_TOP="$top" \
        out/host/linux-x86/bin/create_reference_dumps \
        -p aosp_arm64 --build-variant user

    # Update new versions of files. See update-vndk-list.sh (which requires envsetup.sh)
    $m check-vndk-list || \
        { cp $top/out/soong/vndk/vndk.libraries.txt $top/build/make/target/product/gsi/current.txt; }

    # This command tests:
    #   The release state for AIDL.
    #   ABI difference between user and userdebug builds.
    # In the future, we would want to actually turn the branch into the REL
    # state and test with that.
    AIDL_FROZEN_REL=true $m droidcore

    # Build SDK (TODO)
    # lunch sdk...
    # m ...
}

finalize_main
