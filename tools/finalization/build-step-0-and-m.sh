
#!/bin/bash
# Copyright 2024 Google Inc. All rights reserved.
set -ex
function help() {
    echo "Finalize VINTF and build a target for test."
    echo "usage: $(basename "$0") target [goals...]"
}
function finalize_main_step0_and_m() {
    if [ $# == 0 ] ; then
        help
        exit 1
    fi;
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/build-step-0.sh
    local m="$top/build/soong/soong_ui.bash --make-mode TARGET_PRODUCT=$1 TARGET_RELEASE=fina_0 TARGET_BUILD_VARIANT=userdebug"
    # This command tests the release state for AIDL.
    AIDL_FROZEN_REL=true $m ${@:2}
}
finalize_main_step0_and_m $@
