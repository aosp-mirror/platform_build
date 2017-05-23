#
# Copyright (C) 2017 The Android Open-Source Project
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

# Common boardconfig settings for generic AOSP products targetting mobile
# (phone/table) devices.

# Bootloader is not part of generic AOSP image
TARGET_NO_BOOTLOADER := true

# Kernel is also not part of generic AOSP image
TARGET_NO_KERNEL := true

# system.img is always ext4 with sparse option
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_SPARSE_EXT_DISABLED := false
TARGET_USES_MKE2FS := true

# Enable dex pre-opt to speed up initial boot
ifeq ($(HOST_OS),linux)
  ifeq ($(WITH_DEXPREOPT),)
    WITH_DEXPREOPT := true
    WITH_DEXPREOPT_PIC := true
    ifneq ($(TARGET_BUILD_VARIANT),user)
      # Retain classes.dex in APK's for non-user builds
      DEX_PREOPT_DEFAULT := nostripping
    endif
  endif
endif

# Generic AOSP image always requires separate vendor.img
BOARD_USES_VENDORIMAGE := true
TARGET_COPY_OUT_VENDOR := vendor

# Generic AOSP image does NOT support HWC1
TARGET_USES_HWC2 := true

TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := generic

BOARD_SYSTEMIMAGE_PARTITION_SIZE := 1610612736

# TODO(b/35790399): remove when b/35790399 is fixed.
BOARD_NAND_SPARE_SIZE := 0
BOARD_FLASH_BLOCK_SIZE := 512

BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true

