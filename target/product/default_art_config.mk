#
# Copyright (C) 2020 The Android Open Source Project
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

ifeq ($(ART_APEX_JARS),)
  $(error ART_APEX_JARS is empty; cannot initialize PRODUCT_BOOT_JARS variable)
endif

# Order of the jars on BOOTCLASSPATH follows:
# 1. ART APEX jars
# 2. System jars
# 3. System_ext jars
# 4. Non-updatable APEX jars
# 5. Updatable APEX jars
#
# ART APEX jars (1) are defined in ART_APEX_JARS. System, system_ext, and non updatable boot jars
# are defined below in PRODUCT_BOOT_JARS. All updatable APEX boot jars are part of
# PRODUCT_UPDATABLE_BOOT_JARS.
#
# The actual runtime ordering matching above is determined by derive_classpath service at runtime.
# See packages/modules/SdkExtensions/README.md for more details.

# The order of PRODUCT_BOOT_JARS matters for runtime class lookup performance.
PRODUCT_BOOT_JARS := \
    $(ART_APEX_JARS)

# /system and /system_ext boot jars.
PRODUCT_BOOT_JARS += \
    framework-minus-apex \
    framework-graphics \
    ext \
    telephony-common \
    voip-common \
    ims-common

# Non-updatable APEX jars. Keep the list sorted.
PRODUCT_BOOT_JARS += \
    com.android.i18n:core-icu4j

# Updatable APEX boot jars. Keep the list sorted by module names and then library names.
PRODUCT_UPDATABLE_BOOT_JARS := \
    com.android.appsearch:framework-appsearch \
    com.android.conscrypt:conscrypt \
    com.android.ipsec:android.net.ipsec.ike \
    com.android.media:updatable-media \
    com.android.mediaprovider:framework-mediaprovider \
    com.android.mediaprovider:framework-pdf \
    com.android.mediaprovider:framework-photopicker \
    com.android.os.statsd:framework-statsd \
    com.android.permission:framework-permission \
    com.android.permission:framework-permission-s \
    com.android.scheduling:framework-scheduling \
    com.android.sdkext:framework-sdkextensions \
    com.android.tethering:framework-connectivity \
    com.android.tethering:framework-tethering \
    com.android.wifi:framework-wifi

# Updatable APEX system server jars. Keep the list sorted by module names and then library names.
PRODUCT_UPDATABLE_SYSTEM_SERVER_JARS := \
    com.android.appsearch:service-appsearch \
    com.android.media:service-media-s \
    com.android.permission:service-permission \

# Minimal configuration for running dex2oat (default argument values).
# PRODUCT_USES_DEFAULT_ART_CONFIG must be true to enable boot image compilation.
PRODUCT_USES_DEFAULT_ART_CONFIG := true
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.image-dex2oat-Xms=64m \
    dalvik.vm.image-dex2oat-Xmx=64m \
    dalvik.vm.dex2oat-Xms=64m \
    dalvik.vm.dex2oat-Xmx=512m \
