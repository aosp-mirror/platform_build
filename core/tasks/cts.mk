# Copyright (C) 2015 The Android Open Source Project
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

test_suite_name := cts
test_suite_tradefed := cts-tradefed
test_suite_dynamic_config := cts/tools/cts-tradefed/DynamicConfig.xml
test_suite_readme := cts/tools/cts-tradefed/README
test_suite_tools := $(HOST_OUT_JAVA_LIBRARIES)/ats_console_deploy.jar \
  $(HOST_OUT_JAVA_LIBRARIES)/ats_olc_server_local_mode_deploy.jar

$(call declare-1p-target,$(test_suite_dynamic_config),cts)
$(call declare-1p-target,$(test_suite_readme),cts)

include $(BUILD_SYSTEM)/tasks/tools/compatibility.mk

.PHONY: cts
cts: $(compatibility_zip) $(compatibility_tests_list_zip)
$(call dist-for-goals, cts, $(compatibility_zip) $(compatibility_tests_list_zip))

.PHONY: cts_v2
cts_v2: cts

# platform version check (b/32056228)
# ============================================================
ifneq (,$(wildcard cts/))
  cts_platform_version_path := cts/tests/tests/os/assets/platform_versions.txt
  cts_platform_version_string := $(shell cat $(cts_platform_version_path))
  cts_platform_release_path := cts/tests/tests/os/assets/platform_releases.txt
  cts_platform_release_string := $(shell cat $(cts_platform_release_path))

  ifneq (REL,$(PLATFORM_VERSION_CODENAME))
    ifeq (,$(findstring $(PLATFORM_VERSION),$(cts_platform_version_string)))
      define error_msg
        ============================================================
        Could not find version "$(PLATFORM_VERSION)" in CTS platform version file:
        $(cts_platform_version_path)
        Most likely PLATFORM_VERSION in build/core/version_defaults.mk
        has changed and a new version must be added to this CTS file.
        ============================================================
      endef
      $(error $(error_msg))
    endif
  endif
  ifeq (,$(findstring $(PLATFORM_VERSION_LAST_STABLE),$(cts_platform_release_string)))
    define error_msg
      ============================================================
      Could not find version "$(PLATFORM_VERSION_LAST_STABLE)" in CTS platform release file:
      $(cts_platform_release_path)
      Most likely PLATFORM_VERSION_LAST_STABLE in build/core/version_defaults.mk
      has changed and a new version must be added to this CTS file.
      ============================================================
    endef
    $(error $(error_msg))
  endif
endif

# Creates a "cts-verifier" directory that will contain:
#
# 1. Out directory with a "android-cts-verifier" containing the CTS Verifier
#    and other binaries it needs.
#
# 2. Zipped version of the android-cts-verifier directory to be included with
#    the build distribution.
##
cts-dir := $(HOST_OUT)/cts-verifier
verifier-dir-name := android-cts-verifier
verifier-dir := $(cts-dir)/$(verifier-dir-name)
verifier-zip-name := $(verifier-dir-name).zip
verifier-zip := $(cts-dir)/$(verifier-zip-name)

cts : $(verifier-zip)
$(verifier-zip): PRIVATE_DIR := $(cts-dir)
$(verifier-zip): $(SOONG_ANDROID_CTS_VERIFIER_ZIP)
	rm -rf $(PRIVATE_DIR)
	mkdir -p $(PRIVATE_DIR)
	unzip -q -d $(PRIVATE_DIR) $<
	$(copy-file-to-target)

# For producing CTS coverage reports.
# Run "make cts-test-coverage" in the $ANDROID_BUILD_TOP directory.

cts_api_coverage_exe := $(HOST_OUT_EXECUTABLES)/cts-api-coverage
dexdeps_exe := $(HOST_OUT_EXECUTABLES)/dexdeps
cts_api_map_exe := $(HOST_OUT_EXECUTABLES)/cts-api-map

coverage_out := $(HOST_OUT)/cts-api-coverage
api_map_out := $(HOST_OUT)/cts-api-map

