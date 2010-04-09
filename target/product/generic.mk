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

# This is a generic phone product that isn't specialized for a specific device.
# It includes the base Android platform.

PRODUCT_POLICY := android.policy_phone

PRODUCT_PACKAGES := \
    AccountAndSyncSettings \
    CarHome \
    DeskClock \
    AlarmProvider \
    Bluetooth \
    Calculator \
    Calendar \
    Camera \
    CertInstaller \
    DrmProvider \
    Email \
    Gallery3D \
    LatinIME \
    Launcher2 \
    Mms \
    Music \
    Provision \
    Phone \
    Protips \
    QuickSearchBox \
    Settings \
    Sync \
    Updater \
    CalendarProvider \
    SyncProvider

$(call inherit-product, $(SRC_TARGET_DIR)/product/core.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := generic
