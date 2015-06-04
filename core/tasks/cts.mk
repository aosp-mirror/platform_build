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

JUNIT_HOST_JAR := $(HOST_OUT_JAVA_LIBRARIES)/junit.jar
HOSTTESTLIB_JAR := $(HOST_OUT_JAVA_LIBRARIES)/hosttestlib.jar
TF_JAR := $(HOST_OUT_JAVA_LIBRARIES)/tradefed-prebuilt.jar
CTS_TF_JAR := $(HOST_OUT_JAVA_LIBRARIES)/cts-tradefed.jar
CTS_TF_EXEC_PATH ?= $(HOST_OUT_EXECUTABLES)/cts-tradefed
CTS_TF_README_PATH := $(cts_tools_src_dir)/tradefed-host/README

VMTESTSTF_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,vm-tests-tf,HOST)
VMTESTSTF_JAR := $(VMTESTSTF_INTERMEDIATES)/android.core.vm-tests-tf.jar

# The list of test packages that core-tests (libcore/Android.mk)
# is split into.
CTS_CORE_CASE_LIST := \
	android.core.tests.libcore.package.dalvik \
	android.core.tests.libcore.package.com \
	android.core.tests.libcore.package.conscrypt \
	android.core.tests.libcore.package.sun \
	android.core.tests.libcore.package.tests \
	android.core.tests.libcore.package.org \
	android.core.tests.libcore.package.libcore \
	android.core.tests.libcore.package.jsr166 \
	android.core.tests.libcore.package.harmony_annotation \
	android.core.tests.libcore.package.harmony_java_io \
	android.core.tests.libcore.package.harmony_java_lang \
	android.core.tests.libcore.package.harmony_java_math \
	android.core.tests.libcore.package.harmony_java_net \
	android.core.tests.libcore.package.harmony_java_nio \
	android.core.tests.libcore.package.harmony_java_text \
	android.core.tests.libcore.package.harmony_java_util \
	android.core.tests.libcore.package.harmony_javax_security \
	android.core.tests.libcore.package.okhttp \
	android.core.tests.runner

# Additional CTS packages for code under libcore
CTS_CORE_CASE_LIST += \
	android.core.tests.libcore.package.tzdata

# The list of test packages that apache-harmony-tests (external/apache-harmony/Android.mk)
# is split into.
CTS_CORE_CASE_LIST += \
	android.core.tests.libcore.package.harmony_beans \
	android.core.tests.libcore.package.harmony_logging \
	android.core.tests.libcore.package.harmony_prefs \
	android.core.tests.libcore.package.harmony_sql


CTS_TEST_JAR_LIST := \
	cts-junit \
	CtsJdwp

# Depend on the full package paths rather than the phony targets to avoid
# rebuilding the packages every time.
CTS_CORE_CASES := $(foreach pkg,$(CTS_CORE_CASE_LIST),$(call intermediates-dir-for,APPS,$(pkg))/package.apk)
CTS_TEST_JAR_FILES := $(foreach c,$(CTS_TEST_JAR_LIST),$(call intermediates-dir-for,JAVA_LIBRARIES,$(c))/javalib.jar)

-include cts/CtsTestCaseList.mk

# A module may have mutliple installed files (e.g. split apks)
CTS_CASE_LIST_APKS :=
$(foreach m, $(CTS_TEST_CASE_LIST),\
  $(foreach fp, $(ALL_MODULES.$(m).BUILT_INSTALLED),\
    $(eval pair := $(subst :,$(space),$(fp)))\
    $(eval CTS_CASE_LIST_APKS += $(CTS_TESTCASES_OUT)/$(notdir $(word 2,$(pair))))))\
$(foreach m, $(CTS_CORE_CASE_LIST),\
  $(foreach fp, $(ALL_MODULES.$(m).BUILT_INSTALLED),\
    $(eval pair := $(subst :,$(space),$(fp)))\
    $(eval built := $(word 1,$(pair)))\
    $(eval installed := $(CTS_TESTCASES_OUT)/$(notdir $(word 2,$(pair))))\
    $(eval $(call copy-one-file, $(built), $(installed)))\
    $(eval CTS_CASE_LIST_APKS += $(installed))))

CTS_CASE_LIST_JARS :=
$(foreach m, $(CTS_TEST_JAR_LIST),\
  $(eval CTS_CASE_LIST_JARS += $(CTS_TESTCASES_OUT)/$(m).jar))

CTS_SHARED_LIBS :=

