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

ifdef BOARD_SYSTEMSDK_VERSIONS
  # Apps and jars in vendor, product or odm partition are forced to build against System SDK.
  _cannot_use_platform_apis :=
  ifneq (,$(filter true,$(LOCAL_VENDOR_MODULE) $(LOCAL_ODM_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
    # Note: no need to check LOCAL_MODULE_PATH* since LOCAL_[VENDOR|ODM|OEM]_MODULE is already
    # set correctly before this is included.
    _cannot_use_platform_apis := true
  else ifeq ($(LOCAL_PRODUCT_MODULE),true)
    ifeq ($(PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE),true)
      _cannot_use_platform_apis := true
    endif
  endif
  ifneq (,$(filter JAVA_LIBRARIES APPS,$(LOCAL_MODULE_CLASS)))
    ifndef LOCAL_SDK_VERSION
      ifeq ($(_cannot_use_platform_apis),true)
        ifeq (,$(LOCAL_IS_RUNTIME_RESOURCE_OVERLAY))
          # Runtime resource overlays are exempted from building against System SDK.
          # TODO(b/155027019): remove this, after no product/vendor apps rely on this behavior.
          LOCAL_SDK_VERSION := system_current
        endif
      endif
    endif
  endif
endif

# Ensure that the selected System SDK version is one of the supported versions.
# The range of support versions becomes narrower when BOARD_SYSTEMSDK_VERSIONS
# is set, which is a subset of PLATFORM_SYSTEMSDK_VERSIONS.
ifneq (,$(call has-system-sdk-version,$(LOCAL_SDK_VERSION)))
  ifneq ($(_cannot_use_platform_apis),true)
    # apps bundled in system partition can use all system sdk versions provided by the platform
    _supported_systemsdk_versions := $(PLATFORM_SYSTEMSDK_VERSIONS)
  else ifdef BOARD_SYSTEMSDK_VERSIONS
    # When BOARD_SYSTEMSDK_VERSIONS is set, vendors apps are restricted to use those versions
    # which is equal to or smaller than PLATFORM_SYSTEMSDK_VERSIONS
    _supported_systemsdk_versions := $(BOARD_SYSTEMSDK_VERSIONS)
  else
    # If not, vendor apks are treated equally to system apps
    _supported_systemsdk_versions := $(PLATFORM_SYSTEMSDK_VERSIONS)
  endif
  _system_sdk_version := $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION))
  ifneq ($(_system_sdk_version),$(filter $(_system_sdk_version),$(_supported_systemsdk_versions)))
    $(call pretty-error,Incompatible LOCAL_SDK_VERSION '$(LOCAL_SDK_VERSION)'. \
           System SDK version '$(_system_sdk_version)' is not supported. Supported versions are: $(_supported_systemsdk_versions))
  endif
  _system_sdk_version :=
  _supported_systemsdk_versions :=
endif
