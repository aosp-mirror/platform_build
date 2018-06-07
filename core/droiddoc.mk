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
###########################################################
## Common logic to both droiddoc and javadoc
###########################################################
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
  else ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),core_current)
    LOCAL_JAVA_LIBRARIES := core.current.stubs $(LOCAL_JAVA_LIBRARIES)
    $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, core.current.stubs)
  else
    # core_<ver> is subset of <ver>. Instead of defining a prebuilt lib for core_<ver>,
    # use the stub for <ver> when building for apps.
    _version := $(patsubst core_%,%,$(LOCAL_SDK_VERSION))
    LOCAL_JAVA_LIBRARIES := sdk_v$(_version) $(LOCAL_JAVA_LIBRARIES)
    $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, sdk_v$(_version))
    _version :=
  endif
else
  ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    LOCAL_JAVA_LIBRARIES := core-oj core-libart
  else
    LOCAL_JAVA_LIBRARIES := core-oj core-libart ext framework $(LOCAL_JAVA_LIBRARIES)
  endif
  $(full_target): PRIVATE_BOOTCLASSPATH := $(call java-lib-files, core-oj):$(call java-lib-files, core-libart)
endif  # LOCAL_SDK_VERSION
LOCAL_JAVA_LIBRARIES := $(sort $(LOCAL_JAVA_LIBRARIES))

full_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES)) $(LOCAL_CLASSPATH)
endif # !LOCAL_IS_HOST_MODULE

$(full_target): PRIVATE_CLASSPATH := $(call normalize-path-list,$(full_java_libs))

intermediates.COMMON := $(call local-intermediates-dir,COMMON)

$(full_target): PRIVATE_SOURCE_PATH := $(call normalize-path-list,$(LOCAL_DROIDDOC_SOURCE_PATH))
$(full_target): PRIVATE_JAVA_FILES := $(filter %.java,$(full_src_files))
$(full_target): PRIVATE_JAVA_FILES += $(addprefix $($(my_prefix)OUT_COMMON_INTERMEDIATES)/, $(filter %.java,$(LOCAL_INTERMEDIATE_SOURCES)))
$(full_target): PRIVATE_JAVA_FILES += $(filter %.java,$(LOCAL_GENERATED_SOURCES))
$(full_target): PRIVATE_SRCJARS := $(LOCAL_SRCJARS)
$(full_target): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates.COMMON)/src
$(full_target): PRIVATE_SRCJAR_INTERMEDIATES_DIR := $(intermediates.COMMON)/srcjars
$(full_target): PRIVATE_SRC_LIST_FILE := $(intermediates.COMMON)/droiddoc-src-list
$(full_target): PRIVATE_SRCJAR_LIST_FILE := $(intermediates.COMMON)/droiddoc-srcjar-list

ifneq ($(strip $(LOCAL_ADDITIONAL_JAVA_DIR)),)
$(full_target): PRIVATE_ADDITIONAL_JAVA_DIR := $(LOCAL_ADDITIONAL_JAVA_DIR)
endif

$(full_target): PRIVATE_OUT_DIR := $(out_dir)
$(full_target): PRIVATE_DROIDDOC_OPTIONS := $(LOCAL_DROIDDOC_OPTIONS)
$(full_target): PRIVATE_STUB_OUT_DIR := $(LOCAL_DROIDDOC_STUB_OUT_DIR)
$(full_target): PRIVATE_METALAVA_DOCS_STUB_OUT_DIR := $(LOCAL_DROIDDOC_METALAVA_DOCS_STUB_OUT_DIR)

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

###########################################################
## Logic for droiddoc only
###########################################################
ifneq ($(strip $(LOCAL_DROIDDOC_USE_STANDARD_DOCLET)),true)

droiddoc_templates := \
    $(sort $(shell find $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR) -type f $(if $(ALLOW_MISSING_DEPENDENCIES),2>/dev/null)))

ifdef ALLOW_MISSING_DEPENDENCIES
  ifndef droiddoc_templates
    droiddoc_templates := $(LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR)
  endif
endif

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

# TODO(nanzhang): Remove it if this is not used any more
$(full_target): PRIVATE_LOCAL_PATH := $(LOCAL_PATH)

ifeq ($(strip $(LOCAL_DROIDDOC_USE_METALAVA)),true)
ifneq ($(LOCAL_DROIDDOC_METALAVA_PREVIOUS_API),)
$(full_target): PRIVATE_DROIDDOC_METALAVA_PREVIOUS_API := --previous-api $(LOCAL_DROIDDOC_METALAVA_PREVIOUS_API)
else
$(full_target): PRIVATE_DROIDDOC_METALAVA_PREVIOUS_API :=
endif #!LOCAL_DROIDDOC_METALAVA_PREVIOUS_API

