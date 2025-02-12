#
# Copyright (C) 2025 The Android Open-Source Project
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

# aosp_arm64_plus_armv7 is for building CTS and other test suites with
# arm64 as the primary architecture and armv7 arm32 as the secondary
# architecture.

#
# All components inherited here go to system image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed

#
# All components inherited here go to system_ext image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony_system_ext.mk)

# pKVM
$(call inherit-product-if-exists, packages/modules/Virtualization/apex/product_packages.mk)

#
# All components inherited here go to product image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_product.mk)

#
# All components inherited here go to vendor or vendor_boot image
#
$(call inherit-product, $(SRC_TARGET_DIR)/board/generic_arm64/device.mk)
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS ?= system

#
# Special settings for GSI releasing
#
# Build modules from source if this has not been pre-configured
MODULE_BUILD_FROM_SOURCE ?= true

$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)


PRODUCT_NAME := aosp_arm64_plus_armv7
PRODUCT_DEVICE := generic_arm64_plus_armv7
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on ARM64 with ARMV7

PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO := true
