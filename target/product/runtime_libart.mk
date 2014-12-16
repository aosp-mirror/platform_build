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

PRODUCT_PACKAGES += \
    apache-xml \
    bouncycastle \
    cacerts \
    conscrypt \
    core-junit \
    core-libart \
    dalvikvm \
    dex2oat \
    dexdeps \
    dexdump \
    dexlist \
    dmtracedump \
    dx \
    ext \
    hprof-conv \
    libart \
    libcrypto \
    libexpat \
    libicui18n \
    libicuuc \
    libjavacore \
    libnativehelper \
    libssl \
    libz \
    oatdump \
    okhttp \
    patchoat

PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    dalvik.vm.image-dex2oat-Xms=64m \
    dalvik.vm.image-dex2oat-Xmx=64m \
    dalvik.vm.dex2oat-Xms=64m \
    dalvik.vm.dex2oat-Xmx=512m \
    ro.dalvik.vm.native.bridge=0 \
