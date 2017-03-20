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
# on the generic system image, place them in build/make/target/board/generic_arm64_ab/
# system.prop.

PRODUCT_COPY_FILES := \
    device/generic/goldfish/data/etc/apns-conf.xml:system/etc/apns-conf.xml \
    device/generic/goldfish/camera/media_profiles.xml:system/etc/media_profiles.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:system/etc/media_codecs_google_audio.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_telephony.xml:system/etc/media_codecs_google_telephony.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_video.xml:system/etc/media_codecs_google_video.xml \
    device/generic/goldfish/camera/media_codecs.xml:system/etc/media_codecs.xml \

# TODO(jiyong): remove sailfish/marlin rc and fstab files. They should be in
# /vendor/etc/init after b/35269867
PRODUCT_COPY_FILES += \
    device/google/marlin/fstab.common:root/fstab.sailfish \
    device/google/marlin/init.recovery.common.rc:root/init.recovery.sailfish.rc \

PRODUCT_COPY_FILES += \
    device/google/marlin/fstab.common:root/fstab.marlin \
    device/google/marlin/init.recovery.common.rc:root/init.recovery.marlin.rc \

# For now, let's use marlin bootanimation as the default boot animation
PRODUCT_COPY_FILES += \
    vendor/google/products/marlin/bootanimation-1440-256col.zip:system/media/bootanimation.zip

# TODO(jiyong): remove this marlin-specific overlay when b/35742444 is fixed.
PRODUCT_PACKAGE_OVERLAYS := \
    device/google/marlin/overlay

# Some of HAL interface libraries are automatically added by the dependencies from
# the framework. However, we list them all here to make it explicit and prevent
# possible mistake.
PRODUCT_PACKAGES := \
    android.dvr.composer@1.0 \
    android.hardware.audio@2.0 \
    android.hardware.audio.common@2.0 \
    android.hardware.audio.common@2.0-util \
    android.hardware.audio.effect@2.0 \
    android.hardware.biometrics.fingerprint@2.1 \
    android.hardware.bluetooth@1.0 \
    android.hardware.boot@1.0 \
    android.hardware.broadcastradio@1.0 \
    android.hardware.broadcastradio@1.1 \
    android.hardware.camera.common@1.0 \
    android.hardware.camera.device@1.0 \
    android.hardware.camera.device@3.2 \
    android.hardware.camera.provider@2.4 \
    android.hardware.configstore@1.0 \
    android.hardware.contexthub@1.0 \
    android.hardware.drm@1.0 \
    android.hardware.gatekeeper@1.0 \
    android.hardware.gnss@1.0 \
    android.hardware.graphics.allocator@2.0 \
    android.hardware.graphics.common@1.0 \
    android.hardware.graphics.composer@2.1 \
    android.hardware.graphics.mapper@2.0 \
    android.hardware.ir@1.0 \
    android.hardware.keymaster@3.0 \
    android.hardware.light@2.0 \
    android.hardware.media@1.0 \
    android.hardware.media.omx@1.0 \
    android.hardware.media.omx@1.0-utils \
    android.hardware.memtrack@1.0 \
    android.hardware.nfc@1.0 \
    android.hardware.power@1.0 \
    android.hardware.radio@1.0 \
    android.hardware.radio.deprecated@1.0 \
    android.hardware.sensors@1.0 \
    android.hardware.soundtrigger@2.0 \
    android.hardware.thermal@1.0 \
    android.hardware.tv.cec@1.0 \
    android.hardware.tv.input@1.0 \
    android.hardware.usb@1.0 \
    android.hardware.vibrator@1.0 \
    android.hardware.vr@1.0 \
    android.hardware.wifi@1.0 \
    android.hidl.allocator@1.0 \
    android.hidl.base@1.0 \
    android.hidl.manager@1.0 \
    android.hidl.memory@1.0 \

PRODUCT_PACKAGES += \
    libdynamic_sensor_ext \
    libaudioroute \
    libxml2 \
    libtinyalsa \
    libtinycompress \
    cplay

PRODUCT_SYSTEM_VERITY_PARTITION := /dev/block/bootdevice/by-name/system

AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := system
PRODUCT_PACKAGES += \
    update_engine \
    update_verifier

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/verity.mk)

PRODUCT_NAME := aosp_arm64_ab
PRODUCT_DEVICE := generic_arm64_ab
PRODUCT_BRAND := Android
PRODUCT_MODEL := AOSP on ARM64
