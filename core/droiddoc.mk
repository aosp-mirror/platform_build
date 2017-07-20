#
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
#

$(call record-module-type,DROIDDOC)
##
##
## Common to both droiddoc and javadoc
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
out_dir := $(OUT_DOCS)/$(LOCAL_MODULE)
full_target := $(call doc-timestamp-for,$(LOCAL_MODULE))

ifeq ($(LOCAL_DROIDDOC_SOURCE_PATH),)
LOCAL_DROIDDOC_SOURCE_PATH := $(LOCAL_PATH)
endif

ifeq ($(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR),)
LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR := $(SRC_DROIDDOC_DIR)/$(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR)
endif

ifeq ($(LOCAL_DROIDDOC_ASSET_DIR),)
LOCAL_DROIDDOC_ASSET_DIR := assets
endif
ifeq ($(LOCAL_DROIDDOC_CUSTOM_ASSET_DIR),)
LOCAL_DROIDDOC_CUSTOM_ASSET_DIR := assets
endif

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
    LOCAL_JAVA_LIBRARIES := sdk_v$(LOCAL_SDK_VERSION) $(LOCAL_JAVA_LIBRARIES)
    $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, sdk_v$(LOCAL_SDK_VERSION))
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


intermediates.COMMON := $(call local-intermediates-dir,COMMON)

$(full_target): PRIVATE_SOURCE_PATH := $(call normalize-path-list,$(LOCAL_DROIDDOC_SOURCE_PATH))
$(full_target): PRIVATE_JAVA_FILES := $(filter %.java,$(full_src_files))
$(full_target): PRIVATE_JAVA_FILES += $(addprefix $($(my_prefix)OUT_COMMON_INTERMEDIATES)/, $(filter %.java,$(LOCAL_INTERMEDIATE_SOURCES)))
$(full_target): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/src
$(full_target): PRIVATE_SRC_LIST_FILE := $(intermediates.COMMON)/droiddoc-src-list

ifneq ($(strip $(LOCAL_ADDITIONAL_JAVA_DIR)),)
$(full_target): PRIVATE_ADDITIONAL_JAVA_DIR := $(LOCAL_ADDITIONAL_JAVA_DIR)
endif

$(full_target): PRIVATE_OUT_DIR := $(out_dir)
$(full_target): PRIVATE_DROIDDOC_OPTIONS := $(LOCAL_DROIDDOC_OPTIONS)
$(full_target): PRIVATE_STUB_OUT_DIR := $(LOCAL_DROIDDOC_STUB_OUT_DIR)

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

ifeq (a,b)
$(full_target): PRIVATE_PROFILING_OPTIONS := \
    -J-agentlib:jprofilerti=port=8849 -J-Xbootclasspath/a:/Applications/jprofiler5/bin/agent.jar
endif


ifneq ($(strip $(LOCAL_DROIDDOC_USE_STANDARD_DOCLET)),true)
##
##
## droiddoc only
##
##

droiddoc_templates := \
    $(sort $(shell find $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR) -type f $(if $(ALLOW_MISSING_DEPENDENCIES),2>/dev/null)))

ifdef ALLOW_MISSING_DEPENDENCIES
  ifndef droiddoc_templates
    droiddoc_templates := $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR)
  endif
endif

droiddoc := \
	$(HOST_JDK_TOOLS_JAR) \
	$(HOST_OUT_JAVA_LIBRARIES)/doclava$(COMMON_JAVA_PACKAGE_SUFFIX)

$(full_target): PRIVATE_DOCLETPATH := $(HOST_OUT_JAVA_LIBRARIES)/jsilver$(COMMON_JAVA_PACKAGE_SUFFIX):$(HOST_OUT_JAVA_LIBRARIES)/doclava$(COMMON_JAVA_PACKAGE_SUFFIX)
$(full_target): PRIVATE_CURRENT_BUILD := -hdf page.build $(BUILD_ID)-$(BUILD_NUMBER_FROM_FILE)
$(full_target): PRIVATE_CURRENT_TIME :=  -hdf page.now "$$($(DATE_FROM_FILE) "+%d %b %Y %k:%M")"
$(full_target): PRIVATE_CUSTOM_TEMPLATE_DIR := $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR)
$(full_target): PRIVATE_IN_CUSTOM_ASSET_DIR := $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR)/$(LOCAL_DROIDDOC_CUSTOM_ASSET_DIR)
$(full_target): PRIVATE_OUT_ASSET_DIR := $(out_dir)/$(LOCAL_DROIDDOC_ASSET_DIR)
$(full_target): PRIVATE_OUT_CUSTOM_ASSET_DIR := $(out_dir)/$(LOCAL_DROIDDOC_CUSTOM_ASSET_DIR)

html_dir_files :=
ifneq ($(strip $(LOCAL_DROIDDOC_HTML_DIR)),)
$(full_target): PRIVATE_DROIDDOC_HTML_DIR := -htmldir $(LOCAL_PATH)/$(LOCAL_DROIDDOC_HTML_DIR)
html_dir_files := $(sort $(shell find $(LOCAL_PATH)/$(LOCAL_DROIDDOC_HTML_DIR) -type f))
else
$(full_target): PRIVATE_DROIDDOC_HTML_DIR :=
endif
ifneq ($(strip $(LOCAL_ADDITIONAL_HTML_DIR)),)
$(full_target): PRIVATE_ADDITIONAL_HTML_DIR := -htmldir2 $(LOCAL_PATH)/$(LOCAL_ADDITIONAL_HTML_DIR)
else
$(full_target): PRIVATE_ADDITIONAL_HTML_DIR :=
endif

