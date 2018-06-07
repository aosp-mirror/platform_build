#
# Copyright (C) 2013 The Android Open Source Project
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
$(call record-module-type,HOST_DALVIK_JAVA_LIBRARY)

#
# Rules for building a host dalvik java library. These libraries
# are meant to be used by a dalvik VM instance running on the host.
# They will be compiled against libcore and not the host JRE.
#

ifeq ($(HOST_OS),linux)
USE_CORE_LIB_BOOTCLASSPATH := true

#######################################
include $(BUILD_SYSTEM)/host_java_library_common.mk
#######################################

full_classes_turbine_jar := $(intermediates.COMMON)/classes-turbine.jar
full_classes_header_jarjar := $(intermediates.COMMON)/classes-header-jarjar.jar
full_classes_header_jar := $(intermediates.COMMON)/classes-header.jar
full_classes_compiled_jar := $(intermediates.COMMON)/classes-full-debug.jar
full_classes_combined_jar := $(intermediates.COMMON)/classes-combined.jar
full_classes_desugar_jar := $(intermediates.COMMON)/desugar.classes.jar
full_classes_jarjar_jar := $(intermediates.COMMON)/classes-jarjar.jar
full_classes_jar := $(intermediates.COMMON)/classes.jar
built_dex := $(intermediates.COMMON)/classes.dex
java_source_list_file := $(intermediates.COMMON)/java-source-list

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_turbine_jar) \
    $(full_classes_compiled_jar) \
    $(full_classes_combined_jar) \
    $(full_classes_desugar_jar) \
    $(full_classes_jarjar_jar) \
    $(full_classes_jar) \
    $(built_dex) \
    $(java_source_list_file)

# See comment in java.mk
ifndef LOCAL_CHECKED_MODULE
ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
LOCAL_CHECKED_MODULE := $(full_classes_compiled_jar)
else
LOCAL_CHECKED_MODULE := $(built_dex)
endif
endif

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################
java_sources := $(addprefix $(LOCAL_PATH)/, $(filter %.java,$(LOCAL_SRC_FILES))) \
                $(filter %.java,$(LOCAL_GENERATED_SOURCES))
all_java_sources := $(java_sources)

include $(BUILD_SYSTEM)/java_common.mk

include $(BUILD_SYSTEM)/sdk_check.mk

$(cleantarget): PRIVATE_CLEAN_FILES += $(intermediates.COMMON)

# List of dependencies for anything that needs all java sources in place
java_sources_deps := \
    $(java_sources) \
    $(java_resource_sources) \
    $(proto_java_sources_file_stamp) \
    $(LOCAL_SRCJARS) \
    $(LOCAL_ADDITIONAL_DEPENDENCIES)

$(java_source_list_file): $(java_sources_deps)
	$(write-java-source-list)

$(full_classes_compiled_jar): PRIVATE_JAVA_LAYERS_FILE := $(layers_file)
$(full_classes_compiled_jar): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS) $(annotation_processor_flags)
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_FILES :=
$(full_classes_compiled_jar): PRIVATE_JAR_PACKAGES :=
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_PACKAGES :=
$(full_classes_compiled_jar): PRIVATE_SRCJARS := $(LOCAL_SRCJARS)
$(full_classes_compiled_jar): PRIVATE_SRCJAR_LIST_FILE := $(intermediates.COMMON)/srcjar-list
$(full_classes_compiled_jar): PRIVATE_SRCJAR_INTERMEDIATES_DIR := $(intermediates.COMMON)/srcjars
$(full_classes_compiled_jar): \
    $(java_source_list_file) \
    $(java_sources_deps) \
    $(full_java_header_libs) \
    $(full_java_bootclasspath_libs) \
    $(full_java_system_modules_deps) \
    $(annotation_processor_deps) \
    $(NORMALIZE_PATH) \
    $(JAR_ARGS) \
    $(ZIPSYNC) \
    | $(SOONG_JAVAC_WRAPPER)
	$(transform-host-java-to-dalvik-package)

ifneq ($(TURBINE_ENABLED),false)

$(full_classes_turbine_jar): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS) $(annotation_processor_flags)
$(full_classes_turbine_jar): PRIVATE_DONT_DELETE_JAR_META_INF := $(LOCAL_DONT_DELETE_JAR_META_INF)
$(full_classes_turbine_jar): PRIVATE_SRCJARS := $(LOCAL_SRCJARS)
$(full_classes_turbine_jar): \
    $(java_source_list_file) \
    $(java_sources_deps) \
    $(full_java_header_libs) \
    $(full_java_bootclasspath_libs) \
    $(NORMALIZE_PATH) \
    $(JAR_ARGS) \
    $(ZIPTIME) \
    | $(TURBINE) \
    $(MERGE_ZIPS)
	$(transform-java-to-header.jar)