DEFAULT_TEST_PLAN := $(cts_dir)/$(cts_name)/resource/plans
$(cts_dir)/all_cts_files_stamp: $(CTS_CORE_CASES) $(CTS_TEST_JAR_FILES) $(CTS_TEST_CASES) $(CTS_CASE_LIST_APKS) $(CTS_CASE_LIST_JARS) $(JUNIT_HOST_JAR) $(HOSTTESTLIB_JAR) $(CTS_HOST_LIBRARY_JARS) $(TF_JAR) $(VMTESTSTF_JAR) $(CTS_TF_JAR) $(CTS_TF_EXEC_PATH) $(CTS_TF_README_PATH) $(ADDITIONAL_TF_JARS) $(ACP) $(CTS_SHARED_LIBS)

# Make necessary directory for CTS
	$(hide) mkdir -p $(TMP_DIR)
	$(hide) mkdir -p $(PRIVATE_DIR)/docs
	$(hide) mkdir -p $(PRIVATE_DIR)/tools
	$(hide) mkdir -p $(PRIVATE_DIR)/repository/testcases
	$(hide) mkdir -p $(PRIVATE_DIR)/repository/plans
# Copy executable and JARs to CTS directory
	$(hide) $(ACP) -fp $(VMTESTSTF_JAR) $(CTS_TESTCASES_OUT)
	$(hide) $(ACP) -fp $(HOSTTESTLIB_JAR) $(CTS_HOST_LIBRARY_JARS) $(TF_JAR) $(CTS_TF_JAR) $(CTS_TF_EXEC_PATH) $(ADDITIONAL_TF_JARS) $(CTS_TF_README_PATH) $(PRIVATE_DIR)/tools
	$(hide) $(call copy-files-with-structure, $(CTS_SHARED_LIBS),$(HOST_OUT)/,$(PRIVATE_DIR))
	$(hide) touch $@

# Generate the test descriptions for the core-tests
# Parameters:
# $1 : The output file where the description should be written (without the '.xml' extension)
# $2 : The AndroidManifest.xml corresponding to the test package
# $3 : The jar file name on PRIVATE_CLASSPATH containing junit tests to search for
# $4 : The package prefix of classes to include, possible empty
# $5 : The architecture of the current build
# $6 : The directory containing vogar expectations files
# $7 : The Android.mk corresponding to the test package (required for host-side tests only)
define generate-core-test-description
@echo "Generate core-test description ("$(notdir $(1))")"
$(hide) java -Xmx256M \
	-Xbootclasspath/a:$(PRIVATE_CLASSPATH):$(JUNIT_HOST_JAR) \
	-classpath $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar:$(HOST_JDK_TOOLS_JAR) \
	$(PRIVATE_PARAMS) CollectAllTests $(1) $(2) $(3) "$(4)" $(5) $(6) $(7)
endef

CORE_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-libart,,COMMON)
CONSCRYPT_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,conscrypt,,COMMON)
BOUNCYCASTLE_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,bouncycastle,,COMMON)
APACHEXML_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,apache-xml,,COMMON)
OKHTTP_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,okhttp-nojarjar,,COMMON)
OKHTTPTESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,okhttp-tests-nojarjar,,COMMON)
OKHTTP_REPACKAGED_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,okhttp,,COMMON)
APACHEHARMONYTESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,apache-harmony-tests,,COMMON)
SQLITEJDBC_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,sqlite-jdbc,,COMMON)
JUNIT_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-junit,,COMMON)
CORETESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-tests,,COMMON)
JSR166TESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,jsr166-tests,,COMMON)
CONSCRYPTTESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,conscrypt-tests,,COMMON)
TZDATAUPDATETESTS_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,tzdata_update-tests,,COMMON)

GEN_CLASSPATH := \
    $(CORE_INTERMEDIATES)/classes.jar:$(CONSCRYPT_INTERMEDIATES)/classes.jar:$(BOUNCYCASTLE_INTERMEDIATES)/classes.jar:$(APACHEXML_INTERMEDIATES)/classes.jar:$(APACHEHARMONYTESTS_INTERMEDIATES)/classes.jar:$(OKHTTP_INTERMEDIATES)/classes.jar:$(OKHTTPTESTS_INTERMEDIATES)/classes.jar:$(OKHTTP_REPACKAGED_INTERMEDIATES)/classes.jar:$(JUNIT_INTERMEDIATES)/classes.jar:$(SQLITEJDBC_INTERMEDIATES)/javalib.jar:$(CORETESTS_INTERMEDIATES)/javalib.jar:$(JSR166TESTS_INTERMEDIATES)/javalib.jar:$(CONSCRYPTTESTS_INTERMEDIATES)/javalib.jar:$(TZDATAUPDATETESTS_INTERMEDIATES)/javalib.jar

CTS_CORE_XMLS := \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.dalvik.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.com.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.conscrypt.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.sun.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.tests.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.org.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.libcore.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.jsr166.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_annotation.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_io.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_lang.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_math.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_net.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_nio.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_text.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_util.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_javax_security.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_beans.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_logging.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_prefs.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_sql.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.okhttp.xml \
	$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.tzdata.xml \

