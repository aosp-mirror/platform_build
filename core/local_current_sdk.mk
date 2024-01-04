#
# Copyright (C) 2020 The Android Open Source Project
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
ifdef BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES
  _override_to := $(BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES)

  # b/314011075: apks and jars in the vendor or odm partitions cannot use
  # system SDK 35 and beyond. In order not to suddenly break those vendor
  # modules using current or system_current as their LOCAL_SDK_VERSION,
  # override it to 34, which is the maximum API level allowed for them.
  ifneq (,$(filter JAVA_LIBRARIES APPS,$(LOCAL_MODULE_CLASS)))
    _override_to := 34
  endif

  ifneq (current,$(_override_to))
    ifneq (,$(filter true,$(LOCAL_VENDOR_MODULE) $(LOCAL_ODM_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
      ifeq (current,$(LOCAL_SDK_VERSION))
        LOCAL_SDK_VERSION := $(_override_to)
      else ifeq (system_current,$(LOCAL_SDK_VERSION))
        LOCAL_SDK_VERSION := system_$(_override_to)
      endif
    endif
  endif
  _override_to :=
endif
