#
# Copyright (C) 2018 The Android Open Source Project
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

# This makefile contains the system partition contents for
# media-capable devices (non-wearables). Only add something
# here if it definitely doesn't belong on wearables. Otherwise,
# choose base_system.mk.
$(call inherit-product, $(SRC_TARGET_DIR)/product/base_system.mk)

PRODUCT_PACKAGES += \
    com.android.future.usb.accessory \
    com.android.mediadrm.signer \
    com.android.media.remotedisplay \
    com.android.media.remotedisplay.xml \
    CompanionDeviceManager \
    drmserver \
    ethernet-service \
    fsck.f2fs \
    HTMLViewer \
    libfilterpack_imageproc \
    libwebviewchromium_loader \
    libwebviewchromium_plat_support \
    make_f2fs \
    requestsync \
    StatementService \

PRODUCT_HOST_PACKAGES += \
    fsck.f2fs \

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.webview.xml:system/etc/permissions/android.software.webview.xml

ifneq (REL,$(PLATFORM_VERSION_CODENAME))
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.preview_sdk.xml:system/etc/permissions/android.software.preview_sdk.xml
endif

# The order here is the same order they end up on the classpath, so it matters.
PRODUCT_SYSTEM_SERVER_JARS := \
    com.android.location.provider \
    services \
    ethernet-service

# system server jars which are updated via apex modules.
# The values should be of the format <apex name>:<jar name>
PRODUCT_UPDATABLE_SYSTEM_SERVER_JARS := \
    com.android.permission:service-permission \
    com.android.wifi:service-wifi \
    com.android.ipsec:android.net.ipsec.ike \

PRODUCT_COPY_FILES += \
    system/core/rootdir/etc/public.libraries.android.txt:system/etc/public.libraries.txt

# Enable boot.oat filtering of compiled classes to reduce boot.oat size. b/28026683
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/compiled-classes-phone:system/etc/compiled-classes)

# Enable dirty image object binning to reduce dirty pages in the image.
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/dirty-image-objects-phone:system/etc/dirty-image-objects)

# On userdebug builds, collect more tombstones by default.
ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    tombstoned.max_tombstone_count=50
endif

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.logd.size.stats=64K \
    log.tag.stats_log=I

# Enable CFI for security-sensitive components
$(call inherit-product, $(SRC_TARGET_DIR)/product/cfi-common.mk)
$(call inherit-product-if-exists, vendor/google/products/cfi-vendor.mk)
