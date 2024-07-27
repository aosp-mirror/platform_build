#!/bin/bash
# Copyright 2024 Google Inc. All rights reserved.

set -ex

function finalize_main_step0() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    local need_vintf_finalize=false
    if [ "$FINAL_STATE" = "unfinalized" ] ; then
        need_vintf_finalize=true
    else
        # build-step-0.sh tests the vintf finalization step (step-0) when the
        # FINAL_BOARD_API_LEVEL is the same as the RELEASE_BOARD_API_LEVEL; and
        # RELEASE_BOARD_API_LEVEL_FROZEN is not true from the fina_0 configuration.
        # The FINAL_BOARD_API_LEVEL must be the next vendor API level to be finalized.
        local board_api_level_vars=$(TARGET_RELEASE=fina_0 $top/build/soong/soong_ui.bash --dumpvars-mode -vars "RELEASE_BOARD_API_LEVEL_FROZEN RELEASE_BOARD_API_LEVEL")
        local target_board_api_level_vars="RELEASE_BOARD_API_LEVEL_FROZEN=''
RELEASE_BOARD_API_LEVEL='$FINAL_BOARD_API_LEVEL'"
        if [ "$board_api_level_vars" = "$target_board_api_level_vars" ] ; then
            echo The target is a finalization candidate.
            need_vintf_finalize=true
        fi;
    fi;

    if [ "$need_vintf_finalize" = true ] ; then        # VINTF finalization
        source $top/build/make/tools/finalization/finalize-vintf-resources.sh
    fi;
}

finalize_main_step0
