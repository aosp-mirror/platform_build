#!/bin/bash

set -ex

function finalize_vintf_resources() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # TODO(b/314010764): finalize LL_NDK

    # system/sepolicy
    "$top/system/sepolicy/tools/finalize-vintf-resources.sh" "$top" "$FINAL_BOARD_API_LEVEL"

    create_new_compat_matrix_and_kernel_configs

    # pre-finalization build target (trunk)
    local aidl_m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_RELEASE=fina_0 TARGET_BUILD_VARIANT=userdebug DIST_DIR=out/dist"
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
    local build_cmd="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_RELEASE=fina_0 TARGET_BUILD_VARIANT=userdebug DIST_DIR=out/dist"
    $build_cmd bpmodify

    ANDROID_BUILD_TOP="$top" PATH="$PATH:$top/out/host/linux-x86/bin/" "$top/prebuilts/build-tools/path/linux-x86/python3" "$top/hardware/interfaces/compatibility_matrices/bump.py" "$CURRENT_COMPATIBILITY_MATRIX_LEVEL" "$NEXT_COMPATIBILITY_MATRIX_LEVEL" "$CURRENT_RELEASE_LETTER" "$NEXT_RELEASE_LETTER"
}

finalize_vintf_resources

