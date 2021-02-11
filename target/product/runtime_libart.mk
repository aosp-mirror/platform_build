#
# Copyright (C) 2013 The Android Open Source Project
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

# Provides a functioning ART environment without Android frameworks

$(call inherit-product, $(SRC_TARGET_DIR)/product/default_art_config.mk)

# Additional mixins to the boot classpath.
PRODUCT_PACKAGES += \
    android.test.base \

# Why are we pulling in ext, which is frameworks/base, depending on tagsoup and nist-sip?
PRODUCT_PACKAGES += \
    ext \

# Runtime (Bionic) APEX module.
PRODUCT_PACKAGES += com.android.runtime

# ART APEX module.
# Note that this package includes the minimal boot classpath JARs (listed in
# ART_APEX_JARS), which should no longer be added directly to PRODUCT_PACKAGES.
PRODUCT_PACKAGES += com.android.art-autoselect
PRODUCT_HOST_PACKAGES += com.android.art-autoselect

# Certificates.
PRODUCT_PACKAGES += \
    cacerts \

PRODUCT_PACKAGES += \
    hiddenapi-package-whitelist.xml \

PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.usejit=true \
    dalvik.vm.usejitprofiles=true \
    dalvik.vm.dexopt.secondary=true \
    dalvik.vm.appimageformat=lz4

PRODUCT_SYSTEM_PROPERTIES += \
    ro.dalvik.vm.native.bridge=0

# Different dexopt types for different package update/install times.
# On eng builds, make "boot" reasons only extract for faster turnaround.
ifeq (eng,$(TARGET_BUILD_VARIANT))
    PRODUCT_SYSTEM_PROPERTIES += \
        pm.dexopt.first-boot-ota?=extract \
        pm.dexopt.boot-after-ota?=extract
else
    PRODUCT_SYSTEM_PROPERTIES += \
        pm.dexopt.first-boot?=verify \
        pm.dexopt.boot-after-ota?=verify
endif

# The install filter is speed-profile in order to enable the use of
# profiles from the dex metadata files. Note that if a profile is not provided
# or if it is empty speed-profile is equivalent to (quicken + empty app image).
PRODUCT_SYSTEM_PROPERTIES += \
    pm.dexopt.post-boot?=extract \
    pm.dexopt.install?=speed-profile \
    pm.dexopt.install-fast?=skip \
    pm.dexopt.install-bulk?=speed-profile \
    pm.dexopt.install-bulk-secondary?=verify \
    pm.dexopt.install-bulk-downgraded?=verify \
    pm.dexopt.install-bulk-secondary-downgraded?=extract \
    pm.dexopt.bg-dexopt?=speed-profile \
    pm.dexopt.ab-ota?=speed-profile \
    pm.dexopt.inactive?=verify \
    pm.dexopt.shared?=speed

# Pass file with the list of updatable boot class path packages to dex2oat.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.dex2oat-updatable-bcp-packages-file=/system/etc/updatable-bcp-packages.txt

# Enable resolution of startup const strings.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.dex2oat-resolve-startup-strings=true

# Specify default block size of 512K to enable parallel image decompression.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.dex2oat-max-image-block-size=524288

# Enable minidebuginfo generation unless overridden.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.minidebuginfo=true \
    dalvik.vm.dex2oat-minidebuginfo=true

# Two other device configs are added to IORap besides "ro.iorapd.enable".
# IORap by default is off and starts when
# (https://source.corp.google.com/android/system/iorap/iorapd.rc?q=iorapd.rc)
#
# * "ro.iorapd.enable" is true excluding unset
# * One of the device configs is true.
#
# "ro.iorapd.enable" has to be set to true, so that iorap can be started.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.iorapd.enable?=true

