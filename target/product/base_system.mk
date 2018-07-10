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
    adb \
    adbd \
    am \
    android.hidl.allocator@1.0-service \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
    android.hidl.memory@1.0-impl \
    android.hidl.memory@1.0-impl.vendor \
    android.test.mock \
    android.test.runner \
    applypatch \
    appops \
    app_process \
    appwidget \
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
    libdrmframework \
    libdrmframework_jni \
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
    libstagefright_enc_common \
    libstagefright_foundation \
    libstagefright_omx \
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
    selinux_policy_system \
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

PRODUCT_COPY_FILES += \
    system/core/rootdir/init.usb.rc:root/init.usb.rc \
    system/core/rootdir/init.usb.configfs.rc:root/init.usb.configfs.rc \
    system/core/rootdir/ueventd.rc:root/ueventd.rc \
    system/core/rootdir/etc/hosts:system/etc/hosts

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += ro.zygote=zygote32
PRODUCT_COPY_FILES += system/core/rootdir/init.zygote32.rc:root/init.zygote32.rc

# Ensure that this property is always defined so that bionic_systrace.cpp
# can rely on it being initially set by init.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    debug.atrace.tags.enableflags=0

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
