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
# Note that make will eat the newline just before endef.
define newline


endef
# The pound character "#"
define pound
#
endef
# Unfortunately you can't simply define backslash as \ or \\.
backslash := \a
backslash := $(patsubst %a,%,$(backslash))

# this turns off the suffix rules built into make
.SUFFIXES:

# this turns off the RCS / SCCS implicit rules of GNU Make
% : RCS/%,v
% : RCS/%
% : %,v
% : s.%
% : SCCS/s.%

# If a rule fails, delete $@.
.DELETE_ON_ERROR:

# Check for broken versions of make.
ifndef KATI
ifneq (1,$(strip $(shell expr $(MAKE_VERSION) \>= 3.81)))
$(warning ********************************************************************************)
$(warning *  You are using version $(MAKE_VERSION) of make.)
$(warning *  Android can only be built by versions 3.81 and higher.)
$(warning *  see https://source.android.com/source/download.html)
$(warning ********************************************************************************)
$(error stopping)
endif
endif

# Used to force goals to build.  Only use for conditionally defined goals.
.PHONY: FORCE
FORCE:

ORIGINAL_MAKECMDGOALS := $(MAKECMDGOALS)

# Tell python not to spam the source tree with .pyc files.  This
# only has an effect on python 2.6 and above.
export PYTHONDONTWRITEBYTECODE := 1

ifneq ($(filter --color=always, $(GREP_OPTIONS)),)
$(warning The build system needs unmodified output of grep.)
$(error Please remove --color=always from your  $$GREP_OPTIONS)
endif

SRC_TARGET_DIR := $(TOPDIR)build/target
SRC_API_DIR := $(TOPDIR)prebuilts/sdk/api
SRC_SYSTEM_API_DIR := $(TOPDIR)prebuilts/sdk/system-api
SRC_TEST_API_DIR := $(TOPDIR)prebuilts/sdk/test-api

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
BUILD_HEADER_LIBRARY:= $(BUILD_SYSTEM)/header_library.mk
BUILD_AUX_STATIC_LIBRARY:= $(BUILD_SYSTEM)/aux_static_library.mk
BUILD_AUX_EXECUTABLE:= $(BUILD_SYSTEM)/aux_executable.mk
BUILD_SHARED_LIBRARY:= $(BUILD_SYSTEM)/shared_library.mk
BUILD_EXECUTABLE:= $(BUILD_SYSTEM)/executable.mk
BUILD_HOST_EXECUTABLE:= $(BUILD_SYSTEM)/host_executable.mk
BUILD_PACKAGE:= $(BUILD_SYSTEM)/package.mk
BUILD_PHONY_PACKAGE:= $(BUILD_SYSTEM)/phony_package.mk
BUILD_RRO_PACKAGE:= $(BUILD_SYSTEM)/build_rro_package.mk
BUILD_HOST_PREBUILT:= $(BUILD_SYSTEM)/host_prebuilt.mk
BUILD_PREBUILT:= $(BUILD_SYSTEM)/prebuilt.mk
BUILD_MULTI_PREBUILT:= $(BUILD_SYSTEM)/multi_prebuilt.mk
BUILD_JAVA_LIBRARY:= $(BUILD_SYSTEM)/java_library.mk
BUILD_STATIC_JAVA_LIBRARY:= $(BUILD_SYSTEM)/static_java_library.mk
BUILD_HOST_JAVA_LIBRARY:= $(BUILD_SYSTEM)/host_java_library.mk
BUILD_DROIDDOC:= $(BUILD_SYSTEM)/droiddoc.mk
BUILD_COPY_HEADERS := $(BUILD_SYSTEM)/copy_headers.mk
BUILD_NATIVE_TEST := $(BUILD_SYSTEM)/native_test.mk
BUILD_NATIVE_BENCHMARK := $(BUILD_SYSTEM)/native_benchmark.mk
BUILD_HOST_NATIVE_TEST := $(BUILD_SYSTEM)/host_native_test.mk
BUILD_FUZZ_TEST := $(BUILD_SYSTEM)/fuzz_test.mk
BUILD_HOST_FUZZ_TEST := $(BUILD_SYSTEM)/host_fuzz_test.mk

BUILD_SHARED_TEST_LIBRARY := $(BUILD_SYSTEM)/shared_test_lib.mk
BUILD_HOST_SHARED_TEST_LIBRARY := $(BUILD_SYSTEM)/host_shared_test_lib.mk
BUILD_STATIC_TEST_LIBRARY := $(BUILD_SYSTEM)/static_test_lib.mk
BUILD_HOST_STATIC_TEST_LIBRARY := $(BUILD_SYSTEM)/host_static_test_lib.mk

BUILD_NOTICE_FILE := $(BUILD_SYSTEM)/notice_files.mk
BUILD_HOST_DALVIK_JAVA_LIBRARY := $(BUILD_SYSTEM)/host_dalvik_java_library.mk
BUILD_HOST_DALVIK_STATIC_JAVA_LIBRARY := $(BUILD_SYSTEM)/host_dalvik_static_java_library.mk


# ###############################################################
# Parse out any modifier targets.
# ###############################################################

# The 'showcommands' goal says to show the full command
# lines being executed, instead of a short message about
# the kind of operation being done.
SHOW_COMMANDS:= $(filter showcommands,$(MAKECMDGOALS))
hide := $(if $(SHOW_COMMANDS),,@)

################################################################
# Tools needed in product configuration makefiles.
################################################################
NORMALIZE_PATH := build/tools/normalize_path.py

# $(1): the paths to be normalized
define normalize-paths
$(if $(1),$(shell $(NORMALIZE_PATH) $(1)))
endef

# ###############################################################
# Set common values
# ###############################################################

# Set the extensions used for various packages
COMMON_PACKAGE_SUFFIX := .zip
COMMON_JAVA_PACKAGE_SUFFIX := .jar
COMMON_ANDROID_PACKAGE_SUFFIX := .apk

ifdef TMPDIR
JAVA_TMPDIR_ARG := -Djava.io.tmpdir=$(TMPDIR)
else
JAVA_TMPDIR_ARG :=
endif

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

# Pruned directory options used when using findleaves.py
# See envsetup.mk for a description of SCAN_EXCLUDE_DIRS
FIND_LEAVES_EXCLUDES := $(addprefix --prune=, $(SCAN_EXCLUDE_DIRS) .repo .git)

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
# bionic/libc/kernel/tools/clean_header.py tool. Additionally, the original
# kernel headers must also be checked in, but in a different subdirectory. By
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

BOARD_KERNEL_BASE := $(strip $(BOARD_KERNEL_BASE))
BOARD_KERNEL_PAGESIZE := $(strip $(BOARD_KERNEL_PAGESIZE))

# Commands to generate .toc file common to ELF .so files.
define _gen_toc_command_for_elf
$(hide) ($($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)READELF) -d $(1) | grep SONAME || echo "No SONAME for $1") > $(2)
$(hide) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)READELF) --dyn-syms $(1) | awk '{$$2=""; $$3=""; print}' >> $(2)
endef

