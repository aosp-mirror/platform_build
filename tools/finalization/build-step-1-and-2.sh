#!/bin/bash

set -ex

function finalize_main_step12() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # SDK codename -> int
    source $top/build/make/tools/finalization/finalize-aidl-vndk-sdk-resources.sh

    # Platform/Mainline SDKs build and move to prebuilts
    source $top/build/make/tools/finalization/localonly-finalize-mainline-sdk.sh

    # REL
    source $top/build/make/tools/finalization/finalize-sdk-rel.sh
}

finalize_main_step12

