#!/bin/bash

set -ex

function revert_droidstubs_hack() {
    if grep -q 'STOPSHIP: RESTORE THIS LOGIC WHEN DECLARING "REL" BUILD' "$top/build/soong/java/droidstubs.go" ; then
        patch --strip=1 --no-backup-if-mismatch --directory="$top/build/soong" --input=../../build/make/tools/finalization/build_soong_java_droidstubs.go.revert_hack.diff
    fi
}

function revert_resources_sdk_int_fix() {
    if grep -q 'public static final int RESOURCES_SDK_INT = SDK_INT;' "$top/frameworks/base/core/java/android/os/Build.java" ; then
        patch --strip=1 --no-backup-if-mismatch --directory="$top/frameworks/base" --input=../../build/make/tools/finalization/frameworks_base.revert_resource_sdk_int.diff
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

    # in REL mode, resources would correctly set the resources_sdk_int, no fix required
    revert_resources_sdk_int_fix

    # cts
    echo "$FINAL_PLATFORM_VERSION" > "$top/cts/tests/tests/os/assets/platform_versions.txt"
    if [ "$FINAL_PLATFORM_CODENAME" != "$CURRENT_PLATFORM_CODENAME" ]; then
        echo "$CURRENT_PLATFORM_CODENAME" >> "./cts/tests/tests/os/assets/platform_versions.txt"
    fi
    git -C "$top/cts" mv hostsidetests/theme/assets/${FINAL_PLATFORM_CODENAME} hostsidetests/theme/assets/${FINAL_PLATFORM_SDK_VERSION}

    # prebuilts/abi-dumps/platform
    mkdir -p "$top/prebuilts/abi-dumps/platform/$FINAL_PLATFORM_SDK_VERSION"
    cp -r "$top/prebuilts/abi-dumps/platform/current/64/" "$top/prebuilts/abi-dumps/platform/$FINAL_PLATFORM_SDK_VERSION/"

    # TODO(b/309880485)
    # uncomment and update
    # prebuilts/abi-dumps/ndk
    #mkdir -p "$top/prebuilts/abi-dumps/ndk/$FINAL_PLATFORM_SDK_VERSION"
    #cp -r "$top/prebuilts/abi-dumps/ndk/current/64/" "$top/prebuilts/abi-dumps/ndk/$FINAL_PLATFORM_SDK_VERSION/"
}

finalize_sdk_rel

