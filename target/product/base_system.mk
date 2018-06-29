#
# Copyright (C) 2018 The Android Open Source Project
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

# Base modules and settings for the system partition.
PRODUCT_PACKAGES += \
    20-dns.conf \
    95-configured \
    adb \
    adbd \
    am \
    android.hidl.allocator@1.0-service \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
    android.hidl.memory@1.0-impl \
    android.hidl.memory@1.0-impl.vendor \
    android.policy \
    android.test.base \
    android.test.mock \
    android.test.runner \
    applypatch \
    appops \
    app_process \
    appwidget \
    atest \
    atrace \
    audioserver \
    BackupRestoreConfirmation \
    bcc \
    bit \
    blank_screen \
    blkid \
    bmgr \
    bootanimation \
    bootstat \
    bpfloader \
    bu \
    bugreport \
    bugreportz \
    cameraserver \
    charger \
    cmd \
    com.android.location.provider \
    ContactsProvider \
    content \
    crash_dump \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    debuggerd\
    DefaultContainerService \
    dnsmasq \
    DownloadProvider \
    dpm \
    dumpstate \
    dumpsys \
    e2fsck \
    ExtServices \
    ExtShared \
    fastboot \
    framework \
    framework-res \
    framework-sysconfig.xml \
    fsck_msdos \
    fs_config_files_system \
    fs_config_dirs_system \
    gatekeeperd \
    healthd \
    hid \
    hwservicemanager \
    idmap \
    ime \
    ims-common \
    incident \
    incidentd \
    incident_helper \
    incident_report \
    init \
    init.environ.rc \
    init.rc \
    input \
    installd \
    ip \
    ip6tables \
    iptables \
    ip-up-vpn \
    javax.obex \
    keystore \
    ld.config.txt \
    ld.mc \
    libaaudio \
    libamidi \
    libandroid \
    libandroidfw \
    libandroid_runtime \
    libandroid_servers \
    libaudioeffect_jni \
    libaudioflinger \
    libaudiopolicymanager \
    libaudiopolicyservice \
    libaudioutils \
    libbinder \
    libc \
    libcamera2ndk \
    libcamera_client \
    libcameraservice \
    libc_malloc_debug \
    libc_malloc_hooks \
    libcutils \
    libdl \
    libdrmclearkeyplugin \
    libdrmframework \
    libdrmframework_jni \
    libdynproc \
    libEGL \
    libETC1 \
    libFFTEm \
    libfilterfw \
    libgatekeeper \
    libGLESv1_CM \
    libGLESv2 \
    libGLESv3 \
    libgui \
    libhardware \
    libhardware_legacy \
    libinput \
    libinputflinger \
    libiprouteutil \
    libjnigraphics \
    libjpeg \
    libkeystore \
    liblog \
    libm \
    libmdnssd \
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
    libpixelflinger \
    libpower \
    libpowermanager \
    libradio_metadata \
    librtp_jni \
    libsensorservice \
    libsigchain \
    libskia \
    libsonic \
    libsonivox \
    libsoundpool \
    libsoundtrigger \
    libsoundtriggerservice \
    libspeexresampler \
    libsqlite \
    libstagefright \
    libstagefright_amrnb_common \
    libstagefright_avc_common \
    libstagefright_enc_common \
    libstagefright_foundation \
    libstagefright_omx \
    libstagefright_yuv \
    libstdc++ \
    libsurfaceflinger \
    libsurfaceflinger_ddmconnection \
    libsysutils \
    libui \
    libusbhost \
    libutils \
    libvorbisidec \
    libvulkan \
    libwifi-service \
    libwilhelm \
    linker \
    lmkd \
    locksettings \
    logcat \
    logd \
    lshal \
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
    SecureElement \
    selinux_policy \
    sensorservice \
    service \
    servicemanager \
    services \
    settings \
    SettingsProvider \
    sgdisk \
    Shell \
    shell_and_utilities_system \
    sm \
    statsd \
    storaged \
    surfaceflinger \
    svc \
    tc \
    telecom \
    telephony-common \
    thermalserviced \
    tombstoned \
    traced \
    traced_probes \
    tune2fs \
    tzdatacheck \
    uiautomator \
    uncrypt \
    usbd \
    vdc \
    voip-common \
    vold \
    WallpaperBackup \
    wificond \
    wifi-service \
    wm \

# VINTF data
PRODUCT_PACKAGES += \
    device_manifest.xml \
    framework_manifest.xml \
    framework_compatibility_matrix.xml \

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

PRODUCT_COPY_FILES += \
    system/core/rootdir/init.usb.rc:root/init.usb.rc \
    system/core/rootdir/init.usb.configfs.rc:root/init.usb.configfs.rc \
    system/core/rootdir/ueventd.rc:root/ueventd.rc \
    system/core/rootdir/etc/hosts:system/etc/hosts

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

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += debug.atrace.tags.enableflags=0

# Packages included only for eng or userdebug builds, previously debug tagged
PRODUCT_PACKAGES_DEBUG := \
    adb_keys \
    iotop \
    logpersist.start \
    micro_bench \
    perfprofd \
    procrank \
    showmap \
    sqlite3 \
    strace \
    sanitizer-status

# The set of packages whose code can be loaded by the system server.
PRODUCT_SYSTEM_SERVER_APPS += \
    SettingsProvider \
    WallpaperBackup

# Packages included only for eng/userdebug builds, when building with SANITIZE_TARGET=address
PRODUCT_PACKAGES_DEBUG_ASAN := \
    fuzz \
    honggfuzz

PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/preloaded-classes:system/etc/preloaded-classes)

# Note: it is acceptable to not have a dirty-image-objects file. In that case, the special bin
#       for known dirty objects in the image will be empty.
PRODUCT_COPY_FILES += $(call add-to-product-copy-files-if-exists,\
    frameworks/base/config/dirty-image-objects:system/etc/dirty-image-objects)

$(call inherit-product, $(SRC_TARGET_DIR)/product/runtime_libart.mk)
