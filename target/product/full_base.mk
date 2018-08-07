#
# Copyright (C) 2009 The Android Open Source Project
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

# This is a build configuration for a full-featured build of the
# Open-Source part of the tree. It's geared toward a US-centric
# build of the emulator, but all those aspects can be overridden
# in inherited configurations.

PRODUCT_PACKAGES := \
    libfwdlockengine \
    WAPPushManager

PRODUCT_PACKAGES += \
    Galaxy4 \
    HoloSpiralWallpaper \
    LiveWallpapers \
    LiveWallpapersPicker \
    MagicSmokeWallpapers \
    NoiseField \
    PhaseBeam \
    PhotoTable

# Bluetooth:
#   audio.a2dp.default is a system module. Generic system image includes
#   audio.a2dp.default to support A2DP if board has the capability.
PRODUCT_PACKAGES += \
    audio.a2dp.default

# Net:
#   Vendors can use the platform-provided network configuration utilities (ip,
#   iptable, etc.) to configure the Linux networking stack, but these utilities
#   do not yet include a HIDL interface wrapper. This is a solution on
#   Android O.
PRODUCT_PACKAGES += \
    netutils-wrapper-1.0

# Additional settings used in all AOSP builds
PRODUCT_PROPERTY_OVERRIDES := \
    ro.config.ringtone=Ring_Synth_04.ogg \
    ro.config.notification_sound=pixiedust.ogg

# Put en_US first in the list, so make it default.
PRODUCT_LOCALES := en_US

# Get some sounds
$(call inherit-product-if-exists, frameworks/base/data/sounds/AllAudio.mk)

# Get a list of languages.
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# Get everything else from the parent package
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_no_telephony.mk)

# Add adb keys to debuggable AOSP builds (if they exist)
$(call inherit-product-if-exists, vendor/google/security/adb/vendor_key.mk)
