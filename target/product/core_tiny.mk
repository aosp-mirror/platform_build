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
    BackupRestoreConfirmation \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    DefaultContainerService \
    ExtShared \
    ExtServices \
    SettingsProvider \
    Shell \
    WallpaperBackup \
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
    nullwebview \
    screencap \
    sensorservice \
    uiautomator \
    uncrypt \
    telephony-common \
    voip-common \
    logd \
    wifi-service

# The order matters
PRODUCT_BOOT_JARS := \
    core-oj \
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
    apache-xml \
    nullwebview \
    org.apache.http.legacy.boot

# The order of PRODUCT_SYSTEM_SERVER_JARS matters.
PRODUCT_SYSTEM_SERVER_JARS := \
    services \
    wifi-service

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote32
PRODUCT_COPY_FILES += \
    system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

PRODUCT_PROPERTY_OVERRIDES += \
    ro.carrier=unknown

# Different dexopt types for different package update/install times.
# On eng builds, make "boot" reasons do pure JIT for faster turnaround.
ifeq (eng,$(TARGET_BUILD_VARIANT))
    PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
        pm.dexopt.first-boot=verify-at-runtime \
        pm.dexopt.boot=verify-at-runtime
else
    PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
        pm.dexopt.first-boot=interpret-only \
        pm.dexopt.boot=verify-profile
endif
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    pm.dexopt.install=interpret-only \
    pm.dexopt.bg-dexopt=speed-profile \
    pm.dexopt.ab-ota=speed-profile \
    pm.dexopt.nsys-library=speed \
    pm.dexopt.shared-apk=speed \
    pm.dexopt.forced-dexopt=speed \
    pm.dexopt.core-app=speed

$(call inherit-product, $(SRC_TARGET_DIR)/product/runtime_libart.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product-if-exists, frameworks/base/data/fonts/fonts.mk)
$(call inherit-product-if-exists, external/roboto-fonts/fonts.mk)

# Overrides
PRODUCT_BRAND := tiny
PRODUCT_DEVICE := tiny
PRODUCT_NAME := core_tiny
