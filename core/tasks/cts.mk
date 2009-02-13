# Copyright (C) 2008 The Android Open Source Project
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

cts_dir := $(HOST_OUT)/cts
cts_tools_src_dir := cts/tools

# Build a name that looks like:
#
#     linux-x86   --> android-cts_linux-x86
#     darwin-x86  --> android-cts_mac-x86
#     windows-x86 --> android-cts_windows
#
cts_name := android-cts
ifeq ($(HOST_OS),darwin)
    cts_host_os := mac
else
    cts_host_os := $(HOST_OS)
endif
ifneq ($(HOST_OS),windows)
    cts_host_os := $(cts_host_os)-$(HOST_ARCH)
endif
cts_name := $(cts_name)_$(cts_host_os)

CTS_EXECUTABLE := cts
ifeq ($(HOST_OS),windows)
    CTS_EXECUTABLE_PATH := $(cts_tools_src_dir)/host/etc/cts.bat
else
    CTS_EXECUTABLE_PATH := $(HOST_OUT_EXECUTABLES)/$(CTS_EXECUTABLE)
endif
CTS_HOST_JAR := $(HOST_OUT_JAVA_LIBRARIES)/cts.jar

CTS_CASE_LIST := \
	DeviceInfoCollector \
	CtsTestStubs \
	CtsAppTestCases \
	CtsContentTestCases \
	CtsDatabaseTestCases \
	CtsGraphicsTestCases \
	CtsLocationTestCases \
	CtsNetTestCases \
	CtsOsTestCases \
	CtsProviderTestCases \
	CtsTextTestCases \
	CtsUtilTestCases \
	CtsViewTestCases \
	CtsWidgetTestCases \
	SignatureTest

DEFAULT_TEST_PLAN := $(PRIVATE_DIR)/resource/plans

$(cts_dir)/all_cts_files_stamp: $(CTS_CASE_LIST) | $(ACP)
# Make necessary directory for CTS
	@rm -rf $(PRIVATE_CTS_DIR)
	@mkdir -p $(TMP_DIR)
	@mkdir -p $(PRIVATE_DIR)/docs
	@mkdir -p $(PRIVATE_DIR)/tools
	@mkdir -p $(PRIVATE_DIR)/repository/testcases
	@mkdir -p $(PRIVATE_DIR)/repository/plans
# Copy executable to CTS directory
	$(hide) $(ACP) -fp $(CTS_HOST_JAR) $(PRIVATE_DIR)/tools
	$(hide) $(ACP) -fp $(CTS_EXECUTABLE_PATH) $(PRIVATE_DIR)/tools
# Change mode of the executables
	$(hide) chmod ug+rwX $(PRIVATE_DIR)/tools/$(notdir $(CTS_EXECUTABLE_PATH))
	$(foreach apk,$(CTS_CASE_LIST), \
			$(call copy-testcase-apk,$(apk)))
# Copy CTS host config and start script to CTS directory
	$(hide) $(ACP) -fp $(cts_tools_src_dir)/utils/host_config.xml $(PRIVATE_DIR)/repository/
	$(hide) $(ACP) -fp $(cts_tools_src_dir)/utils/startcts $(PRIVATE_DIR)/tools/
	$(hide) touch $@

# Generate the default test plan for User.
$(DEFAULT_TEST_PLAN): $(cts_dir)/all_cts_files_stamp $(cts_tools_src_dir)/utils/genDefaultTestPlan.sh
	$(hide) bash $(cts_tools_src_dir)/utils/genDefaultTestPlan.sh cts/tests/tests/ \
     $(PRIVATE_DIR) $(TMP_DIR) $(TOP) $(TARGET_COMMON_OUT_ROOT) $(OUT_DIR)

# Package CTS and clean up.
INTERNAL_CTS_TARGET := $(cts_dir)/$(cts_name).zip
$(INTERNAL_CTS_TARGET): PRIVATE_NAME := $(cts_name)
$(INTERNAL_CTS_TARGET): PRIVATE_CTS_DIR := $(cts_dir)
$(INTERNAL_CTS_TARGET): PRIVATE_DIR := $(cts_dir)/$(cts_name)
$(INTERNAL_CTS_TARGET): TMP_DIR := $(cts_dir)/temp
$(INTERNAL_CTS_TARGET): $(cts_dir)/all_cts_files_stamp $(DEFAULT_TEST_PLAN)
	@echo "Package CTS: $@"
	$(hide) cd $(dir $@) && zip -rq $(notdir $@) $(PRIVATE_NAME)

.PHONY: cts
cts: $(INTERNAL_CTS_TARGET) adb
$(call dist-for-goals,cts,$(INTERNAL_CTS_TARGET))

define copy-testcase-apk

$(hide) $(ACP) -fp $(call intermediates-dir-for,APPS,$(1))/package.apk \
	$(PRIVATE_DIR)/repository/testcases/$(1).apk

endef

