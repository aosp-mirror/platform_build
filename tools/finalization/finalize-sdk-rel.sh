#!/bin/bash

set -ex

function revert_droidstubs_hack() {
    if grep -q 'STOPSHIP: RESTORE THIS LOGIC WHEN DECLARING "REL" BUILD' "$top/build/soong/java/droidstubs.go" ; then
        git -C "$top/build/soong" apply --allow-empty ../../build/make/tools/finalization/build_soong_java_droidstubs.go.revert_hack.diff
    fi
}

function apply_prerelease_sdk_hack() {
    if ! grep -q 'STOPSHIP: hack for the pre-release SDK' "$top/frameworks/base/core/java/android/content/pm/parsing/FrameworkParsingPackageUtils.java" ; then
        git -C "$top/frameworks/base" apply --allow-empty ../../build/make/tools/finalization/frameworks_base.apply_hack.diff
    fi
}

function finalize_sdk_rel() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # default target to modify tree and build SDK
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug DIST_DIR=out/dist"

    # revert droidstubs hack now we are switching to REL
    revert_droidstubs_hack

    # let the apps built with pre-release SDK parse
    apply_prerelease_sdk_hack

    # adb keys
    $m adb
    LOGNAME=android-eng HOSTNAME=google.com "$top/out/host/linux-x86/bin/adb" keygen "$top/vendor/google/security/adb/${FINAL_PLATFORM_VERSION}.adb_key"

    # build/make/core/version_defaults.mk
    sed -i -e "s/PLATFORM_VERSION_CODENAME.${FINAL_BUILD_PREFIX} := .*/PLATFORM_VERSION_CODENAME.${FINAL_BUILD_PREFIX} := REL/g" "$top/build/make/core/version_defaults.mk"

    # cts
    echo "$FINAL_PLATFORM_VERSION" > "$top/cts/tests/tests/os/assets/platform_versions.txt"
    if [ "$FINAL_PLATFORM_CODENAME" != "$CURRENT_PLATFORM_CODENAME" ]; then
        echo "$CURRENT_PLATFORM_CODENAME" >> "./cts/tests/tests/os/assets/platform_versions.txt"
    fi
    git -C "$top/cts" mv hostsidetests/theme/assets/${FINAL_PLATFORM_CODENAME} hostsidetests/theme/assets/${FINAL_PLATFORM_SDK_VERSION}

    # system/sepolicy
    mkdir -p "$top/system/sepolicy/prebuilts/api/${FINAL_PLATFORM_SDK_VERSION}.0/"
    cp -r "$top/system/sepolicy/public/" "$top/system/sepolicy/prebuilts/api/${FINAL_PLATFORM_SDK_VERSION}.0/"
    cp -r "$top/system/sepolicy/private/" "$top/system/sepolicy/prebuilts/api/${FINAL_PLATFORM_SDK_VERSION}.0/"

    # prebuilts/abi-dumps/ndk
    mv "$top/prebuilts/abi-dumps/ndk/current" "$top/prebuilts/abi-dumps/ndk/$FINAL_PLATFORM_SDK_VERSION"

    # prebuilts/abi-dumps/vndk
    mv "$top/prebuilts/abi-dumps/vndk/$CURRENT_PLATFORM_CODENAME" "$top/prebuilts/abi-dumps/vndk/$FINAL_PLATFORM_SDK_VERSION"

    # prebuilts/abi-dumps/platform
    mv "$top/prebuilts/abi-dumps/platform/current" "$top/prebuilts/abi-dumps/platform/$FINAL_PLATFORM_SDK_VERSION"
}

finalize_sdk_rel

