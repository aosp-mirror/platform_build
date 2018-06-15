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

# Base modules (will move elsewhere, previously user tagged)
PRODUCT_PACKAGES += \
    20-dns.conf \
    95-configured \
    am \
    android.hardware.cas@1.0-service \
    android.hardware.media.omx@1.0-service \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
    android.policy \
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
    content \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    dnsmasq \
    DownloadProvider \
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
    idmap \
    ime \
    ims-common \
    incident \
    incidentd \
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
    libneuralnetworks \
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
    mdnsd \
    media \
    media_cmd \
    mediadrmserver \
    mediaextractor \
    mediametrics \
    media_profiles_V1_0.dtd \
    MediaProvider \
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
    sensorservice \
    services \
    settings \
    SettingsProvider \
    sgdisk \
    Shell \
    sm \
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

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote32
PRODUCT_COPY_FILES += system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

# Packages included only for eng or userdebug builds, previously debug tagged
PRODUCT_PACKAGES_DEBUG := \
    iotop \
    logpersist.start \
    micro_bench \
    perfprofd \
    sqlite3 \
    strace

# Packages included only for eng/userdebug builds, when building with SANITIZE_TARGET=address
PRODUCT_PACKAGES_DEBUG_ASAN :=

PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/preloaded-classes:system/etc/preloaded-classes)

# Note: it is acceptable to not have a dirty-image-objects file. In that case, the special bin
#       for known dirty objects in the image will be empty.
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/dirty-image-objects:system/etc/dirty-image-objects)

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.zygote=zygote32
PRODUCT_COPY_FILES += \
    system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

$(call inherit-product, $(SRC_TARGET_DIR)/product/runtime_libart.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
