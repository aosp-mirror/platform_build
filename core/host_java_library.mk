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
java_source_list_file := $(intermediates.COMMON)/java-source-list
full_classes_header_jar := $(intermediates.COMMON)/classes-header.jar
full_classes_combined_jar := $(intermediates.COMMON)/classes-combined.jar

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_compiled_jar) \
    $(full_classes_jarjar_jar) \
    $(java_source_list_file) \
    $(full_classes_combined_jar)

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

java_sources := $(addprefix $(LOCAL_PATH)/, $(filter %.java,$(LOCAL_SRC_FILES))) \
                $(filter %.java,$(LOCAL_GENERATED_SOURCES))
all_java_sources := $(java_sources)

include $(BUILD_SYSTEM)/java_common.mk

# The layers file allows you to enforce a layering between java packages.
# Run build/make/tools/java-layers.py for more details.
layers_file := $(addprefix $(LOCAL_PATH)/, $(LOCAL_JAVA_LAYERS_FILE))

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
    $(full_java_libs) \
    $(full_java_bootclasspath_libs) \
    $(annotation_processor_deps) \
    $(NORMALIZE_PATH) \
    $(ZIPTIME) \
    $(JAR_ARGS) \
    $(ZIPSYNC) \
    | $(SOONG_JAVAC_WRAPPER)
	$(transform-host-java-to-package)
	$(remove-timestamps-from-package)

javac-check : $(full_classes_compiled_jar)
javac-check-$(LOCAL_MODULE) : $(full_classes_compiled_jar)
.PHONY: javac-check-$(LOCAL_MODULE)

$(full_classes_combined_jar): $(full_classes_compiled_jar) \
                              $(jar_manifest_file) \
                              $(full_static_java_libs) | $(MERGE_ZIPS)
	$(if $(PRIVATE_JAR_MANIFEST), $(hide) sed -e "s/%BUILD_NUMBER%/$(BUILD_NUMBER_FROM_FILE)/" \
            $(PRIVATE_JAR_MANIFEST) > $(dir $@)/manifest.mf)
	$(MERGE_ZIPS) -j --ignore-duplicates $(if $(PRIVATE_JAR_MANIFEST),-m $(dir $@)/manifest.mf) \
            -stripDir META-INF -zipToNotStrip $< $@ $< $(call reverse-list,$(PRIVATE_STATIC_JAVA_LIBRARIES))

# Run jarjar if necessary, otherwise just copy the file.
ifneq ($(strip $(LOCAL_JARJAR_RULES)),)
$(full_classes_jarjar_jar): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jarjar_jar): $(full_classes_combined_jar) $(LOCAL_JARJAR_RULES) | $(JARJAR)
	@echo JarJar: $@
	$(hide) $(JAVA) -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
else
full_classes_jarjar_jar := $(full_classes_combined_jar)
endif


#######################################
LOCAL_FULL_CLASSES_PRE_JACOCO_JAR := $(full_classes_jarjar_jar)

include $(BUILD_SYSTEM)/jacoco.mk
#######################################

$(eval $(call copy-one-file,$(LOCAL_FULL_CLASSES_JACOCO_JAR),$(LOCAL_BUILT_MODULE)))
$(eval $(call copy-one-file,$(LOCAL_FULL_CLASSES_JACOCO_JAR),$(full_classes_jar)))

ifeq ($(TURBINE_ENABLED),false)
$(eval $(call copy-one-file,$(LOCAL_FULL_CLASSES_JACOCO_JAR),$(full_classes_header_jar)))
endif
