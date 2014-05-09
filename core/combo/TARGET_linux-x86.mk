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

# Configuration for Linux on x86 as a target.
# Included by combo/select.mk

# Provide a default variant.
ifeq ($(strip $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT)),)
TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT := x86
endif

# Decouple NDK library selection with platform compiler version
$(combo_2nd_arch_prefix)TARGET_NDK_GCC_VERSION := 4.8

ifeq ($(strip $(TARGET_GCC_VERSION_EXP)),)
$(combo_2nd_arch_prefix)TARGET_GCC_VERSION := 4.8
else
$(combo_2nd_arch_prefix)TARGET_GCC_VERSION := $(TARGET_GCC_VERSION_EXP)
endif

# Include the arch-variant-specific configuration file.
# Its role is to define various ARCH_X86_HAVE_XXX feature macros,
# plus initial values for TARGET_GLOBAL_CFLAGS
#
TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_$(combo_2nd_arch_prefix)ARCH)/$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown $(TARGET_$(combo_2nd_arch_prefix)ARCH) architecture version: $(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT))
endif

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)


# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)),)
$(combo_2nd_arch_prefix)TARGET_TOOLCHAIN_ROOT := prebuilts/gcc/$(HOST_PREBUILT_TAG)/x86/x86_64-linux-android-$($(combo_2nd_arch_prefix)TARGET_GCC_VERSION)
$(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX := $($(combo_2nd_arch_prefix)TARGET_TOOLCHAIN_ROOT)/bin/x86_64-linux-android-
endif

$(combo_2nd_arch_prefix)TARGET_CC := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_CXX := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_AR := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_OBJCOPY := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_LD := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_READELF := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)readelf$(HOST_EXECUTABLE_SUFFIX)
$(combo_2nd_arch_prefix)TARGET_STRIP := $($(combo_2nd_arch_prefix)TARGET_TOOLS_PREFIX)strip$(HOST_EXECUTABLE_SUFFIX)

ifneq ($(wildcard $($(combo_2nd_arch_prefix)TARGET_CC)),)
$(combo_2nd_arch_prefix)TARGET_LIBGCC := \
	$(shell $($(combo_2nd_arch_prefix)TARGET_CC) -m32 -print-file-name=libgcc.a)
