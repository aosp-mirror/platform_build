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

CTS_EXECUTABLE := startcts
ifeq ($(HOST_OS),windows)
    CTS_EXECUTABLE_PATH := $(cts_tools_src_dir)/host/etc/cts.bat
else
    CTS_EXECUTABLE_PATH := $(cts_tools_src_dir)/utils/$(CTS_EXECUTABLE)
endif
CTS_HOST_JAR := $(HOST_OUT_JAVA_LIBRARIES)/cts.jar

DDMLIB_JAR := $(HOST_OUT_JAVA_LIBRARIES)/ddmlib-prebuilt.jar
junit_host_jar := $(HOST_OUT_JAVA_LIBRARIES)/junit.jar
HOSTTESTLIB_JAR := $(HOST_OUT_JAVA_LIBRARIES)/hosttestlib.jar

CTS_CORE_CASE_LIST := \
	android.core.tests.dom \
	android.core.tests.luni.io \
	android.core.tests.luni.lang \
	android.core.tests.luni.net \
	android.core.tests.luni.util \
	android.core.tests.xml \
	android.core.tests.runner

-include cts/CtsTestCaseList.mk
CTS_CASE_LIST := $(CTS_CORE_CASE_LIST) $(CTS_TEST_CASE_LIST)

DEFAULT_TEST_PLAN := $(PRIVATE_DIR)/resource/plans

$(cts_dir)/all_cts_files_stamp: PRIVATE_JUNIT_HOST_JAR := $(junit_host_jar)

-include cts/CtsHostLibraryList.mk
$(cts_dir)/all_cts_files_stamp: $(CTS_CASE_LIST) $(junit_host_jar) $(HOSTTESTLIB_JAR) $(CTS_HOST_LIBRARY_JARS) $(ACP)
# Make necessary directory for CTS
	@rm -rf $(PRIVATE_CTS_DIR)
	@mkdir -p $(TMP_DIR)
	@mkdir -p $(PRIVATE_DIR)/docs
	@mkdir -p $(PRIVATE_DIR)/tools
	@mkdir -p $(PRIVATE_DIR)/repository/testcases
	@mkdir -p $(PRIVATE_DIR)/repository/plans
# Copy executable and JARs to CTS directory
	$(hide) $(ACP) -fp $(CTS_HOST_JAR) $(CTS_EXECUTABLE_PATH) $(DDMLIB_JAR) $(PRIVATE_JUNIT_HOST_JAR) $(HOSTTESTLIB_JAR) $(CTS_HOST_LIBRARY_JARS) $(PRIVATE_DIR)/tools
# Change mode of the executables
	$(hide) chmod ug+rwX $(PRIVATE_DIR)/tools/$(notdir $(CTS_EXECUTABLE_PATH))
	$(foreach apk,$(CTS_CASE_LIST), \
			$(call copy-testcase-apk,$(apk)))
# Copy CTS host config to CTS directory
	$(hide) $(ACP) -fp $(cts_tools_src_dir)/utils/host_config.xml $(PRIVATE_DIR)/repository/
	$(hide) touch $@

# Generate the test descriptions for the core-tests
# Parameters:
# $1 : The output file where the description should be written (without the '.xml' extension)
# $2 : The AndroidManifest.xml corresponding to the test package
# $3 : The name of the TestSuite generator class to use
# $4 : The directory containing vogar expectations files
# $5 : The Android.mk corresponding to the test package (required for host-side tests only)
define generate-core-test-description
@echo "Generate core-test description ("$(notdir $(1))")"
$(hide) java $(PRIVATE_JAVAOPTS) \
	-classpath $(PRIVATE_CLASSPATH) \
	$(PRIVATE_PARAMS) CollectAllTests $(1) \
	$(2) $(3) $(4) $(5)
endef

