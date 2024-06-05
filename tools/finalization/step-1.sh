#!/bin/bash
# Script to perform a 1st step of Android Finalization: API/SDK finalization, create CLs and upload to Gerrit.

set -ex

function commit_step_1_changes() {
    set +e
    repo forall -c '\
        if [[ $(git status --short) ]]; then
            repo start "'$repo_branch'" ;
            git add -A . ;
            git commit -m "$FINAL_PLATFORM_CODENAME is now $FINAL_PLATFORM_SDK_VERSION and extension version $FINAL_MAINLINE_EXTENSION" \
                       -m "Ignore-AOSP-First: $FINAL_PLATFORM_CODENAME Finalization
Bug: $FINAL_BUG_ID
Test: build";
            repo upload '"$repo_upload_dry_run_arg"' --cbr --no-verify -o nokeycheck -t -y . ;
        fi'
}

function finalize_step_1_main() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh
    local repo_branch="$FINAL_PLATFORM_CODENAME-SDK-Finalization"
    source $top/build/make/tools/finalization/command-line-options.sh

    source $top/build/make/tools/finalization/finalize-sdk-resources.sh

    # move all changes to finalization branch/topic and upload to gerrit
    commit_step_1_changes

    # build to confirm everything is OK
    local m_next="$top/build/soong/soong_ui.bash --make-mode TARGET_RELEASE=next TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"
    $m_next

    local m_fina="$top/build/soong/soong_ui.bash --make-mode TARGET_RELEASE=fina_1 TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"
    $m_fina
}

finalize_step_1_main $@
