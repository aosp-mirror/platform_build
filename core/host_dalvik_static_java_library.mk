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
$(call record-module-type,HOST_DALVIK_STATIC_JAVA_LIBRARY)

#
# Rules for building a host dalvik static java library.
# These libraries will be compiled against libcore and not the host
# JRE.
#
LOCAL_UNINSTALLABLE_MODULE := true
LOCAL_IS_STATIC_JAVA_LIBRARY := true

include $(BUILD_SYSTEM)/host_dalvik_java_library.mk

LOCAL_IS_STATIC_JAVA_LIBRARY :=
