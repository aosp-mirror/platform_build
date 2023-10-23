#!/bin/bash -e
# Copyright (C) 2023 The Android Open Source Project
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


source $(cd $(dirname $BASH_SOURCE) &> /dev/null && pwd)/../shell_utils.sh
require_top

function print_help() {
    echo -e "overrideflags is used to set default value for local build."
    echo -e "\nOptions:"
    echo -e "\t--release-config  \tPath to release configuration directory. Required"
    echo -e "\t--no-edit         \tIf present, skip editing flag value file."
    echo -e "\t-h/--help         \tShow this help."
}

function main() {
    while (($# > 0)); do
        case $1 in
        --release-config)
            if [[ $# -le 1 ]]; then
                echo "--release-config requires a path"
                return 1
            fi
            local release_config_dir="$2"
            shift 2
            ;;
        --no-edit)
            local no_edit="true"
            shift 1
            ;;
        -h|--help)
            print_help
            return
            ;;
        *)
            echo "$1 is unrecognized"
            print_help
            return 1
            ;;
        esac
    done



    case $(uname -s) in
        Darwin)
            local host_arch=darwin-x86
            ;;
        Linux)
            local host_arch=linux-x86
            ;;
        *)
            >&2 echo Unknown host $(uname -s)
            return
            ;;
    esac

    if [[ -z "${release_config_dir}" ]]; then
        echo "Please provide release configuration path by --release-config"
        exit 1
    elif [ ! -d "${release_config_dir}" ]; then
        echo "${release_config_dir} is an invalid directory"
        exit 1
    fi
    local T="$(gettop)"
    local aconfig_dir="${T}"/build/make/tools/aconfig/
    local overrideflag_py="${aconfig_dir}"/overrideflags/overrideflags.py
    local overridefile="${release_config_dir}/aconfig/override_values.textproto"

    # Edit override file
    if [[ -z "${no_edit}" ]]; then
        editor="${EDITOR:-$(which vim)}"

        eval "${editor} ${overridefile}"
        if [ $? -ne 0 ]; then
            echo "Fail to set override values"
            return 1
        fi
    fi

    ${T}/prebuilts/build-tools/${host_arch}/bin/py3-cmd -u "${overrideflag_py}" \
        --overrides "${overridefile}" \
        --out "${release_config_dir}/aconfig"
}


main "$@"
