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
# This file is included by other product makefiles to add all the
# emulator-related modules to PRODUCT_PACKAGES.
#

# Host modules
PRODUCT_PACKAGES += \


# Device modules
PRODUCT_PACKAGES += \
    egl.cfg \
    gralloc.goldfish \
    gralloc.goldfish.default \
    gralloc.ranchu \
    libGLESv1_CM_emulation \
    lib_renderControl_enc \
    libEGL_emulation \
    libGLES_android \
    libGLESv2_enc \
    libOpenglSystemCommon \
    libGLESv2_emulation \
    libGLESv1_enc \
    libEGL_swiftshader \
    libGLESv1_CM_swiftshader \
    libGLESv2_swiftshader \
    qemu-props \
    camera.goldfish \
    camera.goldfish.jpeg \
    camera.ranchu \
    camera.ranchu.jpeg \
    gatekeeper.ranchu \
    lights.goldfish \
    gps.goldfish \
    gps.ranchu \
    fingerprint.goldfish \
    sensors.goldfish \
    audio.primary.goldfish \
    audio.primary.goldfish_legacy \
    android.hardware.audio@2.0-service \
    android.hardware.wifi@1.0-service \
    vibrator.goldfish \
    power.goldfish \
    power.ranchu \
    fingerprint.ranchu \
    android.hardware.biometrics.fingerprint@2.1-service \
    sensors.ranchu \
    android.hardware.graphics.composer@2.1-impl \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.mapper@2.0-impl \
    hwcomposer.goldfish \
    hwcomposer.ranchu \
    sh_vendor \
    vintf \
    toybox_vendor \
    CarrierConfig \
    audio.primary.goldfish \
    audio.r_submix.default \
    local_time.default \
    SdkSetup

PRODUCT_PACKAGES += \
    android.hardware.audio@2.0-impl \
    android.hardware.audio.effect@2.0-impl \
    android.hardware.broadcastradio@1.1-service \
    android.hardware.broadcastradio@1.0-impl \
    android.hardware.soundtrigger@2.0-impl

PRODUCT_PACKAGES += \
    android.hardware.keymaster@3.0-impl \
    android.hardware.keymaster@3.0-service

PRODUCT_PACKAGES += \
    android.hardware.keymaster@4.0-strongbox-service

PRODUCT_PACKAGES += \
    android.hardware.gnss@1.0-service \
    android.hardware.gnss@1.0-impl

PRODUCT_PACKAGES += \
    android.hardware.sensors@1.0-impl \
    android.hardware.sensors@1.0-service

PRODUCT_PACKAGES += \
    android.hardware.drm@1.0-service \
    android.hardware.drm@1.0-impl

PRODUCT_PACKAGES += \
    android.hardware.power@1.0-service \
    android.hardware.power@1.0-impl

PRODUCT_PACKAGES += \
    camera.device@1.0-impl \
    android.hardware.camera.provider@2.4-service \
    android.hardware.camera.provider@2.4-impl \

PRODUCT_PACKAGES += \
    android.hardware.gatekeeper@1.0-impl \
    android.hardware.gatekeeper@1.0-service

# need this for gles libraries to load properly
# after moving to /vendor/lib/
PRODUCT_PACKAGES += \
    vndk-sp

# WiFi
PRODUCT_PACKAGES += \
	createns \
	dhcpclient \
	dhcpserver \
	execns \
	hostapd \
	ip \
	ipv6proxy \
	iw \
	wificond \
	wpa_supplicant \

PRODUCT_COPY_FILES += \
    device/generic/goldfish/data/etc/apns-conf.xml:data/misc/apns/apns-conf.xml \
    device/generic/goldfish/init.ranchu-core.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.ranchu-core.sh \
    device/generic/goldfish/init.ranchu-net.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.ranchu-net.sh \
    device/generic/goldfish/wifi/init.wifi.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.wifi.sh \
    device/generic/goldfish/init.ranchu.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.ranchu.rc \
    device/generic/goldfish/fstab.ranchu:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.ranchu \
    device/generic/goldfish/ueventd.ranchu.rc:$(TARGET_COPY_OUT_VENDOR)/ueventd.rc \
    device/generic/goldfish/input/goldfish_rotary.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/goldfish_rotary.idc \
    device/generic/goldfish/manifest.xml:$(TARGET_COPY_OUT_VENDOR)/manifest.xml \
    device/generic/goldfish/data/etc/permissions/privapp-permissions-goldfish.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/privapp-permissions-goldfish.xml \
    device/generic/goldfish/data/etc/config.ini:config.ini \
    device/generic/goldfish/wifi/simulated_hostapd.conf:$(TARGET_COPY_OUT_VENDOR)/etc/simulated_hostapd.conf \
    device/generic/goldfish/wifi/wpa_supplicant.conf:$(TARGET_COPY_OUT_VENDOR)/etc/wifi/wpa_supplicant.conf \
    device/generic/goldfish/wifi/WifiConfigStore.xml:data/misc/wifi/WifiConfigStore.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    device/generic/goldfish/data/etc/handheld_core_hardware.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.xml \
    device/generic/goldfish/camera/media_profiles.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_audio.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_audio.xml \
    frameworks/av/media/libstagefright/data/media_codecs_google_telephony.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_telephony.xml \
    device/generic/goldfish/camera/media_codecs_google_video.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_video.xml \
    device/generic/goldfish/camera/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    device/generic/goldfish/camera/media_codecs_performance.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_performance.xml \
    frameworks/native/data/etc/android.hardware.touchscreen.multitouch.jazzhand.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.touchscreen.multitouch.jazzhand.xml \
    frameworks/native/data/etc/android.hardware.camera.autofocus.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.autofocus.xml \
    frameworks/native/data/etc/android.hardware.camera.full.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.full.xml \
    frameworks/native/data/etc/android.hardware.fingerprint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.fingerprint.xml \
    frameworks/native/data/etc/android.software.autofill.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.autofill.xml \
    frameworks/av/media/libeffects/data/audio_effects.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.conf \
    device/generic/goldfish/audio_policy.conf:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy.conf


PRODUCT_PACKAGE_OVERLAYS := device/generic/goldfish/overlay

PRODUCT_CHARACTERISTICS := emulator

PRODUCT_FULL_TREBLE_OVERRIDE := true

#watchdog tiggers reboot because location service is not
#responding, disble it for now.
#still keep it on internal master as it is still working
#once it is fixed in aosp, remove this block of comment.
#PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
#config.disable_location=true

# Enable Perfetto traced
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.traced.enable=1

# enable Google-specific location features,
# like NetworkLocationProvider and LocationCollector
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.com.google.locationfeatures=1

# disable setupwizard
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.setupwizard.mode=DISABLED
