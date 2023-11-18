#
# Copyright (C) 2014 The Android Open Source Project
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

# This is a simple product that uses configures the minimum amount
# needed to build the SDK (without the emulator).

# In order to build the bootclasspath sources, the bootclasspath needs to
# be setup via default_art_config.mk. The sources only really make sense
# together with a device (e.g. the emulator). So if the SDK sources change
# to be built with the device, this could be removed.
$(call inherit-product, $(SRC_TARGET_DIR)/product/default_art_config.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_default.mk)

PRODUCT_NAME := sdk
PRODUCT_BRAND := Android
PRODUCT_DEVICE := mainline_x86

PRODUCT_NEXT_RELEASE_HIDE_FLAGGED_API := true

PRODUCT_BUILD_FROM_SOURCE_STUB := true