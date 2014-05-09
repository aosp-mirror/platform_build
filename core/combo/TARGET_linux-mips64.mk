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
# than mips64. Each value should correspond to a file named
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
ifeq ($(strip $(TARGET_ARCH_VARIANT)),)
TARGET_ARCH_VARIANT := mips64r2
endif

# Decouple NDK library selection with platform compiler version
TARGET_NDK_GCC_VERSION := 4.8

ifeq ($(strip $(TARGET_GCC_VERSION_EXP)),)
TARGET_GCC_VERSION := 4.8
else
TARGET_GCC_VERSION := $(TARGET_GCC_VERSION_EXP)
endif

TARGET_IS_64_BIT := true

TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_ARCH)/$(TARGET_ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown MIPS architecture variant: $(TARGET_ARCH_VARIANT))
endif

# TODO: Enable Clang when its mips64 prebuilt is added
WITHOUT_TARGET_CLANG := true

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $(TARGET_TOOLS_PREFIX)),)
TARGET_TOOLCHAIN_ROOT := prebuilts/gcc/$(HOST_PREBUILT_TAG)/mips/mips64el-linux-android-$(TARGET_GCC_VERSION)
TARGET_TOOLS_PREFIX := $(TARGET_TOOLCHAIN_ROOT)/bin/mips64el-linux-android-
endif

TARGET_CC := $(TARGET_TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
TARGET_CXX := $(TARGET_TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
TARGET_AR := $(TARGET_TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
TARGET_OBJCOPY := $(TARGET_TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
TARGET_LD := $(TARGET_TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)
TARGET_READELF := $(TARGET_TOOLS_PREFIX)readelf$(HOST_EXECUTABLE_SUFFIX)
TARGET_STRIP := $(TARGET_TOOLS_PREFIX)strip$(HOST_EXECUTABLE_SUFFIX)

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

android_config_h := $(call select-android-config-h,linux-mips64)

TARGET_GLOBAL_CFLAGS += \
			$(TARGET_mips_CFLAGS) \
			-U__unix -U__unix__ -Umips \
			-fpic -fPIE\
			-ffunction-sections \
			-fdata-sections \
			-funwind-tables \
			-Wa,--noexecstack \
			-Werror=format-security \
			-D_FORTIFY_SOURCE=2 \
			-no-canonical-prefixes \
			-fno-canonical-system-headers \
			$(arch_variant_cflags) \
			-include $(android_config_h) \
			-I $(dir $(android_config_h))

# This warning causes dalvik not to build with gcc 4.6+ and -Werror.
# We cannot turn it off blindly since the option is not available
# in gcc-4.4.x.
ifneq ($(filter 4.6 4.6.% 4.7 4.7.% 4.8, $(TARGET_GCC_VERSION)),)
TARGET_GLOBAL_CFLAGS += -Wno-unused-but-set-variable \
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
TARGET_GLOBAL_CFLAGS += -Wno-psabi

ifneq ($(ARCH_MIPS_PAGE_SHIFT),)
TARGET_GLOBAL_CFLAGS += -DPAGE_SHIFT=$(ARCH_MIPS_PAGE_SHIFT)
endif

TARGET_GLOBAL_LDFLAGS += \
			-Wl,-z,noexecstack \
			-Wl,-z,relro \
			-Wl,-z,now \
			-Wl,--warn-shared-textrel \
			-Wl,--fatal-warnings \
			$(arch_variant_ldflags)

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
libstdc++_root := bionic/libstdc++
libthread_db_root := bionic/libthread_db


## on some hosts, the target cross-compiler is not available so do not run this command
ifneq ($(wildcard $(TARGET_CC)),)
# We compile with the global cflags to ensure that
# any flags which affect libgcc are correctly taken
# into account.
TARGET_LIBGCC := \
  $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -print-file-name=libgcc.a)
LIBGCC_EH := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -print-file-name=libgcc_eh.a)
ifneq ($(LIBGCC_EH),libgcc_eh.a)
  TARGET_LIBGCC += $(LIBGCC_EH)
endif
target_libgcov := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) \
        --print-file-name=libgcov.a)
endif

# Define FDO (Feedback Directed Optimization) options.

TARGET_FDO_CFLAGS:=
TARGET_FDO_LIB:=

