#!/bin/bash
# Continuous Integration script for *-finalization-1 branches.
# Reverts previous finalization script commits and runs local build.

function revert_to_unfinalized_state() {
    repo forall -c '\
        git checkout . ; git revert --abort ; git clean -fdx ;\
        git checkout @ ; git branch fina-step1 -D ; git reset --hard; \
        repo start fina-step1 ; git checkout @ ; git b fina-step1 -D ;\
        baselineHash="$(git log --format=%H --no-merges --max-count=1 --grep ^FINALIZATION_STEP_1_BASELINE_COMMIT)" ;\
        if [[ $baselineHash ]]; then
          previousHash="$(git log --format=%H --no-merges --max-count=100 --grep ^FINALIZATION_STEP_1_SCRIPT_COMMIT $baselineHash..HEAD | tr \n \040)" ;\
        else
          previousHash="$(git log --format=%H --no-merges --max-count=100 --grep ^FINALIZATION_STEP_1_SCRIPT_COMMIT | tr \n \040)" ;\
        fi ; \
        if [[ $previousHash ]]; then git revert --no-commit --strategy=ort --strategy-option=ours $previousHash ; fi ;'
}

function finalize_step_1_main() {
    local top="$(dirname "$0")"/../..
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    revert_to_unfinalized_state

    set -ex

    # vndk etc finalization
    source $top/build/make/finalize-aidl-vndk-sdk-resources.sh

    # build to confirm everything is OK
    AIDL_FROZEN_REL=true $m
}

finalize_step_1_main
