#
# Copyright 2022 The Android Open-Source Project
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

# The system image of aosp_riscv64-userdebug is a GSI for the devices with:
# - riscv64 user space
# - 64 bits binder interface
# - system-as-root
# - VNDK enforcement
# - compatible property override enabled

# This is a build configuration for a full-featured build of the
# Open-Source part of the tree. It's geared toward a US-centric
# build quite specifically for the emulator, and might not be
# entirely appropriate to inherit from for on-device configurations.

# GSI for system/product & support 64-bit apps only
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/mainline_system.mk)

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
$(call inherit-product, $(SRC_TARGET_DIR)/board/generic_riscv64/device.mk)

#
# Special settings for GSI releasing
#
ifeq (aosp_riscv64,$(TARGET_PRODUCT))
# Build modules from source if this has not been pre-configured
MODULE_BUILD_FROM_SOURCE ?= true

$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)
endif

PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    root/init.zygote64.rc

# TODO(b/206676167): This property can be removed when renderscript is removed.
# Prevents framework from attempting to load renderscript libraries, which are
# not supported on this architecture.
PRODUCT_SYSTEM_PROPERTIES += \
    config.disable_renderscript=1 \

# This build configuration supports 64-bit apps only
PRODUCT_NAME := aosp_riscv64
PRODUCT_DEVICE := generic_riscv64
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on Riscv64
