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

# TODO(b/172480615): Remove when platform uses ART Module prebuilts by default.
ifeq (,$(filter art_module,$(SOONG_CONFIG_NAMESPACES)))
  $(call add_soong_config_namespace,art_module)
  SOONG_CONFIG_art_module += source_build
endif
ifneq (,$(filter true,$(NATIVE_COVERAGE) $(CLANG_COVERAGE)))
  # Always build ART APEXes from source in coverage builds since the prebuilts
  # aren't built with instrumentation.
  # TODO(b/172480617): Find another solution for this.
  SOONG_CONFIG_art_module_source_build := true
else
  # This sets the default for building ART APEXes from source rather than
  # prebuilts (in packages/modules/ArtPrebuilt and prebuilt/module_sdk/art) in
  # all other platform builds.
  SOONG_CONFIG_art_module_source_build ?= true
endif

# Apex build mode variables
ifdef APEX_BUILD_FOR_PRE_S_DEVICES
$(call add_soong_config_var_value,ANDROID,library_linking_strategy,prefer_static)
endif
