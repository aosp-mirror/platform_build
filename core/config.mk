# This is included by the top-level Makefile.
# It sets up standard variables based on the
# current configuration and platform, which
# are not specific to what is being built.

# Only use ANDROID_BUILD_SHELL to wrap around bash.
# DO NOT use other shells such as zsh.
ifdef ANDROID_BUILD_SHELL
SHELL := $(ANDROID_BUILD_SHELL)
else
# Use bash, not whatever shell somebody has installed as /bin/sh
# This is repeated from main.mk, since envsetup.sh runs this file
# directly.
SHELL := /bin/bash
endif

# Utility variables.
empty :=
space := $(empty) $(empty)
comma := ,

# Tell python not to spam the source tree with .pyc files.  This
# only has an effect on python 2.6 and above.
export PYTHONDONTWRITEBYTECODE := 1

# Standard source directories.
SRC_DOCS:= $(TOPDIR)docs
# TODO: Enforce some kind of layering; only add include paths
#       when a module links against a particular library.
# TODO: See if we can remove most of these from the global list.
SRC_HEADERS := \
	$(TOPDIR)system/core/include \
	$(TOPDIR)hardware/libhardware/include \
	$(TOPDIR)hardware/libhardware_legacy/include \
	$(TOPDIR)hardware/ril/include \
	$(TOPDIR)libnativehelper/include \
	$(TOPDIR)frameworks/native/include \
	$(TOPDIR)frameworks/native/opengl/include \
	$(TOPDIR)frameworks/av/include \
	$(TOPDIR)frameworks/base/include \
	$(TOPDIR)external/skia/include
SRC_HOST_HEADERS:=$(TOPDIR)tools/include
SRC_LIBRARIES:= $(TOPDIR)libs
SRC_SERVERS:= $(TOPDIR)servers
SRC_TARGET_DIR := $(TOPDIR)build/target
SRC_API_DIR := $(TOPDIR)prebuilts/sdk/api

# Some specific paths to tools
SRC_DROIDDOC_DIR := $(TOPDIR)build/tools/droiddoc

# Various mappings to avoid hard-coding paths all over the place
include $(BUILD_SYSTEM)/pathmap.mk

# ###############################################################
# Build system internal files
# ###############################################################

BUILD_COMBOS:= $(BUILD_SYSTEM)/combo

CLEAR_VARS:= $(BUILD_SYSTEM)/clear_vars.mk
BUILD_HOST_STATIC_LIBRARY:= $(BUILD_SYSTEM)/host_static_library.mk
BUILD_HOST_SHARED_LIBRARY:= $(BUILD_SYSTEM)/host_shared_library.mk
BUILD_STATIC_LIBRARY:= $(BUILD_SYSTEM)/static_library.mk
BUILD_RAW_STATIC_LIBRARY := $(BUILD_SYSTEM)/raw_static_library.mk
BUILD_SHARED_LIBRARY:= $(BUILD_SYSTEM)/shared_library.mk
BUILD_EXECUTABLE:= $(BUILD_SYSTEM)/executable.mk
BUILD_RAW_EXECUTABLE:= $(BUILD_SYSTEM)/raw_executable.mk
BUILD_HOST_EXECUTABLE:= $(BUILD_SYSTEM)/host_executable.mk
BUILD_PACKAGE:= $(BUILD_SYSTEM)/package.mk
BUILD_PHONY_PACKAGE:= $(BUILD_SYSTEM)/phony_package.mk
BUILD_HOST_PREBUILT:= $(BUILD_SYSTEM)/host_prebuilt.mk
BUILD_PREBUILT:= $(BUILD_SYSTEM)/prebuilt.mk
BUILD_MULTI_PREBUILT:= $(BUILD_SYSTEM)/multi_prebuilt.mk
BUILD_JAVA_LIBRARY:= $(BUILD_SYSTEM)/java_library.mk
BUILD_STATIC_JAVA_LIBRARY:= $(BUILD_SYSTEM)/static_java_library.mk
BUILD_HOST_JAVA_LIBRARY:= $(BUILD_SYSTEM)/host_java_library.mk
BUILD_DROIDDOC:= $(BUILD_SYSTEM)/droiddoc.mk
BUILD_COPY_HEADERS := $(BUILD_SYSTEM)/copy_headers.mk
BUILD_NATIVE_TEST := $(BUILD_SYSTEM)/native_test.mk
BUILD_HOST_NATIVE_TEST := $(BUILD_SYSTEM)/host_native_test.mk

