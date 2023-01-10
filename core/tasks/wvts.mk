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

# Arguments;
#  1 - Name of the report printed out on the screen
#  2 - List of apk files that will be scanned to generate the report
#  3 - Format of the report
define generate-coverage-report-wvts
	$(hide) mkdir -p $(dir $@)
	$(hide) $(PRIVATE_CTS_API_COVERAGE_EXE) -d $(PRIVATE_DEXDEPS_EXE) -a $(PRIVATE_API_XML_DESC) -n $(PRIVATE_NAPI_XML_DESC) -f $(3) -o $@ $(2)
	@ echo $(1): file://$$(cd $(dir $@); pwd)/$(notdir $@)
endef

# Reset temp vars
wvts_api_coverage_dependencies :=
wvts_system_api_coverage_dependencies :=
wvts-combined-coverage-report :=
wvts-combined-xml-coverage-report :=
wvts-verifier-coverage-report :=
wvts-test-coverage-report :=
wvts-system-api-coverage-report :=
wvts-system-api-xml-coverage-report :=
api_xml_description :=
api_text_description :=
system_api_xml_description :=
napi_xml_description :=
napi_text_description :=
coverage_out :=
dexdeps_exe :=
wvts_api_coverage_exe :=
wvts_verifier_apk :=
android_wvts_zip :=