.KATI_RESTAT: $(full_classes_turbine_jar)

# Run jarjar before generate classes-header.jar if necessary.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_header_jarjar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_header_jarjar): $(full_classes_turbine_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	@echo Header JarJar: $@
	$(hide) $(JAVA) -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
full_classes_header_jarjar := $(full_classes_turbine_jar)
endif

$(eval $(call copy-one-file,$(full_classes_header_jarjar),$(full_classes_header_jar)))

endif # TURBINE_ENABLED != false

$(full_classes_combined_jar): PRIVATE_DONT_DELETE_JAR_META_INF := $(LOCAL_DONT_DELETE_JAR_META_INF)
$(full_classes_combined_jar): $(full_classes_compiled_jar) \
                              $(jar_manifest_file) \
                              $(full_static_java_libs)  | $(MERGE_ZIPS)
	$(if $(PRIVATE_JAR_MANIFEST), $(hide) sed -e "s/%BUILD_NUMBER%/$(BUILD_NUMBER_FROM_FILE)/" \
            $(PRIVATE_JAR_MANIFEST) > $(dir $@)/manifest.mf)
	$(MERGE_ZIPS) -j --ignore-duplicates $(if $(PRIVATE_JAR_MANIFEST),-m $(dir $@)/manifest.mf) \
            $(if $(PRIVATE_DONT_DELETE_JAR_META_INF),,-stripDir META-INF -zipToNotStrip $<) \
            $@ $< $(call reverse-list,$(PRIVATE_STATIC_JAVA_LIBRARIES))

# Run jarjar if necessary, otherwise just copy the file.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_combined_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	@echo JarJar: $@
	$(hide) $(JAVA) -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
full_classes_jarjar_jar := $(full_classes_combined_jar)
endif

$(eval $(call copy-one-file,$(full_classes_jarjar_jar),$(full_classes_jar)))

ifneq ($(USE_D8_DESUGAR),true)
my_desugaring :=
ifeq ($(LOCAL_JAVA_LANGUAGE_VERSION),1.8)
my_desugaring := true
$(full_classes_desugar_jar): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)
$(full_classes_desugar_jar): $(full_classes_jar) $(full_java_header_libs) $(DESUGAR)
	$(desugar-classes-jar)
endif
else
my_desugaring :=
endif

ifndef my_desugaring
full_classes_desugar_jar := $(full_classes_jar)
endif

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# No dex; all we want are the .class files with resources.
$(LOCAL_BUILT_MODULE) : $(java_resource_sources)
$(LOCAL_BUILT_MODULE) : $(full_classes_jar)
	@echo "host Static Jar: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)

else # !LOCAL_IS_STATIC_JAVA_LIBRARY
$(built_dex): PRIVATE_INTERMEDIATES_DIR := $(intermediates.COMMON)
$(built_dex): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)
$(built_dex): $(full_classes_desugar_jar) $(DX) $(ZIP2ZIP)
ifneq ($(USE_D8_DESUGAR),true)
	$(transform-classes.jar-to-dex)
else
	$(transform-classes-d8.jar-to-dex)
endif

$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE): PRIVATE_SOURCE_ARCHIVE := $(full_classes_jarjar_jar)
$(LOCAL_BUILT_MODULE): PRIVATE_DONT_DELETE_JAR_DIRS := $(LOCAL_DONT_DELETE_JAR_DIRS)
$(LOCAL_BUILT_MODULE): $(built_dex) $(java_resource_sources)
	@echo "Host Jar: $(PRIVATE_MODULE) ($@)"
	$(call initialize-package-file,$(PRIVATE_SOURCE_ARCHIVE),$@)
	$(add-dex-to-package)

endif # !LOCAL_IS_STATIC_JAVA_LIBRARY

ifneq (,$(filter-out current system_current test_current core_current, $(LOCAL_SDK_VERSION)))
  my_default_app_target_sdk := $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION))
  my_sdk_version := $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION))
else
  my_default_app_target_sdk := $(DEFAULT_APP_TARGET_SDK)
  my_sdk_version := $(PLATFORM_SDK_VERSION)
endif

ifdef LOCAL_MIN_SDK_VERSION
  my_min_sdk_version := $(LOCAL_MIN_SDK_VERSION)
else
  my_min_sdk_version := $(call codename-or-sdk-to-sdk,$(my_default_app_target_sdk))
endif

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_DEFAULT_APP_TARGET_SDK := $(my_default_app_target_sdk)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SDK_VERSION := $(my_sdk_version)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_MIN_SDK_VERSION := $(my_min_sdk_version)

USE_CORE_LIB_BOOTCLASSPATH :=

endif
