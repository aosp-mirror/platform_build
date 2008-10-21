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
$(combo_target)GLOBAL_CFLAGS += -DUSE_MINGW
$(combo_target)C_INCLUDES += /usr/lib/gcc/i586-mingw32msvc/3.4.4/include
$(combo_target)GLOBAL_LD_DIRS += -L/usr/i586-mingw32msvc/lib
endif
endif

$(combo_target)CC := $(TOOLS_PREFIX)gcc$(TOOLS_EXE_SUFFIX)
$(combo_target)CXX := $(TOOLS_PREFIX)g++$(TOOLS_EXE_SUFFIX)
$(combo_target)AR := $(TOOLS_PREFIX)ar$(TOOLS_EXE_SUFFIX)

$(combo_target)GLOBAL_CFLAGS += -include $(call select-android-config-h,windows)
$(combo_target)GLOBAL_LDFLAGS += --enable-stdcall-fixup

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
$(combo_target)GLOBAL_CFLAGS += -mno-cygwin
$(combo_target)GLOBAL_LDFLAGS += -mno-cygwin -mconsole
endif
endif

$(combo_target)SHLIB_SUFFIX := .dll
$(combo_target)EXECUTABLE_SUFFIX := .exe

ifeq ($(combo_target),HOST_)
# $(1): The file to check
# TODO: find out what format cygwin's stat(1) uses
define get-file-size
999999999
endef
endif
