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

# Including this makefile will force AAPT2 on,
# rewriting some properties to convert standard AAPT usage to AAPT2.

ifeq ($(LOCAL_USE_AAPT2),false)
  $(call pretty-error, LOCAL_USE_AAPT2 := false is no longer supported)
endif

# Filter out support library resources
LOCAL_RESOURCE_DIR := $(filter-out \
  prebuilts/sdk/current/% \
  frameworks/support/%,\
    $(LOCAL_RESOURCE_DIR))
# Filter out unnecessary aapt flags
ifneq (,$(filter --extra-packages,$(LOCAL_AAPT_FLAGS)))
  LOCAL_AAPT_FLAGS := $(subst --extra-packages=,--extra-packages$(space), \
    $(filter-out \
      --extra-packages=android.support.% \
      --extra-packages=androidx.%, \
        $(subst --extra-packages$(space),--extra-packages=,$(LOCAL_AAPT_FLAGS))))
    ifeq (,$(filter --extra-packages,$(LOCAL_AAPT_FLAGS)))
      LOCAL_AAPT_FLAGS := $(filter-out --auto-add-overlay,$(LOCAL_AAPT_FLAGS))
    endif
endif

# AAPT2 is pickier about missing resources.  Support library may have references to resources
# added in current, so always treat LOCAL_SDK_VERSION := <number> as LOCAL_SDK_RES_VERSION := current.
ifneq (,$(filter-out current system_current test_current core_current,$(LOCAL_SDK_VERSION)))
  LOCAL_SDK_RES_VERSION := current
endif

