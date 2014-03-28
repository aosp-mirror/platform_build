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
    DownloadProvider \
    HTMLViewer \
    MediaProvider \
    PackageInstaller \
    SettingsProvider \
    Shell \
    bu \
    com.android.location.provider \
    com.android.location.provider.xml \
    com.android.media.remotedisplay \
    com.android.media.remotedisplay.xml \
    drmserver \
    framework-res \
    idmap \
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
    libdrmframework \
    libdrmframework_jni \
    libfilterfw \
    libsqlite_jni \
    libwilhelm \
    logd \
    make_ext4fs \
    screencap \
    sensorservice \
    uiautomator

# The order of PRODUCT_BOOT_JARS matters.
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
    apache-xml \
    webviewchromium

PRODUCT_RUNTIMES := runtime_libart_default
PRODUCT_RUNTIMES += runtime_libdvm

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote32
PRODUCT_COPY_FILES += \
    system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