$(CTS_CORE_XMLS): PRIVATE_CLASSPATH:=$(GEN_CLASSPATH)
# Why does this depend on javalib.jar instead of classes.jar?  Because
# even though the tool will operate on the classes.jar files, the
# build system requires that dependencies use javalib.jar.  If
# javalib.jar is up-to-date, then classes.jar is as well.  Depending
# on classes.jar will build the files incorrectly.
CTS_CORE_XMLS_DEPS := $(CTS_CORE_CASES) $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar $(JUNIT_HOST_JAR) $(CORE_INTERMEDIATES)/javalib.jar $(BOUNCYCASTLE_INTERMEDIATES)/javalib.jar $(APACHEXML_INTERMEDIATES)/javalib.jar $(APACHEHARMONYTESTS_INTERMEDIATES)/javalib.jar $(OKHTTP_INTERMEDIATES)/javalib.jar $(OKHTTPTESTS_INTERMEDIATES)/javalib.jar $(OKHTTP_REPACKAGED_INTERMEDIATES)/javalib.jar $(SQLITEJDBC_INTERMEDIATES)/javalib.jar $(JUNIT_INTERMEDIATES)/javalib.jar $(CORETESTS_INTERMEDIATES)/javalib.jar $(JSR166TESTS_INTERMEDIATES)/javalib.jar $(CONSCRYPTTESTS_INTERMEDIATES)/javalib.jar $(TZDATAUPDATETESTS_INTERMEDIATES)/javalib.jar build/core/tasks/cts.mk | $(ACP)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.dalvik.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.dalvik,\
		cts/tests/core/libcore/dalvik/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,dalvik,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.com.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.com,\
		cts/tests/core/libcore/com/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,com,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.conscrypt.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.conscrypt,\
		cts/tests/core/libcore/conscrypt/AndroidManifest.xml,\
		$(CONSCRYPTTESTS_INTERMEDIATES)/javalib.jar,,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.sun.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.sun,\
		cts/tests/core/libcore/sun/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,sun,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.tests.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.tests,\
		cts/tests/core/libcore/tests/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,tests,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.org.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.org,\
		cts/tests/core/libcore/org/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,\
		org.w3c.domts:\
		org.apache.harmony.security.tests:\
		org.apache.harmony.nio.tests:\
		org.apache.harmony.crypto.tests:\
		org.apache.harmony.regex.tests:\
		org.apache.harmony.luni.tests:\
		org.apache.harmony.tests.internal.net.www.protocol:\
		org.apache.harmony.tests.javax.net:\
		org.json,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.libcore.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.libcore,\
		cts/tests/core/libcore/libcore/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,libcore,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.jsr166.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.jsr166,\
		cts/tests/core/libcore/jsr166/AndroidManifest.xml,\
		$(JSR166TESTS_INTERMEDIATES)/javalib.jar,jsr166,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_annotation.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_annotation,\
		cts/tests/core/libcore/harmony_annotation/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.annotation.tests,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_io.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_io,\
		cts/tests/core/libcore/harmony_java_io/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.java.io,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_lang.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_lang,\
		cts/tests/core/libcore/harmony_java_lang/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.java.lang,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_math.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_math,\
		cts/tests/core/libcore/harmony_java_math/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.java.math,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_net.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_net,\
		cts/tests/core/libcore/harmony_java_net/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.java.net,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_nio.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_nio,\
		cts/tests/core/libcore/harmony_java_nio/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.java.nio,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_text.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_text,\
		cts/tests/core/libcore/harmony_java_text/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.java.text,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_util.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_java_util,\
		cts/tests/core/libcore/harmony_java_util/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.java.util,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_javax_security.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_javax_security,\
		cts/tests/core/libcore/harmony_javax_security/AndroidManifest.xml,\
		$(CORETESTS_INTERMEDIATES)/javalib.jar,org.apache.harmony.tests.javax.security,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_beans.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_beans,\
		cts/tests/core/libcore/harmony_beans/AndroidManifest.xml,\
		$(APACHEHARMONYTESTS_INTERMEDIATES)/javalib.jar,com.android.org.apache.harmony.beans,\
		$(TARGET_ARCH),libcore/expectations external/apache-harmony/Android.mk)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_logging.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_logging,\
		cts/tests/core/libcore/harmony_logging/AndroidManifest.xml,\
		$(APACHEHARMONYTESTS_INTERMEDIATES)/javalib.jar,com.android.org.apache.harmony.logging,\
		$(TARGET_ARCH),libcore/expectations external/apache-harmony/Android.mk)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_prefs.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_prefs,\
		cts/tests/core/libcore/harmony_prefs/AndroidManifest.xml,\
		$(APACHEHARMONYTESTS_INTERMEDIATES)/javalib.jar,com.android.org.apache.harmony.prefs,\
		$(TARGET_ARCH),libcore/expectations external/apache-harmony/Android.mk)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_sql.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.harmony_sql,\
		cts/tests/core/libcore/harmony_sql/AndroidManifest.xml,\
		$(APACHEHARMONYTESTS_INTERMEDIATES)/javalib.jar,com.android.org.apache.harmony.sql,\
		$(TARGET_ARCH),libcore/expectations external/apache-harmony/Android.mk)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.okhttp.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.okhttp,\
		cts/tests/core/libcore/okhttp/AndroidManifest.xml,\
		$(OKHTTPTESTS_INTERMEDIATES)/javalib.jar,,\
		$(TARGET_ARCH),libcore/expectations)