metalava_annotations_deps :=
ifeq ($(strip $(LOCAL_DROIDDOC_METALAVA_ANNOTATIONS_ENABLED)),true)
ifeq ($(LOCAL_DROIDDOC_METALAVA_PREVIOUS_API),)
$(error $(LOCAL_PATH): LOCAL_DROIDDOC_METALAVA_PREVIOUS_API has to be non-empty if metalava annotations was enabled!)
endif
ifeq ($(LOCAL_DROIDDOC_METALAVA_MERGE_ANNOTATIONS_DIR),)
$(error $(LOCAL_PATH): LOCAL_DROIDDOC_METALAVA_MERGE_ANNOTATIONS_DIR has to be non-empty if metalava annotations was enabled!)
endif

$(full_target): PRIVATE_DROIDDOC_METALAVA_ANNOTATIONS := --include-annotations --migrate-nullness \
    --extract-annotations $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(LOCAL_MODULE)_annotations.zip \
    --merge-annotations $(LOCAL_DROIDDOC_METALAVA_MERGE_ANNOTATIONS_DIR) \
    --hide HiddenTypedefConstant --hide SuperfluousPrefix --hide AnnotationExtraction
metalava_annotations_deps := $(sort $(shell find $(LOCAL_DROIDDOC_METALAVA_MERGE_ANNOTATIONS_DIR) -type f))
else
$(full_target): PRIVATE_DROIDDOC_METALAVA_ANNOTATIONS :=
endif #LOCAL_DROIDDOC_METALAVA_ANNOTATIONS_ENABLED=true

ifneq (,$(filter --generate-documentation,$(LOCAL_DROIDDOC_OPTIONS)))

pos = $(if $(findstring $1,$2),$(call pos,$1,$(wordlist 2,$(words $2),$2),x $3),$3)
metalava_args := $(wordlist 1, $(words $(call pos,--generate-documentation,$(LOCAL_DROIDDOC_OPTIONS))), \
    $(LOCAL_DROIDDOC_OPTIONS))
remaining_args :=  $(wordlist $(words $(call pos,--generate-documentation,$(LOCAL_DROIDDOC_OPTIONS))), \
    $(words $(LOCAL_DROIDDOC_OPTIONS)), $(LOCAL_DROIDDOC_OPTIONS))
doclava_args := $(wordlist 2, $(words $(remaining_args)), $(remaining_args))

$(full_target): \
        $(full_src_files) $(LOCAL_GENERATED_SOURCES) \
        $(droiddoc_templates) \
        $(HOST_JDK_TOOLS_JAR) \
        $(HOST_OUT_JAVA_LIBRARIES)/jsilver$(COMMON_JAVA_PACKAGE_SUFFIX) \
        $(HOST_OUT_JAVA_LIBRARIES)/doclava$(COMMON_JAVA_PACKAGE_SUFFIX) \
        $(HOST_OUT_JAVA_LIBRARIES)/metalava$(COMMON_JAVA_PACKAGE_SUFFIX) \
        $(html_dir_files) \
        $(full_java_libs) \
        $(ZIPSYNC) \
        $(LOCAL_SRCJARS) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES) \
        $(LOCAL_DROIDDOC_METALAVA_PREVIOUS_API) \
        $(metalava_annotations_deps)
	@echo metalava based docs: $(PRIVATE_OUT_DIR)
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $(PRIVATE_STUB_OUT_DIR)
	$(hide) rm -rf $(PRIVATE_METALAVA_DOCS_STUB_OUT_DIR)
	$(call prepare-doc-source-list,$(PRIVATE_SRC_LIST_FILE),$(PRIVATE_JAVA_FILES), \
			$(PRIVATE_SOURCE_INTERMEDIATES_DIR) $(PRIVATE_ADDITIONAL_JAVA_DIR))
	$(ZIPSYNC) -d $(PRIVATE_SRCJAR_INTERMEDIATES_DIR) -l $(PRIVATE_SRCJAR_LIST_FILE) -f "*.java" $(PRIVATE_SRCJARS)
	$(hide) ( \
		$(JAVA) -jar $(HOST_OUT_JAVA_LIBRARIES)/metalava$(COMMON_JAVA_PACKAGE_SUFFIX) \
                -encoding UTF-8 -source 1.8 \@$(PRIVATE_SRC_LIST_FILE) \@$(PRIVATE_SRCJAR_LIST_FILE) \
                $(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH)) \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
                --sourcepath $(PRIVATE_SOURCE_PATH) \
                --no-banner --color --quiet \
                $(addprefix --stubs ,$(PRIVATE_STUB_OUT_DIR)) \
                $(addprefix --doc-stubs ,$(PRIVATE_METALAVA_DOCS_STUB_OUT_DIR)) \
                --write-stubs-source-list $(intermediates.COMMON)/stubs-src-list \
                $(metalava_args) $(PRIVATE_DROIDDOC_METALAVA_PREVIOUS_API) $(PRIVATE_DROIDDOC_METALAVA_ANNOTATIONS) \
                $(JAVADOC) -encoding UTF-8 -source 1.8 STUBS_SOURCE_LIST \
                -J-Xmx1600m -J-XX:-OmitStackTraceInFastThrow -XDignore.symbol.file \
                -quiet -doclet com.google.doclava.Doclava -docletpath $(PRIVATE_DOCLETPATH) \
                -templatedir $(PRIVATE_CUSTOM_TEMPLATE_DIR) \
                $(PRIVATE_DROIDDOC_HTML_DIR) $(PRIVATE_ADDITIONAL_HTML_DIR) \
                $(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH)) \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
                -sourcepath $(PRIVATE_SOURCE_PATH) \
                -d $(PRIVATE_OUT_DIR) \
                $(PRIVATE_CURRENT_BUILD) $(PRIVATE_CURRENT_TIME) $(doclava_args) \
        && touch -f $@ ) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)
