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
#
# Select either release (com.android.art) or debug (com.android.art.debug)
# variant of the ART APEX. By default, "user" build variants contain the release
# module, while the "eng" build variant contain the debug module. However, if
# `PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD` is defined, it overrides the previous
# logic:
# - if `PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD` is set to `false`, the
#   build will include the release module (whatever the build
#   variant);
# - if `PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD` is set to `true`, the
#   build will include the debug module (whatever the build variant).
#
# Note that the ART APEX package includes the minimal boot classpath JARs
# (listed in ART_APEX_JARS), which should no longer be added directly to
# PRODUCT_PACKAGES.

art_target_include_debug_build := $(PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD)
ifneq (false,$(art_target_include_debug_build))
  ifneq (,$(filter eng,$(TARGET_BUILD_VARIANT)))
    art_target_include_debug_build := true
  endif
endif

ifeq (true,$(art_target_include_debug_build))
  PRODUCT_PACKAGES += com.android.art.debug
  apex_test_module := art-check-debug-apex-gen-fakebin
else
  PRODUCT_PACKAGES += com.android.art
  apex_test_module := art-check-release-apex-gen-fakebin
endif

ifeq (true,$(call soong_config_get,art_module,source_build))
  PRODUCT_HOST_PACKAGES += $(apex_test_module)
endif

art_target_include_debug_build :=
apex_test_module :=

# Certificates.
PRODUCT_PACKAGES += \
    cacerts \

PRODUCT_PACKAGES += \
    hiddenapi-package-whitelist.xml \

ifeq (,$(TARGET_BUILD_UNBUNDLED))
  # Don't depend on the framework boot image profile in unbundled builds where
  # frameworks/base may not be present.
  # TODO(b/179900989): We may not need this check once we stop using full
  # platform products on the thin ART manifest branch.
  PRODUCT_DEX_PREOPT_BOOT_IMAGE_PROFILE_LOCATION += frameworks/base/boot/boot-image-profile.txt
endif

# The dalvik.vm.dexopt.thermal-cutoff property must contain one of the values
# listed here:
#
# https://source.android.com/devices/architecture/hidl/thermal-mitigation#thermal-api
#
# If the thermal status of the device reaches or exceeds the value set here
# background dexopt will be terminated and rescheduled using an exponential
# backoff polcy.
#
# The thermal cutoff value is currently set to THERMAL_STATUS_MODERATE.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.usejit=true \
    dalvik.vm.dexopt.secondary=true \
    dalvik.vm.dexopt.thermal-cutoff=2 \
    dalvik.vm.appimageformat=lz4

PRODUCT_SYSTEM_PROPERTIES += \
    ro.dalvik.vm.native.bridge?=0

# The install filter is speed-profile in order to enable the use of
# profiles from the dex metadata files. Note that if a profile is not provided
# or if it is empty speed-profile is equivalent to (quicken + empty app image).
# Note that `cmdline` is not strictly needed but it simplifies the management
# of compilation reason in the platform (as we have a unified, single path,
# without exceptions).
# TODO(b/243646876): Remove `pm.dexopt.post-boot`.
PRODUCT_SYSTEM_PROPERTIES += \
    pm.dexopt.post-boot?=verify \
    pm.dexopt.first-boot?=verify \
    pm.dexopt.boot-after-ota?=verify \
    pm.dexopt.boot-after-mainline-update?=verify \
    pm.dexopt.install?=speed-profile \
    pm.dexopt.install-fast?=skip \
    pm.dexopt.install-bulk?=speed-profile \
    pm.dexopt.install-bulk-secondary?=verify \
    pm.dexopt.install-bulk-downgraded?=verify \
    pm.dexopt.install-bulk-secondary-downgraded?=verify \
    pm.dexopt.bg-dexopt?=speed-profile \
    pm.dexopt.ab-ota?=speed-profile \
    pm.dexopt.inactive?=verify \
    pm.dexopt.cmdline?=verify \
    pm.dexopt.shared?=speed

ifneq (,$(filter eng,$(TARGET_BUILD_VARIANT)))
    OVERRIDE_DISABLE_DEXOPT_ALL ?= true
endif

# OVERRIDE_DISABLE_DEXOPT_ALL disables all dexpreopt (build-time) and dexopt (on-device) activities.
# This option is for faster iteration during development and should never be enabled for production.
ifneq (,$(filter true,$(OVERRIDE_DISABLE_DEXOPT_ALL)))
  PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.disable-art-service-dexopt=true \
    dalvik.vm.disable-odrefresh=true

  # Disable all dexpreopt activities except for the ART boot image.
  # We have to dexpreopt the ART boot image because they are used by ART tests. This should not
  # be too much of a problem for platform developers because a change to framework code should not
  # trigger dexpreopt for the ART boot image.
  WITH_DEXPREOPT_ART_BOOT_IMG_ONLY := true
endif

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

# Enable Madvising of the whole art, odex and vdex files to MADV_WILLNEED.
# The size specified here is the size limit of how much of the file
# (in bytes) is madvised.
# We madvise the whole .art file to MADV_WILLNEED with UINT_MAX limit.
# For odex and vdex files, we limit madvising to 100MB.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.madvise.vdexfile.size=104857600 \
    dalvik.vm.madvise.odexfile.size=104857600 \
    dalvik.vm.madvise.artfile.size=4294967295

# Properties for the Unspecialized App Process Pool
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.usap_pool_enabled?=false \
    dalvik.vm.usap_refill_threshold?=1 \
    dalvik.vm.usap_pool_size_max?=3 \
    dalvik.vm.usap_pool_size_min?=1 \
    dalvik.vm.usap_pool_refill_delay_ms?=3000

PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.useartservice=true \
    dalvik.vm.enable_pr_dexopt=true

# Copy preopted files from system_b on first boot.
PRODUCT_SYSTEM_PROPERTIES += ro.cp_system_other_odex=1
PRODUCT_PACKAGES += \
  cppreopts.sh
