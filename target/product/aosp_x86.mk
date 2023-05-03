#
# Copyright 2013 The Android Open-Source Project
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

# The system image of aosp_x86-userdebug is a GSI for the devices with:
# - x86 32 bits user space
# - 64 bits binder interface
# - system-as-root
# - VNDK enforcement
# - compatible property override enabled

#
# All components inherited here go to system image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

# Enable mainline checking for excat this product name
ifeq (aosp_x86,$(TARGET_PRODUCT))
PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed
endif

#
# All components inherited here go to system_ext image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony_system_ext.mk)

#
# All components inherited here go to product image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_product.mk)

#
# All components inherited here go to vendor image
#
$(call inherit-product, $(SRC_TARGET_DIR)/board/generic_x86/device.mk)


#
# Special settings for GSI releasing
#
ifeq (aosp_x86,$(TARGET_PRODUCT))
# Build modules from source if this has not been pre-configured
MODULE_BUILD_FROM_SOURCE ?= true

$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)
endif


PRODUCT_NAME := aosp_x86
PRODUCT_DEVICE := generic_x86
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on x86
