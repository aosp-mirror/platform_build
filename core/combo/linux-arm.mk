# Configuration for Linux on ARM.
# Included by combo/select.make

# You can set TARGET_ARCH_VARIANT to use an arch version other
# than ARMv5TE. Each value should correspond to a file named
# $(BUILD_COMBOS)/arch/<name>.mk which must contain
# makefile variable definitions similar to the preprocessor
# defines in system/core/include/arch/<combo>/AndroidConfig.h. Their
# purpose is to allow module Android.mk files to selectively compile
# different versions of code based upon the funtionality and
# instructions available in a given architecture version.
#
# The blocks also define specific arch_variant_cflags, which
# include defines, and compiler settings for the given architecture
# version.
#
ifeq ($(strip $(TARGET_ARCH_VARIANT)),)
TARGET_ARCH_VARIANT := armv5te
endif

# TARGET_ARCH_VARIANT used to be called TARGET_ARCH_VERSION
# to avoid any weirdness, issue an error message if the latter
# is defined.
#
ifneq ($(strip $(TARGET_ARCH_VERSION)),)
$(info Definition for TARGET_ARCH_VERSION encountered !)
$(info This variable has been renamed TARGET_ARCH_VARIANT, please update your build files !!)
$(error Aborting the build.)
endif

TARGET_ARCH_SPECIFIC_MAKEFILE := $(BUILD_COMBOS)/arch/$(TARGET_ARCH)/$(TARGET_ARCH_VARIANT).mk
ifeq ($(strip $(wildcard $(TARGET_ARCH_SPECIFIC_MAKEFILE))),)
$(error Unknown ARM architecture version: $(TARGET_ARCH_VARIANT))
endif

include $(TARGET_ARCH_SPECIFIC_MAKEFILE)

# You can set TARGET_TOOLS_PREFIX to get gcc from somewhere else
ifeq ($(strip $($(combo_target)TOOLS_PREFIX)),)
$(combo_target)TOOLS_PREFIX := \
	prebuilt/$(HOST_PREBUILT_TAG)/toolchain/arm-eabi-4.2.1/bin/arm-eabi-
endif

$(combo_target)CC := $($(combo_target)TOOLS_PREFIX)gcc$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)CXX := $($(combo_target)TOOLS_PREFIX)g++$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)AR := $($(combo_target)TOOLS_PREFIX)ar$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)OBJCOPY := $($(combo_target)TOOLS_PREFIX)objcopy$(HOST_EXECUTABLE_SUFFIX)
$(combo_target)LD := $($(combo_target)TOOLS_PREFIX)ld$(HOST_EXECUTABLE_SUFFIX)

$(combo_target)NO_UNDEFINED_LDFLAGS := -Wl,--no-undefined

TARGET_arm_CFLAGS :=    -O2 \
                        -fomit-frame-pointer \
                        -fstrict-aliasing    \
                        -funswitch-loops     \
                        -finline-limit=300

# Modules can choose to compile some source as thumb. As
# non-thumb enabled targets are supported, this is treated
# as a 'hint'. If thumb is not enabled, these files are just
# compiled as ARM.
ifeq ($(ARCH_ARM_HAVE_THUMB_SUPPORT),true)
TARGET_thumb_CFLAGS :=  -mthumb \
                        -Os \
                        -fomit-frame-pointer \
                        -fno-strict-aliasing \
                        -finline-limit=64
else
TARGET_thumb_CFLAGS := $(TARGET_arm_CFLAGS)
endif

# Set FORCE_ARM_DEBUGGING to "true" in your buildspec.mk
# or in your environment to force a full arm build, even for
# files that are normally built as thumb; this can make
# gdb debugging easier.  Don't forget to do a clean build.
#
# NOTE: if you try to build a -O0 build with thumb, several
# of the libraries (libpv, libwebcore, libkjs) need to be built
# with -mlong-calls.  When built at -O0, those libraries are
# too big for a thumb "BL <label>" to go from one end to the other.
ifeq ($(FORCE_ARM_DEBUGGING),true)
  TARGET_arm_CFLAGS += -fno-omit-frame-pointer -fno-strict-aliasing
  TARGET_thumb_CFLAGS += -marm -fno-omit-frame-pointer
