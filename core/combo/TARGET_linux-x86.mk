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
ifeq ($(strip $(TARGET_ARCH_VARIANT)),)
TARGET_ARCH_VARIANT := x86
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


# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $(TARGET_TOOLS_PREFIX)),)
TARGET_TOOLCHAIN_ROOT := prebuilts/gcc/$(HOST_PREBUILT_TAG)/x86/i686-android-linux-4.4.3
TARGET_TOOLS_PREFIX := $(TARGET_TOOLCHAIN_ROOT)/bin/i686-android-linux-
endif

TARGET_CC := $(TARGET_TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
TARGET_CXX := $(TARGET_TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
TARGET_AR := $(TARGET_TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
TARGET_OBJCOPY := $(TARGET_TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
TARGET_LD := $(TARGET_TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)
TARGET_STRIP := $(TARGET_TOOLS_PREFIX)strip$(HOST_EXECUTABLE_SUFFIX)

ifeq ($(TARGET_BUILD_VARIANT),user)
TARGET_STRIP_COMMAND = $(TARGET_STRIP) --strip-debug $< -o $@
else
TARGET_STRIP_COMMAND = $(TARGET_STRIP) --strip-debug $< -o $@ && \
	$(TARGET_OBJCOPY) --add-gnu-debuglink=$< $@
endif

ifneq ($(wildcard $(TARGET_CC)),)
TARGET_LIBGCC := \
	$(shell $(TARGET_CC) -m32 -print-file-name=libgcc.a)
endif

TARGET_NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

libc_root := bionic/libc
libm_root := bionic/libm
libstdc++_root := bionic/libstdc++
libthread_db_root := bionic/libthread_db

# unless CUSTOM_KERNEL_HEADERS is defined, we're going to use
# symlinks located in out/ to point to the appropriate kernel
# headers. see 'config/kernel_headers.make' for more details
#
ifneq ($(CUSTOM_KERNEL_HEADERS),)
    KERNEL_HEADERS_COMMON := $(CUSTOM_KERNEL_HEADERS)
    KERNEL_HEADERS_ARCH   := $(CUSTOM_KERNEL_HEADERS)
else
    KERNEL_HEADERS_COMMON := $(libc_root)/kernel/common
    KERNEL_HEADERS_ARCH   := $(libc_root)/kernel/arch-$(TARGET_ARCH)
endif
KERNEL_HEADERS := $(KERNEL_HEADERS_COMMON) $(KERNEL_HEADERS_ARCH)

TARGET_GLOBAL_CFLAGS += \
			-O2 \
			-Ulinux \
			-Wa,--noexecstack \
			-Werror=format-security \
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
			-include $(call select-android-config-h,target_linux-x86)

# XXX: Not sure this is still needed. Must check with our toolchains.
TARGET_GLOBAL_CPPFLAGS += \
			-fno-use-cxa-atexit

# XXX: Our toolchain is normally configured to always set these flags by default
# however, there have been reports that this is sometimes not the case. So make
# them explicit here unless we have the time to carefully check it
#
TARGET_GLOBAL_CFLAGS += -mstackrealign -msse3 -mfpmath=sse

# XXX: These flags should not be defined here anymore. Instead, the Android.mk
# of the modules that depend on these features should instead check the
# corresponding macros (e.g. ARCH_X86_HAVE_SSE2 and ARCH_X86_HAVE_SSSE3)
# Keep them here until this is all cleared up.
#
ifeq ($(ARCH_X86_HAVE_SSE2),true)
TARGET_GLOBAL_CFLAGS += -DUSE_SSE2
endif

ifeq ($(ARCH_X86_HAVE_SSSE3),true)   # yes, really SSSE3, not SSE3!
TARGET_GLOBAL_CFLAGS += -DUSE_SSSE3
endif

# XXX: This flag is probably redundant. I believe our toolchain always sets
# it by default. Consider for removal.
#
TARGET_GLOBAL_CFLAGS += -mbionic

# XXX: This flag is probably redundant. The macro should be defined by our
# toolchain binaries automatically (as a compiler built-in).
# Check with: $BINPREFIX-gcc -dM -E < /dev/null
#
# Consider for removal.
#
TARGET_GLOBAL_CFLAGS += -D__ANDROID__

# XXX: This flag is probably redundant since our toolchain binaries already
# generate 32-bit machine code. It probably dates back to the old days
# where we were using the host toolchain on Linux to build the platform
# images. Consider it for removal.
TARGET_GLOBAL_LDFLAGS += -m32

TARGET_GLOBAL_LDFLAGS += -Wl,-z,noexecstack
TARGET_GLOBAL_LDFLAGS += -Wl,-z,relro -Wl,-z,now
TARGET_GLOBAL_LDFLAGS += -Wl,--gc-sections

TARGET_C_INCLUDES := \
	$(libc_root)/arch-x86/include \
	$(libc_root)/include \
	$(libstdc++_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/i387 \
	$(libthread_db_root)/include

TARGET_CRTBEGIN_STATIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_dynamic.o
TARGET_CRTEND_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtend_android.o

TARGET_CRTBEGIN_SO_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_so.o
TARGET_CRTEND_SO_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtend_so.o

TARGET_STRIP_MODULE:=true

TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libstdc++ libm

TARGET_CUSTOM_LD_COMMAND := true
define transform-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	 -nostdlib -Wl,-soname,$(notdir $@) \
	 -shared -Bsymbolic \
	$(TARGET_GLOBAL_CFLAGS) \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTBEGIN_SO_O)) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(PRIVATE_TARGET_CRTEND_SO_O))
endef


define transform-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
	$(TARGET_GLOBAL_LDFLAGS) \
	-nostdlib -Bdynamic \
	-Wl,-dynamic-linker,/system/bin/linker \
	-Wl,-z,nocopyreloc \
	-fPIE -pie \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	-Wl,-rpath-link=$(TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(TARGET_CRTBEGIN_DYNAMIC_O)) \
	$(PRIVATE_ALL_OBJECTS) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(PRIVATE_LDFLAGS) \
	$(TARGET_LIBGCC) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(TARGET_CRTEND_O))
endef

define transform-o-to-static-executable-inner
$(hide) $(PRIVATE_CXX) \
	$(TARGET_GLOBAL_LDFLAGS) \
	-nostdlib -Bstatic \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(TARGET_CRTBEGIN_STATIC_O)) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--start-group \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(TARGET_LIBGCC) \
	-Wl,--end-group \
	$(if $(filter true,$(PRIVATE_NO_CRT)),,$(TARGET_CRTEND_O))
endef

# Special check for x86 NDK ABI compatibility.
# The TARGET_CPU_ABI variable should be defined in BoardConfig.mk to 'x86'
# *only* if the platform image is compatible with the NDK x86 ABI.
#
# We perform a small check here to ensure that nothing bad can happen.
#
ifeq ($(TARGET_CPU_ABI),x86)
  ifneq (true-true-true-true,$(ARCH_X86_HAVE_MMX)-$(ARCH_X86_HAVE_SSE)-$(ARCH_X86_HAVE_SSE2)-$(ARCH_X86_HAVE_SSE3))
    $(info ERROR: Your x86 platform image is not compatible with the NDK x86 ABI)
    $(info As such, you should *not* define TARGET_CPU_ABI to 'x86' in your BoardConfig.mk)
    $(info to ensure that your device will not be mistakenly listed as compatible by
    $(info the Android Market. Also, it is likely that the image will fail the CTS tests)
    $(info Please undefine TARGET_CPU_ABI in your BoardConfig.mk, or select the value 'none')
    $(info The corresponding image will still be able to run Dalvik-based Android applications)
    $(error Aborting build! Please fix your BoardConfig.mk)
  endif
endif
