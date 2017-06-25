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
    local_time.default \
    power.default

PRODUCT_PACKAGES += \
    BackupRestoreConfirmation \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    DefaultContainerService \
    ExtShared \
    ExtServices \
    SettingsProvider \
    Shell \
    WallpaperBackup \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
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
    gatekeeperd \
    keystore \
    keystore.default \
    ld.mc \
    libaaudio \
    libOpenMAXAL \
    libOpenSLES \
    libdownmix \
    libfilterfw \
    libgatekeeper \
    libkeystore \
    libwilhelm \
    libdrmframework_jni \
    libdrmframework \
    make_ext4fs \
    e2fsck \
    resize2fs \
    tune2fs \
    nullwebview \
    screencap \
    sensorservice \
    uiautomator \
    uncrypt \
    telephony-common \
    voip-common \
    logd \

# Wifi modules
PRODUCT_PACKAGES += \
    wifi-service \
    wificond \

ifeq ($(TARGET_CORE_JARS),)
$(error TARGET_CORE_JARS is empty; cannot initialize PRODUCT_BOOT_JARS variable)
endif

# The order matters
PRODUCT_BOOT_JARS := \
    $(TARGET_CORE_JARS) \
    legacy-test \
    ext \
    framework \
    telephony-common \
    voip-common \
    ims-common \
    nullwebview \
    org.apache.http.legacy.boot \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java

# The order of PRODUCT_SYSTEM_SERVER_JARS matters.
PRODUCT_SYSTEM_SERVER_JARS := \
    services \
    wifi-service

# The set of packages whose code can be loaded by the system server.
PRODUCT_SYSTEM_SERVER_APPS += \
    FusedLocation \
    InputDevices \
    SettingsProvider \
    WallpaperBackup \

# The set of packages we want to force 'speed' compilation on.
PRODUCT_DEXPREOPT_SPEED_APPS := \

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote32
PRODUCT_COPY_FILES += \
    system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=unknown

$(call inherit-product, $(SRC_TARGET_DIR)/product/runtime_libart.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product-if-exists, frameworks/base/data/fonts/fonts.mk)
$(call inherit-product-if-exists, external/roboto-fonts/fonts.mk)

# Overrides
PRODUCT_BRAND := tiny
PRODUCT_DEVICE := tiny
PRODUCT_NAME := core_tiny
