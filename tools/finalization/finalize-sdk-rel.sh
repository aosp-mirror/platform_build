#!/bin/bash

set -ex

function revert_droidstubs_hack() {
    if grep -q 'STOPSHIP: RESTORE THIS LOGIC WHEN DECLARING "REL" BUILD' "$top/build/soong/java/droidstubs.go" ; then
        patch --strip=1 --no-backup-if-mismatch --directory="$top/build/soong" --input=../../build/make/tools/finalization/build_soong_java_droidstubs.go.revert_hack.diff
    fi
}

function apply_prerelease_sdk_hack() {
    if ! grep -q 'STOPSHIP: hack for the pre-release SDK' "$top/frameworks/base/core/java/android/content/pm/parsing/FrameworkParsingPackageUtils.java" ; then
        patch --strip=1 --no-backup-if-mismatch --directory="$top/frameworks/base" --input=../../build/make/tools/finalization/frameworks_base.apply_hack.diff
    fi
}

function finalize_sdk_rel() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # revert droidstubs hack now we are switching to REL
    revert_droidstubs_hack

    # let the apps built with pre-release SDK parse
    apply_prerelease_sdk_hack

    # cts
    if ! grep -q "${FINAL_PLATFORM_VERSION}" "$top/cts/tests/tests/os/assets/platform_versions.txt" ; then
        echo ${FINAL_PLATFORM_VERSION} >> "$top/cts/tests/tests/os/assets/platform_versions.txt"
    fi
    if [ "$FINAL_PLATFORM_CODENAME" != "$CURRENT_PLATFORM_CODENAME" ]; then
        echo "$CURRENT_PLATFORM_CODENAME" >> "./cts/tests/tests/os/assets/platform_versions.txt"
    fi
    git -C "$top/cts" mv hostsidetests/theme/assets/${FINAL_PLATFORM_CODENAME} hostsidetests/theme/assets/${FINAL_PLATFORM_SDK_VERSION}

    # prebuilts/abi-dumps/platform
    "$top/build/soong/soong_ui.bash" --make-mode TARGET_RELEASE=next TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug create_reference_dumps
    ANDROID_BUILD_TOP="$top" "$top/out/host/linux-x86/bin/create_reference_dumps" -release next --build-variant userdebug --lib-variant APEX
}

finalize_sdk_rel