else
# no docs generation
$(full_target): \
        $(full_src_files) $(LOCAL_GENERATED_SOURCES) \
        $(full_java_libs) \
        $(HOST_OUT_JAVA_LIBRARIES)/metalava$(COMMON_JAVA_PACKAGE_SUFFIX) \
        $(ZIPSYNC) \
        $(LOCAL_SRCJARS) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES)
	@echo metalava based stubs: $@
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $(PRIVATE_STUB_OUT_DIR)
	$(call prepare-doc-source-list,$(PRIVATE_SRC_LIST_FILE),$(PRIVATE_JAVA_FILES), \
			$(PRIVATE_SOURCE_INTERMEDIATES_DIR) $(PRIVATE_ADDITIONAL_JAVA_DIR))
	$(ZIPSYNC) -d $(PRIVATE_SRCJAR_INTERMEDIATES_DIR) -l $(PRIVATE_SRCJAR_LIST_FILE) -f "*.java" $(PRIVATE_SRCJARS)
	$(hide) ( \
		$(JAVA) -jar $(HOST_OUT_JAVA_LIBRARIES)/metalava$(COMMON_JAVA_PACKAGE_SUFFIX) \
                -encoding UTF-8 -source 1.8 \@$(PRIVATE_SRC_LIST_FILE) \@$(PRIVATE_SRCJAR_LIST_FILE) \
                $(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH)) \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
                --sourcepath $(PRIVATE_SOURCE_PATH) \
                $(PRIVATE_DROIDDOC_OPTIONS) $(PRIVATE_DROIDDOC_METALAVA_PREVIOUS_API) $(PRIVATE_DROIDDOC_METALAVA_ANNOTATIONS) \
                --no-banner --color --quiet \
                $(addprefix --stubs ,$(PRIVATE_STUB_OUT_DIR)) \
        && touch -f $@ ) || (rm -rf $(PRIVATE_SRC_LIST_FILE); exit 45)

endif # stubs + docs generation
ifeq ($(strip $(LOCAL_DROIDDOC_METALAVA_ANNOTATIONS_ENABLED)),true)
$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(LOCAL_MODULE)_annotations.zip: $(full_target)
endif

else # doclava based droiddoc generation

