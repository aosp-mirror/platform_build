#
# Copyright (C) 2007 The Android Open Source Project
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

PRODUCT_BRAND := generic
PRODUCT_DEVICE := generic
PRODUCT_NAME := core

PRODUCT_PROPERTY_OVERRIDES := \
    ro.config.notification_sound=OnTheHunt.ogg \
    ro.config.alarm_alert=Alarm_Classic.ogg

# Core modules (will move elsewhere)
PRODUCT_PACKAGES := \
    20-dns.conf \
    95-configured \
    adb \
    adbd \
    am \
    android.policy \
    android.test.runner \
    app_process \
    applypatch \
    bmgr \
    bootanimation \
    bugreport \
    dbus-daemon \
    debuggerd \
    dhcpcd \
    dhcpcd-run-hooks \
    dnsmasq \
    dumpstate \
    dumpsys \
    framework \
    fsck_msdos \
    gralloc.default \
    gzip \
    ime \
    init \
    input \
    javax.obex \
    keystore \
    libEGL \
    libETC1 \
    libFFTEm \
    libGLES_android \
    libGLESv1_CM \
    libGLESv2 \
    libSR_AudioIn \
    libandroid \
    libandroid_runtime \
    libandroid_servers \
    libaudioeffect_jni \
    libaudioflinger \
    libbinder \
    libbundlewrapper \
    libc \
    libcamera_client \
    libcameraservice \
    libchromium_net \
    libctest \
    libcutils \
    libdbus \
    libdl \
    libdrm1 \
    libdrm1_jni \
    libeffects \
    libexif \
    libgui \
    libhardware \
    libhardware_legacy \
    libiprouteutil \
    libjni_latinime \
    libjnigraphics \
    libjpeg \
    liblog \
    libm \
    libmedia \
    libmedia_jni \
    libmediaplayerservice \
    libmtp \
    libnetlink \
    libnetutils \
    libpixelflinger \
    libpower \
    libreference-ril \
    libreverbwrapper \
    libril \
    librtp_jni \
    libsensorservice \
    libskia \
    libsonivox \
    libsoundpool \
    libsqlite \
    libsrec_jni \
    libstagefright \
    libstagefright_amrnb_common \
    libstagefright_avc_common \
    libstagefright_enc_common \
    libstagefright_foundation \
    libstagefright_omx \
    libstagefright_yuv \
    libstdc++ \
    libstlport \
    libsurfaceflinger \
    libsurfaceflinger_client \
    libsystem_server \
    libsysutils \
    libthread_db \
    libui \
    libusbhost \
    libutils \
    libvisualizer \
    libvorbisidec \
    libwebcore \
    libwpa_client \
    linker \
    logcat \
    logwrapper \
    mediaserver \
    monkey \
    mtpd \
    ndc \
    netcfg \
    netd \
    omx_tests \
    ping \
    platform.xml \
    pppd \
    pm \
    racoon \
    rild \
    run-as \
    schedtest \
    screenshot \
    sdcard \
    service \
    servicemanager \
    services \
    simg2img \
    surfaceflinger \
    svc \
    system_server \
    tc \
    toolbox \
    vdc \
    vold

PRODUCT_PACKAGES += \
    ApplicationsProvider \
    BackupRestoreConfirmation \
    Browser \
    Contacts \
    ContactsProvider \
    DefaultContainerService \
    DownloadProvider \
    DownloadProviderUi \
    HTMLViewer \
    Home \
    KeyChain \
    MediaProvider \
    PackageInstaller \
    PicoTts \
    SettingsProvider \
    SharedStorageBackup \
    TelephonyProvider \
    UserDictionaryProvider \
    VpnDialogs \
    apache-xml \
    atrace \
    bouncycastle \
    bu \
    cacerts \
    com.android.location.provider \
    com.android.location.provider.xml \
    core \
    core-junit \
    dalvikvm \
    dexdeps \
    dexdump \
    dexlist \
    dexopt \
    dmtracedump \
    drmserver \
    dx \
    ext \
    framework-res \
    hprof-conv \
    icu.dat \
    installd \
    ip \
    ip-up-vpn \
    ip6tables \
    iptables \
    keystore \
    keystore.default \
    libandroidfw \
    libOpenMAXAL \
    libOpenSLES \
    libaudiopreprocessing \
    libaudioutils \
    libcrypto \
    libdownmix \
    libdvm \
    libdrmframework \
    libdrmframework_jni \
    libexpat \
    libfilterfw \
    libfilterpack_imageproc \
    libgabi++ \
    libicui18n \
    libicuuc \
    libjavacore \
    libkeystore \
    libmdnssd \
    libnativehelper \
    libnfc_ndef \
    libpowermanager \
    libspeexresampler \
    libsqlite_jni \
    libssl \
    libstagefright_soft_aacdec \
    libstagefright_soft_aacenc \
    libstagefright_soft_amrdec \
    libstagefright_soft_amrnbenc \
    libstagefright_soft_amrwbenc \
    libstagefright_soft_flacenc \
    libstagefright_soft_g711dec \
    libstagefright_soft_h264dec \
    libstagefright_soft_h264enc \
    libstagefright_soft_mp3dec \
    libstagefright_soft_mpeg4dec \
    libstagefright_soft_mpeg4enc \
    libstagefright_soft_vorbisdec \
    libstagefright_soft_vpxdec \
    libstagefright_soft_rawdec \
    libvariablespeed \
    libwebrtc_audio_preprocessing \
    libwilhelm \
    libz \
    mdnsd \
    requestsync \
    screencap \
    sensorservice \
    lint \
    uiautomator \
    telephony-common \
    mms-common \
    zoneinfo.dat \
    zoneinfo.idx \
    zoneinfo.version

PRODUCT_COPY_FILES += \
    system/core/rootdir/init.usb.rc:root/init.usb.rc \
    system/core/rootdir/init.trace.rc:root/init.trace.rc \

# host-only dependencies
ifeq ($(WITH_HOST_DALVIK),true)
    PRODUCT_PACKAGES += \
        apache-xml-hostdex \
        bouncycastle-hostdex \
        core-hostdex \
        libcrypto \
        libexpat \
        libicui18n \
        libicuuc \
        libjavacore \
        libssl \
        libz-host \
        dalvik \
        zoneinfo-host.dat \
        zoneinfo-host.idx \
        zoneinfo-host.version
endif

ifeq ($(HAVE_SELINUX),true)
    PRODUCT_PACKAGES += \
        sepolicy \
        file_contexts \
        seapp_contexts \
        property_contexts \
        mac_permissions.xml
endif
