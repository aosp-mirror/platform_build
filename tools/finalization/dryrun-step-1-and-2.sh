#!/bin/bash
# Script to perform 1st and 2nd step of Android Finalization, create CLs and upload to Gerrit.

function commit_step_2_changes() {
    repo forall -c '\
        if [[ $(git status --short) ]]; then
            repo start "$FINAL_PLATFORM_CODENAME-SDK-Finalization-DryRun-Rel" ;
            git add -A . ;
            git commit -m "$FINAL_PLATFORM_CODENAME/$FINAL_PLATFORM_SDK_VERSION is now REL" \
                       -m "Ignore-AOSP-First: $FINAL_PLATFORM_CODENAME Finalization
Bug: $FINAL_BUG_ID
Test: build";

            repo upload --cbr --no-verify -o nokeycheck -t -y . ;
        fi'
}

function finalize_step_2_main() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    source $top/build/make/tools/finalization/finalize-sdk-resources.sh

    source $top/build/make/tools/finalization/localonly-steps.sh

    source $top/build/make/tools/finalization/finalize-sdk-rel.sh

    # move all changes to finalization branch/topic and upload to gerrit
    commit_step_2_changes

    # build to confirm everything is OK
    local m_next="$top/build/soong/soong_ui.bash --make-mode TARGET_RELEASE=next TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"
    $m_next

    local m_fina="$top/build/soong/soong_ui.bash --make-mode TARGET_RELEASE=fina_2 TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"
    $m_fina
}

finalize_step_2_main
