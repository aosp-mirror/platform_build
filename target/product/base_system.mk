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
    abb \
    adbd \
    am \
    android.hidl.allocator@1.0-service \
    android.hidl.base-V1.0-java \
    android.hidl.manager-V1.0-java \
    android.hidl.memory@1.0-impl \
    android.hidl.memory@1.0-impl.vendor \
    android.system.suspend@1.0-service \
    android.test.base \
    android.test.mock \
    android.test.runner \
    apexd \
    applypatch \
    appops \
    app_process \
    appwidget \
    ashmemd \
    atrace \
    audioserver \
    BackupRestoreConfirmation \
    bcc \
    blank_screen \
    blkid \
    bmgr \
    bootanimation \
    bootstat \
    bpfloader \
    bu \
    bugreport \
    bugreportz \
    cgroups.json \
    charger \
    cmd \
    com.android.conscrypt \
    com.android.location.provider \
    com.android.media \
    com.android.media.swcodec \
    com.android.resolv \
    com.android.tzdata \
    ContactsProvider \
    content \
    crash_dump \
    CtsShimPrebuilt \
    CtsShimPrivPrebuilt \
    debuggerd\
    device_config \
    dmctl \
    dnsmasq \
    DownloadProvider \
    dpm \
    dumpstate \
    dumpsys \
    DynamicSystemInstallationService \
    e2fsck \
    ExtServices \
    ExtShared \
    flags_health_check \
    framework \
    framework-res \
    framework-sysconfig.xml \
    fsck_msdos \
    fs_config_files_system \
    fs_config_dirs_system \
    gsid \
    gsi_tool \
    heapprofd \
    heapprofd_client \
    gatekeeperd \
    gpuservice \
    hid \
    hwservicemanager \
    idmap \
    idmap2 \
    idmap2d \
    ime \
    ims-common \
    incident \
    incidentd \
    incident_helper \
    init.environ.rc \
    init.rc \
    init_system \
    input \
    installd \
    iorapd \
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
    libartpalette-system \
    libashmemd_client \
    libaudioeffect_jni \
    libbinder \
    libbinder_ndk \
    libc.bootstrap \
    libcamera2ndk \
    libc_malloc_debug \
    libc_malloc_hooks \
    libcutils \
    libdl.bootstrap \
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
    libm.bootstrap \
    libmdnssd \
    libmedia \
    libmedia_jni \
    libmediandk \
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
    libsfplugin_ccodec \
    libskia \
    libsonic \
    libsonivox \
    libsoundpool \
    libspeexresampler \
    libsqlite \
    libstagefright \
    libstagefright_amrnb_common \
    libstagefright_enc_common \
    libstagefright_foundation \
    libstagefright_omx \
    libstdc++ \
    libsurfaceflinger \
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
    LocalTransport \
    locksettings \
    logcat \
    logd \
    lpdump \
    lshal \
    mdnsd \
    media \
    mediacodec.policy \
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
    NetworkStack \
    org.apache.http.legacy \
    PackageInstaller \
    perfetto \
    PermissionController \
    ping \
    ping6 \
    platform.xml \
    pm \
    pppd \
    privapp-permissions-platform.xml \
    racoon \
    recovery-persist \
    resize2fs \
    rss_hwm_reset \
    run-as \
    schedtest \
    screencap \
    sdcard \
    secdiscard \
    SecureElement \
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
    statsd \
    storaged \
    surfaceflinger \
    svc \
    task_profiles.json \
    tc \
    telecom \
    telephony-common \
    tombstoned \
    traced \
    traced_probes \
    tune2fs \
    tzdatacheck \
    uiautomator \
    uncrypt \
    usbd \
    vdc \
    viewcompiler \
    voip-common \
    vold \
    WallpaperBackup \
    watchdogd \
    wificond \
    wifi-service \
    wm \

# VINTF data for system image
PRODUCT_PACKAGES += \
    system_manifest.xml \
    system_compatibility_matrix.xml \

# Host tools to install
PRODUCT_HOST_PACKAGES += \
    BugReport \
    adb \
    art-tools \
    atest \
    bcc \
    bit \
    e2fsck \
    fastboot \
    flags_health_check \
    icu-data_host_runtime_apex \
    idmap2 \
    incident_report \
    ld.mc \
    lpdump \
    mdnsd \
    minigzip \
    mke2fs \
    resize2fs \
    sgdisk \
    sqlite3 \
    tinyplay \
    tune2fs \
    tzdatacheck \
    unwind_info \
    unwind_reg_info \
    unwind_symbols \
    viewcompiler \
    tzdata_host \
    tzdata_host_runtime_apex \
    tzlookup.xml_host_runtime_apex \
    tz_version_host \
    tz_version_host_runtime_apex \

ifeq ($(TARGET_CORE_JARS),)
$(error TARGET_CORE_JARS is empty; cannot initialize PRODUCT_BOOT_JARS variable)
endif

# The order matters for runtime class lookup performance.
PRODUCT_BOOT_JARS := \
    $(TARGET_CORE_JARS) \
    framework \
    ext \
    telephony-common \
    voip-common \
    ims-common \
    updatable-media
PRODUCT_UPDATABLE_BOOT_MODULES := conscrypt updatable-media
PRODUCT_UPDATABLE_BOOT_LOCATIONS := \
    /apex/com.android.conscrypt/javalib/conscrypt.jar \
    /apex/com.android.media/javalib/updatable-media.jar


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
    arping \
    gdbserver \
    init-debug.rc \
    iotop \
    iw \
    logpersist.start \
    logtagd.rc \
    procrank \
    showmap \
    sqlite3 \
    ss \
    strace \
    su \
    sanitizer-status \
    tracepath \
    tracepath6 \
    traceroute6 \
    unwind_info \
    unwind_reg_info \
    unwind_symbols \

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
