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
    CalendarProvider \
    ContactsProvider \
    CertInstaller \
    FusedLocation \
    InputDevices

PRODUCT_PACKAGES += \
    clatd \
    clatd.conf \
    pppd

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
    bcc \
    bu \
    com.android.location.provider \
    com.android.location.provider.xml \
    framework-res \
    installd \
    ims-common \
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
    libkeystore \
    libsqlite_jni \
    libwilhelm \
    libdrmframework_jni \
    libdrmframework \
    make_ext4fs \
    e2fsck \
    resize2fs \
    nullwebview \
    screencap \
    sensorservice \
    uiautomator \
    uncrypt \
    telephony-common \
    voip-common \
    logd \
    mms-common \
    wifi-service

# The order matters
PRODUCT_BOOT_JARS := \
    core-libart \
    conscrypt \
    okhttp \
    core-junit \
    bouncycastle \
    ext \
    framework \
    telephony-common \
    voip-common \
    ims-common \
    mms-common \
    android.policy \
    apache-xml \
    nullwebview \

# The order of PRODUCT_SYSTEM_SERVER_JARS matters.
PRODUCT_SYSTEM_SERVER_JARS := \
    services \
    wifi-service

PRODUCT_RUNTIMES := runtime_libart_default

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote32
PRODUCT_COPY_FILES += \
    system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=unknown

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product-if-exists, frameworks/base/data/fonts/fonts.mk)

# Overrides
PRODUCT_BRAND := tiny
PRODUCT_DEVICE := tiny
PRODUCT_NAME := core_tiny
