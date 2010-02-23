#
# Copyright (C) 2006 The Android Open Source Project
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

# Configuration for builds hosted on linux-x86.
# Included by combo/select.mk

# $(1): The file to check
define get-file-size
stat --format "%s" "$(1)" | tr -d '\n'
endef

# The emulator is 32-bit-only. Force host tools to be built
# in 32-bit when the emulator is involved.
# Why we don't also force simulator builds to be 32-bit is a mystery.
ifneq ($(TARGET_SIMULATOR),true)
HOST_GLOBAL_CFLAGS += -m32
HOST_GLOBAL_LDFLAGS += -m32
endif

HOST_GLOBAL_CFLAGS += -fPIC
HOST_GLOBAL_CFLAGS += \
	-include $(call select-android-config-h,linux-x86)

HOST_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined
