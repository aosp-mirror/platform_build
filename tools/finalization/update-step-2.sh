#!/bin/bash
# Script to perform a 2nd step of Android Finalization: REL finalization, create CLs and upload to Gerrit.

function update_step_2_changes() {
    set +e
    repo forall -c '\
        if [[ $(git status --short) ]]; then
            git stash -u ;
            repo start "$FINAL_PLATFORM_CODENAME-SDK-Finalization-Rel" ;
            git stash pop ;
            git add -A . ;
            git commit --amend --no-edit ;
            repo upload --cbr --no-verify -o nokeycheck -t -y . ;
        fi'
}

function update_step_2_main() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # prebuilts etc
    source $top/build/make/tools/finalization/finalize-sdk-rel.sh

    # move all changes to finalization branch/topic and upload to gerrit
    update_step_2_changes

    # build to confirm everything is OK
    AIDL_FROZEN_REL=true $m
}

update_step_2_main
