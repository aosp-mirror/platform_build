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

# Exclude all files under system/product and system/system_ext
PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST += \
    system/product/% \
    system/system_ext/%

# Split selinux policy
PRODUCT_FULL_TREBLE_OVERRIDE := true

# Enable dynamic partition size
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

# Needed by Pi newly launched device to pass VtsTrebleSysProp on GSI
PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE := true

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
    init.gsi.rc

# Support addtional P and Q VNDK packages
PRODUCT_EXTRA_VNDK_VERSIONS := 28 29
