#
# Copyright (C) 2018 The Android Open Source Project
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

# Base modules and settings for recovery.
PRODUCT_PACKAGES += \
    adbd.recovery \
    android.hardware.health@2.0-impl-default.recovery \
    cgroups.recovery.json \
    charger.recovery \
    init_second_stage.recovery \
    ld.config.recovery.txt \
    linker.recovery \
    otacerts.recovery \
    recovery \
    servicemanager.recovery \
    shell_and_utilities_recovery \
    watchdogd.recovery \

PRODUCT_VENDOR_PROPERTIES += \
    ro.recovery.usb.vid?=18D1 \
    ro.recovery.usb.adb.pid?=D001 \
    ro.recovery.usb.fastboot.pid?=4EE0 \

# These had been pulled in via init_second_stage.recovery, but may not be needed.
PRODUCT_HOST_PACKAGES += \
    e2fsdroid \
    mke2fs \
    sload_f2fs \
    make_f2fs \

PRODUCT_HOST_PACKAGES += \
    icu-data_host_i18n_apex

# Base modules and settings for the vendor partition.
PRODUCT_PACKAGES += \
    com.android.hardware.cas \
    boringssl_self_test_vendor \
    dumpsys_vendor \
    fs_config_files_nonsystem \
    fs_config_dirs_nonsystem \
    gralloc.default \
    group_odm \
    group_vendor \
    init_vendor \
    libbundlewrapper \
    libclearkeycasplugin \
    libdownmix \
    libdrmclearkeyplugin \
    libdynproc \
    libeffectproxy \
    libeffects \
    libhapticgenerator \
    libldnhncr \
    libreference-ril \
    libreverbwrapper \
    libril \
    libvisualizer \
    passwd_odm \
    passwd_vendor \
    selinux_policy_nonsystem \
    shell_and_utilities_vendor \

# Base modules when shipping api level is less than or equal to 34
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_34 += \
     android.hidl.memory@1.0-impl.vendor \

# OMX not supported for 64bit_only builds
# Only supported when SHIPPING_API_LEVEL is less than or equal to 33
ifneq ($(TARGET_SUPPORTS_OMX_SERVICE),false)
    PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33 += \
        android.hardware.media.omx@1.0-service \

endif

# Base modules when shipping api level is less than or equal to 33
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33 += \
    android.hardware.cas@1.2-service \

# Base modules when shipping api level is less than or equal to 29
PRODUCT_PACKAGES_SHIPPING_API_LEVEL_29 += \
    android.hardware.configstore@1.1-service \
    vndservice \
    vndservicemanager \

# VINTF data for vendor image
PRODUCT_PACKAGES += \
    vendor_compatibility_matrix.xml \

# Base modules and settings for the debug ramdisk, which is then packed
# into a boot-debug.img and a vendor_boot-debug.img.
PRODUCT_PACKAGES += \
    adb_debug.prop \
    userdebug_plat_sepolicy.cil
