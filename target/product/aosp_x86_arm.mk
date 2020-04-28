#
# Copyright 2016 The Android Open-Source Project
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

PRODUCT_USE_DYNAMIC_PARTITIONS := true

# aosp_x86 with arm libraries needed by binary translation.

# The system image of aosp_x86-userdebug is a GSI for the devices with:
# - x86 32 bits user space
# - 64 bits binder interface
# - system-as-root
# - VNDK enforcement
# - compatible property override enabled

-include device/generic/goldfish/x86-vendor.mk

include $(SRC_TARGET_DIR)/product/full_x86.mk

# Enable dynamic partition size
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

# Needed by Pi newly launched device to pass VtsTrebleSysProp on GSI
PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE := true

# Support addtional P vendor interface
PRODUCT_EXTRA_VNDK_VERSIONS := 28

PRODUCT_NAME := aosp_x86_arm
PRODUCT_DEVICE := generic_x86_arm
