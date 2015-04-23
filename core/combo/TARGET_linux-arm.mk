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

# Configuration for Linux on ARM.
# Included by combo/select.mk

# You can set TARGET_ARCH_VARIANT to use an arch version other
# than ARMv5TE. Each value should correspond to a file named
# $(BUILD_COMBOS)/arch/<name>.mk which must contain
# makefile variable definitions similar to the preprocessor
# defines in build/core/combo/include/arch/<combo>/AndroidConfig.h. Their
# purpose is to allow module Android.mk files to selectively compile
# different versions of code based upon the funtionality and
# instructions available in a given architecture version.
#
# The blocks also define specific arch_variant_cflags, which
# include defines, and compiler settings for the given architecture
# version.
#
ifeq ($(strip $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT)),)
TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT := armv5te
endif

# Decouple NDK library selection with platform compiler version
$(combo_2nd_arch_prefix)TARGET_NDK_GCC_VERSION := 4.9

ifeq ($(strip $(TARGET_GCC_VERSION_EXP)),)
$(combo_2nd_arch_prefix)TARGET_GCC_VERSION := 4.9
else
$(combo_2nd_arch_prefix)TARGET_GCC_VERSION := $(TARGET_GCC_VERSION_EXP)
endif

TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_$(combo_2nd_arch_prefix)ARCH)/$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown ARM architecture version: $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT))
endif

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)
include $(BUILD_SYSTEM)/combo/fdo.mk

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)),)
$(combo_2nd_arch_prefix)TARGET_TOOLCHAIN_ROOT := prebuilts/gcc/$(HOST_PREBUILT_TAG)/arm/arm-linux-androideabi-$($(combo_2nd_arch_prefix)TARGET_GCC_VERSION)
$(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX := $($(combo_2nd_arch_prefix)TARGET_TOOLCHAIN_ROOT)/bin/arm-linux-androideabi-
endif

$(combo_2nd_arch_prefix)TARGET_CC := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_CXX := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_AR := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_OBJCOPY := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_LD := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_READELF := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)readelf$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_STRIP := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)strip$(HOST_EXECUTABLE_SUFFIX)

$(combo_2nd_arch_prefix)TARGET_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

$(combo_2nd_arch_prefix)TARGET_arm_CFLAGS :=    -O2 \
                        -fomit-frame-pointer \
                        -fstrict-aliasing    \
                        -funswitch-loops

# Modules can choose to compile some source as thumb.
$(combo_2nd_arch_prefix)TARGET_thumb_CFLAGS :=  -mthumb \
                        -Os \
                        -fomit-frame-pointer \
                        -fno-strict-aliasing

# Set FORCE_ARM_DEBUGGING to "true" in your buildspec.mk
# or in your environment to force a full arm build, even for
# files that are normally built as thumb; this can make
# gdb debugging easier.  Don't forget to do a clean build.
#
# NOTE: if you try to build a -O0 build with thumb, several
# of the libraries (libpv, libwebcore, libkjs) need to be built
# with -mlong-calls.  When built at -O0, those libraries are
# too big for a thumb "BL <label>" to go from one end to the other.
ifeq ($(FORCE_ARM_DEBUGGING),true)
  $(combo_2nd_arch_prefix)TARGET_arm_CFLAGS += -fno-omit-frame-pointer -fno-strict-aliasing
  $(combo_2nd_arch_prefix)TARGET_thumb_CFLAGS += -marm -fno-omit-frame-pointer
endif

android_config_h := $(call select-android-config-h,linux-arm)

