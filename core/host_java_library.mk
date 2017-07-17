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

$(call record-module-type,HOST_JAVA_LIBRARY)

#
# Standard rules for building a host java library.
#

#######################################
include $(BUILD_SYSTEM)/host_java_library_common.mk
#######################################

# Enable emma instrumentation only if the module asks so.
ifeq (true,$(LOCAL_EMMA_INSTRUMENT))
ifneq (true,$(EMMA_INSTRUMENT))
LOCAL_EMMA_INSTRUMENT :=
endif
endif

full_classes_compiled_jar := $(intermediates.COMMON)/classes-full-debug.jar
full_classes_jarjar_jar := $(intermediates.COMMON)/classes-jarjar.jar
full_classes_jar := $(intermediates.COMMON)/classes.jar

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_compiled_jar) \
    $(full_classes_jarjar_jar) \

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

java_sources := $(addprefix $(LOCAL_PATH)/, $(filter %.java,$(LOCAL_SRC_FILES))) \
                $(filter %.java,$(LOCAL_GENERATED_SOURCES))
all_java_sources := $(java_sources)

include $(BUILD_SYSTEM)/java_common.mk

# The layers file allows you to enforce a layering between java packages.
# Run build/tools/java-layers.py for more details.
layers_file := $(addprefix $(LOCAL_PATH)/, $(LOCAL_JAVA_LAYERS_FILE))

# If error prone is enabled then add LOCAL_ERROR_PRONE_FLAGS to LOCAL_JAVACFLAGS
ifeq ($(RUN_ERROR_PRONE),true)
LOCAL_JAVACFLAGS += $(LOCAL_ERROR_PRONE_FLAGS)
endif

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
        $(ZIPTIME) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES) \
        | $(SOONG_JAVAC_WRAPPER)
	$(transform-host-java-to-package)
	$(remove-timestamps-from-package)

javac-check : $(full_classes_compiled_jar)
javac-check-$(LOCAL_MODULE) : $(full_classes_compiled_jar)

# Run jarjar if necessary, otherwise just copy the file.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_compiled_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	@echo JarJar: $@
	$(hide) $(JAVA) -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
full_classes_jarjar_jar := $(full_classes_compiled_jar)
endif


LOCAL_FULL_CLASSES_PRE_JACOCO_JAR := $(full_classes_jarjar_jar)

#######################################
include $(BUILD_SYSTEM)/jacoco.mk
#######################################

$(eval $(call copy-one-file,$(LOCAL_FULL_CLASSES_JACOCO_JAR),$(LOCAL_BUILT_MODULE)))
$(eval $(call copy-one-file,$(LOCAL_FULL_CLASSES_JACOCO_JAR),$(full_classes_jar)))