cts_jar_files := $(api_map_out)/api_map_files.txt
$(cts_jar_files): PRIVATE_API_MAP_FILES := $(sort $(COMPATIBILITY.cts.API_MAP_FILES))
$(cts_jar_files):
	mkdir -p $(dir $@)
	echo $(PRIVATE_API_MAP_FILES) > $@

api_xml_description := $(TARGET_OUT_COMMON_INTERMEDIATES)/api.xml

napi_text_description := cts/tools/cts-api-coverage/etc/ndk-api.xml
napi_xml_description := $(coverage_out)/ndk-api.xml
$(napi_xml_description) : $(napi_text_description) $(ACP)
		$(hide) echo "Preparing NDK API XML: $@"
		$(hide) mkdir -p $(dir $@)
		$(hide) $(ACP)  $< $@

system_api_xml_description := $(TARGET_OUT_COMMON_INTERMEDIATES)/system-api.xml

cts-test-coverage-report := $(coverage_out)/test-coverage.html
cts-system-api-coverage-report := $(coverage_out)/system-api-coverage.html
cts-system-api-xml-coverage-report := $(coverage_out)/system-api-coverage.xml
cts-verifier-coverage-report := $(coverage_out)/verifier-coverage.html
cts-combined-coverage-report := $(coverage_out)/combined-coverage.html
cts-combined-xml-coverage-report := $(coverage_out)/combined-coverage.xml

cts_api_coverage_dependencies := $(cts_api_coverage_exe) $(dexdeps_exe) $(api_xml_description) $(napi_xml_description)
cts_system_api_coverage_dependencies := $(cts_api_coverage_exe) $(dexdeps_exe) $(system_api_xml_description)

cts-api-xml-api-map-report := $(api_map_out)/api-map.xml
cts-api-html-api-map-report := $(api_map_out)/api-map.html
cts-system-api-xml-api-map-report := $(api_map_out)/system-api-map.xml
cts-system-api-html-api-map-report := $(api_map_out)/system-api-map.html

cts_system_api_map_dependencies := $(cts_api_map_exe) $(system_api_xml_description) $(cts_jar_files)
cts_api_map_dependencies := $(cts_api_map_exe) $(api_xml_description) $(cts_jar_files)

android_cts_zip := $(HOST_OUT)/cts/android-cts.zip
cts_verifier_apk := $(call intermediates-dir-for,APPS,CtsVerifier)/package.apk

$(cts-test-coverage-report): PRIVATE_TEST_CASES := $(COMPATIBILITY_TESTCASES_OUT_cts)
$(cts-test-coverage-report): PRIVATE_CTS_API_COVERAGE_EXE := $(cts_api_coverage_exe)
$(cts-test-coverage-report): PRIVATE_DEXDEPS_EXE := $(dexdeps_exe)
$(cts-test-coverage-report): PRIVATE_API_XML_DESC := $(api_xml_description)
$(cts-test-coverage-report): PRIVATE_NAPI_XML_DESC := $(napi_xml_description)
$(cts-test-coverage-report) : $(android_cts_zip) $(cts_api_coverage_dependencies) | $(ACP)
	$(call generate-coverage-report-cts,"CTS Tests API-NDK Coverage Report",\
			$(PRIVATE_TEST_CASES),html)

$(cts-system-api-coverage-report): PRIVATE_TEST_CASES := $(COMPATIBILITY_TESTCASES_OUT_cts)
$(cts-system-api-coverage-report): PRIVATE_CTS_API_COVERAGE_EXE := $(cts_api_coverage_exe)
$(cts-system-api-coverage-report): PRIVATE_DEXDEPS_EXE := $(dexdeps_exe)
$(cts-system-api-coverage-report): PRIVATE_API_XML_DESC := $(system_api_xml_description)
$(cts-system-api-coverage-report): PRIVATE_NAPI_XML_DESC := ""
$(cts-system-api-coverage-report) : $(android_cts_zip) $(cts_system_api_coverage_dependencies) | $(ACP)
	$(call generate-coverage-report-cts,"CTS System API Coverage Report",\
			$(PRIVATE_TEST_CASES),html)

