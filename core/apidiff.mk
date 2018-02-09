#
# Copyright (C) 2017 The Android Open Source Project
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
#

##
##
## Common to both jdiff and javadoc
##
##

LOCAL_IS_HOST_MODULE := $(call true-or-empty,$(LOCAL_IS_HOST_MODULE))
ifeq ($(LOCAL_IS_HOST_MODULE),true)
my_prefix := HOST_
LOCAL_HOST_PREFIX :=
else
my_prefix := TARGET_
endif

LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))
ifndef LOCAL_MODULE_CLASS
$(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined)
endif

full_src_files := $(patsubst %,$(LOCAL_PATH)/%,$(LOCAL_SRC_FILES))
out_dir := $(OUT_DOCS)/$(LOCAL_MODULE)/api_diff/current
full_target := $(call doc-timestamp-for,$(LOCAL_MODULE)-diff)

ifeq ($(LOCAL_IS_HOST_MODULE),true)
$(full_target): PRIVATE_BOOTCLASSPATH :=
full_java_libs := $(addprefix $(HOST_OUT_JAVA_LIBRARIES)/,\
  $(addsuffix $(COMMON_JAVA_PACKAGE_SUFFIX),$(LOCAL_JAVA_LIBRARIES)))
full_java_lib_deps := $(full_java_libs)

else

ifneq ($(LOCAL_SDK_VERSION),)
  ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),current)
    # Use android_stubs_current if LOCAL_SDK_VERSION is current and no TARGET_BUILD_APPS.
    LOCAL_JAVA_LIBRARIES := android_stubs_current $(LOCAL_JAVA_LIBRARIES)
    $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, android_stubs_current)
  else ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),system_current)
    LOCAL_JAVA_LIBRARIES := android_system_stubs_current $(LOCAL_JAVA_LIBRARIES)
    $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, android_system_stubs_current)
  else ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),test_current)
    LOCAL_JAVA_LIBRARIES := android_test_stubs_current $(LOCAL_JAVA_LIBRARIES)
    $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, android_test_stubs_current)
  else
    # core_<ver> is subset of <ver>. Instead of defining a prebuilt lib for core_<ver>,
    # use the stub for <ver> when building for apps.
    _version := $(patsubst core_%,%,$(LOCAL_SDK_VERSION))
    LOCAL_JAVA_LIBRARIES := sdk_v$(_version) $(LOCAL_JAVA_LIBRARIES)
    $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, sdk_v$(_version))
    _version :=
  endif
else
  LOCAL_JAVA_LIBRARIES := core-oj core-libart ext framework $(LOCAL_JAVA_LIBRARIES)
  $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, core-oj):$(call java-lib-files, core-libart)
endif  # LOCAL_SDK_VERSION
LOCAL_JAVA_LIBRARIES := $(sort $(LOCAL_JAVA_LIBRARIES))

full_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES)) $(LOCAL_CLASSPATH)
full_java_lib_deps := $(call java-lib-deps,$(LOCAL_JAVA_LIBRARIES)) $(LOCAL_CLASSPATH)
endif # !LOCAL_IS_HOST_MODULE

$(full_target): PRIVATE_CLASSPATH := $(subst $(space),:,$(full_java_libs))
$(full_target): PRIVATE_DOCLAVA_CLASSPATH := $(HOST_OUT_JAVA_LIBRARIES)/jsilver$(COMMON_JAVA_PACKAGE_SUFFIX):$(HOST_OUT_JAVA_LIBRARIES)/doclava$(COMMON_JAVA_PACKAGE_SUFFIX)

intermediates.COMMON := $(call local-intermediates-dir,COMMON)

$(full_target): PRIVATE_SOURCE_PATH := $(call normalize-path-list,$(LOCAL_DROIDDOC_SOURCE_PATH))
$(full_target): PRIVATE_JAVA_FILES := $(filter %.java,$(full_src_files))
$(full_target): PRIVATE_JAVA_FILES += $(addprefix $($(my_prefix)OUT_COMMON_INTERMEDIATES)/, $(filter %.java,$(LOCAL_INTERMEDIATE_SOURCES)))
$(full_target): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/src
$(full_target): PRIVATE_SRC_LIST_FILE := $(intermediates.COMMON)/droiddoc-src-list

ifneq ($(strip $(LOCAL_ADDITIONAL_JAVA_DIR)),)
$(full_target): PRIVATE_ADDITIONAL_JAVA_DIR := $(LOCAL_ADDITIONAL_JAVA_DIR)
endif

# Lists the input files for the doc build into a text file
# suitable for the @ syntax of javadoc.
# $(1): the file to create
# $(2): files to include
# $(3): list of directories to search for java files in
define prepare-doc-source-list
$(hide) mkdir -p $(dir $(1))
$(call dump-words-to-file, $(2), $(1))
$(hide) for d in $(3) ; do find $$d -name '*.java' -and -not -name '.*' >> $(1) 2> /dev/null ; done ; true
endef

