#
# Copyright (C) 2019 The Android Open Source Project
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

# This makefile contains the system_ext partition contents for
# a generic phone or tablet device. Only add something here if
# it definitely doesn't belong on other types of devices (if it
# does, use base_system_ext.mk).
$(call inherit-product, $(SRC_TARGET_DIR)/product/media_system_ext.mk)

# /system_ext packages
PRODUCT_PACKAGES += \
    AccessibilityMenu \
    Launcher3QuickStep \
    Provision \
    Settings \
    StorageManager \
    SystemUI \
    WallpaperCropper \

# Base modules when shipping api level is less than or equal to 34
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_34 += \
    hwservicemanager \
    android.hidl.allocator@1.0-service \