BUILD_SHARED_TEST_LIBRARY := $(BUILD_SYSTEM)/shared_test_lib.mk
BUILD_HOST_SHARED_TEST_LIBRARY := $(BUILD_SYSTEM)/host_shared_test_lib.mk
BUILD_STATIC_TEST_LIBRARY := $(BUILD_SYSTEM)/static_test_lib.mk
BUILD_HOST_STATIC_TEST_LIBRARY := $(BUILD_SYSTEM)/host_static_test_lib.mk

BUILD_NOTICE_FILE := $(BUILD_SYSTEM)/notice_files.mk
BUILD_HOST_DALVIK_JAVA_LIBRARY := $(BUILD_SYSTEM)/host_dalvik_java_library.mk
BUILD_HOST_DALVIK_STATIC_JAVA_LIBRARY := $(BUILD_SYSTEM)/host_dalvik_static_java_library.mk


-include cts/build/config.mk

# ###############################################################
# Parse out any modifier targets.
# ###############################################################

# The 'showcommands' goal says to show the full command
# lines being executed, instead of a short message about
# the kind of operation being done.
SHOW_COMMANDS:= $(filter showcommands,$(MAKECMDGOALS))


# ###############################################################
# Set common values
# ###############################################################

# These can be changed to modify both host and device modules.
COMMON_GLOBAL_CFLAGS:= -DANDROID -fmessage-length=0 -W -Wall -Wno-unused -Winit-self -Wpointer-arith
COMMON_RELEASE_CFLAGS:= -DNDEBUG -UDEBUG

COMMON_GLOBAL_CPPFLAGS:= $(COMMON_GLOBAL_CFLAGS) -Wsign-promo
COMMON_RELEASE_CPPFLAGS:= $(COMMON_RELEASE_CFLAGS)

# Set the extensions used for various packages
COMMON_PACKAGE_SUFFIX := .zip
COMMON_JAVA_PACKAGE_SUFFIX := .jar
COMMON_ANDROID_PACKAGE_SUFFIX := .apk

# list of flags to turn specific warnings in to errors
TARGET_ERROR_FLAGS := -Werror=return-type -Werror=non-virtual-dtor -Werror=address -Werror=sequence-point

# TODO: do symbol compression
TARGET_COMPRESS_MODULE_SYMBOLS := false

# ###############################################################
# Include sub-configuration files
# ###############################################################

# ---------------------------------------------------------------
# Try to include buildspec.mk, which will try to set stuff up.
# If this file doesn't exist, the environment variables will
# be used, and if that doesn't work, then the default is an
# arm build
ifndef ANDROID_BUILDSPEC
ANDROID_BUILDSPEC := $(TOPDIR)buildspec.mk
endif
-include $(ANDROID_BUILDSPEC)

# ---------------------------------------------------------------
# Define most of the global variables.  These are the ones that
# are specific to the user's build configuration.
include $(BUILD_SYSTEM)/envsetup.mk

