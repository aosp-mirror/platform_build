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
emma_intermediates_dir := $(intermediates.COMMON)/emma_out
# emma is hardcoded to use the leaf name of its input for the output file --
# only the output directory can be changed
full_classes_emma_jar := $(emma_intermediates_dir)/lib/$(notdir $(full_classes_compiled_jar))

LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_compiled_jar) \
    $(full_classes_emma_jar)

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

ifeq (true,$(LOCAL_EMMA_INSTRUMENT))
$(full_classes_emma_jar): PRIVATE_EMMA_COVERAGE_FILE := $(intermediates.COMMON)/coverage.em
$(full_classes_emma_jar): PRIVATE_EMMA_INTERMEDIATES_DIR := $(emma_intermediates_dir)
ifdef LOCAL_EMMA_COVERAGE_FILTER
$(full_classes_emma_jar): PRIVATE_EMMA_COVERAGE_FILTER := $(LOCAL_EMMA_COVERAGE_FILTER)
else
# by default, avoid applying emma instrumentation onto emma classes itself,
# otherwise there will be exceptions thrown
$(full_classes_emma_jar): PRIVATE_EMMA_COVERAGE_FILTER := *,-emma,-emmarun,-com.vladium.*
endif
# this rule will generate both $(PRIVATE_EMMA_COVERAGE_FILE) and
# $(full_classes_emma_jar)
$(full_classes_emma_jar) : $(full_classes_compiled_jar) | $(EMMA_JAR)
	$(transform-classes.jar-to-emma)

$(LOCAL_BUILT_MODULE) : $(full_classes_emma_jar)
	@echo Copying: $@
	$(hide) $(ACP) -fp $< $@

else # LOCAL_EMMA_INSTRUMENT
# Directly build into LOCAL_BUILT_MODULE.
full_classes_compiled_jar := $(LOCAL_BUILT_MODULE)
endif # LOCAL_EMMA_INSTRUMENT

$(full_classes_compiled_jar): PRIVATE_JAVAC_DEBUG_FLAGS := -g

# The layers file allows you to enforce a layering between java packages.
# Run build/tools/java-layers.py for more details.
layers_file := $(addprefix $(LOCAL_PATH)/, $(LOCAL_JAVA_LAYERS_FILE))

$(full_classes_compiled_jar): PRIVATE_JAVA_LAYERS_FILE := $(layers_file)
$(full_classes_compiled_jar): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS)
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_FILES :=
$(full_classes_compiled_jar): PRIVATE_JAR_PACKAGES :=
$(full_classes_compiled_jar): PRIVATE_JAR_EXCLUDE_PACKAGES :=
$(full_classes_compiled_jar): PRIVATE_RMTYPEDEFS :=
$(full_classes_compiled_jar): $(java_sources) $(java_resource_sources) $(full_java_lib_deps) \
		$(jar_manifest_file) $(proto_java_sources_file_stamp) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-host-java-to-package)