target_libgcov := $(shell $($(combo_2nd_arch_prefix)TARGET_CC) $($(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS) \
	-print-file-name=libgcov.a)
endif

$(combo_2nd_arch_prefix)TARGET_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

libc_root := bionic/libc
libm_root := bionic/libm
libstdc++_root := bionic/libstdc++

# Define FDO (Feedback Directed Optimization) options.

$(combo_2nd_arch_prefix)TARGET_FDO_CFLAGS:=
$(combo_2nd_arch_prefix)TARGET_FDO_LIB:=

ifneq ($(strip $(BUILD_FDO_INSTRUMENT)),)
  # Set BUILD_FDO_INSTRUMENT=true to turn on FDO instrumentation.
  # The profile will be generated on /data/local/tmp/profile on the device.
  $(combo_2nd_arch_prefix)TARGET_FDO_CFLAGS := -fprofile-generate=/data/local/tmp/profile -DANDROID_FDO
  $(combo_2nd_arch_prefix)TARGET_FDO_LIB := $(target_libgcov)
else
  # If BUILD_FDO_INSTRUMENT is turned off, then consider doing the FDO optimizations.
  # Set TARGET_FDO_PROFILE_PATH to set a custom profile directory for your build.
  ifeq ($(strip $($(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH)),)
    $(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH := fdo/profiles/$(TARGET_$(combo_2nd_arch_prefix)ARCH)/$(TARGET_$(combo_2nd_arch_prefix)ARCH_VARIANT)
  else
    ifeq ($(strip $(wildcard $($(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH))),)
      $(warning Custom $(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH supplied, but directory does not exist. Turn off FDO.)
    endif
  endif

  # If the FDO profile directory can't be found, then FDO is off.
  ifneq ($(strip $(wildcard $($(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH))),)
    $(combo_2nd_arch_prefix)TARGET_FDO_CFLAGS := -fprofile-use=$($(combo_2nd_arch_prefix)TARGET_FDO_PROFILE_PATH) -DANDROID_FDO
    $(combo_2nd_arch_prefix)TARGET_FDO_LIB := $(target_libgcov)
  endif
endif

KERNEL_HEADERS_COMMON := $(libc_root)/kernel/uapi
KERNEL_HEADERS_ARCH   := $(libc_root)/kernel/uapi/asm-x86 # x86 covers both x86 and x86_64.
KERNEL_HEADERS := $(KERNEL_HEADERS_COMMON) $(KERNEL_HEADERS_ARCH)

android_config_h := $(call select-android-config-h,target_linux-x86)

$(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += \
			-O2 \
			-Wa,--noexecstack \
			-Werror=format-security \
			-D_FORTIFY_SOURCE=2 \
			-Wstrict-aliasing=2 \
			-fPIC -fPIE \
			-ffunction-sections \
			-finline-functions \
			-finline-limit=300 \
			-fno-inline-functions-called-once \
			-fno-short-enums \
			-fstrict-aliasing \
			-funswitch-loops \
			-funwind-tables \
			-fstack-protector \
			-m32 \
			-msse2 \
			-no-canonical-prefixes \
			-fno-canonical-system-headers \
			-include $(android_config_h) \
			-I $(dir $(android_config_h))

$(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += $(arch_variant_cflags)

ifeq ($(ARCH_X86_HAVE_SSSE3),true)   # yes, really SSSE3, not SSE3!
    $(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -DUSE_SSSE3 -mssse3
endif
ifeq ($(ARCH_X86_HAVE_SSE4),true)
    $(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -msse4
endif
ifeq ($(ARCH_X86_HAVE_SSE4_1),true)
    $(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -msse4.1
endif
ifeq ($(ARCH_X86_HAVE_SSE4_2),true)
    $(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -msse4.2
endif
ifeq ($(ARCH_X86_HAVE_AVX),true)
    $(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -mavx
endif
ifeq ($(ARCH_X86_HAVE_AES_NI),true)
    $(combo_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS += -maes
endif

$(combo_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS += -m32

$(combo_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS += -Wl,-z,noexecstack
$(combo_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS += -Wl,-z,relro -Wl,-z,now
$(combo_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS += -Wl,--warn-shared-textrel
$(combo_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS += -Wl,--fatal-warnings
$(combo_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS += -Wl,--gc-sections

$(combo_2nd_arch_prefix)TARGET_C_INCLUDES := \
	$(libc_root)/arch-x86/include \
	$(libc_root)/include \
	$(libstdc++_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/i387 \

$(combo_2nd_arch_prefix)TARGET_CRTBEGIN_STATIC_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_static.o
$(combo_2nd_arch_prefix)TARGET_CRTBEGIN_DYNAMIC_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_dynamic.o
$(combo_2nd_arch_prefix)TARGET_CRTEND_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_android.o

$(combo_2nd_arch_prefix)TARGET_CRTBEGIN_SO_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.o
$(combo_2nd_arch_prefix)TARGET_CRTEND_SO_O := $($(combo_2nd_arch_prefix)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.o

$(combo_2nd_arch_prefix)TARGET_STRIP_MODULE:=true

$(combo_2nd_arch_prefix)TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libstdc++ libm

$(combo_2nd_arch_prefix)TARGET_CUSTOM_LD_COMMAND := true
define $(combo_2nd_arch_prefix)transform-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	 -nostdlib -Wl,-soname,$(notdir $@) \
	 -shared -Bsymbolic \
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
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTEND_SO_O)) \
	$(PRIVATE_LDLIBS)
endef

define $(combo_2nd_arch_prefix)transform-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	-nostdlib -Bdynamic \
	-Wl,-z,nocopyreloc \
	-fPIE -pie \
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
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTEND_O)) \
	$(PRIVATE_LDLIBS)
endef

define $(combo_2nd_arch_prefix)transform-o-to-static-executable-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	-nostdlib -Bstatic \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTBEGIN_STATIC_O)) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	-Wl,--start-group \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(PRIVATE_TARGET_FDO_LIB) \
	$(PRIVATE_TARGET_LIBGCC) \
	-Wl,--end-group \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTEND_O))
endef
