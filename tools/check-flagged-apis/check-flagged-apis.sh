#!/bin/bash

# Copyright (C) 2024 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Run check-flagged-apis for public APIs and the three @SystemApi flavours
# Usage: lunch <your-target> && source <this script>

source $(cd $(dirname $BASH_SOURCE) &> /dev/null && pwd)/../../shell_utils.sh
require_top

function m() {
    $(gettop)/build/soong/soong_ui.bash --build-mode --all-modules --dir="$(pwd)" "$@"
}

function build() {
    m sdk dist && m \
        check-flagged-apis \
        all_aconfig_declarations \
        frameworks-base-api-current.txt \
        frameworks-base-api-system-current.txt \
        frameworks-base-api-system-server-current.txt \
        frameworks-base-api-module-lib-current.txt
}

function run() {
    local errors=0

    echo "# current"
    check-flagged-apis \
        --api-signature $(gettop)/out/target/product/mainline_x86/obj/ETC/frameworks-base-api-current.txt_intermediates/frameworks-base-api-current.txt \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $(gettop)/out/dist/data/api-versions.xml
    (( errors += $? ))

    echo
    echo "# system-current"
    check-flagged-apis \
        --api-signature $(gettop)/out/target/product/mainline_x86/obj/ETC/frameworks-base-api-system-current.txt_intermediates/frameworks-base-api-system-current.txt \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $(gettop)/out/dist/system-data/api-versions.xml
    (( errors += $? ))

    echo
    echo "# system-server-current"
    check-flagged-apis \
        --api-signature $(gettop)/out/target/product/mainline_x86/obj/ETC/frameworks-base-api-system-server-current.txt_intermediates/frameworks-base-api-system-server-current.txt \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $(gettop)/out/dist/system-server-data/api-versions.xml
    (( errors += $? ))

    echo
    echo "# module-lib"
    check-flagged-apis \
        --api-signature $(gettop)/out/target/product/mainline_x86/obj/ETC/frameworks-base-api-module-lib-current.txt_intermediates/frameworks-base-api-module-lib-current.txt \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $(gettop)/out/dist/module-lib-data/api-versions.xml
    (( errors += $? ))

    return $errors
}

if [[ "$1" != "--skip-build" ]]; then
    build && run
else
    run
fi