##
##
## jdiff only
##
##

jdiff := \
	$(HOST_JDK_TOOLS_JAR) \
	$(HOST_OUT_JAVA_LIBRARIES)/jdiff$(COMMON_JAVA_PACKAGE_SUFFIX)

doclava := \
	$(HOST_JDK_TOOLS_JAR) \
	$(HOST_OUT_JAVA_LIBRARIES)/doclava$(COMMON_JAVA_PACKAGE_SUFFIX)

$(full_target): PRIVATE_NEWAPI := $(LOCAL_APIDIFF_NEWAPI)
$(full_target): PRIVATE_OLDAPI := $(LOCAL_APIDIFF_OLDAPI)
$(full_target): PRIVATE_OUT_DIR := $(out_dir)
$(full_target): PRIVATE_OUT_NEWAPI := $(out_dir)/current.xml
$(full_target): PRIVATE_OUT_OLDAPI := $(out_dir)/$(notdir $(basename $(LOCAL_APIDIFF_OLDAPI))).xml
$(full_target): PRIVATE_DOCLETPATH := $(HOST_OUT_JAVA_LIBRARIES)/jdiff$(COMMON_JAVA_PACKAGE_SUFFIX)
$(full_target): \
		$(full_src_files) \
		$(full_java_lib_deps) \
		$(jdiff) \
		$(doclava) \
		$(LOCAL_MODULE)-docs \
		$(LOCAL_ADDITIONAL_DEPENDENCIES)
	@echo Generating API diff: $(PRIVATE_OUT_DIR)
	@echo   Old API: $(PRIVATE_OLDAPI)
	@echo   New API: $(PRIVATE_NEWAPI)
	@echo   Old XML: $(PRIVATE_OUT_OLDAPI)
	@echo   New XML: $(PRIVATE_OUT_NEWAPI)
	$(hide) mkdir -p $(dir $@)
	@echo Converting API files to XML...
	$(hide) mkdir -p $(PRIVATE_OUT_DIR)
	$(hide) ( \
		$(JAVA) \
				$(addprefix -classpath ,$(PRIVATE_CLASSPATH):$(PRIVATE_DOCLAVA_CLASSPATH):$(PRIVATE_BOOTCLASSPATH):$(HOST_JDK_TOOLS_JAR)) \
				com.google.doclava.apicheck.ApiCheck \
				-convert2xml \
					$(basename $(PRIVATE_NEWAPI)).txt \
					$(basename $(PRIVATE_OUT_NEWAPI)).xml \
	) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)
	$(hide) ( \
		$(JAVA) \
				$(addprefix -classpath ,$(PRIVATE_CLASSPATH):$(PRIVATE_DOCLAVA_CLASSPATH):$(PRIVATE_BOOTCLASSPATH):$(HOST_JDK_TOOLS_JAR)) \
				com.google.doclava.apicheck.ApiCheck \
				-convert2xml \
					$(basename $(PRIVATE_OLDAPI)).txt \
					$(basename $(PRIVATE_OUT_OLDAPI)).xml \
	) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)
	@echo Running JDiff...
	$(call prepare-doc-source-list,$(PRIVATE_SRC_LIST_FILE),$(PRIVATE_JAVA_FILES), \
			$(PRIVATE_SOURCE_INTERMEDIATES_DIR) $(PRIVATE_ADDITIONAL_JAVA_DIR))
	$(hide) ( \
		$(JAVADOC) \
				-encoding UTF-8 \
				\@$(PRIVATE_SRC_LIST_FILE) \
				-J-Xmx1600m \
				-XDignore.symbol.file \
				-quiet \
				-doclet jdiff.JDiff \
				-docletpath $(PRIVATE_DOCLETPATH) \
				$(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH)) \
				$(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
				-sourcepath $(PRIVATE_SOURCE_PATH)$(addprefix :,$(PRIVATE_CLASSPATH)) \
				-d $(PRIVATE_OUT_DIR) \
				-newapi $(notdir $(basename $(PRIVATE_OUT_NEWAPI))) \
				-newapidir $(dir $(PRIVATE_OUT_NEWAPI)) \
				-oldapi $(notdir $(basename $(PRIVATE_OUT_OLDAPI))) \
				-oldapidir $(dir $(PRIVATE_OUT_OLDAPI)) \
				-javadocnew ../../../reference/ \
		&& touch -f $@ \
	) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)

ALL_DOCS += $(full_target)

.PHONY: $(LOCAL_MODULE)-diff
$(LOCAL_MODULE)-diff : $(full_target)
