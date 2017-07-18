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

#################################
include $(BUILD_SYSTEM)/configure_local_jack.mk
#################################

#######################################
include $(BUILD_SYSTEM)/host_java_library_common.mk
#######################################
ifdef LOCAL_JACK_ENABLED
ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
  # For static library, $(LOCAL_BUILT_MODULE) is $(full_classes_jack).
  LOCAL_BUILT_MODULE_STEM := classes.jack
endif
endif

ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
  LOCAL_JAVA_LIBRARIES :=  core-oj-hostdex core-libart-hostdex $(LOCAL_JAVA_LIBRARIES)
endif

full_classes_compiled_jar := $(intermediates.COMMON)/classes-full-debug.jar
full_classes_desugar_jar := $(intermediates.COMMON)/desugar.classes.jar
full_classes_jarjar_jar := $(intermediates.COMMON)/classes-jarjar.jar
full_classes_jar := $(intermediates.COMMON)/classes.jar
full_classes_jack := $(intermediates.COMMON)/classes.jack
jack_check_timestamp := $(intermediates.COMMON)/jack.check.timestamp
built_dex := $(intermediates.COMMON)/classes.dex

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_compiled_jar) \
    $(full_classes_desugar_jar) \
    $(full_classes_jarjar_jar) \
    $(full_classes_jack) \
    $(full_classes_jar) \
    $(jack_check_timestamp) \
    $(built_dex)

# See comment in java.mk
ifndef LOCAL_CHECKED_MODULE
ifdef LOCAL_JACK_ENABLED
LOCAL_CHECKED_MODULE := $(jack_check_timestamp)
else
ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
LOCAL_CHECKED_MODULE := $(full_classes_compiled_jar)
else
LOCAL_CHECKED_MODULE := $(built_dex)
endif
endif
endif

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################
java_sources := $(addprefix $(LOCAL_PATH)/, $(filter %.java,$(LOCAL_SRC_FILES))) \
                $(filter %.java,$(LOCAL_GENERATED_SOURCES))
all_java_sources := $(java_sources)

include $(BUILD_SYSTEM)/java_common.mk

$(cleantarget): PRIVATE_CLEAN_FILES += $(intermediates.COMMON)

ifndef LOCAL_JACK_ENABLED

$(full_classes_compiled_jar): PRIVATE_JAVA_LAYERS_FILE := $(layers_file)
$(full_classes_compiled_jar): PRIVATE_JAVACFLAGS := $(GLOBAL_JAVAC_DEBUG_FLAGS) $(LOCAL_JAVACFLAGS) $(annotation_processor_flags)
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_FILES :=
$(full_classes_compiled_jar): PRIVATE_JAR_PACKAGES :=
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_PACKAGES :=
$(full_classes_compiled_jar): \
        $(java_sources) \
        $(java_resource_sources) \
        $(full_java_lib_deps) \
        $(jar_manifest_file) \
        $(proto_java_sources_file_stamp) \
        $(annotation_processor_deps) \
        $(NORMALIZE_PATH) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES) \
        | $(SOONG_JAVAC_WRAPPER)
	$(transform-host-java-to-package)

my_desugaring :=
ifeq ($(LOCAL_JAVA_LANGUAGE_VERSION),1.8)
my_desugaring := true
$(full_classes_desugar_jar): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)
$(full_classes_desugar_jar): $(full_classes_compiled_jar) $(DESUGAR)
	$(desugar-classes-jar)
endif

ifndef my_desugaring
full_classes_desugar_jar := $(full_classes_compiled_jar)
endif

# Run jarjar if necessary, otherwise just copy the file.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_desugar_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	@echo JarJar: $@
	$(hide) $(JAVA) -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
full_classes_jarjar_jar := $(full_classes_desugar_jar)
endif

$(eval $(call copy-one-file,$(full_classes_jarjar_jar),$(full_classes_jar)))

ifeq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
# No dex; all we want are the .class files with resources.
$(LOCAL_BUILT_MODULE) : $(java_resource_sources)
$(LOCAL_BUILT_MODULE) : $(full_classes_jar)
	@echo "host Static Jar: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)

else # !LOCAL_IS_STATIC_JAVA_LIBRARY
$(built_dex): PRIVATE_INTERMEDIATES_DIR := $(intermediates.COMMON)
$(built_dex): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)
$(built_dex): $(full_classes_jar) $(DX)
	$(transform-classes.jar-to-dex)