# TODO(tobiast): Clean this up once we move to -source 1.9.
# OpenJDK 9 does not have the concept of a "boot classpath" so we should
# then rename PRIVATE_BOOTCLASSPATH to PRIVATE_MODULE or similar. For now,
# keep -bootclasspath here since it works in combination with -source 1.8.
$(full_target): \
        $(full_src_files) $(LOCAL_GENERATED_SOURCES) \
        $(droiddoc_templates) \
        $(HOST_JDK_TOOLS_JAR) \
        $(HOST_OUT_JAVA_LIBRARIES)/jsilver$(COMMON_JAVA_PACKAGE_SUFFIX) \
        $(HOST_OUT_JAVA_LIBRARIES)/doclava$(COMMON_JAVA_PACKAGE_SUFFIX) \
        $(html_dir_files) \
        $(full_java_libs) \
        $(ZIPSYNC) \
        $(LOCAL_SRCJARS) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES)
	@echo Docs droiddoc: $(PRIVATE_OUT_DIR)
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -rf $(PRIVATE_STUB_OUT_DIR)
	$(call prepare-doc-source-list,$(PRIVATE_SRC_LIST_FILE),$(PRIVATE_JAVA_FILES), \
			$(PRIVATE_SOURCE_INTERMEDIATES_DIR) $(PRIVATE_ADDITIONAL_JAVA_DIR))
	$(ZIPSYNC) -d $(PRIVATE_SRCJAR_INTERMEDIATES_DIR) -l $(PRIVATE_SRCJAR_LIST_FILE) -f "*.java" $(PRIVATE_SRCJARS)
	$(hide) ( \
		$(JAVADOC) \
                -encoding UTF-8 -source 1.8 \@$(PRIVATE_SRC_LIST_FILE) \@$(PRIVATE_SRCJAR_LIST_FILE) \
                -J-Xmx1600m -J-XX:-OmitStackTraceInFastThrow -XDignore.symbol.file \
                -quiet -doclet com.google.doclava.Doclava -docletpath $(PRIVATE_DOCLETPATH) \
                -templatedir $(PRIVATE_CUSTOM_TEMPLATE_DIR) \
                $(PRIVATE_DROIDDOC_HTML_DIR) $(PRIVATE_ADDITIONAL_HTML_DIR) \
                $(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH)) \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) \
                -sourcepath $(PRIVATE_SOURCE_PATH)$(addprefix :,$(PRIVATE_CLASSPATH)) \
                -d $(PRIVATE_OUT_DIR) \
                $(PRIVATE_CURRENT_BUILD) $(PRIVATE_CURRENT_TIME) $(PRIVATE_DROIDDOC_OPTIONS) \
                $(addprefix -stubs ,$(PRIVATE_STUB_OUT_DIR)) \
        && touch -f $@ ) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)
endif #LOCAL_DROIDDOC_USE_METALAVA

else

###########################################################
## Logic for javadoc only
###########################################################
ifdef USE_OPENJDK9
# For OpenJDK 9 we use --patch-module to define the core libraries code.
# TODO(tobiast): Reorganize this when adding proper support for OpenJDK 9
# modules. Here we treat all code in core libraries as being in java.base
# to work around the OpenJDK 9 module system. http://b/62049770
$(full_target): PRIVATE_BOOTCLASSPATH_ARG := --patch-module=java.base=$(PRIVATE_BOOTCLASSPATH)
else
# For OpenJDK 8 we can use -bootclasspath to define the core libraries code.
$(full_target): PRIVATE_BOOTCLASSPATH_ARG := $(addprefix -bootclasspath ,$(PRIVATE_BOOTCLASSPATH))
endif
$(full_target): $(full_src_files) $(LOCAL_GENERATED_SOURCES) $(full_java_libs) $(ZIPSYNC) $(LOCAL_SRCJARS) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	@echo Docs javadoc: $(PRIVATE_OUT_DIR)
	@mkdir -p $(dir $@)
	$(call prepare-doc-source-list,$(PRIVATE_SRC_LIST_FILE),$(PRIVATE_JAVA_FILES), \
			$(PRIVATE_SOURCE_INTERMEDIATES_DIR) $(PRIVATE_ADDITIONAL_JAVA_DIR))
	$(ZIPSYNC) -d $(PRIVATE_SRCJAR_INTERMEDIATES_DIR) -l $(PRIVATE_SRCJAR_LIST_FILE) -f "*.java" $(PRIVATE_SRCJARS)
	$(hide) ( \
		$(JAVADOC) -encoding UTF-8 \@$(PRIVATE_SRC_LIST_FILE) \@$(PRIVATE_SRCJAR_LIST_FILE) \
                $(PRIVATE_DROIDDOC_OPTIONS) -J-Xmx1024m -XDignore.symbol.file -Xdoclint:none -quiet \
                $(addprefix -classpath ,$(PRIVATE_CLASSPATH)) $(PRIVATE_BOOTCLASSPATH_ARG) \
                -sourcepath $(PRIVATE_SOURCE_PATH) \
                -d $(PRIVATE_OUT_DIR) \
        && touch -f $@ \
    ) || (rm -rf $(PRIVATE_OUT_DIR) $(PRIVATE_SRC_LIST_FILE); exit 45)

endif # !LOCAL_DROIDDOC_USE_STANDARD_DOCLET

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

endif #!LOCAL_UNINSTALLABLE_MODULE
