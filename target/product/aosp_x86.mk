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

-include device/generic/goldfish/x86-vendor.mk

include $(SRC_TARGET_DIR)/product/full_x86.mk

# Enable dynamic partition size
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

# Enable A/B update
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := system
PRODUCT_PACKAGES += \
    update_engine \
    update_verifier

# Needed by Pi newly launched device to pass VtsTrebleSysProp on GSI
PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE := true

# GSI specific tasks on boot
PRODUCT_COPY_FILES += \
    build/make/target/product/gsi/skip_mount.cfg:system/etc/init/config/skip_mount.cfg \
    build/make/target/product/gsi/init.gsi.rc:system/etc/init/init.gsi.rc \

# Support addtional P vendor interface
PRODUCT_EXTRA_VNDK_VERSIONS := 28

PRODUCT_NAME := aosp_x86
