#
# Copyright (C) 2020 The Android Open-Source Project
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

include $(SRC_TARGET_DIR)/product/gsi_release.mk

PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/etc/init/init.legacy-gsi.rc \
    system/etc/init/gsi/init.vndk-27.rc \
    system/etc/ld.config.vndk_lite.txt \

# Legacy GSI support additional O-MR1 interface
PRODUCT_EXTRA_VNDK_VERSIONS += 27

# Support for the O-MR1 devices
PRODUCT_COPY_FILES += \
    build/make/target/product/gsi/init.legacy-gsi.rc:system/etc/init/init.legacy-gsi.rc \
    build/make/target/product/gsi/init.vndk-27.rc:system/etc/init/gsi/init.vndk-27.rc

# Namespace configuration file for non-enforcing VNDK
PRODUCT_PACKAGES += \
    ld.config.vndk_lite.txt

# Legacy GSI relax the compatible property checking
PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE := false
