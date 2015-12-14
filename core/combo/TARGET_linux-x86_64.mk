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

# Configuration for Linux on x86_64 as a target.
# Included by combo/select.mk

# Provide a default variant.
ifeq ($(strip $(TARGET_ARCH_VARIANT)),)
TARGET_ARCH_VARIANT := x86_64
endif

# Decouple NDK library selection with platform compiler version
TARGET_NDK_GCC_VERSION := 4.9

ifeq ($(strip $(TARGET_GCC_VERSION_EXP)),)
TARGET_GCC_VERSION := 4.9
else
TARGET_GCC_VERSION := $(TARGET_GCC_VERSION_EXP)
endif

# Include the arch-variant-specific configuration file.
# Its role is to define various ARCH_X86_HAVE_XXX feature macros,
# plus initial values for TARGET_GLOBAL_CFLAGS
#
TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_ARCH)/$(TARGET_ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown $(TARGET_ARCH) architecture version: $(TARGET_ARCH_VARIANT))
endif

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)
include $(BUILD_SYSTEM)/combo/fdo.mk

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $(TARGET_TOOLS_PREFIX)),)
TARGET_TOOLCHAIN_ROOT := prebuilts/gcc/$(HOST_PREBUILT_TAG)/x86/x86_64-linux-android-$(TARGET_GCC_VERSION)
TARGET_TOOLS_PREFIX := $(TARGET_TOOLCHAIN_ROOT)/bin/x86_64-linux-android-
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

ifneq ($(wildcard $(TARGET_CC)),)
TARGET_LIBGCC := \
	$(shell $(TARGET_CC) -m64 -print-file-name=libgcc.a)
TARGET_LIBATOMIC := \
	$(shell $(TARGET_CC) -m64 -print-file-name=libatomic.a)
TARGET_LIBGCOV := \
	$(shell $(TARGET_CC) -m64 -print-file-name=libgcov.a)
endif

TARGET_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

libc_root := bionic/libc
libm_root := bionic/libm

KERNEL_HEADERS_COMMON := $(libc_root)/kernel/uapi
KERNEL_HEADERS_COMMON += $(libc_root)/kernel/common
KERNEL_HEADERS_ARCH   := $(libc_root)/kernel/uapi/asm-x86 # x86 covers both x86 and x86_64.
KERNEL_HEADERS := $(KERNEL_HEADERS_COMMON) $(KERNEL_HEADERS_ARCH)

TARGET_GLOBAL_CFLAGS += \
			-O2 \
			-Wa,--noexecstack \
			-Werror=format-security \
			-D_FORTIFY_SOURCE=2 \
			-Wstrict-aliasing=2 \
			-ffunction-sections \
			-finline-functions \
			-finline-limit=300 \
			-fno-short-enums \
			-fstrict-aliasing \
			-funswitch-loops \
			-funwind-tables \
			-fstack-protector-strong \
			-m64 \
			-no-canonical-prefixes \
			-fno-canonical-system-headers

# Help catch common 32/64-bit errors.
TARGET_GLOBAL_CFLAGS += \
    -Werror=pointer-to-int-cast \
    -Werror=int-to-pointer-cast \
    -Werror=implicit-function-declaration \

TARGET_GLOBAL_CFLAGS += $(arch_variant_cflags)

ifeq ($(ARCH_X86_HAVE_SSSE3),true)   # yes, really SSSE3, not SSE3!
    TARGET_GLOBAL_CFLAGS += -DUSE_SSSE3 -mssse3
endif
ifeq ($(ARCH_X86_HAVE_SSE4),true)
    TARGET_GLOBAL_CFLAGS += -msse4
endif
ifeq ($(ARCH_X86_HAVE_SSE4_1),true)
    TARGET_GLOBAL_CFLAGS += -msse4.1
endif
ifeq ($(ARCH_X86_HAVE_SSE4_2),true)
    TARGET_GLOBAL_CFLAGS += -msse4.2
endif
ifeq ($(ARCH_X86_HAVE_POPCNT),true)
    TARGET_GLOBAL_CFLAGS += -mpopcnt
endif
ifeq ($(ARCH_X86_HAVE_AVX),true)
    TARGET_GLOBAL_CFLAGS += -mavx
endif
ifeq ($(ARCH_X86_HAVE_AES_NI),true)
    TARGET_GLOBAL_CFLAGS += -maes
endif

TARGET_GLOBAL_LDFLAGS += -m64

TARGET_GLOBAL_LDFLAGS += -Wl,-z,noexecstack
TARGET_GLOBAL_LDFLAGS += -Wl,-z,relro -Wl,-z,now
TARGET_GLOBAL_LDFLAGS += -Wl,--build-id=md5
TARGET_GLOBAL_LDFLAGS += -Wl,--warn-shared-textrel
TARGET_GLOBAL_LDFLAGS += -Wl,--fatal-warnings
TARGET_GLOBAL_LDFLAGS += -Wl,--gc-sections
TARGET_GLOBAL_LDFLAGS += -Wl,--hash-style=gnu
TARGET_GLOBAL_LDFLAGS += -Wl,--no-undefined-version

TARGET_C_INCLUDES := \
	$(libc_root)/arch-x86_64/include \
	$(libc_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/amd64 \

TARGET_CRTBEGIN_STATIC_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_dynamic.o
TARGET_CRTEND_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_android.o

TARGET_CRTBEGIN_SO_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.o
TARGET_CRTEND_SO_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.o

TARGET_LINKER := /system/bin/linker64

TARGET_GLOBAL_YASM_FLAGS := -f elf64 -m amd64
