#
# Copyright (C) 2009 The Android Open Source Project
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

# This is a build configuration for a very minimal build of the
# Open-Source part of the tree.

PRODUCT_PACKAGES += \
    adb \
    adbd \
    android.hardware.configstore@1.0-service \
    android.hidl.allocator@1.0-service \
    android.hidl.memory@1.0-impl \
    atrace \
    bootanimation \
    bootstat \
    charger \
    cmd \
    crash_dump \
    debuggerd\
    dumpstate \
    dumpsys \
    fastboot \
    gralloc.default \
    healthd \
    hwservicemanager \
    init \
    init.environ.rc \
    init.rc \
    libEGL \
    libETC1 \
    libFFTEm \
    libGLESv1_CM \
    libGLESv2 \
    libGLESv3 \
    libbinder \
    libc \
    libc_malloc_debug \
    libcutils \
    libdl \
    libgui \
    libhardware \
    libhardware_legacy \
    libjpeg \
    liblog \
    libm \
    libpixelflinger \
    libpower \
    libsigchain \
    libstdc++ \
    libsurfaceflinger \
    libsurfaceflinger_ddmconnection \
    libsysutils \
    libui \
    libutils \
    linker \
    lmkd \
    logcat \
    logwrapper \
    lshal \
    recovery \
    service \
    servicemanager \
    shell_and_utilities \
    storaged \
    surfaceflinger \
    thermalserviced \
    tombstoned \
    tzdatacheck \
    vndservice \
    vndservicemanager \
    compatibility_matrix.xml \
    manifest.xml \
    system_manifest.xml \
    system_compatibility_matrix.xml \

# SELinux packages
PRODUCT_PACKAGES += \
    nonplat_mac_permissions.xml \
    nonplat_property_contexts \
    nonplat_seapp_contexts \
    nonplat_service_contexts \
    nonplat_hwservice_contexts \
    plat_mac_permissions.xml \
    plat_property_contexts \
    plat_seapp_contexts \
    plat_service_contexts \
    plat_hwservice_contexts \
    selinux_policy \
    vndservice_contexts

# AID Generation for
# <pwd.h> and <grp.h>
PRODUCT_PACKAGES += \
    passwd \
    group \
    fs_config_files \
    fs_config_dirs

# Ensure that this property is always defined so that bionic_systrace.cpp
# can rely on it being initially set by init.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    debug.atrace.tags.enableflags=0

PRODUCT_COPY_FILES += \
    system/core/rootdir/init.usb.rc:root/init.usb.rc \
    system/core/rootdir/init.usb.configfs.rc:root/init.usb.configfs.rc \
    system/core/rootdir/ueventd.rc:root/ueventd.rc \
    system/core/rootdir/etc/hosts:system/etc/hosts
