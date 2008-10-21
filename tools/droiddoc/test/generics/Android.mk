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

LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES:=$(call all-subdir-java-files)

LOCAL_MODULE:=test_generics
LOCAL_DROIDDOC_OPTIONS:=\
        -stubs __test_generics__

LOCAL_DROIDDOC_CUSTOM_TEMPLATE_DIR:=tools/droiddoc/templates-google
LOCAL_DROIDDOC_CUSTOM_ASSET_DIR:=assets-google
LOCAL_MODULE_CLASS := JAVA_LIBRARIES

include $(BUILD_DROIDDOC)
