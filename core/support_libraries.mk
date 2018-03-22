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

# Clear these out so we don't accidentally get old values.
support_android_deps :=
support_java_deps :=

# Delegate dependency expansion to the Support Library's rules. This will store
# its output in the variables support_android_deps and support_java_deps.
include $(RESOLVE_SUPPORT_LIBRARIES)

# Everything is static, which simplifies resource handling. Don't write to any
# vars unless we actually have data, since even an empty ANDROID_LIBRARIES var
# requires an AndroidManifest.xml file!
ifdef support_android_deps
    LOCAL_STATIC_ANDROID_LIBRARIES += $(support_android_deps)
endif #support_android_deps
ifdef support_java_deps
    LOCAL_STATIC_JAVA_LIBRARIES += $(support_java_deps)
endif #support_java_deps

# We have consumed these values. Clean them up.
support_android_deps :=
support_java_deps :=

endif #LOCAL_DISABLE_RESOLVE_SUPPORT_LIBRARIES
LOCAL_DISABLE_RESOLVE_SUPPORT_LIBRARIES :=