# TODO: not clear if this is used any more
$(full_target): PRIVATE_LOCAL_PATH := $(LOCAL_PATH)

# TODO(tobiast): Clean this up once we move to -source 1.9.
# OpenJDK 9 does not have the concept of a "boot classpath" so we should
# then rename PRIVATE_BOOTCLASSPATH to PRIVATE_MODULE or similar. For now,
# keep -bootclasspath here since it works in combination with -source 1.8.
$(full_target): \
        $(full_src_files) \
        $(droiddoc_templates) \
        $(droiddoc) \
        $(html_dir_files) \
        $(full_java_lib_deps) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES)
	@echo Docs droiddoc: $(PRIVATE_OUT_DIR)
	$(hide) mkdir -p $(dir $@)
	$(addprefix $(hide) rm -rf ,$(PRIVATE_STUB_OUT_DIR))
	$(call prepare-doc-source-list,$(PRIVATE_SRC_LIST_FILE),$(PRIVATE_JAVA_FILES), \
			$(PRIVATE_SOURCE_INTERMEDIATES_DIR) $(PRIVATE_ADDITIONAL_JAVA_DIR))
	$(hide) ( \
		$(JAVADOC) \
                -encoding UTF-8 \
                -source 1.8 \
                \@$(PRIVATE_SRC_LIST_FILE) \
                -J-Xmx1600m \
                -J-XX:-OmitStackTraceInFastThrow \
                -XDignore.symbol.file \
                $(PRIVATE_PROFILING_OPTIONS) \
                -quiet \
                -doclet com.google.doclava.Doclava \
                -docletpath $(PRIVATE_DOCLETPATH) \
                -templatedir $(PRIVATE_CUSTOM_TEMPLATE_DIR) \
                $(PRIVATE_DROIDDOC_HTML_DIR) \
                $(PRIVATE_ADDITIONAL_HTML_DIR) \
                $(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH)) \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
                -sourcepath $(PRIVATE_SOURCE_PATH)$(addprefix :,$(PRIVATE_CLASSPATH)) \
                -d $(PRIVATE_OUT_DIR) \
                $(PRIVATE_CURRENT_BUILD) $(PRIVATE_CURRENT_TIME) \
                $(PRIVATE_DROIDDOC_OPTIONS) \
                $(addprefix -stubs ,$(PRIVATE_STUB_OUT_DIR)) \
        && touch -f $@ \
    ) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)



else
##
##
## standard doclet only
##
##

ifneq ($(EXPERIMENTAL_USE_OPENJDK9),)
# For OpenJDK 9 we use --patch-module to define the core libraries code.
# TODO(tobiast): Reorganize this when adding proper support for OpenJDK 9
# modules. Here we treat all code in core libraries as being in java.base
# to work around the OpenJDK 9 module system. http://b/62049770
$(full_target): PRIVATE_BOOTCLASSPATH_ARG := --patch-module=java.base=$(PRIVATE_BOOTCLASSPATH)
else
# For OpenJDK 8 we can use -bootclasspath to define the core libraries code.
$(full_target): PRIVATE_BOOTCLASSPATH_ARG := $(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH))
endif

$(full_target): $(full_src_files) $(full_java_lib_deps)
	@echo Docs javadoc: $(PRIVATE_OUT_DIR)
	@mkdir -p $(dir $@)
	$(call prepare-doc-source-list,$(PRIVATE_SRC_LIST_FILE),$(PRIVATE_JAVA_FILES), \
			$(PRIVATE_SOURCE_INTERMEDIATES_DIR) $(PRIVATE_ADDITIONAL_JAVA_DIR))
	$(hide) ( \
		$(JAVADOC) \
                -encoding UTF-8 \
                $(PRIVATE_DROIDDOC_OPTIONS) \
                \@$(PRIVATE_SRC_LIST_FILE) \
                -J-Xmx1024m \
                -XDignore.symbol.file \
                -Xdoclint:none \
                $(PRIVATE_PROFILING_OPTIONS) \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
                $(PRIVATE_BOOTCLASSPATH_ARG) \
                -sourcepath $(PRIVATE_SOURCE_PATH)$(addprefix :,$(PRIVATE_CLASSPATH)) \
                -d $(PRIVATE_OUT_DIR) \
                -quiet \
        && touch -f $@ \
    ) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)


endif
##
##
## Common to both droiddoc and javadoc
##
##


ALL_DOCS += $(full_target)

.PHONY: $(LOCAL_MODULE)-docs
$(LOCAL_MODULE)-docs : $(full_target)

ifeq ($(strip $(LOCAL_UNINSTALLABLE_MODULE)),)

# Define a rule to create a zip of these docs.
out_zip := $(OUT_DOCS)/$(LOCAL_MODULE)-docs.zip
$(out_zip): PRIVATE_DOCS_DIR := $(out_dir)
$(out_zip): $(full_target)
	@echo Package docs: $@
	@rm -f $@
	@mkdir -p $(dir $@)
	$(hide) ( F=$$(pwd)/$@ ; cd $(PRIVATE_DOCS_DIR) && zip -rqX $$F * )

$(LOCAL_MODULE)-docs.zip : $(out_zip)

$(call dist-for-goals,docs,$(out_zip))

endif
