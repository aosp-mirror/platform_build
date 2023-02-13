#!/bin/bash
# Script to perform a 2nd step of Android Finalization: REL finalization, create CLs and upload to Gerrit.

function commit_step_2_changes() {
    repo forall -c '\
        if [[ $(git status --short) ]]; then
            repo start "$FINA_PLATFORM_CODENAME-SDK-Finalization-Rel" ;
            git add -A . ;
            git commit -m "$FINA_PLATFORM_CODENAME/$FINA_PLATFORM_SDK_VERSION is now REL" \
                       -m "Ignore-AOSP-First: $FINA_PLATFORM_CODENAME Finalization
Bug: $FINA_BUG_ID
Test: build";

            repo upload --cbr --no-verify -o nokeycheck -t -y . ;
            git clean -fdx ; git reset --hard ;
        fi'
}

function finalize_step_2_main() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # prebuilts etc
    source $top/build/make/tools/finalization/finalize-sdk-rel.sh

    # Update prebuilts.
    "$top/prebuilts/build-tools/path/linux-x86/python3" "$top/packages/modules/common/tools/finalize_sdk.py" -b ${FINA_BUG_ID} -f ${FINA_MAINLINE_EXTENSION} -r "${FINA_MAINLINE_SDK_COMMIT_MESSAGE}" ${FINA_MAINLINE_SDK_BUILD_ID}

    # build to confirm everything is OK
    AIDL_FROZEN_REL=true $m

    # move all changes to finalization branch/topic and upload to gerrit
    commit_step_2_changes
}

finalize_step_2_main
