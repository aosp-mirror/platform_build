#!/bin/bash
# Brings local repository to a remote head state.

# set -ex

function finalize_revert_local_changes_main() {
    local top="$(dirname "$0")"/../../../..
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=aosp_arm64 TARGET_BUILD_VARIANT=userdebug"

    # remove the out folder
    $m clobber

    repo selfupdate

    repo forall -c '\
        git checkout . ; git revert --abort ; git clean -fdx ;\
        git checkout @ ; git branch fina-step1 -D ; git reset --hard; \
        repo start fina-step1 ; git checkout @ ; git b fina-step1 -D ;'
}

finalize_revert_local_changes_main
