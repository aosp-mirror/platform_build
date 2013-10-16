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
    android.policy \
    android.test.runner \
    app_process \
    applypatch \
    blkid \
    bmgr \
    bugreport \
    content \
    dhcpcd \
    dhcpcd-run-hooks \
    dnsmasq \
    framework \
    fsck_msdos \
    ime \
    javax.obex \
    libSR_AudioIn \
    libandroid \
    libandroid_runtime \
    libandroid_servers \
    libaudioeffect_jni \
    libaudioflinger \
    libbundlewrapper \
    libcamera_client \
    libcameraservice \
    libdl \
    libeffectproxy \
    libeffects \
    libinput \
    libiprouteutil \
    libjni_latinime \
    libjnigraphics \
    libldnhncr \
    libmedia \
    libmedia_jni \
    libmediaplayerservice \
    libmtp \
    libnetlink \
    libnetutils \
    libpac \
    libreference-ril \
    libreverbwrapper \
    libril \
    librtp_jni \
    libsensorservice \
    libskia \
    libsonivox \
    libsoundpool \
    libsqlite \
    libstagefright \
    libstagefright_amrnb_common \
    libstagefright_avc_common \
    libstagefright_enc_common \
    libstagefright_foundation \
    libstagefright_omx \
    libstagefright_yuv \
    libusbhost \
    libutils \
    libvisualizer \
    libvorbisidec \
    libwpa_client \
    media \
    media_cmd \
    mediaserver \
    monkey \
    mtpd \
    ndc \
    netcfg \
    netd \
    ping \
    ping6 \
    platform.xml \
    pppd \
    pm \
    racoon \
    run-as \
    schedtest \
    screenshot \
    sdcard \
    services \
    settings \
    svc \
    tc \
    vdc \
    vold \
    webview \
    wm


$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