$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE): PRIVATE_SOURCE_ARCHIVE := $(full_classes_jarjar_jar)
$(LOCAL_BUILT_MODULE): PRIVATE_DONT_DELETE_JAR_DIRS := $(LOCAL_DONT_DELETE_JAR_DIRS)
$(LOCAL_BUILT_MODULE): $(built_dex) $(java_resource_sources)
	@echo "Host Jar: $(PRIVATE_MODULE) ($@)"
	$(call initialize-package-file,$(PRIVATE_SOURCE_ARCHIVE),$@)
	$(add-dex-to-package)

endif # !LOCAL_IS_STATIC_JAVA_LIBRARY

ifneq (,$(filter-out current system_current test_current, $(LOCAL_SDK_VERSION)))
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_DEFAULT_APP_TARGET_SDK := $(LOCAL_SDK_VERSION)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SDK_VERSION := $(LOCAL_SDK_VERSION)
else
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_DEFAULT_APP_TARGET_SDK := $(DEFAULT_APP_TARGET_SDK)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SDK_VERSION := $(PLATFORM_SDK_VERSION)
endif

else # LOCAL_JACK_ENABLED
$(LOCAL_INTERMEDIATE_TARGETS): \
  PRIVATE_JACK_INTERMEDIATES_DIR := $(intermediates.COMMON)/jack-rsc

ifeq ($(LOCAL_JACK_ENABLED),incremental)
$(LOCAL_INTERMEDIATE_TARGETS): \
  PRIVATE_JACK_INCREMENTAL_DIR := $(intermediates.COMMON)/jack-incremental
else
$(LOCAL_INTERMEDIATE_TARGETS): \
  PRIVATE_JACK_INCREMENTAL_DIR :=
endif
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JACK_FLAGS := $(GLOBAL_JAVAC_DEBUG_FLAGS) $(LOCAL_JACK_FLAGS)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JACK_VERSION := $(LOCAL_JACK_VERSION)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JACK_MIN_SDK_VERSION := $(PLATFORM_JACK_MIN_SDK_VERSION)

jack_all_deps := $(java_sources) $(java_resource_sources) $(full_jack_deps) \
        $(jar_manifest_file) $(proto_java_sources_file_stamp) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES) $(NORMALIZE_PATH) $(JACK_DEFAULT_ARGS) $(JACK)

ifneq ($(LOCAL_IS_STATIC_JAVA_LIBRARY),true)
$(built_dex): PRIVATE_CLASSES_JACK := $(full_classes_jack)
$(built_dex): PRIVATE_JACK_PLUGIN_PATH := $(LOCAL_JACK_PLUGIN_PATH)
$(built_dex): PRIVATE_JACK_PLUGIN := $(LOCAL_JACK_PLUGIN)
$(built_dex): $(jack_all_deps) $(LOCAL_JACK_PLUGIN_PATH) | setup-jack-server
	@echo Building with Jack: $@
	$(jack-java-to-dex)

# $(full_classes_jack) is just by-product of $(built_dex).
# The dummy command was added because, without it, make misses the fact the $(built_dex) also
# change $(full_classes_jack).
$(full_classes_jack): $(built_dex)
	$(hide) touch $@

$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE): $(built_dex) $(java_resource_sources)
	@echo "Host Jar: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-dex-to-package)
	$(add-carried-jack-resources)

else  # LOCAL_IS_STATIC_JAVA_LIBRARY
$(full_classes_jack): PRIVATE_JACK_PLUGIN_PATH := $(LOCAL_JACK_PLUGIN_PATH)
$(full_classes_jack): PRIVATE_JACK_PLUGIN := $(LOCAL_JACK_PLUGIN)
$(full_classes_jack): $(jack_all_deps) $(LOCAL_JACK_PLUGIN_PATH) | setup-jack-server
	@echo Building with Jack: $@
	$(java-to-jack)

endif  # LOCAL_IS_STATIC_JAVA_LIBRARY

$(jack_check_timestamp): $(jack_all_deps) | setup-jack-server
	@echo Checking build with Jack: $@
	$(jack-check-java)
endif # LOCAL_JACK_ENABLED

USE_CORE_LIB_BOOTCLASSPATH :=

endif
