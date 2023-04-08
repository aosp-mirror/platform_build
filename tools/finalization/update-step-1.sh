#!/bin/bash
# Script to perform a 1st step of Android Finalization: API/SDK finalization, update CLs and upload to Gerrit.

set -ex

function update_step_1_changes() {
    set +e
    repo forall -c '\
        if [[ $(git status --short) ]]; then
            git stash -u ;
            repo start "$FINAL_PLATFORM_CODENAME-SDK-Finalization" ;
            git stash pop ;
            git add -A . ;
            git commit --amend --no-edit ;
            repo upload --cbr --no-verify -o nokeycheck -t -y . ;
        fi'
}

function update_step_1_main() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh


    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # vndk etc finalization
    source $top/build/make/tools/finalization/finalize-aidl-vndk-sdk-resources.sh

    # update existing CLs and upload to gerrit
    update_step_1_changes

    # build to confirm everything is OK
    AIDL_FROZEN_REL=true $m
}

update_step_1_main
