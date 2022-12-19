#!/bin/bash

set -ex

function finalize_aidl_vndk_sdk_resources() {
    local PLATFORM_CODENAME='UpsideDownCake'
    local PLATFORM_CODENAME_JAVA='UPSIDE_DOWN_CAKE'
    local PLATFORM_SDK_VERSION='34'
    local PLATFORM_VERSION='14'

    local SDK_CODENAME="public static final int $PLATFORM_CODENAME_JAVA = CUR_DEVELOPMENT;"
    local SDK_VERSION="public static final int $PLATFORM_CODENAME_JAVA = $PLATFORM_SDK_VERSION;"

    local top="$(dirname "$0")"/../..

    # default target to modify tree and build SDK
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # This script is WIP and only finalizes part of the Android branch for release.
    # The full process can be found at (INTERNAL) go/android-sdk-finalization.

    # Update references in the codebase to new API version (TODO)
    # ...

    # VNDK definitions for new SDK version
    cp "$top/development/vndk/tools/definition-tool/datasets/vndk-lib-extra-list-current.txt" \
       "$top/development/vndk/tools/definition-tool/datasets/vndk-lib-extra-list-$PLATFORM_SDK_VERSION.txt"

    AIDL_TRANSITIVE_FREEZE=true $m aidl-freeze-api create_reference_dumps

    # Generate ABI dumps
    ANDROID_BUILD_TOP="$top" \
        out/host/linux-x86/bin/create_reference_dumps \
        -p aosp_arm64 --build-variant user

    echo "NOTE: THIS INTENTIONALLY MAY FAIL AND REPAIR ITSELF (until 'DONE')"
    # Update new versions of files. See update-vndk-list.sh (which requires envsetup.sh)
    $m check-vndk-list || \
        { cp $top/out/soong/vndk/vndk.libraries.txt $top/build/make/target/product/gsi/current.txt; }
    echo "DONE: THIS INTENTIONALLY MAY FAIL AND REPAIR ITSELF"

    # Finalize SDK

    # build/make
    local version_defaults="$top/build/make/core/version_defaults.mk"
    sed -i -e "s/PLATFORM_SDK_VERSION := .*/PLATFORM_SDK_VERSION := ${PLATFORM_SDK_VERSION}/g" $version_defaults
    sed -i -e "s/PLATFORM_VERSION_LAST_STABLE := .*/PLATFORM_VERSION_LAST_STABLE := ${PLATFORM_VERSION}/g" $version_defaults
    sed -i -e "s/sepolicy_major_vers := .*/sepolicy_major_vers := ${PLATFORM_SDK_VERSION}/g" "$top/build/make/core/config.mk"
    cp "$top/build/make/target/product/gsi/current.txt" "$top/build/make/target/product/gsi/$PLATFORM_SDK_VERSION.txt"

    # build/soong
    sed -i -e "/:.*$((${PLATFORM_SDK_VERSION}-1)),/a \\\t\t\t\"${PLATFORM_CODENAME}\":     ${PLATFORM_SDK_VERSION}," "$top/build/soong/android/api_levels.go"

    # cts
    echo ${PLATFORM_VERSION} > "$top/cts/tests/tests/os/assets/platform_releases.txt"
    sed -i -e "s/EXPECTED_SDK = $((${PLATFORM_SDK_VERSION}-1))/EXPECTED_SDK = ${PLATFORM_SDK_VERSION}/g" "$top/cts/tests/tests/os/src/android/os/cts/BuildVersionTest.java"

    # libcore
    sed -i "s%$SDK_CODENAME%$SDK_VERSION%g" "$top/libcore/dalvik/src/main/java/dalvik/annotation/compat/VersionCodes.java"

    # platform_testing
    local version_codes="$top/platform_testing/libraries/compatibility-common-util/src/com/android/compatibility/common/util/VersionCodes.java"
    sed -i -e "/=.*$((${PLATFORM_SDK_VERSION}-1));/a \\    ${SDK_VERSION}" $version_codes

    # Finalize resources
    "$top/frameworks/base/tools/aapt2/tools/finalize_res.py" \
           "$top/frameworks/base/core/res/res/values/public-staging.xml" \
           "$top/frameworks/base/core/res/res/values/public-final.xml"

    # frameworks/base
    sed -i "s%$SDK_CODENAME%$SDK_VERSION%g" "$top/frameworks/base/core/java/android/os/Build.java"
    sed -i -e "/=.*$((${PLATFORM_SDK_VERSION}-1)),/a \\    SDK_${PLATFORM_CODENAME_JAVA} = ${PLATFORM_SDK_VERSION}," "$top/frameworks/base/tools/aapt/SdkConstants.h"
    sed -i -e "/=.*$((${PLATFORM_SDK_VERSION}-1)),/a \\  SDK_${PLATFORM_CODENAME_JAVA} = ${PLATFORM_SDK_VERSION}," "$top/frameworks/base/tools/aapt2/SdkConstants.h"

    # Force update current.txt
    $m clobber
    $m update-api
}

finalize_aidl_vndk_sdk_resources