$(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += \
			-msoft-float \
			-ffunction-sections \
			-fdata-sections \
			-funwind-tables \
			-fstack-protector \
			-Wa,--noexecstack \
			-Werror=format-security \
			-D_FORTIFY_SOURCE=2 \
			-fno-short-enums \
			-no-canonical-prefixes \
			-fno-canonical-system-headers \
			$(arch_variant_cflags) \
			-include $(android_config_h) \
			-I $(dir $(android_config_h))

# The "-Wunused-but-set-variable" option often breaks projects that enable
# "-Wall -Werror" due to a commom idiom "ALOGV(mesg)" where ALOGV is turned
# into no-op in some builds while mesg is defined earlier. So we explicitly
# disable "-Wunused-but-set-variable" here.
ifneq ($(filter 4.6 4.6.% 4.7 4.7.% 4.8 4.9, $($(combo_2nd_arch_prefix)TARGET_GCC_VERSION)),)
$(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -fno-builtin-sin \
			-fno-strict-volatile-bitfields
endif

# This is to avoid the dreaded warning compiler message:
#   note: the mangling of 'va_list' has changed in GCC 4.4
#
# The fact that the mangling changed does not affect the NDK ABI
# very fortunately (since none of the exposed APIs used va_list
# in their exported C++ functions). Also, GCC 4.5 has already
# removed the warning from the compiler.
#
$(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -Wno-psabi

$(combo_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS += \
			-Wl,-z,noexecstack \
			-Wl,-z,relro \
			-Wl,-z,now \
			-Wl,--build-id=md5 \
			-Wl,--warn-shared-textrel \
			-Wl,--fatal-warnings \
			-Wl,--icf=safe \
			-Wl,--hash-style=gnu \
			$(arch_variant_ldflags)

$(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -mthumb-interwork

$(combo_2nd_arch_prefix)TARGET_GLOBAL_CPPFLAGS += -fvisibility-inlines-hidden

# More flags/options can be added here
$(combo_2nd_arch_prefix)TARGET_RELEASE_CFLAGS := \
			-DNDEBUG \
			-g \
			-Wstrict-aliasing=2 \
			-fgcse-after-reload \
			-frerun-cse-after-loop \
			-frename-registers

libc_root := bionic/libc
libm_root := bionic/libm


## on some hosts, the target cross-compiler is not available so do not run this command
ifneq ($(wildcard $($(combo_2nd_arch_prefix)TARGET_CC)),)
# We compile with the global cflags to ensure that
# any flags which affect libgcc are correctly taken
# into account.
$(combo_2nd_arch_prefix)TARGET_LIBGCC := $(shell $($(combo_2nd_arch_prefix)TARGET_CC) \
        $($(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS) -print-libgcc-file-name)
$(combo_2nd_arch_prefix)TARGET_LIBATOMIC := $(shell $($(combo_2nd_arch_prefix)TARGET_CC) \
        $($(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS) -print-file-name=libatomic.a)
$(combo_2nd_arch_prefix)TARGET_LIBGCOV := $(shell $($(combo_2nd_arch_prefix)TARGET_CC) \
        $($(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS) -print-file-name=libgcov.a)
endif

KERNEL_HEADERS_COMMON := $(libc_root)/kernel/uapi
KERNEL_HEADERS_ARCH   := $(libc_root)/kernel/uapi/asm-$(TARGET_$(combo_2nd_arch_prefix)ARCH)
KERNEL_HEADERS := $(KERNEL_HEADERS_COMMON) $(KERNEL_HEADERS_ARCH)

$(combo_2nd_arch_prefix)TARGET_C_INCLUDES := \
	$(libc_root)/arch-arm/include \
	$(libc_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/arm \

$(combo_2nd_arch_prefix)TARGET_CRTBEGIN_STATIC_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_static.o
$(combo_2nd_arch_prefix)TARGET_CRTBEGIN_DYNAMIC_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_dynamic.o
$(combo_2nd_arch_prefix)TARGET_CRTEND_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_android.o

$(combo_2nd_arch_prefix)TARGET_CRTBEGIN_SO_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.o
$(combo_2nd_arch_prefix)TARGET_CRTEND_SO_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.o

$(combo_2nd_arch_prefix)TARGET_PACK_MODULE_RELOCATIONS := true

$(combo_2nd_arch_prefix)TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libm

$(combo_2nd_arch_prefix)TARGET_LINKER := /system/bin/linker
