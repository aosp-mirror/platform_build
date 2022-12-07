#!/bin/bash
# Continuous Integration script for *-finalization-2 branches.
# Reverts previous finalization script commits and runs local build.

set -ex

function revert_to_unfinalized_state() {
    declare -a projects=(
        "build/make/"
        "build/soong/"
        "cts/"
        "frameworks/base/"
        "frameworks/hardware/interfaces/"
        "frameworks/libs/modules-utils/"
        "frameworks/libs/net/"
        "hardware/interfaces/"
        "libcore/"
        "packages/services/Car/"
        "platform_testing/"
        "prebuilts/abi-dumps/ndk/"
        "prebuilts/abi-dumps/platform/"
        "prebuilts/abi-dumps/vndk/"
        "system/hardware/interfaces/"
        "system/tools/aidl/"
        "tools/platform-compat"
        "device/generic/car"
        "development"
    )

    for project in "${projects[@]}"
    do
        local git_path="$top/$project"
        echo "Reverting: $git_path"
        baselineHash="$(git -C $git_path log --format=%H --no-merges --max-count=1 --grep ^FINALIZATION_STEP_1_BASELINE_COMMIT)" ;
        if [[ $baselineHash ]]; then
          previousHash="$(git -C $git_path log --format=%H --no-merges --max-count=100 --grep ^FINALIZATION_STEP_1_SCRIPT_COMMIT $baselineHash..HEAD | tr \n \040)" ;
        else
          previousHash="$(git -C $git_path log --format=%H --no-merges --max-count=100 --grep ^FINALIZATION_STEP_1_SCRIPT_COMMIT | tr \n \040)" ;
        fi ;
        if [[ $previousHash ]]; then git -C $git_path revert --no-commit --strategy=ort --strategy-option=ours $previousHash ; fi ;
    done
}

function finalize_step_2_main() {
    local top="$(dirname "$0")"/../..
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    revert_to_unfinalized_state

    # vndk etc finalization
    source $top/build/make/finalize-aidl-vndk-sdk-resources.sh

    # prebuilts etc
    source $top/build/make/finalize-sdk-rel.sh

    # build to confirm everything is OK
    AIDL_FROZEN_REL=true $m
}

finalize_step_2_main
