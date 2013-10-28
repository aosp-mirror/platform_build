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
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

$(full_classes_compiled_jar): PRIVATE_JAVAC_DEBUG_FLAGS := -g

java_alternative_checked_module :=

# The layers file allows you to enforce a layering between java packages.
# Run build/tools/java-layers.py for more details.
layers_file := $(addprefix $(LOCAL_PATH)/, $(LOCAL_JAVA_LAYERS_FILE))

$(LOCAL_BUILT_MODULE): PRIVATE_JAVA_LAYERS_FILE := $(layers_file)
$(LOCAL_BUILT_MODULE): PRIVATE_JAVACFLAGS := $(LOCAL_JAVACFLAGS)
$(LOCAL_BUILT_MODULE): PRIVATE_JAR_EXCLUDE_FILES :=
$(LOCAL_BUILT_MODULE): PRIVATE_JAVA_LAYERS_FILE := $(layers_file)
$(LOCAL_BUILT_MODULE): $(java_sources) $(java_resource_sources) $(full_java_lib_deps) \
		$(jar_manifest_file) $(proto_java_sources_file_stamp) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-host-java-to-package)
