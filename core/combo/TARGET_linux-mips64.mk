#
# Copyright (C) 2013 The Android Open Source Project
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

# Configuration for Linux on MIPS64.
# Included by combo/select.mk

# You can set TARGET_ARCH_VARIANT to use an arch version other
# than mips64r6. Each value should correspond to a file named
# $(BUILD_COMBOS)/arch/<name>.mk which must contain
# makefile variable definitions. Their
# purpose is to allow module Android.mk files to selectively compile
# different versions of code based upon the funtionality and
# instructions available in a given architecture version.
#
# The blocks also define specific arch_variant_cflags, which
# include defines, and compiler settings for the given architecture
# version.
#
ifeq ($(strip $(TARGET_ARCH_VARIANT)),)
TARGET_ARCH_VARIANT := mips64r6
endif

# Decouple NDK library selection with platform compiler version
TARGET_NDK_GCC_VERSION := 4.9

ifeq ($(strip $(TARGET_GCC_VERSION_EXP)),)
TARGET_GCC_VERSION := 4.9
else
TARGET_GCC_VERSION := $(TARGET_GCC_VERSION_EXP)
endif

TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_ARCH)/$(TARGET_ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown MIPS architecture variant: $(TARGET_ARCH_VARIANT))
endif

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)
include $(BUILD_SYSTEM)/combo/fdo.mk

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $(TARGET_TOOLS_PREFIX)),)
TARGET_TOOLCHAIN_ROOT := prebuilts/gcc/$(HOST_PREBUILT_TAG)/mips/mips64el-linux-android-$(TARGET_GCC_VERSION)
TARGET_TOOLS_PREFIX := $(TARGET_TOOLCHAIN_ROOT)/bin/mips64el-linux-android-
endif

TARGET_CC := $(TARGET_TOOLS_PREFIX)gcc
TARGET_CXX := $(TARGET_TOOLS_PREFIX)g++
TARGET_AR := $(TARGET_TOOLS_PREFIX)ar
TARGET_OBJCOPY := $(TARGET_TOOLS_PREFIX)objcopy
TARGET_LD := $(TARGET_TOOLS_PREFIX)ld
TARGET_READELF := $(TARGET_TOOLS_PREFIX)readelf
TARGET_STRIP := $(TARGET_TOOLS_PREFIX)strip
TARGET_NM := $(TARGET_TOOLS_PREFIX)nm

define $(combo_var_prefix)transform-shared-lib-to-toc
$(call _gen_toc_command_for_elf,$(1),$(2))
endef

TARGET_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

TARGET_mips_CFLAGS :=	-O2 \
			-fomit-frame-pointer \
			-fno-strict-aliasing    \
			-funswitch-loops

# Set FORCE_MIPS_DEBUGGING to "true" in your buildspec.mk
# or in your environment to gdb debugging easier.
# Don't forget to do a clean build.
ifeq ($(FORCE_MIPS_DEBUGGING),true)
  TARGET_mips_CFLAGS += -fno-omit-frame-pointer
endif

TARGET_GLOBAL_CFLAGS += \
			$(TARGET_mips_CFLAGS) \
			-U__unix -U__unix__ -Umips \
			-ffunction-sections \
			-fdata-sections \
			-funwind-tables \
			-fstack-protector-strong \
			-Wa,--noexecstack \
			-Werror=format-security \
			-D_FORTIFY_SOURCE=2 \
			-no-canonical-prefixes \
			-fno-canonical-system-headers \
			$(arch_variant_cflags) \

# Help catch common 32/64-bit errors.
TARGET_GLOBAL_CFLAGS += \
    -Werror=pointer-to-int-cast \
    -Werror=int-to-pointer-cast \
    -Werror=implicit-function-declaration \

ifneq ($(ARCH_MIPS_PAGE_SHIFT),)
TARGET_GLOBAL_CFLAGS += -DPAGE_SHIFT=$(ARCH_MIPS_PAGE_SHIFT)
endif

TARGET_GLOBAL_LDFLAGS += \
			-Wl,-z,noexecstack \
			-Wl,-z,relro \
			-Wl,-z,now \
			-Wl,--build-id=md5 \
			-Wl,--warn-shared-textrel \
			-Wl,--fatal-warnings \
			-Wl,--no-undefined-version \
			$(arch_variant_ldflags)

# Disable transitive dependency library symbol resolving.
TARGET_GLOBAL_LDFLAGS += -Wl,--allow-shlib-undefined

TARGET_GLOBAL_CPPFLAGS += -fvisibility-inlines-hidden

# More flags/options can be added here
TARGET_RELEASE_CFLAGS := \
			-DNDEBUG \
			-g \
			-Wstrict-aliasing=2 \
			-fgcse-after-reload \
			-frerun-cse-after-loop \
			-frename-registers

libc_root := bionic/libc
libm_root := bionic/libm


## on some hosts, the target cross-compiler is not available so do not run this command
ifneq ($(wildcard $(TARGET_CC)),)
# We compile with the global cflags to ensure that
# any flags which affect libgcc are correctly taken
# into account.
TARGET_LIBGCC := \
  $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -print-file-name=libgcc.a)
TARGET_LIBATOMIC := \
  $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -print-file-name=libatomic.a)
LIBGCC_EH := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -print-file-name=libgcc_eh.a)
ifneq ($(LIBGCC_EH),libgcc_eh.a)
  TARGET_LIBGCC += $(LIBGCC_EH)
endif
TARGET_LIBGCOV := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) \
        --print-file-name=libgcov.a)
endif

KERNEL_HEADERS_COMMON := $(libc_root)/kernel/uapi
KERNEL_HEADERS_COMMON += $(libc_root)/kernel/common
KERNEL_HEADERS_ARCH   := $(libc_root)/kernel/uapi/asm-mips
# TODO: perhaps use $(libc_root)/kernel/uapi/asm-$(TARGET_ARCH) instead of asm-mips ?
KERNEL_HEADERS := $(KERNEL_HEADERS_COMMON) $(KERNEL_HEADERS_ARCH)

TARGET_C_INCLUDES := \
	$(libc_root)/arch-mips64/include \
	$(libc_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/mips \

# TODO: perhaps use $(libm_root)/include/mips64 instead of mips ?

TARGET_CRTBEGIN_STATIC_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_dynamic.o
TARGET_CRTEND_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_android.o

TARGET_CRTBEGIN_SO_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.o
TARGET_CRTEND_SO_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.o

TARGET_PACK_MODULE_RELOCATIONS := true

TARGET_LINKER := /system/bin/linker64
