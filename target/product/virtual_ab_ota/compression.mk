#
# Copyright (C) 2020 The Android Open-Source Project
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

$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.compression.enabled=true
PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.userspace.snapshots.enabled=true
PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.io_uring.enabled=true
PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.batch_writes=true

# Enabling this property, will improve OTA install time
# but will use an additional CPU core
# PRODUCT_VENDOR_PROPERTIES += ro.virtual_ab.compression.threads=true

PRODUCT_VIRTUAL_AB_COMPRESSION := true
PRODUCT_PACKAGES += \
    snapuserd.vendor_ramdisk \
    snapuserd \
    snapuserd.recovery
