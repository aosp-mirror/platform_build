#!/bin/bash
# Brings local repository to a remote head state. Also removes all dryrun branches.

# set -ex

function finalize_revert_local_changes_main() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # remove the out folder
    $m clobber

    repo selfupdate

    repo forall -c '\
        git checkout . ; git revert --abort ; git clean -fdx ;\
        git checkout @ --detach ; git branch fina-step1 -D ; git reset --hard; \
        repo start fina-step1 ; git checkout @ --detach ; git b fina-step1 -D ; \
        git b $FINAL_PLATFORM_CODENAME-SDK-Finalization-DryRun -D; \
        git b $FINAL_PLATFORM_CODENAME-SDK-Finalization-DryRun-Rel -D; '
}

finalize_revert_local_changes_main
