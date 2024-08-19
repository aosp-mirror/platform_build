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

# This script is used to generate the ide_query.out file.
#
# The ide_query.out file is a pre-computed result of running ide_query.sh
# on a set of files. This allows the prober to run its tests without running
# ide_query.sh. The prober doesn't check-out the full source code, so it
# can't run ide_query.sh itself.

cd $(dirname $BASH_SOURCE)
source $(pwd)/../../../shell_utils.sh
require_top

files_to_build=(
  build/make/tools/ide_query/prober_scripts/cpp/general.cc
)

cd ${TOP}
build/make/tools/ide_query/ide_query.sh --lunch_target=aosp_arm-trunk_staging-eng ${files_to_build[@]} > build/make/tools/ide_query/prober_scripts/ide_query.out
