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
# treble_system.prop.

# Generic system image inherits from AOSP with telephony
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony.mk)

# Enable dynamic partition size
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

# Split selinux policy
PRODUCT_FULL_TREBLE_OVERRIDE := true

# The Messaging app:
#   Needed for android.telecom.cts.ExtendedInCallServiceTest#testOnCannedTextResponsesLoaded
PRODUCT_PACKAGES += \
    messaging

# Telephony:
#   Provide a default APN configuration
PRODUCT_COPY_FILES += \
    device/sample/etc/apns-full-conf.xml:system/etc/apns-conf.xml

# NFC:
#   Provide default libnfc-nci.conf file for devices that does not have one in
#   vendor/etc
PRODUCT_COPY_FILES += \
    device/generic/common/nfc/libnfc-nci.conf:system/etc/libnfc-nci.conf

# Support for the O-MR1 devices
PRODUCT_COPY_FILES += \
    build/make/target/product/vndk/init.gsi.rc:system/etc/init/init.gsi.rc \
    build/make/target/product/vndk/init.vndk-27.rc:system/etc/init/gsi/init.vndk-27.rc

# Name space configuration file for non-enforcing VNDK
PRODUCT_PACKAGES += \
    ld.config.vndk_lite.txt

# Support addtional O-MR1 vendor interface
PRODUCT_EXTRA_VNDK_VERSIONS := 27
