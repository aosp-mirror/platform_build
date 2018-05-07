#
# Copyright (C) 2018 The Android Open Source Project
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

###########################################################
## Rules for resolving Support Library dependencies.
##
## The following variables may be modified:
## - LOCAL_JAVA_LIBRARIES
## - LOCAL_STATIC_JAVA_LIBRARIES
## - LOCAL_SHARED_ANDROID_LIBRARIES
## - LOCAL_STATIC_ANDROID_LIBRARIES
###########################################################

# Some projects don't work correctly yet. Allow them to skip resolution.
ifndef LOCAL_DISABLE_RESOLVE_SUPPORT_LIBRARIES

# Aggregate all requested Support Library modules.
requested_support_libs := $(filter $(SUPPORT_LIBRARIES_JARS) $(SUPPORT_LIBRARIES_AARS), \
    $(LOCAL_JAVA_LIBRARIES) $(LOCAL_STATIC_JAVA_LIBRARIES) \
    $(LOCAL_SHARED_ANDROID_LIBRARIES) $(LOCAL_STATIC_ANDROID_LIBRARIES))

# Filter the Support Library modules out of the library variables. We don't
# trust developers to get these right, so they will be added back by the
# build system based on the output of this file and the type of build.
LOCAL_JAVA_LIBRARIES := $(filter-out $(requested_support_libs), \
    $(LOCAL_JAVA_LIBRARIES))
LOCAL_STATIC_JAVA_LIBRARIES := $(filter-out $(requested_support_libs), \
    $(LOCAL_STATIC_JAVA_LIBRARIES))
LOCAL_SHARED_ANDROID_LIBRARIES := $(filter-out $(requested_support_libs), \
    $(LOCAL_SHARED_ANDROID_LIBRARIES))
LOCAL_STATIC_ANDROID_LIBRARIES := $(filter-out $(requested_support_libs), \
    $(LOCAL_STATIC_ANDROID_LIBRARIES))

LOCAL_STATIC_ANDROID_LIBRARIES := $(strip $(LOCAL_STATIC_ANDROID_LIBRARIES) \
    $(filter $(SUPPORT_LIBRARIES_AARS),$(requested_support_libs)))
LOCAL_STATIC_JAVA_LIBRARIES := $(strip $(LOCAL_STATIC_JAVA_LIBRARIES) \
    $(filter $(SUPPORT_LIBRARIES_JARS),$(requested_support_libs)))

endif #LOCAL_DISABLE_RESOLVE_SUPPORT_LIBRARIES
LOCAL_DISABLE_RESOLVE_SUPPORT_LIBRARIES :=
