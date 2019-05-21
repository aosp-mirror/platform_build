#
# Copyright 2017 The Android Open-Source Project
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

PRODUCT_USE_DYNAMIC_PARTITIONS := true

# The system image of aosp_arm-userdebug is a GSI for the devices with:
# - ARM 32 bits user space
# - 64 bits binder interface
# - system-as-root
# - VNDK enforcement
# - compatible property override enabled

# GSI for system/product
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_common.mk)

# Enable mainline checking for excat this product name
ifeq (aosp_arm,$(TARGET_PRODUCT))
PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed
endif

# Emulator for vendor
$(call inherit-product-if-exists, device/generic/goldfish/arm32-vendor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulator_vendor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/board/generic_x86/device.mk)

PRODUCT_NAME := aosp_arm
PRODUCT_DEVICE := generic
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on ARM32
