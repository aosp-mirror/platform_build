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

#
# Rules for building a host dalvik static java library.
# These libraries will be compiled against libcore and not the host
# JRE.
#
ifeq ($(HOST_OS),linux)

LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_IS_STATIC_JAVA_LIBRARY := true
USE_CORE_LIB_BOOTCLASSPATH := true
LOCAL_JAVA_LIBRARIES += core-libart-hostdex

intermediates.COMMON := $(call intermediates-dir-for,JAVA_LIBRARIES,$(LOCAL_MODULE),true,COMMON,)
full_classes_jack := $(intermediates.COMMON)/classes.jack
LOCAL_INTERMEDIATE_TARGETS += \
    $(full_classes_jack)

include $(BUILD_SYSTEM)/host_java_library.mk
# proguard is not supported
# *.proto files are not supported
$(full_classes_jack): PRIVATE_JACK_FLAGS := $(LOCAL_JACK_FLAGS)
$(full_classes_jack): PRIVATE_JARJAR_RULES := $(LOCAL_JARJAR_RULES)
$(full_classes_jack): \
	PRIVATE_JACK_INTERMEDIATES_DIR := $(intermediates.COMMON)/jack-rsc
ifeq ($(LOCAL_JACK_ENABLED),incremental)
$(full_classes_jack): \
	PRIVATE_JACK_INCREMENTAL_DIR := $(intermediates.COMMON)/jack-incremental
else
$(full_classes_jack): \
	PRIVATE_JACK_INCREMENTAL_DIR :=
endif
$(full_classes_jack): $(java_sources) $(java_resource_sources) $(full_jack_lib_deps) \
        $(jar_manifest_file) $(layers_file) $(LOCAL_MODULE_MAKEFILE) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES) $(LOCAL_JARJAR_RULES) \
        $(JACK_JAR) $(JACK_LAUNCHER_JAR)
	@echo Building with Jack: $@
	$(java-to-jack)

USE_CORE_LIB_BOOTCLASSPATH :=
LOCAL_IS_STATIC_JAVA_LIBRARY :=
endif
