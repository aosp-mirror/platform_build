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

# arm emulator specific definitions
TARGET_ARCH := arm

# Note: Before Pi, we built the platform images for ARMv7-A _without_ NEON.
#
ifneq ($(TARGET_BUILD_APPS)$(filter cts sdk,$(MAKECMDGOALS)),)
# DO NOT USE
#
# This architecture variant should NOT be used for 32 bit arm platform
# builds. It is the lowest common denominator required to build
# an unbundled application for all supported 32 platforms.
# cts for 32 bit arm is built using aosp_arm64 product.
#
# If you are building a 32 bit platform (and not an application),
# you should set the following as 2nd arch variant:
#
# TARGET_ARCH_VARIANT := armv7-a-neon
#
# DO NOT USE
TARGET_ARCH_VARIANT := armv7-a
# DO NOT USE
else
# Starting from Pi, System image of aosp_arm products is the new GSI
# for real devices newly launched for Pi. These devices are usualy not
# as performant as the mainstream 64-bit devices and the performance
# provided by NEON is important for them to pass related CTS tests.
TARGET_ARCH_VARIANT := armv7-a-neon
endif
TARGET_CPU_VARIANT := generic
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi

include build/make/target/board/BoardConfigEmuCommon.mk
include build/make/target/board/BoardConfigGsiCommon.mk

BOARD_USERDATAIMAGE_PARTITION_SIZE := 576716800

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
