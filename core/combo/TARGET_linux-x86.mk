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

ifeq ($(TARGET_SIMULATOR),true)
# When building for the simulator, use the HOST settings as TARGET settings
TARGET_CC := $(HOST_CC)
TARGET_CXX := $(HOST_CXX)
TARGET_AR := $(HOST_AR)
TARGET_GLOBAL_CFLAGS := $(HOST_GLOBAL_CFLAGS) -m32
TARGET_GLOBAL_LDFLAGS := $(HOST_GLOBAL_LDFLAGS) -m32
TARGET_NO_UNDEFINED_LDFLAGS := $(HOST_NO_UNDEFINED_LDFLAGS)
TARGET_ARCH_VARIANT := x86
else #simulator

# Provide a default variant.
ifeq ($(strip $(TARGET_ARCH_VARIANT)),)
TARGET_ARCH_VARIANT := x86
endif

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $(TARGET_TOOLS_PREFIX)),)
TARGET_TOOLS_PREFIX := \
	prebuilt/$(HOST_PREBUILT_TAG)/toolchain/i686-unknown-linux-gnu-4.2.1/bin/i686-unknown-linux-gnu-
endif

TARGET_CC := $(TARGET_TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
TARGET_CXX := $(TARGET_TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
TARGET_AR := $(TARGET_TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
TARGET_OBJCOPY := $(TARGET_TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
TARGET_LD := $(TARGET_TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)

ifneq ($(wildcard $(TARGET_CC)),)
TARGET_LIBGCC := \
	$(shell $(TARGET_CC) -m32 -print-file-name=libgcc.a) \
        $(shell $(TARGET_CC) -m32 -print-file-name=libgcc_eh.a)
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
			-march=i686 \
			-m32 \
			-fPIC \
			-include $(call select-android-config-h,target_linux-x86)

TARGET_GLOBAL_CPPFLAGS += \
			-fno-use-cxa-atexit

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

# TARGET_STRIP_MODULE:=true

TARGET_DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libstdc++ libm

TARGET_CUSTOM_LD_COMMAND := true
define transform-o-to-shared-lib-inner
$(TARGET_CXX) \
	$(TARGET_GLOBAL_LDFLAGS) \
	 -nostdlib -Wl,-soname,$(notdir $@) \
	 -shared -Bsymbolic \
	-fPIC -march=i686 \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(TARGET_CRTBEGIN_SO_O) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDFLAGS) \
	$(TARGET_LIBGCC) \
	$(TARGET_CRTEND_SO_O)
endef


define transform-o-to-executable-inner
$(TARGET_CXX) \
	$(TARGET_GLOBAL_LDFLAGS) \
	-nostdlib -Bdynamic \
	-Wl,-dynamic-linker,/system/bin/linker \
	-Wl,-z,nocopyreloc \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	-Wl,-rpath-link=$(TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	$(TARGET_CRTBEGIN_DYNAMIC_O) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(PRIVATE_LDFLAGS) \
	$(TARGET_LIBGCC) \
	$(TARGET_CRTEND_O)
endef

define transform-o-to-static-executable-inner
$(TARGET_CXX) \
	$(TARGET_GLOBAL_LDFLAGS) \
	-nostdlib -Bstatic \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(TARGET_CRTBEGIN_STATIC_O) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--start-group \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(TARGET_LIBGCC) \
	-Wl,--end-group \
	$(TARGET_CRTEND_O)
endef

TARGET_GLOBAL_CFLAGS += -m32
TARGET_GLOBAL_LDFLAGS += -m32

endif #simulator
