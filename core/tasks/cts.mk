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

cts_name := android-cts

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
	CtsOsTestCases \
	CtsProviderTestCases \
	CtsTextTestCases \
	CtsUtilTestCases \
	CtsViewTestCases \
	CtsWidgetTestCases \
	CtsNetTestCases \
	SignatureTest \
	android.core.tests

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

# Generate the test plan for the core-tests
CORE_TEST_PLAN := $(cts_dir)/$(cts_name)/repository/testcases/android.core.tests

CORE_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core,,COMMON)
TESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests,,COMMON)

GEN_CLASSPATH := $(CORE_INTERMEDIATES)/classes.jar:$(TESTS_INTERMEDIATES)/classes.jar:$(CORE_INTERMEDIATES)/javalib.jar:$(TESTS_INTERMEDIATES)/javalib.jar:$(HOST_OUT_JAVA_LIBRARIES)/descGen.jar:$(HOST_JDK_TOOLS_JAR)

$(CORE_TEST_PLAN): PRIVATE_CLASSPATH:=$(GEN_CLASSPATH)
$(CORE_TEST_PLAN): PRIVATE_PARAMS:=-Dcts.useSuppliedTestResult=true
$(CORE_TEST_PLAN): PRIVATE_PARAMS+=-Dcts.useEnhancedJunit=true
$(CORE_TEST_PLAN): PRIVATE_CUSTOM_TOOL := java -classpath $(PRIVATE_CLASSPATH) \
	$(PRIVATE_PARAMS) CollectAllTests $(CORE_TEST_PLAN) \
	cts/tests/core/AndroidManifest.xml tests.AllTests
# Why does this depend on javalib.jar instead of classes.jar?  Because
# even though the tool will operate on the classes.jar files, the
# build system requires that dependencies use javalib.jar.  If
# javalib.jar is up-to-date, then classes.jar is as well.  Depending
# on classes.jar will build the files incorrectly.
$(CORE_TEST_PLAN): android.core.tests $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar $(CORE_INTERMEDIATES)/javalib.jar $(TESTS_INTERMEDIATES)/javalib.jar $(cts_dir)/all_cts_files_stamp
	@echo "Generate the CTS test plan: $@"
	@echo $(PRIVATE_CUSTOM_TOOL)
	$(transform-generated-source)


# ----- Generate the test plan for the vm-tests -----
#
CORE_VM_TEST_PLAN := $(cts_dir)/$(cts_name)/repository/testcases/android.core.vm-tests

VMTESTS_INTERMEDIATES :=$(call intermediates-dir-for,EXECUTABLES,vm-tests,1,)
# core tests only needed to get hold of junit-framework-classes
TESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests,,COMMON)
CORE_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core,,COMMON)

GEN_CLASSPATH := $(CORE_INTERMEDIATES)/classes.jar:$(TESTS_INTERMEDIATES)/classes.jar:$(VMTESTS_INTERMEDIATES)/android.core.vm-tests.jar:$(HOST_OUT_JAVA_LIBRARIES)/descGen.jar:$(HOST_JDK_TOOLS_JAR)

$(CORE_VM_TEST_PLAN): PRIVATE_CLASSPATH:=$(GEN_CLASSPATH)
$(CORE_VM_TEST_PLAN): PRIVATE_PARAMS:=-Dcts.useSuppliedTestResult=true
$(CORE_VM_TEST_PLAN): PRIVATE_PARAMS+=-Dcts.useEnhancedJunit=true
$(CORE_VM_TEST_PLAN): PRIVATE_CUSTOM_TOOL := java -classpath $(PRIVATE_CLASSPATH) \
	$(PRIVATE_PARAMS) CollectAllTests $(CORE_VM_TEST_PLAN) \
	cts/tests/vm-tests/AndroidManifest.xml dot.junit.AllJunitHostTests
# Please see big comment above on why this line depends on javalib.jar instead of classes.jar
$(CORE_VM_TEST_PLAN): vm-tests $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar $(CORE_INTERMEDIATES)/javalib.jar $(VMTESTS_INTERMEDIATES)/android.core.vm-tests.jar $(TESTS_INTERMEDIATES)/javalib.jar $(cts_dir)/all_cts_files_stamp | $(ACP)
	@echo "Generate the CTS vm-test plan: $@"
	@echo $(PRIVATE_CUSTOM_TOOL)
	$(transform-generated-source)
	$(ACP) -fv $(VMTESTS_INTERMEDIATES)/android.core.vm-tests.jar $(PRIVATE_DIR)/repository/testcases/android.core.vm-tests.jar

# Generate the default test plan for User.
$(DEFAULT_TEST_PLAN): $(cts_dir)/all_cts_files_stamp $(cts_tools_src_dir)/utils/genDefaultTestPlan.sh
	$(hide) bash $(cts_tools_src_dir)/utils/genDefaultTestPlan.sh cts/tests/tests/ \
     $(PRIVATE_DIR) $(TMP_DIR) $(TOP) $(TARGET_COMMON_OUT_ROOT) $(OUT_DIR)

# Package CTS and clean up.
#
# TODO:
#   Pack cts.bat into the same zip file as well. See http://buganizer/issue?id=1656821 for more details
INTERNAL_CTS_TARGET := $(cts_dir)/$(cts_name).zip
$(INTERNAL_CTS_TARGET): PRIVATE_NAME := $(cts_name)
$(INTERNAL_CTS_TARGET): PRIVATE_CTS_DIR := $(cts_dir)
$(INTERNAL_CTS_TARGET): PRIVATE_DIR := $(cts_dir)/$(cts_name)
$(INTERNAL_CTS_TARGET): TMP_DIR := $(cts_dir)/temp
$(INTERNAL_CTS_TARGET): $(cts_dir)/all_cts_files_stamp $(DEFAULT_TEST_PLAN) $(CORE_TEST_PLAN) $(CORE_VM_TEST_PLAN)
	@echo "Package CTS: $@"
	$(hide) cd $(dir $@) && zip -rq $(notdir $@) $(PRIVATE_NAME)

.PHONY: cts
cts: $(INTERNAL_CTS_TARGET) adb
$(call dist-for-goals,cts,$(INTERNAL_CTS_TARGET))

define copy-testcase-apk

$(hide) $(ACP) -fp $(call intermediates-dir-for,APPS,$(1))/package.apk \
	$(PRIVATE_DIR)/repository/testcases/$(1).apk

endef