# Commands to generate .toc file from Darwin dynamic library.
define _gen_toc_command_for_macho
$(hide) otool -l $(1) | grep LC_ID_DYLIB -A 5 > $(2)
$(hide) nm -gP $(1) | cut -f1-2 -d" " | (grep -v U$$ >> $(2) || true)
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

# Load the windows cross compiler under Linux
ifdef HOST_CROSS_OS
combo_target := HOST_CROSS_
combo_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/combo/select.mk

ifdef HOST_CROSS_2ND_ARCH
combo_target := HOST_CROSS_
combo_2nd_arch_prefix := $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/combo/select.mk
endif
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

ifndef KATI
include $(BUILD_SYSTEM)/ccache.mk
include $(BUILD_SYSTEM)/goma.mk

export CC_WRAPPER
export CXX_WRAPPER
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
# be overriden in the board configuration.
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

# GCC version selection
TARGET_GCC_VERSION := 4.9
ifdef TARGET_2ND_ARCH
2ND_TARGET_GCC_VERSION := 4.9
endif

# Normalize WITH_STATIC_ANALYZER
ifeq ($(strip $(WITH_STATIC_ANALYZER)),0)
  WITH_STATIC_ANALYZER :=
endif

# define clang/llvm versions and base directory.
include $(BUILD_SYSTEM)/clang/versions.mk

