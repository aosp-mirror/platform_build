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

# Run check-flagged-apis for public APIs and the three @SystemApi flavours.
#
# This script expects an argument to tell it which subcommand of
# check-flagged-apis to execute. Run the script without any arguments to see
# the valid options.
#
# Remember to lunch to select the relevant release config before running this script.

source $(cd $(dirname $BASH_SOURCE) &> /dev/null && pwd)/../../shell_utils.sh
require_top

PUBLIC_XML_VERSIONS=out/target/common/obj/PACKAGING/api_versions_public_generated-api-versions.xml
SYSTEM_XML_VERSIONS=out/target/common/obj/PACKAGING/api_versions_system_generated-api-versions.xml
SYSTEM_SERVER_XML_VERSONS=out/target/common/obj/PACKAGING/api_versions_system_server_complete_generated-api-versions.xml
MODULE_LIB_XML_VERSIONS=out/target/common/obj/PACKAGING/api_versions_module_lib_complete_generated-api-versions.xml

function m() {
    $(gettop)/build/soong/soong_ui.bash --build-mode --all-modules --dir="$(pwd)" "$@"
}

function build() {
    m \
        check-flagged-apis \
        all_aconfig_declarations \
        frameworks-base-api-current.txt \
        frameworks-base-api-system-current.txt \
        frameworks-base-api-system-server-current.txt \
        frameworks-base-api-module-lib-current.txt \
        $PUBLIC_XML_VERSIONS \
        $SYSTEM_XML_VERSIONS \
        $SYSTEM_SERVER_XML_VERSONS \
        $MODULE_LIB_XML_VERSIONS
}

function noop() {
    true
}

function aninja() {
    local T="$(gettop)"
    (\cd "${T}" && prebuilts/build-tools/linux-x86/bin/ninja -f out/combined-${TARGET_PRODUCT}.ninja "$@")
}

function path_to_api_signature_file {
    aninja -t query device_"$1"_all_targets | grep -A1 -e input: | tail -n1
}

function run_check() {
    local errors=0

    echo "# current"
    check-flagged-apis check \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $PUBLIC_XML_VERSIONS
    (( errors += $? ))

    echo
    echo "# system-current"
    check-flagged-apis check \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-system-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $SYSTEM_XML_VERSIONS
    (( errors += $? ))

    echo
    echo "# system-server-current"
    check-flagged-apis check \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-system-server-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $SYSTEM_SERVER_XML_VERSONS
    (( errors += $? ))

    echo
    echo "# module-lib"
    check-flagged-apis check \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-module-lib-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb \
        --api-versions $MODULE_LIB_XML_VERSIONS
    (( errors += $? ))

    return $errors
}

function run_list() {
    echo "# current"
    check-flagged-apis list \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb

    echo
    echo "# system-current"
    check-flagged-apis list \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-system-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb

    echo
    echo "# system-server-current"
    check-flagged-apis list \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-system-server-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb

    echo
    echo "# module-lib"
    check-flagged-apis list \
        --api-signature $(path_to_api_signature_file "frameworks-base-api-module-lib-current.txt") \
        --flag-values $(gettop)/out/soong/.intermediates/all_aconfig_declarations.pb
}

build_cmd=build
if [[ "$1" == "--skip-build" ]]; then
    build_cmd=noop
    shift 1
fi

case "$1" in
    check) $build_cmd && run_check ;;
    list) $build_cmd && run_list ;;
    *) echo "usage: $(basename $0): [--skip-build] check|list"; exit 1
esac
