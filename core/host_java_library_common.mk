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
# Common rules for building a host java library.
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
    ifneq ($(filter host-libprotobuf-java-2.3.0-micro,$(LOCAL_JAVA_LIBRARIES)),)
        $(warning Stripping unneeded dependency on host-libprotobuf-java-2.3.0-micro in $(LOCAL_MODULE))
        LOCAL_JAVA_LIBRARIES := $(filter-out host-libprotobuf-java-2.3.0-micro,$(LOCAL_JAVA_LIBRARIES))
    endif
    LOCAL_JAVA_LIBRARIES += host-libprotobuf-java-micro
else
  ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nano)
    ifneq ($(filter host-libprotobuf-java-2.3.0-nano,$(LOCAL_JAVA_LIBRARIES)),)
        $(warning Stripping unneeded dependency on host-libprotobuf-java-2.3.0-nano in $(LOCAL_MODULE))
        LOCAL_JAVA_LIBRARIES := $(filter-out host-libprotobuf-java-2.3.0-nano,$(LOCAL_JAVA_LIBRARIES))
    endif
    LOCAL_JAVA_LIBRARIES += host-libprotobuf-java-nano
  else
    ifneq ($(filter host-libprotobuf-java-2.3.0-lite,$(LOCAL_JAVA_LIBRARIES)),)
        $(warning Stripping unneeded dependency on host-libprotobuf-java-2.3.0-lite in $(LOCAL_MODULE))
        LOCAL_JAVA_LIBRARIES := $(filter-out host-libprotobuf-java-2.3.0-lite,$(LOCAL_JAVA_LIBRARIES))
    endif
    LOCAL_JAVA_LIBRARIES += host-libprotobuf-java-lite
  endif
endif
endif

intermediates := $(call local-intermediates-dir)
intermediates.COMMON := $(call local-intermediates-dir,COMMON)

LOCAL_INTERMEDIATE_SOURCE_DIR := $(intermediates.COMMON)/src
LOCAL_JAVA_LIBRARIES := $(sort $(LOCAL_JAVA_LIBRARIES))

