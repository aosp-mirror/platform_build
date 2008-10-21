# Select a combo based on the compiler being used.
#
# Inputs:
#	combo_target -- prefix for final variables (HOST_ or TARGET_)
#
# Outputs:
#   $(combo_target)OS -- standard name for this host (LINUX, DARWIN, etc.)
#   $(combo_target)ARCH -- standard name for process architecture (powerpc, x86, etc.)
#   $(combo_target)GLOBAL_CFLAGS -- C compiler flags to use for everything
#   $(combo_target)DEBUG_CFLAGS -- additional C compiler flags for debug builds
#   $(combo_target)RELEASE_CFLAGS -- additional C compiler flags for release builds
#   $(combo_target)GLOBAL_ARFLAGS -- flags to use for static linking everything
#   $(combo_target)SHLIB_SUFFIX -- suffix of shared libraries

# Build a target string like "linux-arm" or "darwin-x86".
combo_os_arch := $($(combo_target)OS)-$($(combo_target)ARCH)

# Set the defaults.

HOST_CC ?= $(CC)
HOST_CXX ?= $(CXX)
HOST_AR ?= $(AR)

$(combo_target)BINDER_MINI := 0

$(combo_target)HAVE_EXCEPTIONS := 0
$(combo_target)HAVE_UNIX_FILE_PATH := 1
$(combo_target)HAVE_WINDOWS_FILE_PATH := 0
$(combo_target)HAVE_RTTI := 1
$(combo_target)HAVE_CALL_STACKS := 1
$(combo_target)HAVE_64BIT_IO := 1
$(combo_target)HAVE_CLOCK_TIMERS := 1
$(combo_target)HAVE_PTHREAD_RWLOCK := 1
$(combo_target)HAVE_STRNLEN := 1
$(combo_target)HAVE_STRERROR_R_STRRET := 1
$(combo_target)HAVE_STRLCPY := 0
$(combo_target)HAVE_STRLCAT := 0
$(combo_target)HAVE_KERNEL_MODULES := 0

# These flags might (will) be overridden by the target makefiles
$(combo_target)GLOBAL_CFLAGS := -fno-exceptions -Wno-multichar
$(combo_target)DEBUG_CFLAGS := -O0 -g
$(combo_target)RELEASE_CFLAGS := -O2 -g -fno-strict-aliasing
$(combo_target)GLOBAL_ARFLAGS := crs

$(combo_target)EXECUTABLE_SUFFIX := 
$(combo_target)SHLIB_SUFFIX := .so
$(combo_target)JNILIB_SUFFIX := $($(combo_target)SHLIB_SUFFIX)
$(combo_target)STATIC_LIB_SUFFIX := .a

$(combo_target)PRELINKER_MAP := $(BUILD_SYSTEM)/prelink-$(combo_os_arch).map

# Now include the combo for this specific target.
include $(BUILD_COMBOS)/$(combo_os_arch).mk

ifneq ($(USE_CCACHE),)
  ccache := prebuilt/$(HOST_PREBUILT_TAG)/ccache/ccache
  $(combo_target)CC := $(ccache) $($(combo_target)CC)
  $(combo_target)CXX := $(ccache) $($(combo_target)CXX)
  ccache =
endif
