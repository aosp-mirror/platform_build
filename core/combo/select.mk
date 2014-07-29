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

# Select a combo based on the compiler being used.
#
# Inputs:
#	combo_target -- prefix for final variables (HOST_ or TARGET_)
#	combo_2nd_arch_prefix -- it's defined if this is loaded for the 2nd arch.
#

# Build a target string like "linux-arm" or "darwin-x86".
combo_os_arch := $($(combo_target)OS)-$($(combo_target)$(combo_2nd_arch_prefix)ARCH)

combo_var_prefix := $(combo_2nd_arch_prefix)$(combo_target)

# Set reasonable defaults for the various variables

$(combo_var_prefix)CC := $(CC)
$(combo_var_prefix)CXX := $(CXX)
$(combo_var_prefix)AR := $(AR)
$(combo_var_prefix)STRIP := $(STRIP)

$(combo_var_prefix)BINDER_MINI := 0

$(combo_var_prefix)HAVE_EXCEPTIONS := 0
$(combo_var_prefix)HAVE_UNIX_FILE_PATH := 1
$(combo_var_prefix)HAVE_WINDOWS_FILE_PATH := 0
$(combo_var_prefix)HAVE_RTTI := 1
$(combo_var_prefix)HAVE_CALL_STACKS := 1
$(combo_var_prefix)HAVE_64BIT_IO := 1
$(combo_var_prefix)HAVE_CLOCK_TIMERS := 1
$(combo_var_prefix)HAVE_PTHREAD_RWLOCK := 1
$(combo_var_prefix)HAVE_STRNLEN := 1
$(combo_var_prefix)HAVE_STRERROR_R_STRRET := 1
$(combo_var_prefix)HAVE_STRLCPY := 0
$(combo_var_prefix)HAVE_STRLCAT := 0
$(combo_var_prefix)HAVE_KERNEL_MODULES := 0

$(combo_var_prefix)GLOBAL_CFLAGS := -fno-exceptions -Wno-multichar
$(combo_var_prefix)RELEASE_CFLAGS := -O2 -g -fno-strict-aliasing
$(combo_var_prefix)GLOBAL_CPPFLAGS :=
$(combo_var_prefix)GLOBAL_LDFLAGS :=
$(combo_var_prefix)GLOBAL_ARFLAGS := crsPD
$(combo_var_prefix)GLOBAL_LD_DIRS :=

$(combo_var_prefix)EXECUTABLE_SUFFIX :=
$(combo_var_prefix)SHLIB_SUFFIX := .so
$(combo_var_prefix)JNILIB_SUFFIX := $($(combo_var_prefix)SHLIB_SUFFIX)
$(combo_var_prefix)STATIC_LIB_SUFFIX := .a

# Now include the combo for this specific target.
include $(BUILD_COMBOS)/$(combo_target)$(combo_os_arch).mk

ifneq ($(USE_CCACHE),)
  # The default check uses size and modification time, causing false misses
  # since the mtime depends when the repo was checked out
  export CCACHE_COMPILERCHECK := content

  # See man page, optimizations to get more cache hits
  # implies that __DATE__ and __TIME__ are not critical for functionality.
  # Ignore include file modification time since it will depend on when
  # the repo was checked out
  export CCACHE_SLOPPINESS := time_macros,include_file_mtime,file_macro

  # Turn all preprocessor absolute paths into relative paths.
  # Fixes absolute paths in preprocessed source due to use of -g.
  # We don't really use system headers much so the rootdir is
  # fine; ensures these paths are relative for all Android trees
  # on a workstation.
  export CCACHE_BASEDIR := /

  # Workaround for ccache with clang.
  # See http://petereisentraut.blogspot.com/2011/09/ccache-and-clang-part-2.html
  export CCACHE_CPP2 := true

  CCACHE_HOST_TAG := $(HOST_PREBUILT_TAG)
  # If we are cross-compiling Windows binaries on Linux
  # then use the linux ccache binary instead.
  ifeq ($(HOST_OS)-$(BUILD_OS),windows-linux)
    CCACHE_HOST_TAG := linux-$(HOST_PREBUILT_ARCH)
  endif
  ccache := prebuilts/misc/$(CCACHE_HOST_TAG)/ccache/ccache
  # Check that the executable is here.
  ccache := $(strip $(wildcard $(ccache)))
  ifdef ccache
    ifndef CC_WRAPPER
      CC_WRAPPER := $(ccache)
    endif
    ifndef CXX_WRAPPER
      CXX_WRAPPER := $(ccache)
    endif
    ccache =
  endif
endif

# The C/C++ compiler can be wrapped by setting the CC/CXX_WRAPPER vars.
ifdef CC_WRAPPER
  ifneq ($(CC_WRAPPER),$(firstword $($(combo_var_prefix)CC)))
    $(combo_var_prefix)CC := $(CC_WRAPPER) $($(combo_var_prefix)CC)
  endif
endif
ifdef CXX_WRAPPER
  ifneq ($(CXX_WRAPPER),$(firstword $($(combo_var_prefix)CXX)))
    $(combo_var_prefix)CXX := $(CXX_WRAPPER) $($(combo_var_prefix)CXX)
  endif
endif
