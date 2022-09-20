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

test_target=//build/bazel/scripts/difftool:difftool

b cquery 'kind(test, //build/bazel/...)'
b build "$test_target"
b build "$test_target" --run-soong-tests
b build --run-soong-tests "$test_target"
b --run-soong-tests build "$test_target"
b run $test_target
b run $test_target -- --help
b cquery --output=build 'kind(test, //build/bazel/...)'
b cquery 'kind(test, //build/bazel/...)' --output=build
