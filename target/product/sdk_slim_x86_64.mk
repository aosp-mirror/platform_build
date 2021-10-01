#
# Copyright (C) 2021 The Android Open Source Project
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
QEMU_USE_SYSTEM_EXT_PARTITIONS := true
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# This is a build configuration for the 'slim' image targeted
# for headless automated testing. Compared to the full AOSP 'sdk_phone'
# image it removes/replaces most product apps, and turns off rendering
# by default.

#
# All components inherited here go to system image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

# Enable mainline checking for exact this product name
ifeq (sdk_slim_x86_64,$(TARGET_PRODUCT))
PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed
endif

#
# All components inherited here go to system_ext image
#
# don't include full handheld_system_Ext which includes SystemUi, Settings etc
$(call inherit-product, $(SRC_TARGET_DIR)/product/media_system_ext.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony_system_ext.mk)

#
# All components inherited here go to product image
#
# Just include webview, do not include most other apps
$(call inherit-product, $(SRC_TARGET_DIR)/product/media_product.mk)

# Include FakeSystemApp which replaces core system apps like Settings,
# Launcher
PRODUCT_PACKAGES += \
    FakeSystemApp \

#
# All components inherited here go to vendor image
#
# this must go first - overwrites the goldfish handheld_core_hardware.xml
$(call inherit-product, device/generic/goldfish/slim/vendor.mk)

$(call inherit-product-if-exists, device/generic/goldfish/x86_64-vendor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulator_vendor.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/board/emulator_x86_64/device.mk)

# include the overlay that overrides systemui definitions with fakesystemapp
DEVICE_PACKAGE_OVERLAYS := device/generic/goldfish/slim/overlay

# Define the host tools and libs that are parts of the SDK.
$(call inherit-product-if-exists, sdk/build/product_sdk.mk)
$(call inherit-product-if-exists, development/build/product_sdk.mk)

# Overrides
PRODUCT_BRAND := Android
PRODUCT_NAME := sdk_slim_x86_64
PRODUCT_DEVICE := emulator_x86_64
PRODUCT_MODEL := Android SDK built for x86_64
# Disable <uses-library> checks for SDK product. It lacks some libraries (e.g.
# RadioConfigLib), which makes it impossible to translate their module names to
# library name, so the check fails.
PRODUCT_BROKEN_VERIFY_USES_LIBRARIES := true