# Unset WITH_TIDY_ONLY if global WITH_TIDY_ONLY is not true nor 1.
ifeq (,$(filter 1 true,$(WITH_TIDY_ONLY)))
  WITH_TIDY_ONLY :=
endif

PATH_TO_CLANG_TIDY := \
    $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/bin/clang-tidy
ifeq ($(wildcard $(PATH_TO_CLANG_TIDY)),)
  ifneq (,$(filter 1 true,$(WITH_TIDY)))
    $(warning *** Disable WITH_TIDY because $(PATH_TO_CLANG_TIDY) does not exist)
  endif
  PATH_TO_CLANG_TIDY :=
endif

# Disable WITH_STATIC_ANALYZER if tool can't be found
SYNTAX_TOOLS_PREFIX := \
    $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/tools/scan-build/libexec
ifneq ($(strip $(WITH_STATIC_ANALYZER)),)
  ifeq ($(wildcard $(SYNTAX_TOOLS_PREFIX)/ccc-analyzer),)
    $(warning *** Disable WITH_STATIC_ANALYZER because $(SYNTAX_TOOLS_PREFIX)/ccc-analyzer does not exist)
    WITH_STATIC_ANALYZER :=
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

# Set up PDK so we can use TARGET_BUILD_PDK to select prebuilt tools below
.PHONY: pdk fusion
pdk fusion: $(DEFAULT_GOAL)

# What to build:
# pdk fusion if:
# 1) PDK_FUSION_PLATFORM_ZIP is passed in from the environment
# or
# 2) the platform.zip exists in the default location
# or
# 3) fusion is a command line build goal,
#    PDK_FUSION_PLATFORM_ZIP is needed anyway, then do we need the 'fusion' goal?
# otherwise pdk only if:
# 1) pdk is a command line build goal
# or
# 2) TARGET_BUILD_PDK is passed in from the environment

# if PDK_FUSION_PLATFORM_ZIP is specified, do not override.
ifndef PDK_FUSION_PLATFORM_ZIP
# Most PDK project paths should be using vendor/pdk/TARGET_DEVICE
# but some legacy ones (e.g. mini_armv7a_neon generic PDK) were setup
# with vendor/pdk/TARGET_PRODUCT.
_pdk_fusion_default_platform_zip = $(strip \
  $(wildcard vendor/pdk/$(TARGET_DEVICE)/$(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)/platform/platform.zip) \
  $(wildcard vendor/pdk/$(TARGET_DEVICE)/$(patsubst aosp_%,full_%,$(TARGET_PRODUCT))-$(TARGET_BUILD_VARIANT)/platform/platform.zip) \
  $(wildcard vendor/pdk/$(TARGET_PRODUCT)/$(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT)/platform/platform.zip) \
  $(wildcard vendor/pdk/$(TARGET_PRODUCT)/$(patsubst aosp_%,full_%,$(TARGET_PRODUCT))-$(TARGET_BUILD_VARIANT)/platform/platform.zip))
ifneq (,$(_pdk_fusion_default_platform_zip))
PDK_FUSION_PLATFORM_ZIP := $(word 1, $(_pdk_fusion_default_platform_zip))
TARGET_BUILD_PDK := true
endif # _pdk_fusion_default_platform_zip
endif # !PDK_FUSION_PLATFORM_ZIP

ifneq (,$(filter pdk fusion, $(MAKECMDGOALS)))
TARGET_BUILD_PDK := true
ifneq (,$(filter fusion, $(MAKECMDGOALS)))
ifndef PDK_FUSION_PLATFORM_ZIP
  $(error Specify PDK_FUSION_PLATFORM_ZIP to do a PDK fusion.)
endif
endif  # fusion
endif  # pdk or fusion

