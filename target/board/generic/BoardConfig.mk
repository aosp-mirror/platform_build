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

# Note: Before P, we built the platform images for ARMv7-A _without_ NEON.
# Note: Before Q, we built the CTS and SDK images for ARMv7-A _without_ NEON.
# Note: Before Q, we built unbundled apps for ARMv7-A _without_ NEON.
#
# Starting from Pi, System image of aosp_arm products is the new GSI
# for real devices newly launched for Pi. These devices are usualy not
# as performant as the mainstream 64-bit devices and the performance
# provided by NEON is important for them to pass related CTS tests.
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_VARIANT := generic
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi

include build/make/target/board/BoardConfigGsiCommon.mk
