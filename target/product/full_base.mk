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
    OpenWnn \
    PinyinIME \
    VoiceDialer \
    libWnnEngDic \
    libWnnJpnDic \
    libwnndict

# Additional settings used in all AOSP builds
PRODUCT_PROPERTY_OVERRIDES := \
    ro.com.android.dateformat=MM-dd-yyyy

# Put en_US first in the list, so make it default.
PRODUCT_LOCALES := en_US

# Pick up some sounds.
$(call inherit-product-if-exists, frameworks/base/data/sounds/AudioPackage4.mk)

# Get the TTS language packs
$(call inherit-product-if-exists, external/svox/pico/lang/all_pico_languages.mk)

# Get a list of languages.
$(call inherit-product, $(SRC_TARGET_DIR)/product/locales_full.mk)

# Get everything else from the parent package
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_no_telephony.mk)