ifdef PDK_FUSION_PLATFORM_ZIP
TARGET_BUILD_PDK := true
ifeq (,$(wildcard $(PDK_FUSION_PLATFORM_ZIP)))
  $(error Cannot find file $(PDK_FUSION_PLATFORM_ZIP).)
endif
endif

BUILD_PLATFORM_ZIP := $(filter platform platform-java,$(MAKECMDGOALS))

#
# Tools that are prebuilts for TARGET_BUILD_APPS
#
prebuilt_sdk_tools := prebuilts/sdk/tools
prebuilt_sdk_tools_bin := $(prebuilt_sdk_tools)/$(HOST_OS)/bin

AIDL := $(HOST_OUT_EXECUTABLES)/aidl
AAPT := $(HOST_OUT_EXECUTABLES)/aapt
AAPT2 := $(HOST_OUT_EXECUTABLES)/aapt2
ZIPALIGN := $(HOST_OUT_EXECUTABLES)/zipalign
SIGNAPK_JAR := $(HOST_OUT_JAVA_LIBRARIES)/signapk$(COMMON_JAVA_PACKAGE_SUFFIX)
SIGNAPK_JNI_LIBRARY_PATH := $(HOST_OUT_SHARED_LIBRARIES)
LLVM_RS_CC := $(HOST_OUT_EXECUTABLES)/llvm-rs-cc
BCC_COMPAT := $(HOST_OUT_EXECUTABLES)/bcc_compat
DEPMOD := $(HOST_OUT_EXECUTABLES)/depmod

DX := $(HOST_OUT_EXECUTABLES)/dx
MAINDEXCLASSES := $(HOST_OUT_EXECUTABLES)/mainDexClasses

SOONG_ZIP := $(SOONG_HOST_OUT_EXECUTABLES)/soong_zip
ZIP2ZIP := $(SOONG_HOST_OUT_EXECUTABLES)/zip2zip
FILESLIST := $(SOONG_HOST_OUT_EXECUTABLES)/fileslist

SOONG_JAVAC_WRAPPER := $(SOONG_HOST_OUT_EXECUTABLES)/soong_javac_wrapper

# Always use prebuilts for ckati and makeparallel
prebuilt_build_tools := prebuilts/build-tools
ifeq ($(filter address,$(SANITIZE_HOST)),)
prebuilt_build_tools_bin := $(prebuilt_build_tools)/$(HOST_PREBUILT_TAG)/bin
else
prebuilt_build_tools_bin := $(prebuilt_build_tools)/$(HOST_PREBUILT_TAG)/asan/bin
endif
ACP := $(prebuilt_build_tools_bin)/acp
CKATI := $(prebuilt_build_tools_bin)/ckati
IJAR := $(prebuilt_build_tools_bin)/ijar
MAKEPARALLEL := $(prebuilt_build_tools_bin)/makeparallel
ZIPTIME := $(prebuilt_build_tools_bin)/ziptime

USE_PREBUILT_SDK_TOOLS_IN_PLACE := true

# Override the definitions above for unbundled and PDK builds
ifneq (,$(TARGET_BUILD_APPS)$(filter true,$(TARGET_BUILD_PDK)))
AIDL := $(prebuilt_sdk_tools_bin)/aidl
AAPT := $(prebuilt_sdk_tools_bin)/aapt
AAPT2 := $(prebuilt_sdk_tools_bin)/aapt2
ZIPALIGN := $(prebuilt_sdk_tools_bin)/zipalign
SIGNAPK_JAR := $(prebuilt_sdk_tools)/lib/signapk$(COMMON_JAVA_PACKAGE_SUFFIX)
# Use 64-bit libraries unconditionally because 32-bit JVMs are no longer supported
SIGNAPK_JNI_LIBRARY_PATH := $(prebuilt_sdk_tools)/$(HOST_OS)/lib64

DX := $(prebuilt_sdk_tools)/dx
MAINDEXCLASSES := $(prebuilt_sdk_tools)/mainDexClasses