$(cts-system-api-xml-coverage-report): PRIVATE_TEST_CASES := $(COMPATIBILITY_TESTCASES_OUT_cts)
$(cts-system-api-xml-coverage-report): PRIVATE_CTS_API_COVERAGE_EXE := $(cts_api_coverage_exe)
$(cts-system-api-xml-coverage-report): PRIVATE_DEXDEPS_EXE := $(dexdeps_exe)
$(cts-system-api-xml-coverage-report): PRIVATE_API_XML_DESC := $(system_api_xml_description)
$(cts-system-api-xml-coverage-report): PRIVATE_NAPI_XML_DESC := ""
$(cts-system-api-xml-coverage-report) : $(android_cts_zip) $(cts_system_api_coverage_dependencies) | $(ACP)
	$(call generate-coverage-report-cts,"CTS System API Coverage Report - XML",\
			$(PRIVATE_TEST_CASES),xml)

$(cts-verifier-coverage-report): PRIVATE_TEST_CASES := $(foreach c, $(cts_verifier_apk) $(verifier-dir), $(c))
$(cts-verifier-coverage-report): PRIVATE_CTS_API_COVERAGE_EXE := $(cts_api_coverage_exe)
$(cts-verifier-coverage-report): PRIVATE_DEXDEPS_EXE := $(dexdeps_exe)
$(cts-verifier-coverage-report): PRIVATE_API_XML_DESC := $(api_xml_description)
$(cts-verifier-coverage-report): PRIVATE_NAPI_XML_DESC := $(napi_xml_description)
$(cts-verifier-coverage-report) : $(cts_verifier_apk) $(verifier-zip) $(cts_api_coverage_dependencies) | $(ACP)
	$(call generate-coverage-report-cts,"CTS Verifier API Coverage Report",\
			$(PRIVATE_TEST_CASES),html)

$(cts-combined-coverage-report): PRIVATE_TEST_CASES := $(foreach c, $(cts_verifier_apk) $(COMPATIBILITY_TESTCASES_OUT_cts) $(verifier-dir), $(c))
$(cts-combined-coverage-report): PRIVATE_CTS_API_COVERAGE_EXE := $(cts_api_coverage_exe)
$(cts-combined-coverage-report): PRIVATE_DEXDEPS_EXE := $(dexdeps_exe)
$(cts-combined-coverage-report): PRIVATE_API_XML_DESC := $(api_xml_description)
$(cts-combined-coverage-report): PRIVATE_NAPI_XML_DESC := $(napi_xml_description)
$(cts-combined-coverage-report) : $(android_cts_zip) $(cts_verifier_apk) $(verifier-zip) $(cts_api_coverage_dependencies) | $(ACP)
	$(call generate-coverage-report-cts,"CTS Combined API Coverage Report",\
			$(PRIVATE_TEST_CASES),html)

$(cts-combined-xml-coverage-report): PRIVATE_TEST_CASES := $(foreach c, $(cts_verifier_apk) $(COMPATIBILITY_TESTCASES_OUT_cts) $(verifier-dir), $(c))
$(cts-combined-xml-coverage-report): PRIVATE_CTS_API_COVERAGE_EXE := $(cts_api_coverage_exe)
$(cts-combined-xml-coverage-report): PRIVATE_DEXDEPS_EXE := $(dexdeps_exe)
$(cts-combined-xml-coverage-report): PRIVATE_API_XML_DESC := $(api_xml_description)
$(cts-combined-xml-coverage-report): PRIVATE_NAPI_XML_DESC := $(napi_xml_description)
$(cts-combined-xml-coverage-report) : $(android_cts_zip) $(cts_verifier_apk) $(verifier-zip) $(cts_api_coverage_dependencies) | $(ACP)
	$(call generate-coverage-report-cts,"CTS Combined API Coverage Report - XML",\
			$(PRIVATE_TEST_CASES),xml)

