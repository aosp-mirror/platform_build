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

#
# Standard rules for building a host java library.
#

LOCAL_MODULE_CLASS := JAVA_LIBRARIES
LOCAL_MODULE_SUFFIX := $(COMMON_JAVA_PACKAGE_SUFFIX)
LOCAL_IS_HOST_MODULE := true
LOCAL_BUILT_MODULE_STEM := javalib.jar

# base_rules.mk looks at this
all_res_assets :=

proto_sources := $(filter %.proto,$(LOCAL_SRC_FILES))
ifneq ($(proto_sources),)
ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),micro)
    LOCAL_JAVA_LIBRARIES += host-libprotobuf-java-2.3.0-micro
else
  ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nano)
    LOCAL_JAVA_LIBRARIES += host-libprotobuf-java-2.3.0-nano
  else
    LOCAL_JAVA_LIBRARIES += host-libprotobuf-java-2.3.0-lite
  endif
endif
endif

intermediates := $(call local-intermediates-dir)
intermediates.COMMON := $(call local-intermediates-dir,COMMON)

LOCAL_INTERMEDIATE_SOURCE_DIR := $(intermediates.COMMON)/src

ifeq ($(LOCAL_BUILD_HOST_DEX),true)
ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
  LOCAL_JAVA_LIBRARIES +=  core-hostdex
endif

full_classes_compiled_jar := $(intermediates.COMMON)/classes-full-debug.jar
full_classes_jarjar_jar := $(intermediates.COMMON)/classes-jarjar.jar
full_classes_jar := $(intermediates.COMMON)/classes.jar
built_dex := $(intermediates.COMMON)/classes.dex

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_compiled_jar) \
    $(full_classes_jarjar_jar) \
    $(full_classes_jar) \
    $(built_dex)

# See comment in java.mk
java_alternative_checked_module := $(full_classes_compiled_jar)
endif # LOCAL_BUILD_HOST_DEX

LOCAL_JAVA_LIBRARIES := $(sort $(LOCAL_JAVA_LIBRARIES))

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

$(full_classes_compiled_jar): PRIVATE_JAVAC_DEBUG_FLAGS := -g

java_alternative_checked_module :=

# The layers file allows you to enforce a layering between java packages.
# Run build/tools/java-layers.py for more details.
layers_file := $(addprefix $(LOCAL_PATH)/, $(LOCAL_JAVA_LAYERS_FILE))

ifeq ($(LOCAL_BUILD_HOST_DEX),true)
$(LOCAL_INTERMEDIATE_TARGETS): \
	PRIVATE_CLASS_INTERMEDIATES_DIR := $(intermediates.COMMON)/classes
$(LOCAL_INTERMEDIATE_TARGETS): \
	PRIVATE_SOURCE_INTERMEDIATES_DIR := $(LOCAL_INTERMEDIATE_SOURCE_DIR)

$(cleantarget): PRIVATE_CLEAN_FILES += $(intermediates.COMMON)

$(full_classes_compiled_jar): PRIVATE_JAVA_LAYERS_FILE := $(layers_file)
$(full_classes_compiled_jar): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS)
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_FILES :=
$(full_classes_compiled_jar): $(java_sources) $(java_resource_sources) $(full_java_lib_deps) \
        $(jar_manifest_file) $(proto_java_sources_file_stamp) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-host-java-to-package)

# Run jarjar if necessary, otherwise just copy the file.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_compiled_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	@echo JarJar: $@
	$(hide) java -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
$(full_classes_jarjar_jar): $(full_classes_compiled_jar) | $(ACP)
	@echo Copying: $@
	$(hide) $(ACP) -fp $< $@
endif

$(full_classes_jar): $(full_classes_jarjar_jar) | $(ACP)
	@echo Copying: $@
	$(hide) $(ACP) -fp $< $@

$(built_dex): PRIVATE_INTERMEDIATES_DIR := $(intermediates.COMMON)
$(built_dex): PRIVATE_DX_FLAGS := $(LOCAL_DX_FLAGS)
$(built_dex): $(full_classes_jar) $(DX)
	$(transform-classes.jar-to-dex)

$(LOCAL_BUILT_MODULE): PRIVATE_DEX_FILE := $(built_dex)
$(LOCAL_BUILT_MODULE): $(built_dex) $(java_resource_sources)
	@echo "Host Jar: $(PRIVATE_MODULE) ($@)"
	$(create-empty-package)
	$(add-dex-to-package)
	$(add-carried-java-resources)
ifneq ($(extra_jar_args),)
	$(add-java-resources-to-package)
endif

else
$(LOCAL_BUILT_MODULE): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS)
$(LOCAL_BUILT_MODULE): PRIVATE_JAR_EXCLUDE_FILES :=
$(LOCAL_BUILT_MODULE): PRIVATE_JAVA_LAYERS_FILE := $(layers_file)
$(LOCAL_BUILT_MODULE): $(java_sources) $(java_resource_sources) $(full_java_lib_deps) \
		$(jar_manifest_file) $(proto_java_sources_file_stamp) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-host-java-to-package)
endif  # LOCAL_BUILD_HOST_DEX
