#
# Copyright (C) 2012 The Android Open Source Project
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

PRODUCT_PACKAGES += \
    20-dns.conf \
    95-configured \
    am \
    android.hardware.cas@1.0-service \
    android.hardware.media.omx@1.0-service \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
    android.policy \
    android.test.base \
    android.test.mock \
    android.test.runner \
    applypatch \
    appops \
    app_process \
    appwidget \
    audioserver \
    BackupRestoreConfirmation \
    bcc \
    bit \
    blkid \
    bmgr \
    bpfloader \
    bu \
    bugreport \
    bugreportz \
    cameraserver \
    com.android.location.provider \
    com.android.location.provider.xml \
    content \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    dnsmasq \
    dpm \
    e2fsck \
    ExtServices \
    ExtShared \
    framework \
    framework-res \
    framework-sysconfig.xml \
    fsck_msdos \
    gatekeeperd \
    hid \
    ime \
    ims-common \
    incident \
    incidentd \
    incident_helper \
    incident_report \
    input \
    installd \
    ip \
    ip6tables \
    iptables \
    ip-up-vpn \
    javax.obex \
    keystore \
    ld.config.txt \
    ld.config.recovery.txt \
    ld.mc \
    libaaudio \
    libandroid \
    libandroid_runtime \
    libandroid_servers \
    libaudioeffect_jni \
    libaudioflinger \
    libaudiopolicymanager \
    libaudiopolicyservice \
    libbundlewrapper \
    libcamera2ndk \
    libcamera_client \
    libcameraservice \
    libclearkeycasplugin \
    libdownmix \
    libdrmclearkeyplugin \
    libdrmframework \
    libdrmframework_jni \
    libdynproc \
    libeffectproxy \
    libeffects \
    libfilterfw \
    libgatekeeper \
    libinput \
    libinputflinger \
    libiprouteutil \
    libjnigraphics \
    libkeystore \
    libldnhncr \
    libmedia \
    libmedia_jni \
    libmediandk \
    libmediaplayerservice \
    libmtp \
    libnetd_client \
    libnetlink \
    libnetutils \
    libOpenMAXAL \
    libOpenSLES \
    libpdfium \
    libradio_metadata \
    libreference-ril \
    libreverbwrapper \
    libril \
    librtp_jni \
    libsensorservice \
    libskia \
    libsonic \
    libsonivox \
    libsoundpool \
    libsoundtrigger \
    libsoundtriggerservice \
    libsqlite \
    libstagefright \
    libstagefright_amrnb_common \
    libstagefright_avc_common \
    libstagefright_enc_common \
    libstagefright_foundation \
    libstagefright_omx \
    libstagefright_yuv \
    libusbhost \
    libvisualizer \
    libvorbisidec \
    libvulkan \
    libwifi-service \
    libwilhelm \
    locksettings \
    logd \
    media \
    media_cmd \
    media_profiles_V1_0.dtd \
    mediadrmserver \
    mediaextractor \
    mediametrics \
    mediaserver \
    mke2fs \
    monkey \
    mtpd \
    ndc \
    netd \
    org.apache.http.legacy \
    perfetto \
    ping \
    ping6 \
    platform.xml \
    pm \
    pppd \
    privapp-permissions-platform.xml \
    racoon \
    resize2fs \
    run-as \
    schedtest \
    screencap \
    sdcard \
    secdiscard \
    SecureElement \
    sensorservice \
    services \
    settings \
    SettingsProvider \
    sgdisk \
    Shell \
    sm \
    statsd \
    svc \
    tc \
    telecom \
    telephony-common \
    traced \
    traced_probes \
    tune2fs \
    uiautomator \
    uncrypt \
    vdc \
    voip-common \
    vold \
    WallpaperBackup \
    wificond \
    wifi-service \
    wm \


ifeq ($(TARGET_CORE_JARS),)
$(error TARGET_CORE_JARS is empty; cannot initialize PRODUCT_BOOT_JARS variable)
endif

# The order matters
PRODUCT_BOOT_JARS := \
    $(TARGET_CORE_JARS) \
    ext \
    framework \
    telephony-common \
    voip-common \
    ims-common \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java

# Add the compatibility library that is needed when org.apache.http.legacy
# is removed from the bootclasspath.
ifeq ($(REMOVE_OAHL_FROM_BCP),true)
PRODUCT_PACKAGES += framework-oahl-backward-compatibility
PRODUCT_BOOT_JARS += framework-oahl-backward-compatibility
else
PRODUCT_BOOT_JARS += org.apache.http.legacy.impl
endif

# Add the compatibility library that is needed when android.test.base
# is removed from the bootclasspath.
ifeq ($(REMOVE_ATB_FROM_BCP),true)
PRODUCT_PACKAGES += framework-atb-backward-compatibility
PRODUCT_BOOT_JARS += framework-atb-backward-compatibility
else
PRODUCT_BOOT_JARS += android.test.base
endif

PRODUCT_COPY_FILES += system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote32

# Packages included only for eng or userdebug builds, previously debug tagged
PRODUCT_PACKAGES_DEBUG := \
    iotop \
    logpersist.start \
    micro_bench \
    perfprofd \
    sqlite3 \
    strace

# The set of packages whose code can be loaded by the system server.
PRODUCT_SYSTEM_SERVER_APPS += \
    SettingsProvider \
    WallpaperBackup

# Packages included only for eng/userdebug builds, when building with SANITIZE_TARGET=address
PRODUCT_PACKAGES_DEBUG_ASAN :=

PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/preloaded-classes:system/etc/preloaded-classes)

# Note: it is acceptable to not have a dirty-image-objects file. In that case, the special bin
#       for known dirty objects in the image will be empty.
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/dirty-image-objects:system/etc/dirty-image-objects)

$(call inherit-product, $(SRC_TARGET_DIR)/product/runtime_libart.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
