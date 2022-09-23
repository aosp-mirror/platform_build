#!/bin/bash

set -ex

function finalize_aidl_vndk_sdk_resources() {
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

    # Finalize resources
    "$top/frameworks/base/tools/aapt2/tools/finalize_res.py" \
           "$top/frameworks/base/core/res/res/values/public-staging.xml" \
           "$top/frameworks/base/core/res/res/values/public-final.xml"

    # SDK finalization
    local sdk_codename='public static final int UPSIDE_DOWN_CAKE = CUR_DEVELOPMENT;'
    local sdk_version='public static final int UPSIDE_DOWN_CAKE = 34;'
    local sdk_build="$top/frameworks/base/core/java/android/os/Build.java"

    sed -i "s%$sdk_codename%$sdk_version%g" $sdk_build

    # Update the current.txt
    $m update-api
}

finalize_aidl_vndk_sdk_resources