.PHONY: cts-test-coverage
cts-test-coverage : $(cts-test-coverage-report)

.PHONY: cts-system-api-coverage
cts-system-api-coverage : $(cts-system-api-coverage-report)

.PHONY: cts-system-api-xml-coverage
cts-system-api-xml-coverage : $(cts-system-api-xml-coverage-report)

.PHONY: cts-verifier-coverage
cts-verifier-coverage : $(cts-verifier-coverage-report)

.PHONY: cts-combined-coverage
cts-combined-coverage : $(cts-combined-coverage-report)

.PHONY: cts-combined-xml-coverage
cts-combined-xml-coverage : $(cts-combined-xml-coverage-report)

.PHONY: cts-coverage-report-all cts-api-coverage
cts-coverage-report-all: cts-test-coverage cts-verifier-coverage cts-combined-coverage cts-combined-xml-coverage

$(cts-system-api-xml-api-map-report): PRIVATE_CTS_API_MAP_EXE := $(cts_api_map_exe)
$(cts-system-api-xml-api-map-report): PRIVATE_API_XML_DESC := $(system_api_xml_description)
$(cts-system-api-xml-api-map-report): PRIVATE_JAR_FILES := $(cts_jar_files)
$(cts-system-api-xml-api-map-report) : $(android_cts_zip) $(cts_system_api_map_dependencies) | $(ACP)
	$(call generate-api-map-report-cts,"CTS System API MAP Report - XML",\
			$(PRIVATE_JAR_FILES),xml)

$(cts-system-api-html-api-map-report): PRIVATE_CTS_API_MAP_EXE := $(cts_api_map_exe)
$(cts-system-api-html-api-map-report): PRIVATE_API_XML_DESC := $(system_api_xml_description)
$(cts-system-api-html-api-map-report): PRIVATE_JAR_FILES := $(cts_jar_files)
$(cts-system-api-html-api-map-report) : $(android_cts_zip) $(cts_system_api_map_dependencies) | $(ACP)
	$(call generate-api-map-report-cts,"CTS System API MAP Report - HTML",\
			$(PRIVATE_JAR_FILES),html)

$(cts-api-xml-api-map-report): PRIVATE_CTS_API_MAP_EXE := $(cts_api_map_exe)
$(cts-api-xml-api-map-report): PRIVATE_API_XML_DESC := $(api_xml_description)
$(cts-api-xml-api-map-report): PRIVATE_JAR_FILES := $(cts_jar_files)
$(cts-api-xml-api-map-report) : $(android_cts_zip) $(cts_api_map_dependencies) | $(ACP)
	$(call generate-api-map-report-cts,"CTS API MAP Report - XML",\
			$(PRIVATE_JAR_FILES),xml)

$(cts-api-html-api-map-report): PRIVATE_CTS_API_MAP_EXE := $(cts_api_map_exe)
$(cts-api-html-api-map-report): PRIVATE_API_XML_DESC := $(api_xml_description)
$(cts-api-html-api-map-report): PRIVATE_JAR_FILES := $(cts_jar_files)
$(cts-api-html-api-map-report) : $(android_cts_zip) $(cts_api_map_dependencies) | $(ACP)
	$(call generate-api-map-report-cts,"CTS API MAP Report - HTML",\
			$(PRIVATE_JAR_FILES),html)

.PHONY: cts-system-api-xml-api-map
cts-system-api-xml-api-map : $(cts-system-api-xml-api-map-report)

.PHONY: cts-system-api-html-api-map
cts-system-api-html-api-map : $(cts-system-api-html-api-map-report)

.PHONY: cts-api-xml-api-map
cts-api-xml-api-map : $(cts-api-xml-api-map-report)

.PHONY: cts-api-html-api-map
cts-api-html-api-map : $(cts-api-html-api-map-report)

.PHONY: cts-api-map-all

