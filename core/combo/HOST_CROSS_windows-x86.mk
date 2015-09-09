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

# Settings to use MinGW as a cross-compiler under Linux
# Included by combo/select.make

$(combo_var_prefix)GLOBAL_CFLAGS += -DUSE_MINGW -DWIN32_LEAN_AND_MEAN
$(combo_var_prefix)GLOBAL_CFLAGS += -Wno-unused-parameter
$(combo_var_prefix)GLOBAL_CFLAGS += --sysroot=prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8/x86_64-w64-mingw32
$(combo_var_prefix)GLOBAL_CFLAGS += -m32
$(combo_var_prefix)GLOBAL_LDFLAGS += -m32
TOOLS_PREFIX := prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8/bin/x86_64-w64-mingw32-
$(combo_var_prefix)C_INCLUDES += prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/include
$(combo_var_prefix)C_INCLUDES += prebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8/lib/gcc/x86_64-w64-mingw32/4.8.3/include
$(combo_var_prefix)GLOBAL_LD_DIRS += -Lprebuilts/gcc/linux-x86/host/x86_64-w64-mingw32-4.8/x86_64-w64-mingw32/lib32

# Workaround differences in inttypes.h between host and target.
# See bug 12708004.
$(combo_var_prefix)GLOBAL_CFLAGS += -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS
# Use C99-compliant printf functions (%zd).
$(combo_var_prefix)GLOBAL_CFLAGS += -D__USE_MINGW_ANSI_STDIO=1
# Admit to using >= Win2K.
$(combo_2nd_arch_prefix)HOST_GLOBAL_CFLAGS += -D_WIN32_WINNT=0x0500
# Get 64-bit off_t and related functions.
$(combo_2nd_arch_prefix)HOST_GLOBAL_CFLAGS += -D_FILE_OFFSET_BITS=64

$(combo_var_prefix)CC := $(TOOLS_PREFIX)gcc
$(combo_var_prefix)CXX := $(TOOLS_PREFIX)g++
$(combo_var_prefix)AR := $(TOOLS_PREFIX)ar

$(combo_var_prefix)HOST_GLOBAL_LDFLAGS += \
    --enable-stdcall-fixup

ifneq ($(strip $(BUILD_HOST_static)),)
# Statically-linked binaries are desirable for sandboxed environment
$(combo_var_prefix)GLOBAL_LDFLAGS += -static
endif # BUILD_HOST_static

$(combo_var_prefix)SHLIB_SUFFIX := .dll
$(combo_var_prefix)EXECUTABLE_SUFFIX := .exe

$(combo_var_prefix)IS_64_BIT :=
