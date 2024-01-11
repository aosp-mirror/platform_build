#!/bin/bash

set -ex

function finalize_vintf_resources() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # TODO(b/314010764): finalize LL_NDK
    # TODO(b/314010177): finalize SELinux

    create_new_compat_matrix

    # pre-finalization build target (trunk)
    local aidl_m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_RELEASE=trunk TARGET_BUILD_VARIANT=userdebug DIST_DIR=out/dist"
    AIDL_TRANSITIVE_FREEZE=true $aidl_m aidl-freeze-api

    # build/make
    sed -i -e "s/sepolicy_major_vers := .*/sepolicy_major_vers := ${FINAL_PLATFORM_SDK_VERSION}/g" "$top/build/make/core/config.mk"
    cp "$top/build/make/target/product/gsi/current.txt" "$top/build/make/target/product/gsi/$FINAL_PLATFORM_SDK_VERSION.txt"
}

function create_new_compat_matrix() {
    # The compatibility matrix versions are bumped during vFRC
    # These will change every time we have a new vFRC
    export CURRENT_COMPATIBILITY_MATRIX_LEVEL='9'
    export FINAL_COMPATIBILITY_MATRIX_LEVEL='10'

    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    local current_file=compatibility_matrix."$CURRENT_COMPATIBILITY_MATRIX_LEVEL".xml
    local final_file=compatibility_matrix."$FINAL_COMPATIBILITY_MATRIX_LEVEL".xml
    local current_bp_module=framework_$current_file
    local final_bp_module=framework_$final_file
    local src=$top/hardware/interfaces/compatibility_matrices/$current_file
    local dest=$top/hardware/interfaces/compatibility_matrices/$final_file
    local bp_file=$top/hardware/interfaces/compatibility_matrices/Android.bp

    # check to see if this script needs to be run
    if grep -q $final_bp_module $bp_file; then
      echo "Nothing to do because the new module exists"
      return
    fi

    # build the targets required before touching the Android.bp/Android.mk files
    local build_cmd="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_RELEASE=trunk TARGET_BUILD_VARIANT=userdebug DIST_DIR=out/dist"
    $build_cmd bpfmt
    $build_cmd bpmodify
    $build_cmd queryview

    # create the new file and modify the level
    sed "s/level=\""$CURRENT_COMPATIBILITY_MATRIX_LEVEL"\"/level=\""$FINAL_COMPATIBILITY_MATRIX_LEVEL"\"/" "$src" > "$dest"

    echo "
      vintf_compatibility_matrix {
          name: \"$final_bp_module\",
          stem: \"$final_file\",
          srcs: [
              \"$final_file\",
          ],
      }" >> $bp_file

    # get the previous kernel_configs properties and add them to the new module
    local kernel_configs=$($top/out/host/linux-x86/bin/bazel query --config=queryview //hardware/interfaces/compatibility_matrices:"$current_bp_module"--android_common --output=build | grep kernel_configs | sed 's/[^\[]*\[\(.*\)],/\1/' | sed 's/ //g' | sed 's/\"//g')

    $top/out/host/linux-x86/bin/bpmodify -m $final_bp_module -property kernel_configs -a $kernel_configs -w $bp_file

    $top/out/host/linux-x86/bin/bpfmt -w $bp_file

    local make_file=$top/hardware/interfaces/compatibility_matrices/Android.mk
    # replace the current compat matrix in the make file with the final one
    # the only place this resides is in the conditional addition
    sed -i "s/$current_file/$final_file/g" $make_file
    # add the current compat matrix to the unconditional addition
    sed -i "/^    framework_compatibility_matrix.device.xml/i \    $current_bp_module \\\\" $make_file
}

finalize_vintf_resources