# The build system exposes several variables for where to find the kernel
# headers:
#   TARGET_DEVICE_KERNEL_HEADERS is automatically created for the current
#       device being built. It is set as $(TARGET_DEVICE_DIR)/kernel-headers,
#       e.g. device/samsung/tuna/kernel-headers. This directory is not
#       explicitly set by anyone, the build system always adds this subdir.
#
#   TARGET_BOARD_KERNEL_HEADERS is specified by the BoardConfig.mk file
#       to allow other directories to be included. This is useful if there's
#       some common place where a few headers are being kept for a group
#       of devices. For example, device/<vendor>/common/kernel-headers could
#       contain some headers for several of <vendor>'s devices.
#
#   TARGET_PRODUCT_KERNEL_HEADERS is generated by the product inheritance
#       graph. This allows architecture products to provide headers for the
#       devices using that architecture. For example,
#       hardware/ti/omap4xxx/omap4.mk will specify
#       PRODUCT_VENDOR_KERNEL_HEADERS variable that specify where the omap4
#       specific headers are, e.g. hardware/ti/omap4xxx/kernel-headers.
#       The build system then combines all the values specified by all the
#       PRODUCT_VENDOR_KERNEL_HEADERS directives in the product inheritance
#       tree and then exports a TARGET_PRODUCT_KERNEL_HEADERS variable.
#
# The layout of subdirs in any of the kernel-headers dir should mirror the
# layout of the kernel include/ directory. For example,
#     device/samsung/tuna/kernel-headers/linux/,
#     hardware/ti/omap4xxx/kernel-headers/media/,
#     etc.
#
# NOTE: These directories MUST contain post-processed headers using the
# bionic/libc/kernel/clean_header.py tool. Additionally, the original kernel
# headers must also be checked in, but in a different subdirectory. By
# convention, the originals should be checked into original-kernel-headers
# directory of the same parent dir. For example,
#     device/samsung/tuna/kernel-headers            <----- post-processed
#     device/samsung/tuna/original-kernel-headers   <----- originals
#
TARGET_DEVICE_KERNEL_HEADERS := $(strip $(wildcard $(TARGET_DEVICE_DIR)/kernel-headers))

define validate-kernel-headers
$(if $(firstword $(foreach hdr_dir,$(1),\
         $(filter-out kernel-headers,$(notdir $(hdr_dir))))),\
     $(error Kernel header dirs must be end in kernel-headers: $(1)))
endef
# also allow the board config to provide additional directories since
# there could be device/oem/base_hw and device/oem/derived_hw
# that both are valid devices but derived_hw needs to use kernel headers
# from base_hw.
TARGET_BOARD_KERNEL_HEADERS := $(strip $(wildcard $(TARGET_BOARD_KERNEL_HEADERS)))
TARGET_BOARD_KERNEL_HEADERS := $(patsubst %/,%,$(TARGET_BOARD_KERNEL_HEADERS))
$(call validate-kernel-headers,$(TARGET_BOARD_KERNEL_HEADERS))

# then add product-inherited includes, to allow for
# hardware/sivendor/chip/chip.mk to include their own headers
TARGET_PRODUCT_KERNEL_HEADERS := $(strip $(wildcard $(PRODUCT_VENDOR_KERNEL_HEADERS)))
TARGET_PRODUCT_KERNEL_HEADERS := $(patsubst %/,%,$(TARGET_PRODUCT_KERNEL_HEADERS))
$(call validate-kernel-headers,$(TARGET_PRODUCT_KERNEL_HEADERS))

# Clean up/verify variables defined by the board config file.
TARGET_BOOTLOADER_BOARD_NAME := $(strip $(TARGET_BOOTLOADER_BOARD_NAME))
TARGET_CPU_ABI := $(strip $(TARGET_CPU_ABI))
ifeq ($(TARGET_CPU_ABI),)
  $(error No TARGET_CPU_ABI defined by board config: $(board_config_mk))
endif
TARGET_CPU_ABI2 := $(strip $(TARGET_CPU_ABI2))

# $(1): os/arch
define select-android-config-h
build/core/combo/include/arch/$(1)/AndroidConfig.h
endef

combo_target := HOST_
combo_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/combo/select.mk

