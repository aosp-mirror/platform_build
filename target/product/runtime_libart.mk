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

# Minimal boot classpath. This should be a subset of PRODUCT_BOOT_JARS, and equivalent to
# TARGET_CORE_JARS.
PRODUCT_PACKAGES += \
    apache-xml \
    bouncycastle \
    core-oj \
    core-libart \
    conscrypt \
    okhttp \

# Additional mixins to the boot classpath.
PRODUCT_PACKAGES += \
    legacy-test \

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
    libopenjdkjvm \

# Libcore ICU. TODO: Try to figure out if/why we need them explicitly.
PRODUCT_PACKAGES += \
    libicui18n \
    libicuuc \

# ART.
PRODUCT_PACKAGES += \
    dalvikvm \
    dex2oat \
    dexoptanalyzer \
    libart \
    libart_fake \
    libopenjdkjvmti \
    patchoat \
    profman

# ART/dex helpers.
PRODUCT_PACKAGES += \
    ahat \
    dexdump \
    dexlist \
    hprof-conv \
    oatdump \

# Certificates.
PRODUCT_PACKAGES += \
    cacerts \

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    dalvik.vm.image-dex2oat-Xms=64m \
    dalvik.vm.image-dex2oat-Xmx=64m \
    dalvik.vm.dex2oat-Xms=64m \
    dalvik.vm.dex2oat-Xmx=512m \
    ro.dalvik.vm.native.bridge=0 \
    dalvik.vm.usejit=true \
    dalvik.vm.usejitprofiles=true \
    dalvik.vm.dexopt.secondary=true \
    dalvik.vm.appimageformat=lz4