endif

android_config_h := $(call select-android-config-h,linux-arm)
arch_include_dir := $(dir $(android_config_h))

$(combo_target)GLOBAL_CFLAGS += \
			-msoft-float -fpic \
			-ffunction-sections \
			-funwind-tables \
			-fstack-protector \
			-fno-short-enums \
			$(arch_variant_cflags) \
			-include $(android_config_h) \
			-I $(arch_include_dir)

# We only need thumb interworking in cases where thumb support
# is available in the architecture, and just to be sure, (and
# since sometimes thumb-interwork appears to be default), we
# specifically disable when thumb support is unavailable.
ifeq ($(ARCH_ARM_HAVE_THUMB_SUPPORT),true)
$(combo_target)GLOBAL_CFLAGS +=	-mthumb-interwork
else
$(combo_target)GLOBAL_CFLAGS +=	-mno-thumb-interwork
endif

$(combo_target)GLOBAL_CPPFLAGS += -fvisibility-inlines-hidden

$(combo_target)RELEASE_CFLAGS := \
			-DSK_RELEASE -DNDEBUG \
			-g \
			-Wstrict-aliasing=2 \
			-finline-functions \
			-fno-inline-functions-called-once \
			-fgcse-after-reload \
			-frerun-cse-after-loop \
			-frename-registers

libc_root := bionic/libc
libm_root := bionic/libm
libstdc++_root := bionic/libstdc++
libthread_db_root := bionic/libthread_db


## on some hosts, the target cross-compiler is not available so do not run this command
ifneq ($(wildcard $($(combo_target)CC)),)
# We compile with the global cflags to ensure that
# any flags which affect libgcc are correctly taken
# into account.
$(combo_target)LIBGCC := $(shell $($(combo_target)CC) $($(combo_target)GLOBAL_CFLAGS) -print-libgcc-file-name)
endif

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

$(combo_target)C_INCLUDES := \
	$(libc_root)/arch-arm/include \
	$(libc_root)/include \
	$(libstdc++_root)/include \
	$(KERNEL_HEADERS) \
	$(libm_root)/include \
	$(libm_root)/include/arch/arm \
	$(libthread_db_root)/include

TARGET_CRTBEGIN_STATIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_static.o
TARGET_CRTBEGIN_DYNAMIC_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtbegin_dynamic.o
TARGET_CRTEND_O := $(TARGET_OUT_STATIC_LIBRARIES)/crtend_android.o

TARGET_STRIP_MODULE:=true

$(combo_target)DEFAULT_SYSTEM_SHARED_LIBRARIES := libc libstdc++ libm

$(combo_target)CUSTOM_LD_COMMAND := true
define transform-o-to-shared-lib-inner
$(TARGET_CXX) \
	-nostdlib -Wl,-soname,$(notdir $@) -Wl,-T,$(BUILD_SYSTEM)/armelf.xsc \
	-Wl,--gc-sections \
	-Wl,-shared,-Bsymbolic \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDFLAGS) \
	$(TARGET_LIBGCC)
endef

define transform-o-to-executable-inner
$(TARGET_CXX) -nostdlib -Bdynamic -Wl,-T,$(BUILD_SYSTEM)/armelf.x \
	-Wl,-dynamic-linker,/system/bin/linker \
    -Wl,--gc-sections \
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
$(TARGET_CXX) -nostdlib -Bstatic -Wl,-T,$(BUILD_SYSTEM)/armelf.x \
    -Wl,--gc-sections \
	-o $@ \
	$(TARGET_GLOBAL_LD_DIRS) \
	$(TARGET_CRTBEGIN_STATIC_O) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(TARGET_LIBGCC) \
	$(TARGET_CRTEND_O)
endef
