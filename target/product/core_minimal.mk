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

# Base configuration for most consumer android devices.  Do not put
# things that are specific to communication devices (phones, tables,
# etc.) here -- for that, use core.mk.

PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := core

PRODUCT_PACKAGES += \
    BackupRestoreConfirmation \
    CompanionDeviceManager \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    DownloadProvider \
    ExtShared \
    ExtServices \
    HTMLViewer \
    MediaProvider \
    PackageInstaller \
    SettingsProvider \
    Shell \
    StatementService \
    WallpaperBackup \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
    bcc \
    bu \
    com.android.future.usb.accessory \
    com.android.location.provider \
    com.android.location.provider.xml \
    com.android.media.remotedisplay \
    com.android.media.remotedisplay.xml \
    com.android.mediadrm.signer \
    com.android.mediadrm.signer.xml \
    drmserver \
    ethernet-service \
    framework-res \
    idmap \
    installd \
    ims-common \
    ip \
    ip-up-vpn \
    ip6tables \
    iptables \
    gatekeeperd \
    keystore \
    keystore.default \
    ld.config.txt \
    ld.mc \
    libaaudio \
    libOpenMAXAL \
    libOpenSLES \
    libdownmix \
    libdrmframework \
    libdrmframework_jni \
    libfilterfw \
    libkeystore \
    libgatekeeper \
    libwebviewchromium_loader \
    libwebviewchromium_plat_support \
    libwilhelm \
    logd \
    make_ext4fs \
    e2fsck \
    resize2fs \
    tune2fs \
    screencap \
    sensorservice \
    telephony-common \
    uiautomator \
    uncrypt \
    voip-common \
    webview \
    webview_zygote \

# Wifi modules
PRODUCT_PACKAGES += \
    wifi-service \
    wificond \

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.webview.xml:system/etc/permissions/android.software.webview.xml

ifneq (REL,$(PLATFORM_VERSION_CODENAME))
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.software.preview_sdk.xml:system/etc/permissions/android.software.preview_sdk.xml
endif

# The order of PRODUCT_BOOT_JARS matters.
PRODUCT_BOOT_JARS := \
    core-oj \
    core-libart \
    conscrypt \
    okhttp \
    legacy-test \
    bouncycastle \
    ext \
    framework \
    telephony-common \
    voip-common \
    ims-common \
    apache-xml \
    org.apache.http.legacy.boot \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java

# The order of PRODUCT_SYSTEM_SERVER_JARS matters.
PRODUCT_SYSTEM_SERVER_JARS := \
    services \
    ethernet-service \
    wifi-service

# The set of packages whose code can be loaded by the system server.
PRODUCT_SYSTEM_SERVER_APPS += \
    SettingsProvider \
    WallpaperBackup

# Adoptable external storage supports both ext4 and f2fs
PRODUCT_PACKAGES += \
    e2fsck \
    make_ext4fs \
    fsck.f2fs \
    make_f2fs \

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote32
PRODUCT_COPY_FILES += \
    system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

PRODUCT_COPY_FILES += \
    system/core/rootdir/etc/public.libraries.android.txt:system/etc/public.libraries.txt

# Enable boot.oat filtering of compiled classes to reduce boot.oat size. b/28026683
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/compiled-classes-phone:system/etc/compiled-classes)

$(call inherit-product, $(SRC_TARGET_DIR)/product/runtime_libart.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
