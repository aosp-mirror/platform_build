#!/bin/bash

set -ex

function finalize_main_step12() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    if [ "$FINAL_STATE" = "unfinalized" ] ; then
        # VINTF finalization
        source $top/build/make/tools/finalization/finalize-vintf-resources.sh
    fi;

    if [ "$FINAL_STATE" = "unfinalized" ] || [ "$FINAL_STATE" = "vintf" ] ; then
        # SDK codename -> int
        source $top/build/make/tools/finalization/finalize-sdk-resources.sh
    fi;

    if [ "$FINAL_STATE" = "unfinalized" ] || [ "$FINAL_STATE" = "vintf" ] || [ "$FINAL_STATE" = "sdk" ] ; then
        # ADB, Platform/Mainline SDKs build and move to prebuilts
        source $top/build/make/tools/finalization/localonly-steps.sh

        # REL
        source $top/build/make/tools/finalization/finalize-sdk-rel.sh
    fi;
}

finalize_main_step12