# Load the 2nd host arch if it's needed.
ifdef HOST_2ND_ARCH
combo_target := HOST_
combo_2nd_arch_prefix := $(HOST_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/combo/select.mk
endif

# on windows, the tools have .exe at the end, and we depend on the
# host config stuff being done first

combo_target := TARGET_
combo_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/combo/select.mk

# Load the 2nd target arch if it's needed.
ifdef TARGET_2ND_ARCH
combo_target := TARGET_
combo_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/combo/select.mk
endif

ifdef TARGET_PREFER_32_BIT
TARGET_PREFER_32_BIT_APPS := true
TARGET_PREFER_32_BIT_EXECUTABLES := true
endif

ifeq (,$(TARGET_SUPPORTS_32_BIT_APPS)$(TARGET_SUPPORTS_64_BIT_APPS))
  TARGET_SUPPORTS_32_BIT_APPS := true
endif

# "ro.product.cpu.abilist32" and "ro.product.cpu.abilist64" are
# comma separated lists of the 32 and 64 bit ABIs (in order of
# preference) that the target supports. If TARGET_CPU_ABI_LIST_{32,64}_BIT
# are defined by the board config, we use them. Else, we construct
# these lists based on whether TARGET_IS_64_BIT is set.
#
# Note that this assumes that the 2ND_CPU_ABI for a 64 bit target
# is always 32 bits. If this isn't the case, these variables should
# be overriden in the boarc configuration.
ifeq (,$(TARGET_CPU_ABI_LIST_64_BIT))
  ifeq (true|true,$(TARGET_IS_64_BIT)|$(TARGET_SUPPORTS_64_BIT_APPS))
    TARGET_CPU_ABI_LIST_64_BIT := $(TARGET_CPU_ABI) $(TARGET_CPU_ABI2)
  endif
endif

ifeq (,$(TARGET_CPU_ABI_LIST_32_BIT))
  ifneq (true,$(TARGET_IS_64_BIT))
    TARGET_CPU_ABI_LIST_32_BIT := $(TARGET_CPU_ABI) $(TARGET_CPU_ABI2)
  else
    ifeq (true,$(TARGET_SUPPORTS_32_BIT_APPS))
      # For a 64 bit target, assume that the 2ND_CPU_ABI
      # is a 32 bit ABI.
      TARGET_CPU_ABI_LIST_32_BIT := $(TARGET_2ND_CPU_ABI) $(TARGET_2ND_CPU_ABI2)
    endif
  endif
endif

# "ro.product.cpu.abilist" is a comma separated list of ABIs (in order
# of preference) that the target supports. If a TARGET_CPU_ABI_LIST
# is specified by the board configuration, we use that. If not, we
# build a list out of the TARGET_CPU_ABIs specified by the config.
ifeq (,$(TARGET_CPU_ABI_LIST))
  ifeq ($(TARGET_IS_64_BIT)|$(TARGET_PREFER_32_BIT_APPS),true|true)
    TARGET_CPU_ABI_LIST := $(TARGET_CPU_ABI_LIST_32_BIT) $(TARGET_CPU_ABI_LIST_64_BIT)
  else
    TARGET_CPU_ABI_LIST := $(TARGET_CPU_ABI_LIST_64_BIT) $(TARGET_CPU_ABI_LIST_32_BIT)
  endif
endif

# Strip whitespace from the ABI list string.
TARGET_CPU_ABI_LIST := $(subst $(space),$(comma),$(strip $(TARGET_CPU_ABI_LIST)))
TARGET_CPU_ABI_LIST_32_BIT := $(subst $(space),$(comma),$(strip $(TARGET_CPU_ABI_LIST_32_BIT)))
TARGET_CPU_ABI_LIST_64_BIT := $(subst $(space),$(comma),$(strip $(TARGET_CPU_ABI_LIST_64_BIT)))

# Compute TARGET_TOOLCHAIN_ROOT from TARGET_TOOLS_PREFIX
# if only TARGET_TOOLS_PREFIX is passed to the make command.
ifndef TARGET_TOOLCHAIN_ROOT
TARGET_TOOLCHAIN_ROOT := $(patsubst %/, %, $(dir $(TARGET_TOOLS_PREFIX)))
TARGET_TOOLCHAIN_ROOT := $(patsubst %/, %, $(dir $(TARGET_TOOLCHAIN_ROOT)))
TARGET_TOOLCHAIN_ROOT := $(wildcard $(TARGET_TOOLCHAIN_ROOT))
endif

# Normalize WITH_STATIC_ANALYZER and WITH_SYNTAX_CHECK
ifeq ($(strip $(WITH_STATIC_ANALYZER)),0)
  WITH_STATIC_ANALYZER :=
endif
ifeq ($(strip $(WITH_SYNTAX_CHECK)),0)
  WITH_SYNTAX_CHECK :=
endif

# Disable WITH_STATIC_ANALYZER and WITH_SYNTAX_CHECK if tool can't be found
SYNTAX_TOOLS_PREFIX := prebuilts/misc/$(HOST_PREBUILT_TAG)/analyzer/bin
ifneq ($(strip $(WITH_STATIC_ANALYZER)),)
  ifeq ($(wildcard $(SYNTAX_TOOLS_PREFIX)/ccc-analyzer),)
    $(warning *** Disable WITH_STATIC_ANALYZER because $(SYNTAX_TOOLS_PREFIX)/ccc-analyzer does not exist)
    WITH_STATIC_ANALYZER :=
  endif
endif
ifneq ($(strip $(WITH_SYNTAX_CHECK)),)
  ifeq ($(wildcard $(SYNTAX_TOOLS_PREFIX)/ccc-syntax),)
    $(warning *** Disable WITH_SYNTAX_CHECK because $(SYNTAX_TOOLS_PREFIX)/ccc-syntax does not exist)
    WITH_SYNTAX_CHECK :=
  endif
endif

# WITH_STATIC_ANALYZER trumps WITH_SYNTAX_CHECK
ifneq ($(strip $(WITH_STATIC_ANALYZER)),)
  ifneq ($(strip $(WITH_SYNTAX_CHECK)),)
    $(warning *** Disable WITH_SYNTAX_CHECK in the presence of static analyzer WITH_STATIC_ANALYZER)
    WITH_SYNTAX_CHECK :=
  endif
endif

# Pick a Java compiler.
include $(BUILD_SYSTEM)/combo/javac.mk

# ---------------------------------------------------------------
# Check that the configuration is current.  We check that
# BUILD_ENV_SEQUENCE_NUMBER is current against this value.
# Don't fail if we're called from envsetup, so they have a
# chance to update their environment.

ifeq (,$(strip $(CALLED_FROM_SETUP)))
ifneq (,$(strip $(BUILD_ENV_SEQUENCE_NUMBER)))
ifneq ($(BUILD_ENV_SEQUENCE_NUMBER),$(CORRECT_BUILD_ENV_SEQUENCE_NUMBER))
$(warning BUILD_ENV_SEQUENCE_NUMBER is set incorrectly.)
$(info *** If you use envsetup/lunch/choosecombo:)
$(info ***   - Re-execute envsetup (". envsetup.sh"))
$(info ***   - Re-run lunch or choosecombo)
$(info *** If you use buildspec.mk:)
$(info ***   - Look at buildspec.mk.default to see what has changed)
$(info ***   - Update BUILD_ENV_SEQUENCE_NUMBER to "$(CORRECT_BUILD_ENV_SEQUENCE_NUMBER)")
$(error bailing..)
endif
endif
endif


# ---------------------------------------------------------------
# Generic tools.

LEX := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/flex/flex-2.5.39
# The default PKGDATADIR built in the prebuilt bison is a relative path
# external/bison/data.
# To run bison from elsewhere you need to set up enviromental variable
# BISON_PKGDATADIR.
BISON_PKGDATADIR := $(PWD)/external/bison/data
BISON := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/bison/bison
YACC := $(BISON) -d

DOXYGEN:= doxygen
AAPT := $(HOST_OUT_EXECUTABLES)/aapt$(HOST_EXECUTABLE_SUFFIX)
AIDL := $(HOST_OUT_EXECUTABLES)/aidl$(HOST_EXECUTABLE_SUFFIX)
PROTOC := $(HOST_OUT_EXECUTABLES)/aprotoc$(HOST_EXECUTABLE_SUFFIX)
SIGNAPK_JAR := $(HOST_OUT_JAVA_LIBRARIES)/signapk$(COMMON_JAVA_PACKAGE_SUFFIX)
MKBOOTFS := $(HOST_OUT_EXECUTABLES)/mkbootfs$(HOST_EXECUTABLE_SUFFIX)
MINIGZIP := $(HOST_OUT_EXECUTABLES)/minigzip$(HOST_EXECUTABLE_SUFFIX)
ifeq (,$(strip $(BOARD_CUSTOM_MKBOOTIMG)))
MKBOOTIMG := $(HOST_OUT_EXECUTABLES)/mkbootimg$(HOST_EXECUTABLE_SUFFIX)
else
MKBOOTIMG := $(BOARD_CUSTOM_MKBOOTIMG)
endif
MKYAFFS2 := $(HOST_OUT_EXECUTABLES)/mkyaffs2image$(HOST_EXECUTABLE_SUFFIX)
APICHECK := $(HOST_OUT_EXECUTABLES)/apicheck$(HOST_EXECUTABLE_SUFFIX)
FS_GET_STATS := $(HOST_OUT_EXECUTABLES)/fs_get_stats$(HOST_EXECUTABLE_SUFFIX)
MKEXT2IMG := $(HOST_OUT_EXECUTABLES)/genext2fs$(HOST_EXECUTABLE_SUFFIX)
MAKE_EXT4FS := $(HOST_OUT_EXECUTABLES)/make_ext4fs$(HOST_EXECUTABLE_SUFFIX)
MKEXTUSERIMG := $(HOST_OUT_EXECUTABLES)/mkuserimg.sh
MKEXT2BOOTIMG := external/genext2fs/mkbootimg_ext2.sh
SIMG2IMG := $(HOST_OUT_EXECUTABLES)/simg2img$(HOST_EXECUTABLE_SUFFIX)
E2FSCK := $(HOST_OUT_EXECUTABLES)/e2fsck$(HOST_EXECUTABLE_SUFFIX)
MKTARBALL := build/tools/mktarball.sh
TUNE2FS := $(HOST_OUT_EXECUTABLES)/tune2fs$(HOST_EXECUTABLE_SUFFIX)
E2FSCK := $(HOST_OUT_EXECUTABLES)/e2fsck$(HOST_EXECUTABLE_SUFFIX)
JARJAR := $(HOST_OUT_JAVA_LIBRARIES)/jarjar.jar
PROGUARD := external/proguard/bin/proguard.sh
JAVATAGS := build/tools/java-event-log-tags.py
LLVM_RS_CC := $(HOST_OUT_EXECUTABLES)/llvm-rs-cc$(HOST_EXECUTABLE_SUFFIX)
BCC_COMPAT := $(HOST_OUT_EXECUTABLES)/bcc_compat$(HOST_EXECUTABLE_SUFFIX)
LINT := prebuilts/sdk/tools/lint

# ACP is always for the build OS, not for the host OS
ACP := $(BUILD_OUT_EXECUTABLES)/acp$(BUILD_EXECUTABLE_SUFFIX)

# dx is java behind a shell script; no .exe necessary.
DX := $(HOST_OUT_EXECUTABLES)/dx
ZIPALIGN := $(HOST_OUT_EXECUTABLES)/zipalign$(HOST_EXECUTABLE_SUFFIX)
FINDBUGS := prebuilt/common/findbugs/bin/findbugs
EMMA_JAR := external/emma/lib/emma$(COMMON_JAVA_PACKAGE_SUFFIX)

YACC_HEADER_SUFFIX:= .hpp

# Don't use column under Windows, cygwin or not
ifeq ($(HOST_OS),windows)
COLUMN:= cat
else
COLUMN:= column
endif

ifeq ($(HOST_OS),darwin)
ifeq ($(LEGACY_USE_JAVA6),)
HOST_JDK_TOOLS_JAR:= $(shell $(BUILD_SYSTEM)/find-jdk-tools-jar.sh)
else
# Deliberately set to blank for Java 6 installations on MacOS. These
# versions allegedly use a non-standard directory structure.
HOST_JDK_TOOLS_JAR :=
endif
else
HOST_JDK_TOOLS_JAR:= $(shell $(BUILD_SYSTEM)/find-jdk-tools-jar.sh)
endif

ifneq ($(HOST_JDK_TOOLS_JAR),)
ifeq ($(wildcard $(HOST_JDK_TOOLS_JAR)),)
$(error Error: could not find jdk tools.jar, please check if your JDK was installed correctly)
endif
endif

# Is the host JDK 64-bit version?
HOST_JDK_IS_64BIT_VERSION :=
ifneq ($(filter 64-Bit, $(shell java -version 2>&1)),)
HOST_JDK_IS_64BIT_VERSION := true
endif

# It's called md5 on Mac OS and md5sum on Linux
ifeq ($(HOST_OS),darwin)
MD5SUM:=md5 -q
else
MD5SUM:=md5sum
endif

APICHECK_CLASSPATH := $(HOST_JDK_TOOLS_JAR)
APICHECK_CLASSPATH := $(APICHECK_CLASSPATH):$(HOST_OUT_JAVA_LIBRARIES)/doclava$(COMMON_JAVA_PACKAGE_SUFFIX)
APICHECK_CLASSPATH := $(APICHECK_CLASSPATH):$(HOST_OUT_JAVA_LIBRARIES)/jsilver$(COMMON_JAVA_PACKAGE_SUFFIX)
APICHECK_COMMAND := $(APICHECK) -JXmx1024m -J"classpath $(APICHECK_CLASSPATH)"

# The default key if not set as LOCAL_CERTIFICATE
ifdef PRODUCT_DEFAULT_DEV_CERTIFICATE
  DEFAULT_SYSTEM_DEV_CERTIFICATE := $(PRODUCT_DEFAULT_DEV_CERTIFICATE)
else
  DEFAULT_SYSTEM_DEV_CERTIFICATE := build/target/product/security/testkey
endif

# ###############################################################
# Set up final options.
# ###############################################################

HOST_GLOBAL_CFLAGS += $(COMMON_GLOBAL_CFLAGS)
HOST_RELEASE_CFLAGS += $(COMMON_RELEASE_CFLAGS)

HOST_GLOBAL_CPPFLAGS += $(COMMON_GLOBAL_CPPFLAGS)
HOST_RELEASE_CPPFLAGS += $(COMMON_RELEASE_CPPFLAGS)

TARGET_GLOBAL_CFLAGS += $(COMMON_GLOBAL_CFLAGS)
TARGET_RELEASE_CFLAGS += $(COMMON_RELEASE_CFLAGS)

TARGET_GLOBAL_CPPFLAGS += $(COMMON_GLOBAL_CPPFLAGS)
TARGET_RELEASE_CPPFLAGS += $(COMMON_RELEASE_CPPFLAGS)

HOST_GLOBAL_LD_DIRS += -L$(HOST_OUT_INTERMEDIATE_LIBRARIES)
TARGET_GLOBAL_LD_DIRS += -L$(TARGET_OUT_INTERMEDIATE_LIBRARIES)

HOST_PROJECT_INCLUDES:= $(SRC_HEADERS) $(SRC_HOST_HEADERS) $(HOST_OUT_HEADERS)
TARGET_PROJECT_INCLUDES:= $(SRC_HEADERS) $(TARGET_OUT_HEADERS) \
		$(TARGET_DEVICE_KERNEL_HEADERS) $(TARGET_BOARD_KERNEL_HEADERS) \
		$(TARGET_PRODUCT_KERNEL_HEADERS)

# Many host compilers don't support these flags, so we have to make
# sure to only specify them for the target compilers checked in to
# the source tree.
TARGET_GLOBAL_CFLAGS += $(TARGET_ERROR_FLAGS)
TARGET_GLOBAL_CPPFLAGS += $(TARGET_ERROR_FLAGS)

HOST_GLOBAL_CFLAGS += $(HOST_RELEASE_CFLAGS)
HOST_GLOBAL_CPPFLAGS += $(HOST_RELEASE_CPPFLAGS)

TARGET_GLOBAL_CFLAGS += $(TARGET_RELEASE_CFLAGS)
TARGET_GLOBAL_CPPFLAGS += $(TARGET_RELEASE_CPPFLAGS)

ifdef TARGET_2ND_ARCH
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CFLAGS += $(COMMON_GLOBAL_CFLAGS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_RELEASE_CFLAGS += $(COMMON_RELEASE_CFLAGS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CPPFLAGS += $(COMMON_GLOBAL_CPPFLAGS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_RELEASE_CPPFLAGS += $(COMMON_RELEASE_CPPFLAGS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_LD_DIRS += -L$($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_PROJECT_INCLUDES := $(TARGET_PROJECT_INCLUDES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CFLAGS += $(TARGET_ERROR_FLAGS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CPPFLAGS += $(TARGET_ERROR_FLAGS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CFLAGS += $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_RELEASE_CFLAGS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_CPPFLAGS += $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_RELEASE_CPPFLAGS)
endif

ifdef HOST_2ND_ARCH
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_GLOBAL_CFLAGS += $(COMMON_GLOBAL_CFLAGS)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_RELEASE_CFLAGS += $(COMMON_RELEASE_CFLAGS)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_GLOBAL_CPPFLAGS += $(COMMON_GLOBAL_CPPFLAGS)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_RELEASE_CPPFLAGS += $(COMMON_RELEASE_CPPFLAGS)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_GLOBAL_LD_DIRS += -L$($(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_INTERMEDIATE_LIBRARIES)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_PROJECT_INCLUDES := $(HOST_PROJECT_INCLUDES)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_GLOBAL_CFLAGS += $($(HOST_2ND_ARCH_VAR_PREFIX)HOST_RELEASE_CFLAGS)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_GLOBAL_CPPFLAGS += $($(HOST_2ND_ARCH_VAR_PREFIX)HOST_RELEASE_CPPFLAGS)
endif

# allow overriding default Java libraries on a per-target basis
ifeq ($(TARGET_DEFAULT_JAVA_LIBRARIES),)
  TARGET_DEFAULT_JAVA_LIBRARIES := core core-junit ext framework framework2
endif

TARGET_CPU_SMP ?= true

# Flags for DEX2OAT
DEX2OAT_TARGET_ARCH := $(TARGET_ARCH)
DEX2OAT_TARGET_CPU_VARIANT := $(TARGET_CPU_VARIANT)
DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := default

# If for a 64bit build we have a 2nd architecture but the zygote isn't 64bit,
# assume DEX2OAT should DEXPREOPT for the 2nd architecture.
ifdef TARGET_2ND_ARCH
  ifeq (true,$(TARGET_IS_64_BIT))
    ifeq ($(filter ro.zygote=zygote64,$(PRODUCT_DEFAULT_PROPERTY_OVERRIDES)),)
      DEX2OAT_TARGET_ARCH := $(TARGET_2ND_ARCH)
      DEX2OAT_TARGET_CPU_VARIANT := $(TARGET_2ND_CPU_VARIANT)
    endif
  endif
endif

ifneq (,$(filter $(DEX2OAT_TARGET_CPU_VARIANT),cortex-a7 cortex-a15 krait denver))
  DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := div
endif

# define clang/llvm tools and global flags
include $(BUILD_SYSTEM)/clang/config.mk

# ###############################################################
# Collect a list of the SDK versions that we could compile against
# For use with the LOCAL_SDK_VERSION variable for include $(BUILD_PACKAGE)
# ###############################################################

HISTORICAL_SDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/sdk
HISTORICAL_NDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/ndk

# Historical SDK version N is stored in $(HISTORICAL_SDK_VERSIONS_ROOT)/N.
# The 'current' version is whatever this source tree is.
#
# sgrax     is the opposite of xargs.  It takes the list of args and puts them
#           on each line for sort to process.
# sort -g   is a numeric sort, so 1 2 3 10 instead of 1 10 2 3.

# Numerically sort a list of numbers
# $(1): the list of numbers to be sorted
define numerically_sort
$(shell function sgrax() { \
    while [ -n "$$1" ] ; do echo $$1 ; shift ; done \
    } ; \
    ( sgrax $(1) | sort -g ) )
endef

TARGET_AVAILABLE_SDK_VERSIONS := $(call numerically_sort,\
    $(patsubst $(HISTORICAL_SDK_VERSIONS_ROOT)/%/android.jar,%, \
    $(wildcard $(HISTORICAL_SDK_VERSIONS_ROOT)/*/android.jar)))

INTERNAL_PLATFORM_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/public_api.txt

# This is the standard way to name a directory containing prebuilt target
# objects. E.g., prebuilt/$(TARGET_PREBUILT_TAG)/libc.so
TARGET_PREBUILT_TAG := android-$(TARGET_ARCH)

# Set up RS prebuilt variables for compatibility library

RS_PREBUILT_CLCORE := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/libclcore.bc
RS_PREBUILT_LIBPATH := -L prebuilts/ndk/8/platforms/android-9/arch-$(TARGET_ARCH)/usr/lib
RS_PREBUILT_COMPILER_RT := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/libcompiler_rt.a

include $(BUILD_SYSTEM)/dumpvar.mk
