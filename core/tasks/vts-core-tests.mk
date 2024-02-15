# Copyright (C) 2019 The Android Open Source Project
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

test_suite_name := vts
test_suite_tradefed := vts-tradefed
test_suite_readme := test/vts/tools/vts-core-tradefed/README

include $(BUILD_SYSTEM)/tasks/tools/vts-kernel-tests.mk

ltp_copy_pairs := \
  $(call target-native-copy-pairs,$(kernel_ltp_modules),$(kernel_ltp_vts_out))

copy_ltp_tests := $(call copy-many-files,$(ltp_copy_pairs))

test_suite_extra_deps := $(copy_ltp_tests)

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

.PHONY: vts
vts: $(compatibility_zip) $(compatibility_tests_list_zip)
$(call dist-for-goals, vts, $(compatibility_zip) $(compatibility_tests_list_zip))

tests: vts
