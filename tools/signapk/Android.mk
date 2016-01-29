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
LOCAL_PATH := $(call my-dir)

# the signapk tool (a .jar application used to sign packages)
# ============================================================
include $(CLEAR_VARS)
LOCAL_MODULE := signapk
LOCAL_SRC_FILES := $(call all-java-files-under, src)
LOCAL_JAR_MANIFEST := SignApk.mf
LOCAL_STATIC_JAVA_LIBRARIES := bouncycastle-host bouncycastle-bcpkix-host conscrypt-host
LOCAL_REQUIRED_MODULES := libconscrypt_openjdk_jni
include $(BUILD_HOST_JAVA_LIBRARY)

ifeq ($(TARGET_BUILD_APPS),)
ifeq ($(BRILLO),)
# The post-build signing tools need signapk.jar and its shared libraries,
# but we don't need this if we're just doing unbundled apps.
my_dist_files := $(LOCAL_INSTALLED_MODULE) \
    $(HOST_OUT_SHARED_LIBRARIES)/libconscrypt_openjdk_jni$(HOST_SHLIB_SUFFIX)

$(call dist-for-goals,droidcore,$(my_dist_files))
my_dist_files :=
endif
endif
