#
# Copyright (C) 2017 The Android Open-Source Project
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

# Split selinux policy
PRODUCT_FULL_TREBLE_OVERRIDE := true

# HAL interfaces:
#   Some of HAL interface libraries are automatically added by the dependencies
#   from the framework. However, we list them all here to make it explicit and
#   prevent possible mistake.
PRODUCT_PACKAGES := \
    android.frameworks.displayservice@1.0 \
    android.frameworks.schedulerservice@1.0 \
    android.frameworks.sensorservice@1.0 \
    android.frameworks.vr.composer@1.0 \
    android.hardware.audio@2.0 \
    android.hardware.audio.common@2.0 \
    android.hardware.audio.common@2.0-util \
    android.hardware.audio.effect@2.0 \
    android.hardware.automotive.evs@1.0 \
    android.hardware.automotive.vehicle@2.0 \
    android.hardware.automotive.vehicle@2.0-manager-lib-shared \
    android.hardware.automotive.vehicle@2.1 \
    android.hardware.biometrics.fingerprint@2.1 \
    android.hardware.bluetooth@1.0 \
    android.hardware.boot@1.0 \
    android.hardware.broadcastradio@1.0 \
    android.hardware.broadcastradio@1.1 \
    android.hardware.camera.common@1.0 \
    android.hardware.camera.device@1.0 \
    android.hardware.camera.device@3.2 \
    android.hardware.camera.metadata@3.2 \
    android.hardware.camera.provider@2.4 \
    android.hardware.configstore-utils \
    android.hardware.configstore@1.0 \
    android.hardware.contexthub@1.0 \
    android.hardware.drm@1.0 \
    android.hardware.dumpstate@1.0 \
    android.hardware.gatekeeper@1.0 \
    android.hardware.gnss@1.0 \
    android.hardware.graphics.allocator@2.0 \
    android.hardware.graphics.bufferqueue@1.0 \
    android.hardware.graphics.common@1.0 \
    android.hardware.graphics.composer@2.1 \
    android.hardware.graphics.mapper@2.0 \
    android.hardware.health@1.0 \
    android.hardware.ir@1.0 \
    android.hardware.keymaster@3.0 \
    android.hardware.light@2.0 \
    android.hardware.media@1.0 \
    android.hardware.media.omx@1.0-utils \
    android.hardware.media.omx@1.0 \
    android.hardware.memtrack@1.0 \
    android.hardware.nfc@1.0 \
    android.hardware.oemlock@1.0 \
    android.hardware.power@1.0 \
    android.hardware.radio@1.0 \
    android.hardware.radio.deprecated@1.0 \
    android.hardware.sensors@1.0 \
    android.hardware.soundtrigger@2.0 \
    android.hardware.tetheroffload.config@1.0 \
    android.hardware.tetheroffload.control@1.0 \
    android.hardware.thermal@1.0 \
    android.hardware.tv.cec@1.0 \
    android.hardware.tv.input@1.0 \
    android.hardware.usb@1.0 \
    android.hardware.usb@1.1 \
    android.hardware.vibrator@1.0 \
    android.hardware.vr@1.0 \
    android.hardware.weaver@1.0 \
    android.hardware.wifi@1.0 \
    android.hardware.wifi@1.1 \
    android.hardware.wifi.supplicant@1.0 \
    android.hidl.allocator@1.0 \
    android.hidl.manager@1.0 \
    android.hidl.memory@1.0 \
    android.hidl.token@1.0 \
    android.system.net.netd@1.0 \
    android.system.wifi.keystore@1.0 \

# VNDK:
#   Some VNDK shared objects are automatically included indirectly.
#   We list them all here to make it explicit and prevent possible mistakes.
#   An example of one such mistake was libcurl, which is included in A/B
#   devices because of update_engine, but not in non-A/B devices.
PRODUCT_PACKAGES += \
    libaudioroute \
    libaudioutils \
    libbinder \
    libcamera_metadata \
    libcap \
    libcrypto \
    libcrypto_utils \
    libcups \
    libcurl \
    libdiskconfig \
    libdumpstateutil \
    libevent \
    libexif \
    libexpat \
    libfmq \
    libgatekeeper \
    libgui \
    libhardware_legacy \
    libhidlmemory \
    libicui18n \
    libicuuc \
    libjpeg \
    libkeymaster1 \
    libkeymaster_messages \
    libldacBT_abr \
    libldacBT_enc \
    liblz4 \
    liblzma \
    libmdnssd \
    libmemtrack \
    libmemunreachable \
    libmetricslogger \
    libminijail \
    libnetutils \
    libnl \
    libopus \
    libpagemap \
    libpcap \
    libpcre2 \
    libpcrecpp \
    libpdfium \
    libpiex \
    libpower \
    libprocessgroup \
    libprocinfo \
    libprotobuf-cpp-full \
    libprotobuf-cpp-lite \
    libradio_metadata \
    libsoftkeymasterdevice \
    libsonic \
    libsonivox \
    libspeexresampler \
    libsqlite \
    libssl \
    libsuspend \
    libsysutils \
    libtinyalsa \
    libtinyxml2 \
    libui \
    libusbhost \
    libvixl-arm \
    libvixl-arm64 \
    libvorbisidec \
    libwebrtc_audio_preprocessing \
    libxml2 \
    libyuv \
    libziparchive \

# VNDK-SP:
PRODUCT_PACKAGES += \
    vndk-sp \

# LL-NDK:
PRODUCT_PACKAGES += \
    libandroid_net \
    libc \
    libdl \
    liblog \
    libm \
    libstdc++ \
    libvndksupport \
    libz \

# SP-NDK:
PRODUCT_PACKAGES += \
    libEGL \
    libGLESv1_CM \
    libGLESv2 \
    libGLESv3 \
    libnativewindow \
    libsync \
    libvulkan \

# Audio:
USE_XML_AUDIO_POLICY_CONF := 1
# The following policy XML files are used as fallback for
# vendors/devices not using XML to configure audio policy.
PRODUCT_COPY_FILES += \
    frameworks/av/services/audiopolicy/config/audio_policy_configuration_generic.xml:system/etc/audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/primary_audio_policy_configuration.xml:system/etc/primary_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:system/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/audio_policy_volumes.xml:system/etc/audio_policy_volumes.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:system/etc/default_volume_tables.xml \

# Bluetooth:
#   audio.a2dp.default is a system module. Generic system image includes
#   audio.a2dp.default to support A2DP if board has the capability.
PRODUCT_PACKAGES += \
    audio.a2dp.default
