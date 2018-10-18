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

# This makefile is the basis of a generic system image for a handheld device.
$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony_system.mk)

# Shared java libs
PRODUCT_PACKAGES += \
    com.android.nfc_extras \

# Applications
PRODUCT_PACKAGES += \
    DMService \
    LiveWallpapersPicker \
    PartnerBookmarksProvider \
    PresencePolling \
    RcsService \
    SafetyRegulatoryInfo \
    Stk \

# OTA support
PRODUCT_PACKAGES += \
    update_engine \
    update_verifier \

# Wrapped net utils for /vendor access.
PRODUCT_PACKAGES += \
    netutils-wrapper-1.0 \

# Charger images
PRODUCT_PACKAGES += \
    charger_res_images \

# system_other support
PRODUCT_PACKAGES += \
    cppreopts.sh \
    otapreopt_script \

# Bluetooth libraries
PRODUCT_PACKAGES += \
    audio.a2dp.default \
    audio.hearing_aid.default \

PRODUCT_PACKAGES_DEBUG += \
    avbctl \
    bootctl \
    tinyplay \
    tinycap \
    tinymix \
    tinypcminfo \
    update_engine_client \

# Enable dynamic partition size
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

PRODUCT_NAME := mainline_system
PRODUCT_BRAND := generic

_base_mk_whitelist :=

_my_whitelist := $(_base_mk_whitelist)

# For mainline, system.img should be mounted at /, so we include ROOT here.
_my_paths := \
  $(TARGET_COPY_OUT_ROOT)/ \
  $(TARGET_COPY_OUT_SYSTEM)/ \

$(call require-artifacts-in-path, $(_my_paths), $(_my_whitelist))
