#!/bin/bash

set -ex

function finalize_vintf_resources() {
    if [ $# -gt 1 ]; then
        echo "No argument or '--steps_for_build_test_only' is allowed"
        exit 1
    fi
    if [ $# -eq 1 ]; then
        if [ "$1" == "--steps_for_build_test_only" ]; then
            echo "This is only to verify building a target."
            echo "Skip LLNDK ABI dump and VINTF check."
            local build_test_only=true
        else
            echo "Unknown argument $1"
            exit 1
        fi
    fi

    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh
    # environment needed to build dependencies and run scripts
    # These should remain the same for all steps here to speed up build time
    export ANDROID_BUILD_TOP="$top"
    export ANDROID_HOST_OUT="$ANDROID_BUILD_TOP/out/host/linux-x86"
    export ANDROID_PRODUCT_OUT="$ANDROID_BUILD_TOP/out/target/product/generic_arm64"
    export PATH="$PATH:$ANDROID_HOST_OUT/bin/"
    export TARGET_BUILD_VARIANT=userdebug
    export DIST_DIR=out/dist
    export TARGET_RELEASE=fina_0
    export TARGET_PRODUCT=aosp_arm64

    # build/soong
    local vendor_api_level_map="case ${FINAL_NEXT_BOARD_API_LEVEL}:"
    if ! grep -q "$vendor_api_level_map" "$top/build/soong/android/vendor_api_levels.go" ; then
        sed -i -e "/case ${FINAL_BOARD_API_LEVEL}:/{N;a \\\t$vendor_api_level_map\n\t\tsdkVersion = ${FINAL_NEXT_CORRESPONDING_SDK_VERSION}
        }" "$top/build/soong/android/vendor_api_levels.go"
    fi

    # system/sepolicy
    "$top/system/sepolicy/tools/finalize-vintf-resources.sh" "$top" "$FINAL_BOARD_API_LEVEL"

    finalize_compat_matrix $build_test_only

    # pre-finalization build target (trunk)
    local aidl_m="$top/build/soong/soong_ui.bash --make-mode"
    AIDL_TRANSITIVE_FREEZE=true $aidl_m aidl-freeze-api create_reference_dumps

    if ! [ "$build_test_only" = "true" ]; then
        # Generate LLNDK ABI dumps
        # This command depends on ANDROID_BUILD_TOP
        "$ANDROID_HOST_OUT/bin/create_reference_dumps" -release "$TARGET_RELEASE" --build-variant "$TARGET_BUILD_VARIANT" --lib-variant LLNDK
    fi
}

function finalize_compat_matrix() {
    local build_test_only=$1
    local CURRENT_COMPATIBILITY_MATRIX_LEVEL="$FINAL_BOARD_API_LEVEL"

    "$top/prebuilts/build-tools/path/linux-x86/python3" "$top/hardware/interfaces/compatibility_matrices/finalize.py" "$CURRENT_COMPATIBILITY_MATRIX_LEVEL"

    if ! [ "$build_test_only" = "true" ]; then
        # Freeze the current framework manifest file. This relies on the
        # aosp_cf_x86_64-trunk_staging build target to get the right manifest
        # fragments installed.
        "$top/system/libhidl/vintfdata/freeze.sh" "$CURRENT_COMPATIBILITY_MATRIX_LEVEL"
    fi
}

function freeze_framework_manifest() {
   ANDROID_PRODUCT_OUT=~/workspace/internal/main/out/target/product/vsoc_x86 ANDROID_BUILD_TOP=~/workspace/internal/main ANDROID_HOST_OUT=~/workspace/internal/main/out/host/linux-x86 ./freeze.sh 202404

}


finalize_vintf_resources $@

