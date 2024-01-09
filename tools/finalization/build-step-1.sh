#!/bin/bash

set -ex

function finalize_main_step1() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    if [ "$FINAL_STATE" = "unfinalized" ] ; then
        # Build finalization artifacts.
        source $top/build/make/tools/finalization/finalize-vintf-resources.sh
        source $top/build/make/tools/finalization/finalize-sdk-resources.sh
    fi;
}

finalize_main_step1

