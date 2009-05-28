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

ifneq ($(TARGET_SIMULATOR),true)

LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES := applypatch.c bsdiff.c freecache.c imgpatch.c
LOCAL_MODULE := applypatch
LOCAL_FORCE_STATIC_EXECUTABLE := true
LOCAL_MODULE_TAGS := eng
LOCAL_C_INCLUDES += external/bzip2 external/zlib
LOCAL_STATIC_LIBRARIES += libmincrypt libbz libz libc

include $(BUILD_EXECUTABLE)

include $(CLEAR_VARS)

LOCAL_SRC_FILES := imgdiff.c
LOCAL_MODULE := imgdiff
LOCAL_FORCE_STATIC_EXECUTABLE := true
LOCAL_MODULE_TAGS := eng
LOCAL_C_INCLUDES += external/zlib
LOCAL_STATIC_LIBRARIES += libz

include $(BUILD_HOST_EXECUTABLE)

endif  # !TARGET_SIMULATOR
