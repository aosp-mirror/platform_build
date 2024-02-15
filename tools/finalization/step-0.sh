#!/bin/bash
# Copyright 2024 Google Inc. All rights reserved.

# Script to perform a 0th step of Android Finalization: VINTF finalization, create CLs and upload to Gerrit.

set -ex

function commit_step_0_changes() {
    set +e
    repo forall -c '\
        if [[ $(git status --short) ]]; then
            repo start "VINTF-$FINAL_BOARD_API_LEVEL-Finalization" ;
            git add -A . ;
            git commit -m "Vendor API level $FINAL_BOARD_API_LEVEL is now frozen" \
                       -m "Ignore-AOSP-First: VINTF $FINAL_BOARD_API_LEVEL Finalization
Bug: $FINAL_BUG_ID
Test: build";
            repo upload --cbr --no-verify -o nokeycheck -t -y . ;
        fi'
}

function finalize_step_0_main() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_RELEASE=next TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    source $top/build/make/tools/finalization/finalize-vintf-resources.sh

    # move all changes to finalization branch/topic and upload to gerrit
    commit_step_0_changes

    # build to confirm everything is OK
    AIDL_FROZEN_REL=true $m
}

finalize_step_0_main
