#!/bin/bash -e

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

cd $(dirname $BASH_SOURCE)
source $(pwd)/../../shell_utils.sh
require_top

# Ensure cogsetup (out/ will be symlink outside the repo)
. ${TOP}/build/make/cogsetup.sh

case $(uname -s) in
    Linux)
      export PREBUILTS_CLANG_TOOLS_ROOT="${TOP}/prebuilts/clang-tools/linux-x86/"
      PREBUILTS_GO_ROOT="${TOP}/prebuilts/go/linux-x86/"
      ;;
    *)
      echo "Only supported for linux hosts" >&2
      exit 1
      ;;
esac

export ANDROID_BUILD_TOP=$TOP
export OUT_DIR=${OUT_DIR}
exec "${PREBUILTS_GO_ROOT}/bin/go" "run" "ide_query" "$@"
