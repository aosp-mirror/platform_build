#
# Copyright (C) 2017 The Android Open-Source Project
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

# PRODUCT_PROPERTY_OVERRIDES cannot be used here because sysprops will be at
# /vendor/[build|default].prop when build split is on. In order to have sysprops
# on the generic system image, place them in build/make/target/board/
# gsi_system.prop.

# aosp_arm_ab-userdebug is a Legacy GSI for the devices with:
# - ARM 32 bits user space
# - 32 bits binder interface
# - system-as-root

$(call inherit-product, $(SRC_TARGET_DIR)/product/legacy_gsi_common.mk)

# Enable mainline checking for excat this product name
ifeq (aosp_arm_ab,$(TARGET_PRODUCT))
PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed
endif

PRODUCT_NAME := aosp_arm_ab
PRODUCT_DEVICE := generic_arm_ab
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on ARM32
