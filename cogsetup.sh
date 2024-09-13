#
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
#

# This file is executed by build/envsetup.sh, and can use anything
# defined in envsetup.sh.
function _create_out_symlink_for_cog() {
  if [[ "${OUT_DIR}" == "" ]]; then
    OUT_DIR="out"
  fi

  # getoutdir ensures paths are absolute. envsetup could be called from a
  # directory other than the root of the source tree
  local outdir=$(getoutdir)
  if [[ -L "${outdir}" ]]; then
    return
  fi
  if [ -d "${outdir}" ]; then
    echo -e "\tOutput directory ${outdir} cannot be present in a Cog workspace."
    echo -e "\tDelete \"${outdir}\" or create a symlink from \"${outdir}\" to a directory outside your workspace."
    return 1
  fi

  DEFAULT_OUTPUT_DIR="${HOME}/.cog/android-build-out"
  mkdir -p ${DEFAULT_OUTPUT_DIR}
  ln -s ${DEFAULT_OUTPUT_DIR} ${outdir}
}

# This function sets up the build environment to be appropriate for Cog.
function _setup_cog_env() {
  _create_out_symlink_for_cog
  if [ "$?" -eq "1" ]; then
    echo -e "\e[0;33mWARNING:\e[00m Cog environment setup failed!"
    return 1
  fi

  export ANDROID_BUILD_ENVIRONMENT_CONFIG="googler-cog"

  # Running repo command within Cog workspaces is not supported, so override
  # it with this function. If the user is running repo within a Cog workspace,
  # we'll fail with an error, otherwise, we run the original repo command with
  # the given args.
  if ! ORIG_REPO_PATH=`which repo`; then
    return 0
  fi
  function repo {
    if [[ "${PWD}" == /google/cog/* ]]; then
      echo -e "\e[01;31mERROR:\e[0mrepo command is disallowed within Cog workspaces."
      return 1
    fi
    ${ORIG_REPO_PATH} "$@"
  }
}

if [[ "${PWD}" != /google/cog/* ]]; then
  echo -e "\e[01;31mERROR:\e[0m This script must be run from a Cog workspace."
fi

_setup_cog_env
