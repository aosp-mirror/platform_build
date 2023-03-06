#!/bin/bash

set -ex

function finalize_main_step1() {
    local top="$(dirname "$0")"/../../../..
    source $top/build/make/tools/finalization/environment.sh

    # Build finalization artifacts.
    source $top/build/make/tools/finalization/finalize-aidl-vndk-sdk-resources.sh
}

finalize_main_step1

