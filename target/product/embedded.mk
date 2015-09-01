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
    atrace \
    bootanimation \
    debuggerd \
    dumpstate \
    dumpsys \
    fastboot \
    gralloc.default \
    grep \
    gzip \
    healthd \
    init \
    init.environ.rc \
    init.rc \
    libEGL \
    libETC1 \
    libFFTEm \
    libGLESv1_CM \
    libGLESv2 \
    libbinder \
    libc \
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
    mkshrc \
    reboot \
    recovery \
    service \
    servicemanager \
    sh \
    surfaceflinger \
    toolbox \
    toybox \
    tzdatacheck \

# SELinux packages
PRODUCT_PACKAGES += \
    sepolicy \
    file_contexts \
    seapp_contexts \
    property_contexts \
    mac_permissions.xml \
    selinux_version \
    service_contexts

# Ensure that this property is always defined so that bionic_systrace.cpp
# can rely on it being initially set by init.
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    debug.atrace.tags.enableflags=0

PRODUCT_COPY_FILES += \
    system/core/rootdir/init.usb.rc:root/init.usb.rc \
    system/core/rootdir/init.usb.configfs.rc:root/init.usb.configfs.rc \
    system/core/rootdir/init.trace.rc:root/init.trace.rc \
    system/core/rootdir/ueventd.rc:root/ueventd.rc \
    system/core/rootdir/etc/hosts:system/etc/hosts
