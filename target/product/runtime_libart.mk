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

ifeq ($(TARGET_CORE_JARS),)
$(error TARGET_CORE_JARS is empty; cannot update PRODUCT_PACKAGES variable)
endif

# Minimal boot classpath. This should be a subset of PRODUCT_BOOT_JARS, and equivalent to
# TARGET_CORE_JARS.
PRODUCT_PACKAGES += \
    $(TARGET_CORE_JARS)

# Additional mixins to the boot classpath.
PRODUCT_PACKAGES += \
    android.test.base \

# Why are we pulling in ext, which is frameworks/base, depending on tagsoup and nist-sip?
PRODUCT_PACKAGES += \
    ext \

# Why are we pulling in expat, which is used in frameworks, only, it seem?
PRODUCT_PACKAGES += \
    libexpat \

# Libcore.
PRODUCT_PACKAGES += \
    libjavacore \
    libopenjdk \

# Libcore ICU. TODO: Try to figure out if/why we need them explicitly.
PRODUCT_PACKAGES += \
    libicui18n \
    libicuuc \

# ART.
PRODUCT_PACKAGES += art-runtime
# ART/dex helpers.
PRODUCT_PACKAGES += art-tools

# Certificates.
PRODUCT_PACKAGES += \
    cacerts \

PRODUCT_PACKAGES += \
    hiddenapi-package-whitelist.xml \

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    dalvik.vm.image-dex2oat-Xms=64m \
    dalvik.vm.image-dex2oat-Xmx=64m \
    dalvik.vm.dex2oat-Xms=64m \
    dalvik.vm.dex2oat-Xmx=512m \
    dalvik.vm.usejit=true \
    dalvik.vm.usejitprofiles=true \
    dalvik.vm.dexopt.secondary=true \
    dalvik.vm.appimageformat=lz4

PRODUCT_PROPERTY_OVERRIDES += \
    ro.dalvik.vm.native.bridge=0

# Different dexopt types for different package update/install times.
# On eng builds, make "boot" reasons only extract for faster turnaround.
ifeq (eng,$(TARGET_BUILD_VARIANT))
    PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
        pm.dexopt.first-boot=extract \
        pm.dexopt.boot=extract
else
    PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
        pm.dexopt.first-boot=quicken \
        pm.dexopt.boot=verify
endif

# The install filter is speed-profile in order to enable the use of
# profiles from the dex metadata files. Note that if a profile is not provided
# or if it is empty speed-profile is equivalent to (quicken + empty app image).
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    pm.dexopt.install=speed-profile \
    pm.dexopt.bg-dexopt=speed-profile \
    pm.dexopt.ab-ota=speed-profile \
    pm.dexopt.inactive=verify \
    pm.dexopt.shared=speed

# Enable minidebuginfo generation unless overridden.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    dalvik.vm.dex2oat-minidebuginfo=true
