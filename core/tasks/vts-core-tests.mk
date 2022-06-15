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

-include external/linux-kselftest/android/kselftest_test_list.mk
-include external/ltp/android/ltp_package_list.mk

include $(BUILD_SYSTEM)/tasks/tools/vts_package_utils.mk

test_suite_name := vts
test_suite_tradefed := vts-tradefed
test_suite_readme := test/vts/tools/vts-core-tradefed/README

# Copy kernel test modules to testcases directories
kernel_test_host_out := $(HOST_OUT_TESTCASES)/vts_kernel_tests
kernel_test_vts_out := $(HOST_OUT)/$(test_suite_name)/android-$(test_suite_name)/testcases/vts_kernel_tests
kernel_test_modules := \
    $(kselftest_modules) \
    ltp \
    $(ltp_packages)

kernel_test_copy_pairs := \
  $(call target-native-copy-pairs,$(kernel_test_modules),$(kernel_test_vts_out)) \
  $(call target-native-copy-pairs,$(kernel_test_modules),$(kernel_test_host_out))

copy_kernel_tests := $(call copy-many-files,$(kernel_test_copy_pairs))

# PHONY target to be used to build and test `vts_kernel_tests` without building full vts
.PHONY: vts_kernel_tests
vts_kernel_tests: $(copy_kernel_tests)

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

$(compatibility_zip): $(copy_kernel_tests)

.PHONY: vts
vts: $(compatibility_zip)
$(call dist-for-goals, vts, $(compatibility_zip))

tests: vts
