#
# Copyright (C) 2019 The Android Open-Source Project
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

#
# The makefile contains the special settings for GSI releasing.
# This makefile is used for the build targets which used for releasing GSI.
#
# For example:
# - Released GSI contains skip_mount.cfg to skip mounting prodcut paritition
# - Released GSI contains more VNDK packages to support old version vendors
# - etc.
#
# See device/generic/common/README.md for more details.
#

BUILDING_GSI := true

# Exclude all files under system/product and system/system_ext
PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/product/% \
    system/system_ext/%

# GSI should always support up-to-date platform features.
# Keep this value at the latest API level to ensure latest build system
# default configs are applied.
PRODUCT_SHIPPING_API_LEVEL := 34

# Enable dynamic partitions to facilitate mixing onto Cuttlefish
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Enable dynamic partition size
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

# Disable the build-time debugfs restrictions on GSI builds
PRODUCT_SET_DEBUGFS_RESTRICTIONS := false

# GSI targets should install "unflattened" APEXes in /system
TARGET_FLATTEN_APEX := false

# GSI targets should install "flattened" APEXes in /system_ext as well
PRODUCT_INSTALL_EXTRA_FLATTENED_APEXES := true

# The flattened version of com.android.apex.cts.shim.v1 should be explicitly installed
# because the shim apex is prebuilt one and PRODUCT_INSTALL_EXTRA_FLATTENED_APEXES is not
# supported for prebuilt_apex modules yet.
PRODUCT_PACKAGES += com.android.apex.cts.shim.v1_with_prebuilts.flattened

# GSI specific tasks on boot
PRODUCT_PACKAGES += \
    gsi_skip_mount.cfg \
    init.gsi.rc \
    init.vndk-nodef.rc \

# Overlay the GSI specific SystemUI setting
PRODUCT_PACKAGES += gsi_overlay_systemui
PRODUCT_COPY_FILES += \
    device/generic/common/overlays/overlay-config.xml:$(TARGET_COPY_OUT_SYSTEM_EXT)/overlay/config/config.xml

# Support additional VNDK snapshots
PRODUCT_EXTRA_VNDK_VERSIONS := \
    29 \
    30 \
    31 \
    32 \
    33 \

# Do not build non-GSI partition images.
PRODUCT_BUILD_CACHE_IMAGE := false
PRODUCT_BUILD_DEBUG_BOOT_IMAGE := false
PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_USERDATA_IMAGE := false
PRODUCT_BUILD_VENDOR_IMAGE := false
PRODUCT_BUILD_SUPER_PARTITION := false
PRODUCT_BUILD_SUPER_EMPTY_IMAGE := false
PRODUCT_BUILD_SYSTEM_DLKM_IMAGE := false
PRODUCT_EXPORT_BOOT_IMAGE_TO_DIST := true

# Additional settings used in all GSI builds
PRODUCT_PRODUCT_PROPERTIES += \
    ro.crypto.metadata_init_delete_all_keys.enabled=false \

# Window Extensions
$(call inherit-product, $(SRC_TARGET_DIR)/product/window_extensions.mk)