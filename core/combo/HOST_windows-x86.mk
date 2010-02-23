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

# Configuration for Linux on x86.
# Included by combo/select.make

# right now we get these from the environment, but we should
# pick them from the tree somewhere
TOOLS_PREFIX := #prebuilt/windows/host/bin/
TOOLS_EXE_SUFFIX := .exe

# Settings to use MinGW has a cross-compiler under Linux
ifneq ($(findstring Linux,$(UNAME)),)
ifneq ($(strip $(USE_MINGW)),)
HOST_ACP_UNAVAILABLE := true
TOOLS_PREFIX := /usr/bin/i586-mingw32msvc-
TOOLS_EXE_SUFFIX :=
HOST_GLOBAL_CFLAGS += -DUSE_MINGW
HOST_C_INCLUDES += /usr/lib/gcc/i586-mingw32msvc/3.4.4/include
HOST_GLOBAL_LD_DIRS += -L/usr/i586-mingw32msvc/lib
endif
endif

HOST_CC := $(TOOLS_PREFIX)gcc$(TOOLS_EXE_SUFFIX)
HOST_CXX := $(TOOLS_PREFIX)g++$(TOOLS_EXE_SUFFIX)
HOST_AR := $(TOOLS_PREFIX)ar$(TOOLS_EXE_SUFFIX)

HOST_GLOBAL_CFLAGS += -include $(call select-android-config-h,windows)
HOST_GLOBAL_LDFLAGS += --enable-stdcall-fixup

# when building under Cygwin, ensure that we use Mingw compilation by default.
# you can disable this (i.e. to generate Cygwin executables) by defining the
# USE_CYGWIN variable in your environment, e.g.:
#
#   export USE_CYGWIN=1
#
# note that the -mno-cygwin flags are not needed when cross-compiling the
# Windows host tools on Linux
#
ifneq ($(findstring CYGWIN,$(UNAME)),)
ifeq ($(strip $(USE_CYGWIN)),)
HOST_GLOBAL_CFLAGS += -mno-cygwin
HOST_GLOBAL_LDFLAGS += -mno-cygwin -mconsole
endif
endif

HOST_SHLIB_SUFFIX := .dll
HOST_EXECUTABLE_SUFFIX := .exe

# $(1): The file to check
# TODO: find out what format cygwin's stat(1) uses
define get-file-size
999999999
endef