$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.tzdata.xml: $(CTS_CORE_XMLS_DEPS)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.tests.libcore.package.tzdata,\
		cts/tests/core/libcore/tzdata/AndroidManifest.xml,\
		$(TZDATAUPDATETESTS_INTERMEDIATES)/javalib.jar,,\
		$(TARGET_ARCH),libcore/expectations)

# ----- Generate the test descriptions for the vm-tests-tf -----
#
CORE_VM_TEST_TF_DESC := $(CTS_TESTCASES_OUT)/android.core.vm-tests-tf.xml

# core tests only needed to get hold of junit-framework-classes
CORE_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-libart,,COMMON)
JUNIT_INTERMEDIATES :=$(call intermediates-dir-for,JAVA_LIBRARIES,core-junit,,COMMON)

GEN_CLASSPATH := $(CORE_INTERMEDIATES)/classes.jar:$(JUNIT_INTERMEDIATES)/classes.jar:$(VMTESTSTF_JAR):$(TF_JAR)

$(CORE_VM_TEST_TF_DESC): PRIVATE_CLASSPATH:=$(GEN_CLASSPATH)
# Please see big comment above on why this line depends on javalib.jar instead of classes.jar
$(CORE_VM_TEST_TF_DESC): $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar $(JUNIT_HOST_JAR) $(CORE_INTERMEDIATES)/javalib.jar $(JUNIT_INTERMEDIATES)/javalib.jar $(VMTESTSTF_JAR) | $(ACP)
	$(hide) mkdir -p $(CTS_TESTCASES_OUT)
	$(call generate-core-test-description,$(CTS_TESTCASES_OUT)/android.core.vm-tests-tf,\
		cts/tests/vm-tests-tf/AndroidManifest.xml,\
		$(VMTESTSTF_JAR),"",\
		$(TARGET_ARCH),\
		libcore/expectations,\
		cts/tools/vm-tests-tf/Android.mk)

# Generate the default test plan for User.
# Usage: buildCts.py <testRoot> <ctsOutputDir> <tempDir> <androidRootDir> <docletPath>

$(DEFAULT_TEST_PLAN): $(cts_dir)/all_cts_files_stamp $(cts_tools_src_dir)/utils/buildCts.py $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar $(CTS_CORE_XMLS) $(CTS_TEST_XMLS) $(CORE_VM_TEST_TF_DESC)
	$(hide) $(cts_tools_src_dir)/utils/buildCts.py cts/tests/tests/ $(PRIVATE_DIR) $(TMP_DIR) \
		$(TOP) $(HOST_OUT_JAVA_LIBRARIES)/descGen.jar
	$(hide) mkdir -p $(dir $@) && touch $@

# Package CTS and clean up.
#
# TODO:
#   Pack cts.bat into the same zip file as well. See http://buganizer/issue?id=1656821 for more details
INTERNAL_CTS_TARGET := $(cts_dir)/$(cts_name).zip
$(INTERNAL_CTS_TARGET): PRIVATE_NAME := $(cts_name)
$(INTERNAL_CTS_TARGET): PRIVATE_CTS_DIR := $(cts_dir)
$(INTERNAL_CTS_TARGET): PRIVATE_DIR := $(cts_dir)/$(cts_name)
$(INTERNAL_CTS_TARGET): TMP_DIR := $(cts_dir)/temp
$(INTERNAL_CTS_TARGET): $(cts_dir)/all_cts_files_stamp $(DEFAULT_TEST_PLAN)
	$(hide) echo "Package CTS: $@"
	$(hide) cd $(dir $@) && zip -rq $(notdir $@) $(PRIVATE_NAME)

.PHONY: cts
cts: $(INTERNAL_CTS_TARGET) adb
$(call dist-for-goals,cts,$(INTERNAL_CTS_TARGET))