# Put the test coverage report in the dist dir if "cts-api-coverage" is among the build goals.
$(call dist-for-goals, cts-api-coverage, $(cts-test-coverage-report):cts-test-coverage-report.html)
$(call dist-for-goals, cts-api-coverage, $(cts-system-api-coverage-report):cts-system-api-coverage-report.html)
$(call dist-for-goals, cts-api-coverage, $(cts-system-api-xml-coverage-report):cts-system-api-coverage-report.xml)
$(call dist-for-goals, cts-api-coverage, $(cts-verifier-coverage-report):cts-verifier-coverage-report.html)
$(call dist-for-goals, cts-api-coverage, $(cts-combined-coverage-report):cts-combined-coverage-report.html)
$(call dist-for-goals, cts-api-coverage, $(cts-combined-xml-coverage-report):cts-combined-coverage-report.xml)

ALL_TARGETS.$(cts-test-coverage-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-system-api-coverage-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-system-api-xml-coverage-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-verifier-coverage-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-combined-coverage-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-combined-xml-coverage-report).META_LIC:=$(module_license_metadata)

# Put the test api map report in the dist dir if "cts-api-map-all" is among the build goals.
$(call dist-for-goals, cts-api-map-all, $(cts-system-api-xml-api-map-report):cts-system-api-xml-api-map-report.xml)
$(call dist-for-goals, cts-api-map-all, $(cts-system-api-html-api-map-report):cts-system-api-html-api-map-report.html)
$(call dist-for-goals, cts-api-map-all, $(cts-api-xml-api-map-report):cts-api-xml-api-map-report.xml)
$(call dist-for-goals, cts-api-map-all, $(cts-api-html-api-map-report):cts-api-html-api-map-report.html)

ALL_TARGETS.$(cts-system-api-xml-api-map-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-system-api-html-api-map-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-api-xml-api-map-report).META_LIC:=$(module_license_metadata)
ALL_TARGETS.$(cts-api-html-api-map-report).META_LIC:=$(module_license_metadata)

# Arguments;
#  1 - Name of the report printed out on the screen
#  2 - List of apk files that will be scanned to generate the report
#  3 - Format of the report
define generate-coverage-report-cts
	$(hide) mkdir -p $(dir $@)
	$(hide) $(PRIVATE_CTS_API_COVERAGE_EXE) -j 8 -d $(PRIVATE_DEXDEPS_EXE) -a $(PRIVATE_API_XML_DESC) -n $(PRIVATE_NAPI_XML_DESC) -f $(3) -o $@ $(2)
	@ echo $(1): file://$$(cd $(dir $@); pwd)/$(notdir $@)
endef

# Arguments;
#  1 - Name of the report printed out on the screen
#  2 - A file containing list of files that to be analyzed
#  3 - Format of the report
define generate-api-map-report-cts
	$(hide) mkdir -p $(dir $@)
	$(hide) $(PRIVATE_CTS_API_MAP_EXE) -j 8 -a $(PRIVATE_API_XML_DESC) -i $(2) -f $(3) -o $@
	@ echo $(1): file://$$(cd $(dir $@); pwd)/$(notdir $@)
endef

# Reset temp vars
cts_api_coverage_dependencies :=
cts_system_api_coverage_dependencies :=
cts_api_map_dependencies :=
cts_system_api_map_dependencies :=
cts-combined-coverage-report :=
cts-combined-xml-coverage-report :=
cts-verifier-coverage-report :=
cts-test-coverage-report :=
cts-system-api-coverage-report :=
cts-system-api-xml-coverage-report :=
cts-api-xml-api-map-report :=
cts-api-html-api-map-report :=
cts-system-api-xml-api-map-report :=
cts-system-api-html-api-map-report :=
api_xml_description :=
api_text_description :=
system_api_xml_description :=
napi_xml_description :=
napi_text_description :=
coverage_out :=
api_map_out :=
cts_jar_files :=
dexdeps_exe :=
cts_api_coverage_exe :=
cts_api_map_exe :=
cts_verifier_apk :=
android_cts_zip :=
cts-dir :=
verifier-dir-name :=
verifier-dir :=
verifier-zip-name :=
verifier-zip :=
