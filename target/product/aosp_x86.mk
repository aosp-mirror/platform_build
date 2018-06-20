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

# The system image of aosp_x86-userdebug is a GSI for the devices with:
# - x86 32 bits user space
# - 64 bits binder interface
# - system-as-root
# - VNDK enforcement
# - compatible property override enabled

PRODUCT_PROPERTY_OVERRIDES += \
	vendor.rild.libpath=/vendor/lib/libreference-ril.so

# This is a build configuration for a full-featured build of the
# Open-Source part of the tree. It's geared toward a US-centric
# build quite specifically for the emulator, and might not be
# entirely appropriate to inherit from for on-device configurations.
PRODUCT_COPY_FILES += \
    development/sys-img/advancedFeatures.ini:advancedFeatures.ini \
    device/generic/goldfish/data/etc/encryptionkey.img:encryptionkey.img \
    prebuilts/qemu-kernel/x86_64/4.9/kernel-qemu2:kernel-ranchu-64

include $(SRC_TARGET_DIR)/product/full_x86.mk

# Enable A/B update
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := system
PRODUCT_PACKAGES += \
    update_engine \
    update_verifier

# Needed by Pi newly launched device to pass VtsTrebleSysProp on GSI
PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE := true

PRODUCT_NAME := aosp_x86
