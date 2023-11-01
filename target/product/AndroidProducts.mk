#
# Copyright (C) 2008 The Android Open Source Project
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
# This file should set PRODUCT_MAKEFILES to a list of product makefiles
# to expose to the build system.  LOCAL_DIR will already be set to
# the directory containing this file.
# PRODUCT_MAKEFILES is set up in AndroidProducts.mks.
# Format of PRODUCT_MAKEFILES:
# <product_name>:<path_to_the_product_makefile>
# If the <product_name> is the same as the base file name (without dir
# and the .mk suffix) of the product makefile, "<product_name>:" can be
# omitted.
#
# This file may not rely on the value of any variable other than
# LOCAL_DIR; do not use any conditionals, and do not look up the
# value of any variable that isn't set in this file or in a file that
# it includes.
#

# Unbundled apps will be built with the most generic product config.
ifneq ($(TARGET_BUILD_APPS),)
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/aosp_arm64.mk \
    $(LOCAL_DIR)/aosp_arm64_fullmte.mk \
    $(LOCAL_DIR)/aosp_arm.mk \
    $(LOCAL_DIR)/aosp_riscv64.mk \
    $(LOCAL_DIR)/aosp_x86_64.mk \
    $(LOCAL_DIR)/aosp_x86.mk \
    $(LOCAL_DIR)/full.mk \
    $(LOCAL_DIR)/full_x86.mk \

else
PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/aosp_64bitonly_x86_64.mk \
    $(LOCAL_DIR)/aosp_arm64.mk \
    $(LOCAL_DIR)/aosp_arm64_fullmte.mk \
    $(LOCAL_DIR)/aosp_arm.mk \
    $(LOCAL_DIR)/aosp_riscv64.mk \
    $(LOCAL_DIR)/aosp_x86_64.mk \
    $(LOCAL_DIR)/aosp_x86_arm.mk \
    $(LOCAL_DIR)/aosp_x86.mk \
    $(LOCAL_DIR)/full.mk \
    $(LOCAL_DIR)/full_x86.mk \
    $(LOCAL_DIR)/generic.mk \
    $(LOCAL_DIR)/generic_system_arm64.mk \
    $(LOCAL_DIR)/generic_system_x86.mk \
    $(LOCAL_DIR)/generic_system_x86_64.mk \
    $(LOCAL_DIR)/generic_system_x86_arm.mk \
    $(LOCAL_DIR)/generic_x86.mk \
    $(LOCAL_DIR)/mainline_system_arm64.mk \
    $(LOCAL_DIR)/mainline_system_x86.mk \
    $(LOCAL_DIR)/mainline_system_x86_64.mk \
    $(LOCAL_DIR)/mainline_system_x86_arm.mk \
    $(LOCAL_DIR)/ndk.mk \
    $(LOCAL_DIR)/sdk.mk \

endif

PRODUCT_MAKEFILES += \
    $(LOCAL_DIR)/linux_bionic.mk \
    $(LOCAL_DIR)/mainline_sdk.mk \
    $(LOCAL_DIR)/module_arm.mk \
    $(LOCAL_DIR)/module_arm64.mk \
    $(LOCAL_DIR)/module_arm64only.mk \
    $(LOCAL_DIR)/module_riscv64.mk \
    $(LOCAL_DIR)/module_x86.mk \
    $(LOCAL_DIR)/module_x86_64.mk \
    $(LOCAL_DIR)/module_x86_64only.mk \

COMMON_LUNCH_CHOICES := \
    aosp_arm64-trunk_staging-eng \
    aosp_arm-trunk_staging-eng \
    aosp_x86_64-trunk_staging-eng \
    aosp_x86-trunk_staging-eng \