# Don't use prebuilts in PDK
ifneq ($(TARGET_BUILD_PDK),true)
LLVM_RS_CC := $(prebuilt_sdk_tools_bin)/llvm-rs-cc
BCC_COMPAT := $(prebuilt_sdk_tools_bin)/bcc_compat
endif # TARGET_BUILD_PDK
endif # TARGET_BUILD_APPS || TARGET_BUILD_PDK
prebuilt_sdk_tools :=
prebuilt_sdk_tools_bin :=


# ---------------------------------------------------------------
# Generic tools.
JACK := $(HOST_OUT_EXECUTABLES)/jack

LEX := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/flex/flex-2.5.39
# The default PKGDATADIR built in the prebuilt bison is a relative path
# external/bison/data.
# To run bison from elsewhere you need to set up enviromental variable
# BISON_PKGDATADIR.
BISON_PKGDATADIR := $(PWD)/external/bison/data
BISON := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/bison/bison
YACC := $(BISON) -d
BISON_DATA := $(wildcard external/bison/data/* external/bison/data/*/*)

YASM := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/yasm/yasm

DOXYGEN:= doxygen
ifeq ($(HOST_OS),linux)
BREAKPAD_DUMP_SYMS := $(HOST_OUT_EXECUTABLES)/dump_syms
else
# For non-supported hosts, do not generate breakpad symbols.
BREAKPAD_GENERATE_SYMBOLS := false
endif
PROTOC := $(HOST_OUT_EXECUTABLES)/aprotoc$(HOST_EXECUTABLE_SUFFIX)
NANOPB_SRCS := external/nanopb-c/generator/protoc-gen-nanopb \
    $(wildcard external/nanopb-c/generator/*.py \
               external/nanopb-c/generator/google/*.py \
               external/nanopb-c/generator/proto/*.py)
VTSC := $(HOST_OUT_EXECUTABLES)/vtsc$(HOST_EXECUTABLE_SUFFIX)
MKBOOTFS := $(HOST_OUT_EXECUTABLES)/mkbootfs$(HOST_EXECUTABLE_SUFFIX)
MINIGZIP := $(HOST_OUT_EXECUTABLES)/minigzip$(HOST_EXECUTABLE_SUFFIX)
ifeq (,$(strip $(BOARD_CUSTOM_MKBOOTIMG)))
MKBOOTIMG := $(HOST_OUT_EXECUTABLES)/mkbootimg$(HOST_EXECUTABLE_SUFFIX)
else
MKBOOTIMG := $(BOARD_CUSTOM_MKBOOTIMG)
endif
ifeq (,$(strip $(BOARD_CUSTOM_BPTTOOL)))
BPTTOOL := $(HOST_OUT_EXECUTABLES)/bpttool$(HOST_EXECUTABLE_SUFFIX)
else
BPTTOOL := $(BOARD_CUSTOM_BPTTOOL)
endif
ifeq (,$(strip $(BOARD_CUSTOM_AVBTOOL)))
AVBTOOL := $(HOST_OUT_EXECUTABLES)/avbtool$(HOST_EXECUTABLE_SUFFIX)
else
AVBTOOL := $(BOARD_CUSTOM_AVBTOOL)
endif
APICHECK := $(HOST_OUT_EXECUTABLES)/apicheck$(HOST_EXECUTABLE_SUFFIX)
FS_GET_STATS := $(HOST_OUT_EXECUTABLES)/fs_get_stats$(HOST_EXECUTABLE_SUFFIX)
ifeq ($(TARGET_USES_MKE2FS),true)
MAKE_EXT4FS := $(HOST_OUT_EXECUTABLES)/mke2fs$(HOST_EXECUTABLE_SUFFIX)
MKEXTUSERIMG := $(HOST_OUT_EXECUTABLES)/mkuserimg_mke2fs.sh
else
MAKE_EXT4FS := $(HOST_OUT_EXECUTABLES)/make_ext4fs$(HOST_EXECUTABLE_SUFFIX)
MKEXTUSERIMG := $(HOST_OUT_EXECUTABLES)/mkuserimg.sh
endif
BLK_ALLOC_TO_BASE_FS := $(HOST_OUT_EXECUTABLES)/blk_alloc_to_base_fs$(HOST_EXECUTABLE_SUFFIX)
MAKE_SQUASHFS := $(HOST_OUT_EXECUTABLES)/mksquashfs$(HOST_EXECUTABLE_SUFFIX)
MKSQUASHFSUSERIMG := $(HOST_OUT_EXECUTABLES)/mksquashfsimage.sh
MAKE_F2FS := $(HOST_OUT_EXECUTABLES)/make_f2fs$(HOST_EXECUTABLE_SUFFIX)
MKF2FSUSERIMG := $(HOST_OUT_EXECUTABLES)/mkf2fsuserimg.sh
SIMG2IMG := $(HOST_OUT_EXECUTABLES)/simg2img$(HOST_EXECUTABLE_SUFFIX)
IMG2SIMG := $(HOST_OUT_EXECUTABLES)/img2simg$(HOST_EXECUTABLE_SUFFIX)
E2FSCK := $(HOST_OUT_EXECUTABLES)/e2fsck$(HOST_EXECUTABLE_SUFFIX)
MKTARBALL := build/tools/mktarball.sh
TUNE2FS := $(HOST_OUT_EXECUTABLES)/tune2fs$(HOST_EXECUTABLE_SUFFIX)
JARJAR := $(HOST_OUT_JAVA_LIBRARIES)/jarjar.jar
DESUGAR := $(HOST_OUT_JAVA_LIBRARIES)/desugar.jar
DATA_BINDING_COMPILER := $(HOST_OUT_JAVA_LIBRARIES)/databinding-compiler.jar
FAT16COPY := build/tools/fat16copy.py
CHECK_LINK_TYPE := build/tools/check_link_type.py

ifeq ($(ANDROID_COMPILE_WITH_JACK),true)
DEFAULT_JACK_ENABLED:=full
else
DEFAULT_JACK_ENABLED:=
endif
ifneq ($(ANDROID_JACK_EXTRA_ARGS),)
JACK_DEFAULT_ARGS :=
DEFAULT_JACK_EXTRA_ARGS := $(ANDROID_JACK_EXTRA_ARGS)
else
JACK_DEFAULT_ARGS := $(BUILD_SYSTEM)/jack-default.args
DEFAULT_JACK_EXTRA_ARGS := @$(JACK_DEFAULT_ARGS)
endif

PROGUARD := external/proguard/bin/proguard.sh
JAVATAGS := build/tools/java-event-log-tags.py
MERGETAGS := build/tools/merge-event-log-tags.py
BUILD_IMAGE_SRCS := $(wildcard build/tools/releasetools/*.py)
APPEND2SIMG := $(HOST_OUT_EXECUTABLES)/append2simg
VERITY_SIGNER := $(HOST_OUT_EXECUTABLES)/verity_signer
BUILD_VERITY_TREE := $(HOST_OUT_EXECUTABLES)/build_verity_tree
BOOT_SIGNER := $(HOST_OUT_EXECUTABLES)/boot_signer
FUTILITY := $(HOST_OUT_EXECUTABLES)/futility-host
VBOOT_SIGNER := prebuilts/misc/scripts/vboot_signer/vboot_signer.sh
FEC := $(HOST_OUT_EXECUTABLES)/fec
BRILLO_UPDATE_PAYLOAD := $(HOST_OUT_EXECUTABLES)/brillo_update_payload

DEXDUMP := $(HOST_OUT_EXECUTABLES)/dexdump2$(BUILD_EXECUTABLE_SUFFIX)
PROFMAN := $(HOST_OUT_EXECUTABLES)/profman

# relocation packer
RELOCATION_PACKER := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/relocation_packer/relocation_packer

FINDBUGS_DIR := external/owasp/sanitizer/tools/findbugs/bin
FINDBUGS := $(FINDBUGS_DIR)/findbugs
EMMA_JAR := external/emma/lib/emma$(COMMON_JAVA_PACKAGE_SUFFIX)

# Tool to merge AndroidManifest.xmls
ANDROID_MANIFEST_MERGER := java -classpath prebuilts/devtools/tools/lib/manifest-merger.jar com.android.manifmerger.Main merge

COLUMN:= column

# We may not have the right JAVA_HOME/PATH set up yet when this is run from envsetup.sh.
ifneq ($(CALLED_FROM_SETUP),true)
HOST_JDK_TOOLS_JAR:= $(shell $(BUILD_SYSTEM)/find-jdk-tools-jar.sh)

ifneq ($(HOST_JDK_TOOLS_JAR),)
ifeq ($(wildcard $(HOST_JDK_TOOLS_JAR)),)
$(error Error: could not find jdk tools.jar at $(HOST_JDK_TOOLS_JAR), please check if your JDK was installed correctly)
endif
endif

# Is the host JDK 64-bit version?
HOST_JDK_IS_64BIT_VERSION :=
ifneq ($(filter 64-Bit, $(shell java -version 2>&1)),)
HOST_JDK_IS_64BIT_VERSION := true
endif
endif  # CALLED_FROM_SETUP not true

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

# We run gcc/clang with PWD=/proc/self/cwd to remove the $TOP
# from the debug output. That way two builds in two different
# directories will create the same output.
# /proc doesn't exist on Darwin.
ifeq ($(HOST_OS),linux)
RELATIVE_PWD := PWD=/proc/self/cwd
else
RELATIVE_PWD :=
endif

TARGET_PROJECT_INCLUDES :=
TARGET_PROJECT_SYSTEM_INCLUDES := \
		$(TARGET_DEVICE_KERNEL_HEADERS) $(TARGET_BOARD_KERNEL_HEADERS) \
		$(TARGET_PRODUCT_KERNEL_HEADERS)

ifdef TARGET_2ND_ARCH
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_PROJECT_INCLUDES := $(TARGET_PROJECT_INCLUDES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_PROJECT_SYSTEM_INCLUDES := $(TARGET_PROJECT_SYSTEM_INCLUDES)
endif

# allow overriding default Java libraries on a per-target basis
ifeq ($(TARGET_DEFAULT_JAVA_LIBRARIES),)
  TARGET_DEFAULT_JAVA_LIBRARIES := core-oj core-libart ext framework okhttp
endif

# Flags for DEX2OAT
first_non_empty_of_three = $(if $(1),$(1),$(if $(2),$(2),$(3)))
DEX2OAT_TARGET_ARCH := $(TARGET_ARCH)
DEX2OAT_TARGET_CPU_VARIANT := $(call first_non_empty_of_three,$(TARGET_CPU_VARIANT),$(TARGET_ARCH_VARIANT),default)
DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := default

ifdef TARGET_2ND_ARCH
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH := $(TARGET_2ND_ARCH)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT := $(call first_non_empty_of_three,$(TARGET_2ND_CPU_VARIANT),$(TARGET_2ND_ARCH_VARIANT),default)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := default
endif

# These will come from Soong, drop the environment versions
unexport CLANG
unexport CLANG_CXX
unexport CCC_CC
unexport CCC_CXX

# ###############################################################
# Collect a list of the SDK versions that we could compile against
# For use with the LOCAL_SDK_VERSION variable for include $(BUILD_PACKAGE)
# ###############################################################

HISTORICAL_SDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/sdk
HISTORICAL_NDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/ndk

# The path where app can reference the support library resources.
ifdef TARGET_BUILD_APPS
SUPPORT_LIBRARY_ROOT := $(HISTORICAL_SDK_VERSIONS_ROOT)/current/support
else
SUPPORT_LIBRARY_ROOT := frameworks/support
endif

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

# We don't have prebuilt test_current SDK yet.
TARGET_AVAILABLE_SDK_VERSIONS := test_current $(TARGET_AVAILABLE_SDK_VERSIONS)

INTERNAL_PLATFORM_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/public_api.txt
INTERNAL_PLATFORM_REMOVED_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/removed.txt
INTERNAL_PLATFORM_SYSTEM_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/system-api.txt
INTERNAL_PLATFORM_SYSTEM_REMOVED_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/system-removed.txt
INTERNAL_PLATFORM_TEST_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/test-api.txt
INTERNAL_PLATFORM_TEST_REMOVED_API_FILE := $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/test-removed.txt

# This is the standard way to name a directory containing prebuilt target
# objects. E.g., prebuilt/$(TARGET_PREBUILT_TAG)/libc.so
TARGET_PREBUILT_TAG := android-$(TARGET_ARCH)
ifdef TARGET_2ND_ARCH
TARGET_2ND_PREBUILT_TAG := android-$(TARGET_2ND_ARCH)
endif

# Set up RS prebuilt variables for compatibility library

RS_PREBUILT_CLCORE := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/librsrt_$(TARGET_ARCH).bc
RS_PREBUILT_COMPILER_RT := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/libcompiler_rt.a
ifeq (true,$(TARGET_IS_64_BIT))
RS_PREBUILT_LIBPATH := -L prebuilts/ndk/current/platforms/android-21/arch-$(TARGET_ARCH)/usr/lib64 \
                       -L prebuilts/ndk/current/platforms/android-21/arch-$(TARGET_ARCH)/usr/lib
else
RS_PREBUILT_LIBPATH := -L prebuilts/ndk/current/platforms/android-9/arch-$(TARGET_ARCH)/usr/lib
endif

# API Level lists for Renderscript Compat lib.
RSCOMPAT_32BIT_ONLY_API_LEVELS := 8 9 10 11 12 13 14 15 16 17 18 19 20
RSCOMPAT_NO_USAGEIO_API_LEVELS := 8 9 10 11 12 13

ifeq ($(JAVA_NOT_REQUIRED),true)
# Remove java and tools from our path so that we make sure nobody uses them.
unexport ANDROID_JAVA_HOME
unexport JAVA_HOME
export ANDROID_BUILD_PATHS:=$(abspath $(BUILD_SYSTEM)/no_java_path):$(ANDROID_BUILD_PATHS)
export PATH:=$(abspath $(BUILD_SYSTEM)/no_java_path):$(PATH)
endif

# Projects clean of compiler warnings should be compiled with -Werror.
# If most modules in a directory such as external/ have warnings,
# the directory should be in ANDROID_WARNING_ALLOWED_PROJECTS list.
# When some of its subdirectories are cleaned up, the subdirectories
# can be added into ANDROID_WARNING_DISALLOWED_PROJECTS list, e.g.
# external/fio/.
ANDROID_WARNING_DISALLOWED_PROJECTS := \
    art/% \
    bionic/% \
    external/fio/% \
    hardware/interfaces/% \

define find_warning_disallowed_projects
    $(filter $(ANDROID_WARNING_DISALLOWED_PROJECTS),$(1)/)
endef

# Projects with compiler warnings are compiled without -Werror.
ANDROID_WARNING_ALLOWED_PROJECTS := \
    bootable/% \
    cts/% \
    dalvik/% \
    development/% \
    device/% \
    external/% \
    frameworks/% \
    hardware/% \
    packages/% \
    system/% \
    test/vts/% \
    tools/adt/idea/android/ultimate/get_modification_time/jni/% \
    vendor/% \

define find_warning_allowed_projects
    $(filter $(ANDROID_WARNING_ALLOWED_PROJECTS),$(1)/)
endef

# These goals don't need to collect and include Android.mks/CleanSpec.mks
# in the source tree.
dont_bother_goals := clean clobber dataclean installclean \
    help out \
    snod systemimage-nodeps \
    stnod systemtarball-nodeps \
    userdataimage-nodeps userdatatarball-nodeps \
    cacheimage-nodeps \
    bptimage-nodeps \
    vnod vendorimage-nodeps \
    systemotherimage-nodeps \
    ramdisk-nodeps \
    bootimage-nodeps \
    recoveryimage-nodeps \
    vbmetaimage-nodeps \
    product-graph dump-products

ifndef KATI
include $(BUILD_SYSTEM)/ninja_config.mk
include $(BUILD_SYSTEM)/soong_config.mk
endif

include $(BUILD_SYSTEM)/dumpvar.mk
