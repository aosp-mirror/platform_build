#
# Copyright (C) 2007 The Android Open Source Project
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

# This is a generic product for devices with large display but not specialized
# for a specific device. It includes the base Android platform.

PRODUCT_POLICY := android.policy_mid

PRODUCT_PACKAGES := \
    CarHome \
    DeskClock \
    Bluetooth \
    Calculator \
    Calendar \
    CertInstaller \
    Email \
    Exchange2 \
    Gallery2 \
    LatinIME \
    Launcher2 \
    Music \
    Provision \
    QuickSearchBox \
    Settings \
    Sync \
    Updater \
    CalendarProvider \
    SyncProvider \
    bluetooth-health \
    hostapd \
    wpa_supplicant.conf


$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := large_emu_hw
