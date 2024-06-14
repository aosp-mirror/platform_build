#!/bin/bash

set -ex

function finalize_vintf_resources() {
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

    # TODO(b/314010764): finalize LL_NDK

    # system/sepolicy
    "$top/system/sepolicy/tools/finalize-vintf-resources.sh" "$top" "$FINAL_BOARD_API_LEVEL"

    create_new_compat_matrix_and_kernel_configs

    # pre-finalization build target (trunk)
    local aidl_m="$top/build/soong/soong_ui.bash --make-mode"
    AIDL_TRANSITIVE_FREEZE=true $aidl_m aidl-freeze-api
}

function create_new_compat_matrix_and_kernel_configs() {
    # The compatibility matrix versions are bumped during vFRC
    # These will change every time we have a new vFRC
    local CURRENT_COMPATIBILITY_MATRIX_LEVEL='202404'
    local NEXT_COMPATIBILITY_MATRIX_LEVEL='202504'
    # The kernel configs need the letter of the Android release
    local CURRENT_RELEASE_LETTER='v'
    local NEXT_RELEASE_LETTER='w'


    # build the targets required before touching the Android.bp/Android.mk files
    local build_cmd="$top/build/soong/soong_ui.bash --make-mode"
    $build_cmd bpmodify

    "$top/prebuilts/build-tools/path/linux-x86/python3" "$top/hardware/interfaces/compatibility_matrices/bump.py" "$CURRENT_COMPATIBILITY_MATRIX_LEVEL" "$NEXT_COMPATIBILITY_MATRIX_LEVEL" "$CURRENT_RELEASE_LETTER" "$NEXT_RELEASE_LETTER"

    # Freeze the current framework manifest file. This relies on the
    # aosp_cf_x86_64-trunk_staging build target to get the right manifest
    # fragments installed.
    "$top/system/libhidl/vintfdata/freeze.sh" "$CURRENT_COMPATIBILITY_MATRIX_LEVEL"
}

function freeze_framework_manifest() {
   ANDROID_PRODUCT_OUT=~/workspace/internal/main/out/target/product/vsoc_x86 ANDROID_BUILD_TOP=~/workspace/internal/main ANDROID_HOST_OUT=~/workspace/internal/main/out/host/linux-x86 ./freeze.sh 202404

}


finalize_vintf_resources

