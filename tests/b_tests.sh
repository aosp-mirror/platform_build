# Copyright (C) 2022 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# These commands are expected to always return successfully

trap 'exit 1' ERR

source $(dirname $0)/../envsetup.sh

# lunch required to set up PATH to use b
lunch aosp_arm64

test_target=//build/bazel/scripts/difftool:difftool

if b build //build/bazel:nonexistent_module &>/dev/null ; then
    echo "b did not fail when building a nonexistent module" >&2
    exit 1
fi
b build "$test_target"
b build -- "$test_target"
b build "$test_target" --run-soong-tests
b build --run-soong-tests "$test_target"
b --run-soong-tests build "$test_target"
# Test that the bazel server can be restarted once shut down. If run in a
# docker container, you need to run the docker container with --init or
# have some other process as PID 1 that can reap zombies.
b shutdown
b cquery 'kind(test, //build/bazel/examples/android_app/...)' --config=android
b run $test_target -- --help >/dev/null

# Workflow tests for bmod
bmod libm
b run $(bmod fastboot) -- help
b build $(bmod libm) $(bmod libcutils) --config=android
