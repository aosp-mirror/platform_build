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

# This file defines the Soong Config Variable namespace ANDROID, and also any
# variables in that namespace.

# The expectation is that no vendor should be using the ANDROID namespace. This
# check ensures that we don't collide with any existing vendor usage.

ifdef SOONG_CONFIG_ANDROID
$(error The Soong config namespace ANDROID is reserved.)
endif

$(call add_soong_config_namespace,ANDROID)

# Add variables to the namespace below:

$(call add_soong_config_var,ANDROID,TARGET_ENABLE_MEDIADRM_64)
$(call add_soong_config_var,ANDROID,IS_TARGET_MIXED_SEPOLICY)
ifeq ($(IS_TARGET_MIXED_SEPOLICY),true)
$(call add_soong_config_var_value,ANDROID,MIXED_SEPOLICY_VERSION,$(BOARD_SEPOLICY_VERS))
endif
$(call add_soong_config_var,ANDROID,BOARD_USES_ODMIMAGE)
$(call add_soong_config_var,ANDROID,BOARD_USES_RECOVERY_AS_BOOT)
$(call add_soong_config_var,ANDROID,BOARD_BUILD_SYSTEM_ROOT_IMAGE)
$(call add_soong_config_var,ANDROID,PRODUCT_INSTALL_DEBUG_POLICY_TO_SYSTEM_EXT)

# Default behavior for the tree wrt building modules or using prebuilts. This
# can always be overridden by setting the environment variable
# MODULE_BUILD_FROM_SOURCE.
BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true

ifneq (,$(MODULE_BUILD_FROM_SOURCE))
  # Keep an explicit setting.
else ifeq (,$(filter sdk win_sdk sdk_addon,$(MAKECMDGOALS))$(findstring com.google.android.conscrypt,$(PRODUCT_PACKAGES)))
  # Prebuilt module SDKs require prebuilt modules to work, and currently
  # prebuilt modules are only provided for com.google.android.xxx. If we can't
  # find one of them in PRODUCT_PACKAGES then assume com.android.xxx are in use,
  # and disable prebuilt SDKs. In particular this applies to AOSP builds.
  #
  # However, sdk/win_sdk/sdk_addon builds might not include com.google.android.xxx
  # packages, so for those we respect the default behavior.
  MODULE_BUILD_FROM_SOURCE := true
else ifeq (,$(filter-out modules_% mainline_modules_%,$(TARGET_PRODUCT)))
  # Always build from source in unbundled builds using the module targets.
  MODULE_BUILD_FROM_SOURCE := true
else
  MODULE_BUILD_FROM_SOURCE := $(BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE)
endif

ifneq (,$(ART_MODULE_BUILD_FROM_SOURCE))
  # Keep an explicit setting.
else ifneq (,$(findstring .android.art,$(TARGET_BUILD_APPS)))
  # Build ART modules from source if they are listed in TARGET_BUILD_APPS.
  ART_MODULE_BUILD_FROM_SOURCE := true
else ifeq (,$(filter-out modules_% mainline_modules_%,$(TARGET_PRODUCT)))
  # Always build from source for the module targets. This ought to be covered by
  # the TARGET_BUILD_APPS check above, but there are test builds that don't set it.
  ART_MODULE_BUILD_FROM_SOURCE := true
else
  # Do the same as other modules by default.
  ART_MODULE_BUILD_FROM_SOURCE := $(MODULE_BUILD_FROM_SOURCE)
endif

$(call soong_config_set,art_module,source_build,$(ART_MODULE_BUILD_FROM_SOURCE))

# Apex build mode variables
ifdef APEX_BUILD_FOR_PRE_S_DEVICES
$(call add_soong_config_var_value,ANDROID,library_linking_strategy,prefer_static)
endif

ifeq (true,$(MODULE_BUILD_FROM_SOURCE))
$(call add_soong_config_var_value,ANDROID,module_build_from_source,true)
endif

# Messaging app vars
ifeq (eng,$(TARGET_BUILD_VARIANT))
$(call soong_config_set,messaging,build_variant_eng,true)
endif

# TODO(b/203088572): Remove when Java optimizations enabled by default for
# SystemUI.
$(call add_soong_config_var,ANDROID,SYSTEMUI_OPTIMIZE_JAVA)
# TODO(b/196084106): Remove when Java optimizations enabled by default for
# system packages.
$(call add_soong_config_var,ANDROID,SYSTEM_OPTIMIZE_JAVA)
