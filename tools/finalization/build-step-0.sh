#!/bin/bash
# Copyright 2024 Google Inc. All rights reserved.

set -ex

function finalize_main_step0() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    if [ "$FINAL_STATE" = "unfinalized" ] ; then
        # VINTF finalization
        source $top/build/make/tools/finalization/finalize-vintf-resources.sh
    fi;
}

finalize_main_step0