CORE_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core,,COMMON)
JUNIT_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-junit,,COMMON)
RUNNER_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-junitrunner,,COMMON)
SUPPORT_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests-support,,COMMON)
DOM_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests-dom,,COMMON)
XML_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests-xml,,COMMON)
TESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests,,COMMON)
GEN_CLASSPATH := $(CORE_INTERMEDIATES)/classes.jar:$(JUNIT_INTERMEDIATES)/classes.jar:$(RUNNER_INTERMEDIATES)/classes.jar:$(SUPPORT_INTERMEDIATES)/classes.jar:$(DOM_INTERMEDIATES)/classes.jar:$(XML_INTERMEDIATES)/classes.jar:$(TESTS_INTERMEDIATES)/classes.jar:$(CORE_INTERMEDIATES)/javalib.jar:$(JUNIT_INTERMEDIATES)/javalib.jar:$(RUNNER_INTERMEDIATES)/javalib.jar:$(SUPPORT_INTERMEDIATES)/javalib.jar:$(DOM_INTERMEDIATES)/javalib.jar:$(XML_INTERMEDIATES)/javalib.jar:$(TESTS_INTERMEDIATES)/javalib.jar:$(HOST_OUT_JAVA_LIBRARIES)/descGen.jar:$(HOST_JDK_TOOLS_JAR)

$(cts_dir)/all_cts_core_files_stamp: PRIVATE_CLASSPATH:=$(GEN_CLASSPATH)
$(cts_dir)/all_cts_core_files_stamp: PRIVATE_JAVAOPTS:=-Xmx256M
$(cts_dir)/all_cts_core_files_stamp: PRIVATE_PARAMS:=-Dcts.useSuppliedTestResult=true
$(cts_dir)/all_cts_core_files_stamp: PRIVATE_PARAMS+=-Dcts.useEnhancedJunit=true
# Why does this depend on javalib.jar instead of classes.jar?  Because
# even though the tool will operate on the classes.jar files, the
# build system requires that dependencies use javalib.jar.  If
# javalib.jar is up-to-date, then classes.jar is as well.  Depending
# on classes.jar will build the files incorrectly.
$(cts_dir)/all_cts_core_files_stamp: $(CTS_CORE_CASE_LIST) $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar $(CORE_INTERMEDIATES)/javalib.jar $(JUNIT_INTERMEDIATES)/javalib.jar $(RUNNER_INTERMEDIATES)/javalib.jar $(SUPPORT_INTERMEDIATES)/javalib.jar $(DOM_INTERMEDIATES)/javalib.jar $(XML_INTERMEDIATES)/javalib.jar $(TESTS_INTERMEDIATES)/javalib.jar $(cts_dir)/all_cts_files_stamp | $(ACP)
	$(call generate-core-test-description,$(cts_dir)/$(cts_name)/repository/testcases/android.core.tests.dom,\
		cts/tests/core/dom/AndroidManifest.xml,\
		tests.dom.AllTests, libcore/expectations)
	$(call generate-core-test-description,$(cts_dir)/$(cts_name)/repository/testcases/android.core.tests.luni.io,\
		cts/tests/core/luni-io/AndroidManifest.xml,\
		tests.luni.AllTestsIo, libcore/expectations)
	$(call generate-core-test-description,$(cts_dir)/$(cts_name)/repository/testcases/android.core.tests.luni.lang,\
		cts/tests/core/luni-lang/AndroidManifest.xml,\
		tests.luni.AllTestsLang, libcore/expectations)
	$(call generate-core-test-description,$(cts_dir)/$(cts_name)/repository/testcases/android.core.tests.luni.net,\
		cts/tests/core/luni-net/AndroidManifest.xml,\
		tests.luni.AllTestsNet, libcore/expectations)
	$(call generate-core-test-description,$(cts_dir)/$(cts_name)/repository/testcases/android.core.tests.luni.util,\
		cts/tests/core/luni-util/AndroidManifest.xml,\
		tests.luni.AllTestsUtil, libcore/expectations)
	$(call generate-core-test-description,$(cts_dir)/$(cts_name)/repository/testcases/android.core.tests.xml,\
		cts/tests/core/xml/AndroidManifest.xml,\
		tests.xml.AllTests, libcore/expectations)
	$(hide) touch $@


# ----- Generate the test descriptions for the vm-tests -----
#
CORE_VM_TEST_DESC := $(cts_dir)/$(cts_name)/repository/testcases/android.core.vm-tests

VMTESTS_INTERMEDIATES :=$(call intermediates-dir-for,EXECUTABLES,vm-tests,1,)
# core tests only needed to get hold of junit-framework-classes
CORE_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core,,COMMON)
JUNIT_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-junit,,COMMON)
RUNNER_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-junitrunner,,COMMON)
TESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests,,COMMON)

