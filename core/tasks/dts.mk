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

# Desktop test suite
ifneq ($(wildcard test/dts/tools/dts-tradefed/README),)
test_suite_name := dts
test_suite_tradefed := dts-tradefed
test_suite_readme := test/dts/tools/dts-tradefed/README
test_suite_tools := $(HOST_OUT_JAVA_LIBRARIES)/ats_console_deploy.jar \
  $(HOST_OUT_JAVA_LIBRARIES)/ats_olc_server_local_mode_deploy.jar

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

.PHONY: dts
dts: $(compatibility_zip) $(compatibility_tests_list_zip)
$(call dist-for-goals, dts, $(compatibility_zip) $(compatibility_tests_list_zip))
endif
