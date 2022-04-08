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

# arm64 emulator specific definitions
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_VARIANT := generic
TARGET_CPU_ABI := arm64-v8a

TARGET_2ND_ARCH := arm
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi

ifneq ($(TARGET_BUILD_APPS)$(filter cts sdk vts10,$(MAKECMDGOALS)),)
# DO NOT USE
# DO NOT USE
#
# This architecture / CPU variant must NOT be used for any 64 bit
# platform builds. It is the lowest common denominator required
# to build an unbundled application or cts for all supported 32 and 64 bit
# platforms.
#
# If you're building a 64 bit platform (and not an application) the
# ARM-v8 specification allows you to assume all the features available in an
# armv7-a-neon CPU. You should set the following as 2nd arch/cpu variant:
#
# TARGET_2ND_ARCH_VARIANT := armv8-a
# TARGET_2ND_CPU_VARIANT := generic
#
# DO NOT USE
# DO NOT USE
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
# DO NOT USE
# DO NOT USE
TARGET_2ND_CPU_VARIANT := generic
# DO NOT USE
# DO NOT USE
else
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_VARIANT := generic
endif

include build/make/target/board/BoardConfigGsiCommon.mk
include build/make/target/board/BoardConfigEmuCommon.mk

TARGET_NO_KERNEL := false
TARGET_NO_VENDOR_BOOT := false
BOARD_USES_RECOVERY_AS_BOOT := true

BOARD_BOOTIMAGE_PARTITION_SIZE := 0x02000000
BOARD_USERDATAIMAGE_PARTITION_SIZE := 576716800

BOARD_BOOT_HEADER_VERSION := 3
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# Wifi.
BOARD_WLAN_DEVICE           := emulator
BOARD_HOSTAPD_DRIVER        := NL80211
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_PRIVATE_LIB   := lib_driver_cmd_simulated
BOARD_WPA_SUPPLICANT_PRIVATE_LIB := lib_driver_cmd_simulated
WPA_SUPPLICANT_VERSION      := VER_0_8_X
WIFI_DRIVER_FW_PATH_PARAM   := "/dev/null"
WIFI_DRIVER_FW_PATH_STA     := "/dev/null"
WIFI_DRIVER_FW_PATH_AP      := "/dev/null"
