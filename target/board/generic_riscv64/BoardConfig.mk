# Copyright (C) 2022 The Android Open Source Project
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

# riscv64 emulator specific definitions
TARGET_ARCH := riscv64
TARGET_ARCH_VARIANT :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_ABI := riscv64

# Include 64-bit mediaserver to support 64-bit only devices
TARGET_DYNAMIC_64_32_MEDIASERVER := true

include build/make/target/board/BoardConfigGsiCommon.mk

# Temporary hack while prebuilt modules are missing riscv64.
ALLOW_MISSING_DEPENDENCIES := true

# Temporary until dex2oat works when targeting riscv64
WITH_DEXPREOPT := false
