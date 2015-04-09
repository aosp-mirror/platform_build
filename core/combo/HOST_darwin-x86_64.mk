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

# Configuration for Darwin (Mac OS X) on x86_64.
# Included by combo/select.mk

HOST_GLOBAL_CFLAGS += -m64
HOST_GLOBAL_LDFLAGS += -m64

ifneq ($(strip $(BUILD_HOST_static)),)
# Statically-linked binaries are desirable for sandboxed environment
HOST_GLOBAL_LDFLAGS += -static
endif # BUILD_HOST_static

# Workaround differences in inttypes.h between host and target.
# See bug 12708004.
HOST_GLOBAL_CFLAGS += -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS

include $(BUILD_COMBOS)/mac_version.mk

HOST_TOOLCHAIN_ROOT := prebuilts/gcc/darwin-x86/host/i686-apple-darwin-4.2.1
HOST_TOOLCHAIN_PREFIX := $(HOST_TOOLCHAIN_ROOT)/bin/i686-apple-darwin$(gcc_darwin_version)
HOST_CC  := $(HOST_TOOLCHAIN_PREFIX)-gcc
HOST_CXX := $(HOST_TOOLCHAIN_PREFIX)-g++

# gcc location for clang; to be updated when clang is updated
# HOST_TOOLCHAIN_ROOT is a Darwin-specific define
HOST_TOOLCHAIN_FOR_CLANG := $(HOST_TOOLCHAIN_ROOT)

HOST_AR := $(AR)

HOST_GLOBAL_CFLAGS += -isysroot $(mac_sdk_root) -mmacosx-version-min=$(mac_sdk_version) -DMACOSX_DEPLOYMENT_TARGET=$(mac_sdk_version)
HOST_GLOBAL_CPPFLAGS += -isystem $(mac_sdk_path)/Toolchains/XcodeDefault.xctoolchain/usr/include/c++/v1
HOST_GLOBAL_LDFLAGS += -isysroot $(mac_sdk_root) -Wl,-syslibroot,$(mac_sdk_root) -mmacosx-version-min=$(mac_sdk_version)

HOST_GLOBAL_CFLAGS += -fPIC -funwind-tables
HOST_NO_UNDEFINED_LDFLAGS := -Wl,-undefined,error

HOST_SHLIB_SUFFIX := .dylib
HOST_JNILIB_SUFFIX := .jnilib

HOST_GLOBAL_CFLAGS += \
    -include $(call select-android-config-h,darwin-x86)

HOST_GLOBAL_ARFLAGS := cqs

# We Reuse the following functions with the same name from HOST_darwin-x86.mk:
# transform-host-o-to-shared-lib-inner
# transform-host-o-to-executable-inner
# get-file-size
