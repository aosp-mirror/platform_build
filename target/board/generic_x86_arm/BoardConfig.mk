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

TARGET_CPU_ABI := x86
TARGET_ARCH := x86
TARGET_ARCH_VARIANT := x86

TARGET_NATIVE_BRIDGE_ARCH := arm
TARGET_NATIVE_BRIDGE_ARCH_VARIANT := armv7-a-neon
TARGET_NATIVE_BRIDGE_CPU_VARIANT := generic
TARGET_NATIVE_BRIDGE_ABI := armeabi-v7a armeabi

BUILD_BROKEN_DUP_RULES := true

#
# The inclusion order below is important.
# The settings in latter makefiles overwrite those in the former.
#
include build/make/target/board/BoardConfigMainlineCommon.mk

# the settings differ from BoardConfigMainlineCommon.mk
BOARD_USES_SYSTEM_OTHER_ODEX :=

# Resize to 4G to accomodate ASAN and CTS
BOARD_USERDATAIMAGE_PARTITION_SIZE := 4294967296
