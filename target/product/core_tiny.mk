#
# Copyright (C) 2013 The Android Open Source Project
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
# Tiny configuration for small devices such as wearables. Includes base and embedded.
# No telephony

PRODUCT_PACKAGES := \
    Bluetooth \
    CertInstaller \
    FusedLocation \
    InputDevices \
    bluetooth-health \
    hostapd \
    wpa_supplicant.conf

PRODUCT_PACKAGES += \
    audio \
    clatd \
    clatd.conf \
    dhcpcd.conf \
    network \
    pand \
    pppd \
    sdptool \
    wpa_supplicant

PRODUCT_PACKAGES += \
    audio.primary.default \
    audio_policy.default \
    local_time.default \
    power.default

PRODUCT_PACKAGES += \
    local_time.default

PRODUCT_PACKAGES += \
    BackupRestoreConfirmation \
    DefaultContainerService \
    SettingsProvider \
    Shell \
    bu \
    com.android.location.provider \
    com.android.location.provider.xml \
    framework-res \
    installd \
    ip \
    ip-up-vpn \
    ip6tables \
    iptables \
    keystore \
    keystore.default \
    libOpenMAXAL \
    libOpenSLES \
    libdownmix \
    libfilterfw \
    libsqlite_jni \
    libwilhelm \
    make_ext4fs \
    screencap \
    sensorservice \
    uiautomator

# The order matters
PRODUCT_BOOT_JARS := \
    core \
    conscrypt \
    okhttp \
    core-junit \
    bouncycastle \
    ext \
    framework \
    framework2 \
    android.policy \
    services \
    apache-xml

PRODUCT_RUNTIMES := runtime_libdvm_default

PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=unknown

MINIMAL_FONT_FOOTPRINT := true

$(call inherit-product-if-exists, frameworks/base/data/fonts/fonts.mk)

# Overrides
PRODUCT_BRAND := tiny
PRODUCT_DEVICE := tiny
PRODUCT_NAME := core_tiny

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
