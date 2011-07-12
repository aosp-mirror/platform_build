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

PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := core

PRODUCT_PROPERTY_OVERRIDES := \
    ro.config.notification_sound=OnTheHunt.ogg \
    ro.config.alarm_alert=Alarm_Classic.ogg

PRODUCT_PACKAGES := \
    apache-xml \
    bouncycastle \
    bu \
    bluetooth-health \
    cacerts \
    com.android.location.provider \
    com.android.location.provider.xml \
    core \
    core-junit \
    dalvikvm \
    dexdeps \
    dexdump \
    dexlist \
    dexopt \
    dmtracedump \
    dx \
    ext \
    filterfw \
    framework-res \
    hprof-conv \
    icu.dat \
    installd \
    ip-up-vpn \
    libcrypto \
    libdex \
    libdvm \
    libexpat \
    libgabi++ \
    libicui18n \
    libicuuc \
    libjavacore \
    libnativehelper \
    libnfc_ndef \
    libOpenMAXAL \
    libOpenSLES \
    libsqlite_jni \
    libssl \
    libstagefright_soft_aacdec \
    libstagefright_soft_amrdec \
    libstagefright_soft_avcdec \
    libstagefright_soft_g711dec \
    libstagefright_soft_mp3dec \
    libstagefright_soft_mpeg4dec \
    libstagefright_soft_vorbisdec \
    libstagefright_soft_vpxdec \
    libwilhelm \
    libfilterfw \
    libfilterpack_imageproc \
    libz \
    wpa_supplicant.conf \
    KeyChain \
    Browser \
    Contacts \
    Home \
    HTMLViewer \
    ApplicationsProvider \
    BackupRestoreConfirmation \
    ContactsProvider \
    VoicemailProvider \
    DownloadProvider \
    DownloadProviderUi \
    MediaProvider \
    PicoTts \
    SettingsProvider \
    TelephonyProvider \
    TtsService \
    VpnServices \
    UserDictionaryProvider \
    PackageInstaller \
    DefaultContainerService \
    Bugreport \
    ip \
    screencap \
    sensorservice \
    libspeexresampler \
    libwebrtc_audio_preprocessing

# host-only dependencies
ifeq ($(WITH_HOST_DALVIK),true)
    PRODUCT_PACKAGES += \
        apache-xml-hostdex \
        bouncycastle-hostdex \
        core-hostdex \
        libjavacore-host \
        dalvik
endif
