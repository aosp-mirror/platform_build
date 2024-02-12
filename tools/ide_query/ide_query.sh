#!/bin/bash -e

cd $(dirname $BASH_SOURCE)
source $(pwd)/../../shell_utils.sh
require_top

# Ensure cogsetup (out/ will be symlink outside the repo)
. ${TOP}/build/make/cogsetup.sh

export ANDROID_BUILD_TOP=$TOP
export OUT_DIR=${OUT_DIR}
exec "${TOP}/prebuilts/go/linux-x86/bin/go" "run" "ide_query" "$@"
