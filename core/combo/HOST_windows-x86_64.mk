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

# right now we get these from the environment, but we should
# pick them from the tree somewhere
TOOLS_PREFIX := /usr/bin/amd64-mingw32msvc-

HOST_ACP_UNAVAILABLE := true
HOST_GLOBAL_CFLAGS += -DUSE_MINGW
HOST_C_INCLUDES += /usr/lib/gcc/amd64-mingw32msvc/4.4.2/include
HOST_GLOBAL_LD_DIRS += -L/usr/amd64-mingw32msvc/lib

# Workaround differences in inttypes.h between host and target.
# See bug 12708004.
HOST_GLOBAL_CFLAGS += -D__STDC_FORMAT_MACROS -D__STDC_CONSTANT_MACROS
# Use C99-compliant printf functions (%zd).
HOST_GLOBAL_CFLAGS += -D__USE_MINGW_ANSI_STDIO=1
# Admit to using >= Win2K.
HOST_GLOBAL_CFLAGS += -D_WIN32_WINNT=0x0500

HOST_CC := $(TOOLS_PREFIX)gcc$(TOOLS_EXE_SUFFIX)
HOST_CXX := $(TOOLS_PREFIX)g++$(TOOLS_EXE_SUFFIX)
HOST_AR := $(TOOLS_PREFIX)ar$(TOOLS_EXE_SUFFIX)

HOST_GLOBAL_LDFLAGS += --enable-stdcall-fixup
ifneq ($(strip $(BUILD_HOST_static)),)
# Statically-linked binaries are desirable for sandboxed environment
HOST_GLOBAL_LDFLAGS += -static
endif # BUILD_HOST_static
