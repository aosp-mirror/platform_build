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

PRODUCT_PACKAGES := \
    audio.primary.default \
    BasicDreams \
    BlockedNumberProvider \
    Bluetooth \
    BluetoothMidiService \
    BookmarkProvider \
    Browser2 \
    BuiltInPrintService \
    Calendar \
    CalendarProvider \
    Camera2 \
    CaptivePortalLogin \
    CertInstaller \
    clatd \
    clatd.conf \
    Contacts \
    DeskClock \
    DisplayCutoutEmulationCornerOverlay \
    DisplayCutoutEmulationDoubleOverlay \
    DisplayCutoutEmulationTallOverlay \
    DocumentsUI \
    DownloadProviderUi \
    EasterEgg \
    Email \
    ExactCalculator \
    ExternalStorageProvider \
    FusedLocation \
    Gallery2 \
    InputDevices \
    KeyChain \
    Keyguard \
    LatinIME \
    Launcher3QuickStep \
    librs_jni \
    libvideoeditor_core \
    libvideoeditor_jni \
    libvideoeditor_osal \
    libvideoeditorplayer \
    libvideoeditor_videofilters \
    local_time.default \
    ManagedProvisioning \
    MmsService \
    MtpDocumentsProvider \
    Music \
    MusicFX \
    NfcNci \
    OneTimeInitializer \
    PacProcessor \
    power.default \
    PrintRecommendationService \
    PrintSpooler \
    Provision \
    ProxyHandler \
    QuickSearchBox \
    screenrecord \
    SecureElement \
    Settings \
    SettingsIntelligence \
    SharedStorageBackup \
    SimAppDialog \
    StorageManager \
    SystemUI \
    SysuiDarkThemeOverlay \
    Telecom \
    TeleService \
    Traceur \
    vibrator.default \
    VpnDialogs \
    vr \
    WallpaperCropper \


PRODUCT_SYSTEM_SERVER_APPS += \
    FusedLocation \
    InputDevices \
    KeyChain \
    Telecom \

PRODUCT_COPY_FILES := \
        frameworks/av/media/libeffects/data/audio_effects.conf:system/etc/audio_effects.conf

PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=unknown

$(call inherit-product-if-exists, frameworks/base/data/fonts/fonts.mk)
$(call inherit-product-if-exists, external/google-fonts/dancing-script/fonts.mk)
$(call inherit-product-if-exists, external/google-fonts/carrois-gothic-sc/fonts.mk)
$(call inherit-product-if-exists, external/google-fonts/coming-soon/fonts.mk)
$(call inherit-product-if-exists, external/google-fonts/cutive-mono/fonts.mk)
$(call inherit-product-if-exists, external/noto-fonts/fonts.mk)
$(call inherit-product-if-exists, external/roboto-fonts/fonts.mk)
$(call inherit-product-if-exists, external/hyphenation-patterns/patterns.mk)
$(call inherit-product-if-exists, frameworks/base/data/keyboards/keyboards.mk)
$(call inherit-product-if-exists, frameworks/webview/chromium/chromium.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_base.mk)

# Overrides
PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := generic_no_telephony
