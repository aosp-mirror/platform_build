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

# Base configuration for communication-oriented android devices
# (phones, tablets, etc.).  If you want a change to apply to ALMOST ALL
# devices (including non-phones and non-tablets), modify
# core_minimal.mk instead. If you care about wearables, you need to modify
# core_tiny.mk in addition to core_minimal.mk.

PRODUCT_PACKAGES += \
    BasicDreams \
    BlockedNumberProvider \
    BookmarkProvider \
    Browser2 \
    BuiltInPrintService \
    Calendar \
    CalendarProvider \
    CaptivePortalLogin \
    CertInstaller \
    Contacts \
    DeskClock \
    DocumentsUI \
    DownloadProviderUi \
    Email \
    ExactCalculator \
    ExternalStorageProvider \
    FusedLocation \
    InputDevices \
    KeyChain \
    Keyguard \
    LatinIME \
    Launcher3QuickStep \
    ManagedProvisioning \
    MtpDocumentsProvider \
    PacProcessor \
    libpac \
    PrintSpooler \
    PrintRecommendationService \
    ProxyHandler \
    QuickSearchBox \
    SecureElement \
    Settings \
    SettingsIntelligence \
    SharedStorageBackup \
    SimAppDialog \
    StorageManager \
    Telecom \
    TeleService \
    Traceur \
    VpnDialogs \
    vr \
    MmsService

# The set of packages whose code can be loaded by the system server.
PRODUCT_SYSTEM_SERVER_APPS += \
    FusedLocation \
    InputDevices \
    KeyChain \
    Telecom \

# The set of packages we want to force 'speed' compilation on.
PRODUCT_DEXPREOPT_SPEED_APPS += \

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_base.mk)
