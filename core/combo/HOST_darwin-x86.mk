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

# Configuration for Darwin (Mac OS X) on x86.
# Included by combo/select.mk

ifneq ($(strip $(BUILD_HOST_64bit)),)
# By default we build everything in 32-bit, because it gives us
# more consistency between the host tools and the target.
# BUILD_HOST_64bit=1 overrides it for tool like emulator
# which can benefit from 64-bit host arch.
HOST_GLOBAL_CFLAGS += -m64
HOST_GLOBAL_LDFLAGS += -m64
else
HOST_GLOBAL_CFLAGS += -m32
HOST_GLOBAL_LDFLAGS += -m32
endif # BUILD_HOST_64bit

ifneq ($(strip $(BUILD_HOST_static)),)
# Statically-linked binaries are desirable for sandboxed environment
HOST_GLOBAL_LDFLAGS += -static
endif # BUILD_HOST_static

build_mac_version := $(shell sw_vers -productVersion)

mac_sdk_versions_supported :=  10.6 10.7 10.8
ifneq ($(strip $(MAC_SDK_VERSION)),)
mac_sdk_version := $(MAC_SDK_VERSION)
ifeq ($(filter $(mac_sdk_version),$(mac_sdk_versions_supported)),)
$(warning ****************************************************************)
$(warning * MAC_SDK_VERSION $(MAC_SDK_VERSION) isn't one of the supported $(mac_sdk_versions_supported))
$(warning ****************************************************************)
$(error Stop.)
endif
else
mac_sdk_versions_installed := $(shell xcodebuild -showsdks | grep macosx | sort | sed -e "s/.*macosx//g")
mac_sdk_version := $(firstword $(filter $(mac_sdk_versions_installed), $(mac_sdk_versions_supported)))
ifeq ($(mac_sdk_version),)
mac_sdk_version := $(firstword $(mac_sdk_versions_supported))
endif
endif

mac_sdk_path := $(shell xcode-select -print-path)
# try /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.?.sdk
#  or /Volume/Xcode/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.?.sdk
mac_sdk_root := $(mac_sdk_path)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX$(mac_sdk_version).sdk
ifeq ($(wildcard $(mac_sdk_root)),)
# try legacy /Developer/SDKs/MacOSX10.?.sdk
mac_sdk_root := /Developer/SDKs/MacOSX$(mac_sdk_version).sdk
endif
ifeq ($(wildcard $(mac_sdk_root)),)
$(warning *****************************************************)
$(warning * Can not find SDK $(mac_sdk_version) at $(mac_sdk_root))
$(warning *****************************************************)
$(error Stop.)
endif

ifeq ($(mac_sdk_version),10.6)
  gcc_darwin_version := 10
else
  gcc_darwin_version := 11
endif

HOST_TOOLCHAIN_ROOT := prebuilts/gcc/darwin-x86/host/i686-apple-darwin-4.2.1
HOST_TOOLCHAIN_PREFIX := $(HOST_TOOLCHAIN_ROOT)/bin/i686-apple-darwin$(gcc_darwin_version)
# Don't do anything if the toolchain is not there
ifneq (,$(strip $(wildcard $(HOST_TOOLCHAIN_PREFIX)-gcc)))
HOST_CC  := $(HOST_TOOLCHAIN_PREFIX)-gcc
HOST_CXX := $(HOST_TOOLCHAIN_PREFIX)-g++
ifeq ($(mac_sdk_version),10.8)
# Mac SDK 10.8 no longer has stdarg.h, etc
host_toolchain_header := $(HOST_TOOLCHAIN_ROOT)/lib/gcc/i686-apple-darwin$(gcc_darwin_version)/4.2.1/include
HOST_GLOBAL_CFLAGS += -isystem $(host_toolchain_header)
endif
else
HOST_CC := gcc
HOST_CXX := g++
endif # $(HOST_TOOLCHAIN_PREFIX)-gcc exists
HOST_AR := $(AR)
HOST_STRIP := $(STRIP)
HOST_STRIP_COMMAND = $(HOST_STRIP) --strip-debug $< -o $@

HOST_GLOBAL_CFLAGS += -isysroot $(mac_sdk_root) -mmacosx-version-min=$(mac_sdk_version) -DMACOSX_DEPLOYMENT_TARGET=$(mac_sdk_version)
HOST_GLOBAL_LDFLAGS += -isysroot $(mac_sdk_root) -Wl,-syslibroot,$(mac_sdk_root) -mmacosx-version-min=$(mac_sdk_version)

HOST_GLOBAL_CFLAGS += -fPIC -funwind-tables
HOST_NO_UNDEFINED_LDFLAGS := -Wl,-undefined,error

HOST_SHLIB_SUFFIX := .dylib
HOST_JNILIB_SUFFIX := .jnilib

HOST_GLOBAL_CFLAGS += \
    -include $(call select-android-config-h,darwin-x86)

ifneq ($(filter 10.7 10.7.% 10.8 10.8.%, $(build_mac_version)),)
       HOST_RUN_RANLIB_AFTER_COPYING := false
else
       HOST_RUN_RANLIB_AFTER_COPYING := true
       PRE_LION_DYNAMIC_LINKER_OPTIONS := -Wl,-dynamic
endif
HOST_GLOBAL_ARFLAGS := cqs

HOST_CUSTOM_LD_COMMAND := true

define transform-host-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
        -dynamiclib -single_module -read_only_relocs suppress \
        $(HOST_GLOBAL_LD_DIRS) \
        $(HOST_GLOBAL_LDFLAGS) \
        $(PRIVATE_ALL_OBJECTS) \
        $(addprefix -force_load , $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDLIBS) \
        -o $@ \
        -install_name @rpath/$(notdir $@) \
        -Wl,-rpath,@loader_path/../lib \
        $(PRIVATE_LDFLAGS) \
        $(HOST_LIBGCC)
endef

define transform-host-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
        -Wl,-rpath,@loader_path/../lib \
        -o $@ \
        $(PRE_LION_DYNAMIC_LINKER_OPTIONS) -headerpad_max_install_names \
        $(HOST_GLOBAL_LD_DIRS) \
        $(HOST_GLOBAL_LDFLAGS) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
        $(PRIVATE_ALL_OBJECTS) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
        $(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
        $(PRIVATE_LDFLAGS) \
        $(PRIVATE_LDLIBS) \
        $(HOST_LIBGCC)
endef

# $(1): The file to check
define get-file-size
stat -f "%z" $(1)
endef
