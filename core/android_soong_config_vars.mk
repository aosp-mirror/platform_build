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
BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := false

ifneq ($(SANITIZE_TARGET)$(EMMA_INSTRUMENT_FRAMEWORK),)
  # Always use sources when building the framework with Java coverage or
  # sanitized builds as they both require purpose built prebuilts which we do
  # not provide.
  BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true
endif

ifneq ($(CLANG_COVERAGE)$(NATIVE_COVERAGE_PATHS),)
  # Always use sources when building with clang coverage and native coverage.
  # It is possible that there are certain situations when building with coverage
  # would work with prebuilts, e.g. when the coverage is not being applied to
  # modules for which we provide prebuilts. Unfortunately, determining that
  # would require embedding knowledge of which coverage paths affect which
  # modules here. That would duplicate a lot of information, add yet another
  # location  module authors have to update and complicate the logic here.
  # For nowe we will just always build from sources when doing coverage builds.
  BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true
endif

# TODO(b/172063604): Remove once products no longer use dex2oat(d)s.
# If the product uses dex2oats and/or dex2oatds then build from sources as
# ART does not currently provide prebuilts of those tools.
ifneq (,$(filter dex2oats dex2oatds,$(PRODUCT_HOST_PACKAGES)))
  BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true
endif

# ART does not provide linux_bionic variants needed for products that
# set HOST_CROSS_OS=linux_bionic.
ifeq (linux_bionic,${HOST_CROSS_OS})
  BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true
endif

# ART does not provide host side arm64 variants needed for products that
# set HOST_CROSS_ARCH=arm64.
ifeq (arm64,${HOST_CROSS_ARCH})
  BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true
endif

# TV based devices do not seem to work with prebuilts, so build from source
# for now and fix in a follow up.
ifneq (,$(filter tv,$(subst $(comma),$(space),${PRODUCT_CHARACTERISTICS})))
  BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true
endif

# ATV based devices do not seem to work with prebuilts, so build from source
# for now and fix in a follow up.
ifneq (,${PRODUCT_IS_ATV})
  BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE := true
endif

ifneq (,$(MODULE_BUILD_FROM_SOURCE))
  # Keep an explicit setting.
else ifeq (,$(filter docs sdk win_sdk sdk_addon,$(MAKECMDGOALS))$(findstring com.google.android.conscrypt,$(PRODUCT_PACKAGES)))
  # Prebuilt module SDKs require prebuilt modules to work, and currently
  # prebuilt modules are only provided for com.google.android.xxx. If we can't
  # find one of them in PRODUCT_PACKAGES then assume com.android.xxx are in use,
  # and disable prebuilt SDKs. In particular this applies to AOSP builds.
  #
  # However, docs/sdk/win_sdk/sdk_addon builds might not include com.google.android.xxx
  # packages, so for those we respect the default behavior.
  MODULE_BUILD_FROM_SOURCE := true
else ifneq (,$(PRODUCT_MODULE_BUILD_FROM_SOURCE))
  # Let products override the branch default.
  MODULE_BUILD_FROM_SOURCE := $(PRODUCT_MODULE_BUILD_FROM_SOURCE)
else
  MODULE_BUILD_FROM_SOURCE := $(BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE)
endif

ifneq (,$(ART_MODULE_BUILD_FROM_SOURCE))
  # Keep an explicit setting.
else ifneq (,$(findstring .android.art,$(TARGET_BUILD_APPS)))
  # Build ART modules from source if they are listed in TARGET_BUILD_APPS.
  ART_MODULE_BUILD_FROM_SOURCE := true
else
  # Do the same as other modules by default.
  ART_MODULE_BUILD_FROM_SOURCE := $(MODULE_BUILD_FROM_SOURCE)
endif

$(call soong_config_set,art_module,source_build,$(ART_MODULE_BUILD_FROM_SOURCE))

ifdef TARGET_BOARD_AUTO
  $(call add_soong_config_var_value, ANDROID, target_board_auto, $(TARGET_BOARD_AUTO))
endif

# Ensure that those mainline modules who have individually toggleable prebuilts
# are controlled by the MODULE_BUILD_FROM_SOURCE environment variable by
# default.
INDIVIDUALLY_TOGGLEABLE_PREBUILT_MODULES := \
  btservices \
  permission \
  uwb \
  wifi \

$(foreach m, $(INDIVIDUALLY_TOGGLEABLE_PREBUILT_MODULES),\
  $(if $(call soong_config_get,$(m)_module,source_build),,\
    $(call soong_config_set,$(m)_module,source_build,$(MODULE_BUILD_FROM_SOURCE))))

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

# Enable SystemUI optimizations by default unless explicitly set.
SYSTEMUI_OPTIMIZE_JAVA ?= true
$(call add_soong_config_var,ANDROID,SYSTEMUI_OPTIMIZE_JAVA)

# Disable Compose in SystemUI by default.
SYSTEMUI_USE_COMPOSE ?= false
$(call add_soong_config_var,ANDROID,SYSTEMUI_USE_COMPOSE)

# Enable system_server optimizations by default unless explicitly set or if
# there may be dependent runtime jars.
# TODO(b/240588226): Remove the off-by-default exceptions after handling
# system_server jars automatically w/ R8.
ifeq (true,$(PRODUCT_BROKEN_SUBOPTIMAL_ORDER_OF_SYSTEM_SERVER_JARS))
  # If system_server jar ordering is broken, don't assume services.jar can be
  # safely optimized in isolation, as there may be dependent jars.
  SYSTEM_OPTIMIZE_JAVA ?= false
else ifneq (platform:services,$(lastword $(PRODUCT_SYSTEM_SERVER_JARS)))
  # If services is not the final jar in the dependency ordering, don't assume
  # it can be safely optimized in isolation, as there may be dependent jars.
  SYSTEM_OPTIMIZE_JAVA ?= false
else
  SYSTEM_OPTIMIZE_JAVA ?= true
endif
$(call add_soong_config_var,ANDROID,SYSTEM_OPTIMIZE_JAVA)

# Check for SupplementalApi module.
ifeq ($(wildcard packages/modules/SupplementalApi),)
$(call add_soong_config_var_value,ANDROID,include_nonpublic_framework_api,false)
else
$(call add_soong_config_var_value,ANDROID,include_nonpublic_framework_api,true)
endif

