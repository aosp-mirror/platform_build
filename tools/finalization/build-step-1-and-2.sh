#!/bin/bash

set -ex

function finalize_main_step12() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # SDK codename -> int
    source $top/build/make/tools/finalization/finalize-aidl-vndk-sdk-resources.sh

    # ADB, Platform/Mainline SDKs build and move to prebuilts
    source $top/build/make/tools/finalization/localonly-steps.sh

    # REL
    source $top/build/make/tools/finalization/finalize-sdk-rel.sh
}

finalize_main_step12

