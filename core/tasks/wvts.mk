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

# Widevine test suite for non-GMS partners: go/android-wvts
ifneq ($(wildcard test/wvts/tools/wvts-tradefed/README),)
test_suite_name := wvts
test_suite_tradefed := wvts-tradefed
test_suite_dynamic_config := test/wvts/tools/wvts-tradefed/DynamicConfig.xml
test_suite_readme := test/wvts/tools/wvts-tradefed/README

$(call declare-1p-target,$(test_suite_dynamic_config),wvts)
$(call declare-1p-target,$(test_suite_readme),wvts)

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

.PHONY: wvts
wvts: $(compatibility_zip) $(compatibility_tests_list_zip)
$(call dist-for-goals, wvts, $(compatibility_zip) $(compatibility_tests_list_zip))
endif