ifneq ($(strip $(BUILD_FDO_INSTRUMENT)),)
  # Set BUILD_FDO_INSTRUMENT=true to turn on FDO instrumentation.
  # The profile will be generated on /data/local/tmp/profile on the device.
  TARGET_FDO_CFLAGS := -fprofile-generate=/data/local/tmp/profile -DANDROID_FDO
  TARGET_FDO_LIB := $(target_libgcov)
else
  # If BUILD_FDO_INSTRUMENT is turned off, then consider doing the FDO optimizations.
  # Set TARGET_FDO_PROFILE_PATH to set a custom profile directory for your build.
  ifeq ($(strip $(TARGET_FDO_PROFILE_PATH)),)
    TARGET_FDO_PROFILE_PATH := fdo/profiles/$(TARGET_ARCH)/$(TARGET_ARCH_VARIANT)
  else
    ifeq ($(strip $(wildcard $(TARGET_FDO_PROFILE_PATH))),)
      $(warning Custom TARGET_FDO_PROFILE_PATH supplied, but directory does not exist. Turn off FDO.)
    endif
  endif

  # If the FDO profile directory can't be found, then FDO is off.
  ifneq ($(strip $(wildcard $(TARGET_FDO_PROFILE_PATH))),)
    TARGET_FDO_CFLAGS := -fprofile-use=$(TARGET_FDO_PROFILE_PATH) -DANDROID_FDO
    TARGET_FDO_LIB := $(target_libgcov)
  endif
endif


KERNEL_HEADERS_COMMON := $(libc_root)/kernel/uapi
KERNEL_HEADERS_ARCH   := $(libc_root)/kernel/uapi/asm-mips
# TODO: perhaps use $(libc_root)/kernel/uapi/asm-$(TARGET_ARCH) instead of asm-mips ?
KERNEL_HEADERS := $(KERNEL_HEADERS_COMMON) $(KERNEL_HEADERS_ARCH)

TARGET_C_INCLUDES := \
	$(libc_root)/arch-mips64/include \
	$(libc_root)/include \
	$(libstdc++_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/mips \
	$(libthread_db_root)/include
# TODO: perhaps use $(libm_root)/include/mips64 instead of mips ?

TARGET_CRTBEGIN_STATIC_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_dynamic.o
TARGET_CRTEND_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_android.o

TARGET_CRTBEGIN_SO_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.o
TARGET_CRTEND_SO_O := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.o

TARGET_STRIP_MODULE:=true

TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libstdc++ libm

TARGET_CUSTOM_LD_COMMAND := true

define transform-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
	-nostdlib -Wl,-soname,$(notdir $@) \
	-Wl,--gc-sections \
	-Wl,-shared,-Bsymbolic \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTBEGIN_SO_O)) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(PRIVATE_TARGET_FDO_LIB) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTEND_SO_O)) \
	$(PRIVATE_LDLIBS)
endef

define transform-o-to-executable-inner
$(hide) $(PRIVATE_CXX) -nostdlib -Bdynamic -fPIE -pie \
	-Wl,-dynamic-linker,/system/bin/linker64 \
	-Wl,--gc-sections \
	-Wl,-z,nocopyreloc \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	-Wl,-rpath-link=$(PRIVATE_TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTBEGIN_DYNAMIC_O)) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(PRIVATE_TARGET_FDO_LIB) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTEND_O)) \
	$(PRIVATE_LDLIBS)
endef

define transform-o-to-static-executable-inner
$(hide) $(PRIVATE_CXX) -nostdlib -Bstatic \
	-Wl,--gc-sections \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTBEGIN_STATIC_O)) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(call normalize-target-libraries,$(filter-out %libc_nomalloc.a,$(filter-out %libc.a,$(PRIVATE_ALL_STATIC_LIBRARIES)))) \
	-Wl,--start-group \
	$(call normalize-target-libraries,$(filter %libc.a,$(PRIVATE_ALL_STATIC_LIBRARIES))) \
	$(call normalize-target-libraries,$(filter %libc_nomalloc.a,$(PRIVATE_ALL_STATIC_LIBRARIES))) \
	$(PRIVATE_TARGET_FDO_LIB) \
	$(PRIVATE_TARGET_LIBGCC) \
	-Wl,--end-group \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTEND_O))
endef