GEN_CLASSPATH := $(CORE_INTERMEDIATES)/classes.jar:$(JUNIT_INTERMEDIATES)/classes.jar:$(RUNNER_INTERMEDIATES)/classes.jar:$(TESTS_INTERMEDIATES)/classes.jar:$(VMTESTS_INTERMEDIATES)/android.core.vm-tests.jar:$(HOST_OUT_JAVA_LIBRARIES)/descGen.jar:$(HOSTTESTLIB_JAR):$(DDMLIB_JAR):$(HOST_JDK_TOOLS_JAR)

$(CORE_VM_TEST_DESC): PRIVATE_CLASSPATH:=$(GEN_CLASSPATH)
$(CORE_VM_TEST_DESC): PRIVATE_PARAMS:=-Dcts.useSuppliedTestResult=true
$(CORE_VM_TEST_DESC): PRIVATE_PARAMS+=-Dcts.useEnhancedJunit=true
$(CORE_VM_TEST_DESC): PRIVATE_JAVAOPTS:=-Xmx256M
# Please see big comment above on why this line depends on javalib.jar instead of classes.jar
$(CORE_VM_TEST_DESC): vm-tests $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar $(CORE_INTERMEDIATES)/javalib.jar $(JUNIT_INTERMEDIATES)/javalib.jar $(RUNNER_INTERMEDIATES)/javalib.jar $(VMTESTS_INTERMEDIATES)/android.core.vm-tests.jar $(TESTS_INTERMEDIATES)/javalib.jar  $(HOSTTESTLIB_JAR) $(DDMLIB_JAR) $(cts_dir)/all_cts_files_stamp | $(ACP)
	$(call generate-core-test-description,$(CORE_VM_TEST_DESC),\
		cts/tests/vm-tests/AndroidManifest.xml,\
		dot.junit.AllJunitHostTests, libcore/expectations, cts/tools/vm-tests/Android.mk)
	$(ACP) -fv $(VMTESTS_INTERMEDIATES)/android.core.vm-tests.jar $(PRIVATE_DIR)/repository/testcases/android.core.vm-tests.jar

# Move app security host-side tests to the repository
APP_SECURITY_LIB := $(cts_dir)/$(cts_name)/repository/testcases/CtsAppSecurityTests.jar

$(APP_SECURITY_LIB): $(HOST_OUT_JAVA_LIBRARIES)/CtsAppSecurityTests.jar $(cts_dir)/all_cts_files_stamp $(ACP)
	$(ACP) -fv $(HOST_OUT_JAVA_LIBRARIES)/CtsAppSecurityTests.jar $(APP_SECURITY_LIB)

# Generate the default test plan for User.
# Usage: buildCts.py <testRoot> <ctsOutputDir> <tempDir> <androidRootDir> <docletPath>
$(DEFAULT_TEST_PLAN): $(cts_dir)/all_cts_files_stamp $(cts_dir)/all_cts_core_files_stamp $(cts_tools_src_dir)/utils/buildCts.py $(CORE_VM_TEST_DESC) $(APP_SECURITY_LIB) $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar
	$(hide) $(cts_tools_src_dir)/utils/buildCts.py cts/tests/tests/ $(PRIVATE_DIR) $(TMP_DIR) \
		$(TOP) $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar

# Package CTS and clean up.
#
# TODO:
#   Pack cts.bat into the same zip file as well. See http://buganizer/issue?id=1656821 for more details
INTERNAL_CTS_TARGET := $(cts_dir)/$(cts_name).zip
$(INTERNAL_CTS_TARGET): PRIVATE_NAME := $(cts_name)
$(INTERNAL_CTS_TARGET): PRIVATE_CTS_DIR := $(cts_dir)
$(INTERNAL_CTS_TARGET): PRIVATE_DIR := $(cts_dir)/$(cts_name)
$(INTERNAL_CTS_TARGET): TMP_DIR := $(cts_dir)/temp
$(INTERNAL_CTS_TARGET): $(cts_dir)/all_cts_files_stamp $(DEFAULT_TEST_PLAN) $(CORE_VM_TEST_DESC)
	@echo "Package CTS: $@"
	$(hide) cd $(dir $@) && zip -rq $(notdir $@) $(PRIVATE_NAME)

.PHONY: cts
cts: $(INTERNAL_CTS_TARGET) adb
$(call dist-for-goals,cts,$(INTERNAL_CTS_TARGET))

define copy-testcase-apk

$(hide) $(ACP) -fp $(call intermediates-dir-for,APPS,$(1))/package.apk \
	$(PRIVATE_DIR)/repository/testcases/$(1).apk

endef
