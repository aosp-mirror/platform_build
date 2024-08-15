# Copyright (C) 2022 The Android Open Source Project
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

function gettop
{
    local TOPFILE=build/make/core/envsetup.mk
    # The ${TOP-} expansion allows this to work even with set -u
    if [ -n "${TOP:-}" -a -f "${TOP:-}/$TOPFILE" ] ; then
        # The following circumlocution ensures we remove symlinks from TOP.
        (cd "$TOP"; PWD= /bin/pwd)
    else
        if [ -f $TOPFILE ] ; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE=$PWD
            local T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( "$PWD" != "/" \) ]; do
                \cd ..
                T=`PWD= /bin/pwd -P`
            done
            \cd "$HERE"
            if [ -f "$T/$TOPFILE" ]; then
                echo "$T"
            fi
        fi
    fi
}

# Asserts that the root of the tree can be found.
if [ -z "${IMPORTING_ENVSETUP:-}" ] ; then
function require_top
{
    TOP=$(gettop)
    if [[ ! $TOP ]] ; then
        echo "Can not locate root of source tree. $(basename $0) must be run from within the Android source tree or TOP must be set." >&2
        exit 1
    fi
}
fi

# Asserts that the lunch variables have been set
if [ -z "${IMPORTING_ENVSETUP:-}" ] ; then
function require_lunch
{
    if [[ ! $TARGET_PRODUCT || ! $TARGET_RELEASE || ! $TARGET_BUILD_VARIANT  ]] ; then
        echo "Please run lunch and try again." >&2
        exit 1
    fi
}
fi

function getoutdir
{
    local top=$(gettop)
    local out_dir="${OUT_DIR:-}"
    if [[ -z "${out_dir}" ]]; then
        if [[ -n "${OUT_DIR_COMMON_BASE:-}" && -n "${top}" ]]; then
            out_dir="${OUT_DIR_COMMON_BASE}/$(basename ${top})"
        else
            out_dir="out"
        fi
    fi
    if [[ "${out_dir}" != /* ]]; then
        out_dir="${top}/${out_dir}"
    fi
    echo "${out_dir}"
}

# Pretty print the build status and duration
function _wrap_build()
{
    if [[ "${ANDROID_QUIET_BUILD:-}" == true ]]; then
      "$@"
      return $?
    fi
    local start_time=$(date +"%s")
    "$@"
    local ret=$?
    local end_time=$(date +"%s")
    local tdiff=$(($end_time-$start_time))
    local hours=$(($tdiff / 3600 ))
    local mins=$((($tdiff % 3600) / 60))
    local secs=$(($tdiff % 60))
    local ncolors=$(tput colors 2>/dev/null)
    if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
        color_failed=$'\E'"[0;31m"
        color_success=$'\E'"[0;32m"
        color_warning=$'\E'"[0;33m"
        color_reset=$'\E'"[00m"
    else
        color_failed=""
        color_success=""
        color_reset=""
    fi

    echo
    if [ $ret -eq 0 ] ; then
        echo -n "${color_success}#### build completed successfully "
    else
        echo -n "${color_failed}#### failed to build some targets "
    fi
    if [ $hours -gt 0 ] ; then
        printf "(%02g:%02g:%02g (hh:mm:ss))" $hours $mins $secs
    elif [ $mins -gt 0 ] ; then
        printf "(%02g:%02g (mm:ss))" $mins $secs
    elif [ $secs -gt 0 ] ; then
        printf "(%s seconds)" $secs
    fi
    echo " ####${color_reset}"
    echo
    return $ret
}


function log_tool_invocation()
{
    if [[ -z $ANDROID_TOOL_LOGGER ]]; then
        return
    fi

    LOG_TOOL_TAG=$1
    LOG_START_TIME=$(date +%s.%N)
    trap '
        exit_code=$?;
        # Remove the trap to prevent duplicate log.
        trap - EXIT;
        $ANDROID_TOOL_LOGGER \
                --tool_tag="${LOG_TOOL_TAG}" \
                --start_timestamp="${LOG_START_TIME}" \
                --end_timestamp="$(date +%s.%N)" \
                --tool_args="$*" \
                --exit_code="${exit_code}" \
                ${ANDROID_TOOL_LOGGER_EXTRA_ARGS} \
           > /dev/null 2>&1 &
        exit ${exit_code}
    ' SIGINT SIGTERM SIGQUIT EXIT
}

