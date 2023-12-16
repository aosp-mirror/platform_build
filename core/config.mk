# This is included by the top-level Makefile.
# It sets up standard variables based on the
# current configuration and platform, which
# are not specific to what is being built.

ifndef KATI
$(warning Directly using config.mk from make is no longer supported.)
$(warning )
$(warning If you are just attempting to build, you probably need to re-source envsetup.sh:)
$(warning )
$(warning $$ source build/envsetup.sh)
$(warning )
$(warning If you are attempting to emulate get_build_var, use one of the following:)
$(warning $$ build/soong/soong_ui.bash --dumpvar-mode)
$(warning $$ build/soong/soong_ui.bash --dumpvars-mode)
$(warning )
$(error done)
endif

BUILD_SYSTEM :=$= build/make/core
BUILD_SYSTEM_COMMON :=$= build/make/common

include $(BUILD_SYSTEM_COMMON)/core.mk

# -----------------------------------------------------------------
# Rules and functions to help copy important files to DIST_DIR
# when requested. This must be included once only, and must be included before
# soong_config (as soong_config calls make_vars-$(TARGET).mk, and soong may
# propagate calls to dist-for-goals there).
include $(BUILD_SYSTEM)/distdir.mk

# Mark variables that should be coming as environment variables from soong_ui
# as readonly
.KATI_READONLY := OUT_DIR TMPDIR BUILD_DATETIME_FILE
ifdef CALLED_FROM_SETUP
  .KATI_READONLY := CALLED_FROM_SETUP
endif
ifdef KATI_PACKAGE_MK_DIR
  .KATI_READONLY := KATI_PACKAGE_MK_DIR
endif

# Mark variables deprecated/obsolete
CHANGES_URL := https://android.googlesource.com/platform/build/+/master/Changes.md
.KATI_READONLY := CHANGES_URL
$(KATI_deprecated_var TARGET_USES_64_BIT_BINDER,All devices use 64-bit binder by default now. Uses of TARGET_USES_64_BIT_BINDER should be removed.)
$(KATI_deprecated_var PRODUCT_SEPOLICY_SPLIT,All devices are built with split sepolicy.)
$(KATI_deprecated_var PRODUCT_SEPOLICY_SPLIT_OVERRIDE,All devices are built with split sepolicy.)
$(KATI_obsolete_var PATH,Do not use PATH directly. See $(CHANGES_URL)#PATH)
$(KATI_obsolete_var PYTHONPATH,Do not use PYTHONPATH directly. See $(CHANGES_URL)#PYTHONPATH)
$(KATI_obsolete_var OUT,Use OUT_DIR instead. See $(CHANGES_URL)#OUT)
$(KATI_obsolete_var ANDROID_HOST_OUT,Use HOST_OUT instead. See $(CHANGES_URL)#ANDROID_HOST_OUT)
$(KATI_obsolete_var ANDROID_PRODUCT_OUT,Use PRODUCT_OUT instead. See $(CHANGES_URL)#ANDROID_PRODUCT_OUT)
$(KATI_obsolete_var ANDROID_HOST_OUT_TESTCASES,Use HOST_OUT_TESTCASES instead. See $(CHANGES_URL)#ANDROID_HOST_OUT_TESTCASES)
$(KATI_obsolete_var ANDROID_TARGET_OUT_TESTCASES,Use TARGET_OUT_TESTCASES instead. See $(CHANGES_URL)#ANDROID_TARGET_OUT_TESTCASES)
$(KATI_obsolete_var ANDROID_BUILD_TOP,Use '.' instead. See $(CHANGES_URL)#ANDROID_BUILD_TOP)
$(KATI_obsolete_var \
  ANDROID_TOOLCHAIN \
  ANDROID_TOOLCHAIN_2ND_ARCH \
  ANDROID_DEV_SCRIPTS \
  ANDROID_EMULATOR_PREBUILTS \
  ANDROID_PRE_BUILD_PATHS \
  ,See $(CHANGES_URL)#other_envsetup_variables)
$(KATI_obsolete_var PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE,Set FCM Version in device manifest instead. See $(CHANGES_URL)#PRODUCT_COMPATIBILITY_MATRIX_LEVEL_OVERRIDE)
$(KATI_obsolete_var USE_CLANG_PLATFORM_BUILD,Clang is the only supported Android compiler. See $(CHANGES_URL)#USE_CLANG_PLATFORM_BUILD)
$(KATI_obsolete_var BUILD_DROIDDOC,Droiddoc is only supported in Soong. See details on build/soong/java/droiddoc.go)
$(KATI_obsolete_var BUILD_APIDIFF,Apidiff is only supported in Soong. See details on build/soong/java/droiddoc.go)
$(KATI_obsolete_var \
  DEFAULT_GCC_CPP_STD_VERSION \
  HOST_GLOBAL_CFLAGS 2ND_HOST_GLOBAL_CFLAGS \
  HOST_GLOBAL_CONLYFLAGS 2ND_HOST_GLOBAL_CONLYFLAGS \
  HOST_GLOBAL_CPPFLAGS 2ND_HOST_GLOBAL_CPPFLAGS \
  HOST_GLOBAL_LDFLAGS 2ND_HOST_GLOBAL_LDFLAGS \
  HOST_GLOBAL_LLDFLAGS 2ND_HOST_GLOBAL_LLDFLAGS \
  HOST_CLANG_SUPPORTED 2ND_HOST_CLANG_SUPPORTED \
  HOST_CC 2ND_HOST_CC \
  HOST_CXX 2ND_HOST_CXX \
  HOST_CROSS_GLOBAL_CFLAGS 2ND_HOST_CROSS_GLOBAL_CFLAGS \
  HOST_CROSS_GLOBAL_CONLYFLAGS 2ND_HOST_CROSS_GLOBAL_CONLYFLAGS \
  HOST_CROSS_GLOBAL_CPPFLAGS 2ND_HOST_CROSS_GLOBAL_CPPFLAGS \
  HOST_CROSS_GLOBAL_LDFLAGS 2ND_HOST_CROSS_GLOBAL_LDFLAGS \
  HOST_CROSS_GLOBAL_LLDFLAGS 2ND_HOST_CROSS_GLOBAL_LLDFLAGS \
  HOST_CROSS_CLANG_SUPPORTED 2ND_HOST_CROSS_CLANG_SUPPORTED \
  HOST_CROSS_CC 2ND_HOST_CROSS_CC \
  HOST_CROSS_CXX 2ND_HOST_CROSS_CXX \
  TARGET_GLOBAL_CFLAGS 2ND_TARGET_GLOBAL_CFLAGS \
  TARGET_GLOBAL_CONLYFLAGS 2ND_TARGET_GLOBAL_CONLYFLAGS \
  TARGET_GLOBAL_CPPFLAGS 2ND_TARGET_GLOBAL_CPPFLAGS \
  TARGET_GLOBAL_LDFLAGS 2ND_TARGET_GLOBAL_LDFLAGS \
  TARGET_GLOBAL_LLDFLAGS 2ND_TARGET_GLOBAL_LLDFLAGS \
  TARGET_CLANG_SUPPORTED 2ND_TARGET_CLANG_SUPPORTED \
  TARGET_CC 2ND_TARGET_CC \
  TARGET_CXX 2ND_TARGET_CXX \
  TARGET_TOOLCHAIN_ROOT 2ND_TARGET_TOOLCHAIN_ROOT \
  HOST_TOOLCHAIN_ROOT 2ND_HOST_TOOLCHAIN_ROOT \
  HOST_CROSS_TOOLCHAIN_ROOT 2ND_HOST_CROSS_TOOLCHAIN_ROOT \
  HOST_TOOLS_PREFIX 2ND_HOST_TOOLS_PREFIX \
  HOST_CROSS_TOOLS_PREFIX 2ND_HOST_CROSS_TOOLS_PREFIX \
  HOST_GCC_VERSION 2ND_HOST_GCC_VERSION \
  HOST_CROSS_GCC_VERSION 2ND_HOST_CROSS_GCC_VERSION \
  TARGET_NDK_GCC_VERSION 2ND_TARGET_NDK_GCC_VERSION \
  GLOBAL_CFLAGS_NO_OVERRIDE GLOBAL_CPPFLAGS_NO_OVERRIDE \
  ,GCC support has been removed. Use Clang instead)
$(KATI_obsolete_var DIST_DIR dist_goal,Use dist-for-goals instead. See $(CHANGES_URL)#dist)
$(KATI_obsolete_var TARGET_ANDROID_FILESYSTEM_CONFIG_H,Use TARGET_FS_CONFIG_GEN instead)
$(KATI_deprecated_var USER,Use BUILD_USERNAME instead. See $(CHANGES_URL)#USER)
$(KATI_obsolete_var TARGET_ROOT_OUT_SBIN,/sbin has been removed, use /system/bin instead)
$(KATI_obsolete_var TARGET_ROOT_OUT_SBIN_UNSTRIPPED,/sbin has been removed, use /system/bin instead)
$(KATI_obsolete_var BUILD_BROKEN_PHONY_TARGETS)
$(KATI_obsolete_var BUILD_BROKEN_DUP_COPY_HEADERS)
$(KATI_obsolete_var BUILD_BROKEN_ENG_DEBUG_TAGS)
$(KATI_obsolete_export It is a global setting. See $(CHANGES_URL)#export_keyword)
$(KATI_obsolete_var BUILD_BROKEN_ANDROIDMK_EXPORTS)
$(KATI_obsolete_var PRODUCT_STATIC_BOOT_CONTROL_HAL,Use shared library module instead. See $(CHANGES_URL)#PRODUCT_STATIC_BOOT_CONTROL_HAL)
$(KATI_obsolete_var \
  ARCH_ARM_HAVE_ARMV7A \
  ARCH_DSP_REV \
  ARCH_HAVE_ALIGNED_DOUBLES \
  ARCH_MIPS_HAS_DSP \
  ARCH_MIPS_HAS_FPU \
  ARCH_MIPS_REV6 \
  ARCH_X86_HAVE_AES_NI \
  ARCH_X86_HAVE_AVX \
  ARCH_X86_HAVE_AVX2 \
  ARCH_X86_HAVE_AVX512 \
  ARCH_X86_HAVE_MOVBE \
  ARCH_X86_HAVE_POPCNT \
  ARCH_X86_HAVE_SSE4 \
  ARCH_X86_HAVE_SSE4_2 \
  ARCH_X86_HAVE_SSSE3 \
)
$(KATI_obsolete_var PRODUCT_IOT)
$(KATI_obsolete_var MD5SUM)
$(KATI_obsolete_var BOARD_HAL_STATIC_LIBRARIES, See $(CHANGES_URL)#BOARD_HAL_STATIC_LIBRARIES)
$(KATI_obsolete_var LOCAL_HAL_STATIC_LIBRARIES, See $(CHANGES_URL)#BOARD_HAL_STATIC_LIBRARIES)
$(KATI_obsolete_var \
  TARGET_AUX_OS_VARIANT_LIST \
  LOCAL_AUX_ARCH \
  LOCAL_AUX_CPU \
  LOCAL_AUX_OS \
  LOCAL_AUX_OS_VARIANT \
  LOCAL_AUX_SUBARCH \
  LOCAL_AUX_TOOLCHAIN \
  LOCAL_CUSTOM_BUILD_STEP_INPUT \
  LOCAL_CUSTOM_BUILD_STEP_OUTPUT \
  LOCAL_IS_AUX_MODULE \
  ,AUX support has been removed)
$(KATI_obsolete_var HOST_OUT_TEST_CONFIG TARGET_OUT_TEST_CONFIG LOCAL_TEST_CONFIG_OPTIONS)
$(KATI_obsolete_var \
  TARGET_PROJECT_INCLUDES \
  2ND_TARGET_PROJECT_INCLUDES \
  TARGET_PROJECT_SYSTEM_INCLUDES \
  2ND_TARGET_PROJECT_SYSTEM_INCLUDES \
  ,Project include variables have been removed)
$(KATI_obsolete_var TARGET_PREFER_32_BIT TARGET_PREFER_32_BIT_APPS TARGET_PREFER_32_BIT_EXECUTABLES)
$(KATI_obsolete_var PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_WHITELIST,Use PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_ALLOW_LIST)
$(KATI_obsolete_var PRODUCT_ARTIFACT_PATH_REQUIREMENT_WHITELIST,Use PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST)
$(KATI_obsolete_var COVERAGE_PATHS,Use NATIVE_COVERAGE_PATHS instead)
$(KATI_obsolete_var COVERAGE_EXCLUDE_PATHS,Use NATIVE_COVERAGE_EXCLUDE_PATHS instead)
$(KATI_obsolete_var BOARD_VNDK_RUNTIME_DISABLE,VNDK-Lite is no longer supported)
$(KATI_obsolete_var LOCAL_SANITIZE_BLACKLIST,Use LOCAL_SANITIZE_BLOCKLIST instead)
$(KATI_obsolete_var BOARD_PLAT_PUBLIC_SEPOLICY_DIR,Use SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS instead)
$(KATI_obsolete_var BOARD_PLAT_PRIVATE_SEPOLICY_DIR,Use SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS instead)
$(KATI_obsolete_var TARGET_NO_VENDOR_BOOT,Use PRODUCT_BUILD_VENDOR_BOOT_IMAGE instead)
$(KATI_obsolete_var PRODUCT_CHECK_ELF_FILES,Use BUILD_BROKEN_PREBUILT_ELF_FILES instead)
$(KATI_obsolete_var ALL_GENERATED_SOURCES,ALL_GENERATED_SOURCES is no longer used)
$(KATI_obsolete_var ALL_ORIGINAL_DYNAMIC_BINARIES,ALL_ORIGINAL_DYNAMIC_BINARIES is no longer used)
$(KATI_obsolete_var PRODUCT_SUPPORTS_VERITY,VB 1.0 and related variables are no longer supported)
$(KATI_obsolete_var PRODUCT_SUPPORTS_VERITY_FEC,VB 1.0 and related variables are no longer supported)
$(KATI_obsolete_var PRODUCT_SUPPORTS_BOOT_SIGNER,VB 1.0 and related variables are no longer supported)
$(KATI_obsolete_var PRODUCT_VERITY_SIGNING_KEY,VB 1.0 and related variables are no longer supported)
$(KATI_obsolete_var BOARD_PREBUILT_PVMFWIMAGE,pvmfw.bin is now built in AOSP and custom versions are no longer supported)
$(KATI_obsolete_var BUILDING_PVMFW_IMAGE,BUILDING_PVMFW_IMAGE is no longer used)
$(KATI_obsolete_var BOARD_BUILD_SYSTEM_ROOT_IMAGE)

# Used to force goals to build.  Only use for conditionally defined goals.
.PHONY: FORCE
FORCE:

ORIGINAL_MAKECMDGOALS := $(MAKECMDGOALS)

UNAME := $(shell uname -sm)

SRC_TARGET_DIR := $(TOPDIR)build/make/target

# Some specific paths to tools
SRC_DROIDDOC_DIR := $(TOPDIR)build/make/tools/droiddoc

# Mark some inputs as readonly
ifdef TARGET_DEVICE_DIR
  .KATI_READONLY := TARGET_DEVICE_DIR
endif

ONE_SHOT_MAKEFILE :=
.KATI_READONLY := ONE_SHOT_MAKEFILE

# Set up efficient math functions which are used in make.
# Here since this file is included by envsetup as well as during build.
include $(BUILD_SYSTEM_COMMON)/math.mk

include $(BUILD_SYSTEM_COMMON)/strings.mk

include $(BUILD_SYSTEM_COMMON)/json.mk

# Various mappings to avoid hard-coding paths all over the place
include $(BUILD_SYSTEM)/pathmap.mk

# Allow projects to define their own globally-available variables
include $(BUILD_SYSTEM)/project_definitions.mk

# ###############################################################
# Build system internal files
# ###############################################################

BUILD_COMBOS :=$= $(BUILD_SYSTEM)/combo

CLEAR_VARS :=$= $(BUILD_SYSTEM)/clear_vars.mk

BUILD_HOST_STATIC_LIBRARY :=$= $(BUILD_SYSTEM)/host_static_library.mk
BUILD_HOST_SHARED_LIBRARY :=$= $(BUILD_SYSTEM)/host_shared_library.mk
BUILD_STATIC_LIBRARY :=$= $(BUILD_SYSTEM)/static_library.mk
BUILD_HEADER_LIBRARY :=$= $(BUILD_SYSTEM)/header_library.mk
BUILD_SHARED_LIBRARY :=$= $(BUILD_SYSTEM)/shared_library.mk
BUILD_EXECUTABLE :=$= $(BUILD_SYSTEM)/executable.mk
BUILD_HOST_EXECUTABLE :=$= $(BUILD_SYSTEM)/host_executable.mk
BUILD_PACKAGE :=$= $(BUILD_SYSTEM)/package.mk
BUILD_PHONY_PACKAGE :=$= $(BUILD_SYSTEM)/phony_package.mk
BUILD_RRO_PACKAGE :=$= $(BUILD_SYSTEM)/build_rro_package.mk
BUILD_HOST_PREBUILT :=$= $(BUILD_SYSTEM)/host_prebuilt.mk
BUILD_PREBUILT :=$= $(BUILD_SYSTEM)/prebuilt.mk
BUILD_MULTI_PREBUILT :=$= $(BUILD_SYSTEM)/multi_prebuilt.mk
BUILD_JAVA_LIBRARY :=$= $(BUILD_SYSTEM)/java_library.mk
BUILD_STATIC_JAVA_LIBRARY :=$= $(BUILD_SYSTEM)/static_java_library.mk
BUILD_HOST_JAVA_LIBRARY :=$= $(BUILD_SYSTEM)/host_java_library.mk
BUILD_COPY_HEADERS :=$= $(BUILD_SYSTEM)/copy_headers.mk
BUILD_NATIVE_TEST :=$= $(BUILD_SYSTEM)/native_test.mk
BUILD_FUZZ_TEST :=$= $(BUILD_SYSTEM)/fuzz_test.mk

BUILD_NOTICE_FILE :=$= $(BUILD_SYSTEM)/notice_files.mk
BUILD_SBOM_GEN :=$= $(BUILD_SYSTEM)/sbom.mk

include $(BUILD_SYSTEM)/deprecation.mk

# ###############################################################
# Parse out any modifier targets.
# ###############################################################

hide := @

################################################################
# Tools needed in product configuration makefiles.
################################################################
NORMALIZE_PATH := build/make/tools/normalize_path.py

# $(1): the paths to be normalized
define normalize-paths
$(if $(1),$(shell $(NORMALIZE_PATH) $(1)))
endef

# ###############################################################
# Set common values
# ###############################################################

# Initialize SOONG_CONFIG_NAMESPACES so that it isn't recursive.
SOONG_CONFIG_NAMESPACES :=

# TODO(asmundak): remove add_soong_config_namespace, add_soong_config_var,
# and add_soong_config_var_value once all their usages are replaced with
# soong_config_set/soong_config_append.

# The add_soong_config_namespace function adds a namespace and initializes it
# to be empty.
# $1 is the namespace.
# Ex: $(call add_soong_config_namespace,acme)

define add_soong_config_namespace
$(eval SOONG_CONFIG_NAMESPACES += $(strip $1)) \
$(eval SOONG_CONFIG_$(strip $1) :=)
endef

# The add_soong_config_var function adds a a list of soong config variables to
# SOONG_CONFIG_*. The variables and their values are then available to a
# soong_config_module_type in an Android.bp file.
# $1 is the namespace. $2 is the list of variables.
# Ex: $(call add_soong_config_var,acme,COOL_FEATURE_A COOL_FEATURE_B)
define add_soong_config_var
$(eval SOONG_CONFIG_$(strip $1) += $(strip $2)) \
$(foreach v,$(strip $2),$(eval SOONG_CONFIG_$(strip $1)_$v := $(strip $($v))))
endef

# The add_soong_config_var_value function defines a make variable and also adds
# the variable to SOONG_CONFIG_*.
# $1 is the namespace. $2 is the variable name. $3 is the variable value.
# Ex: $(call add_soong_config_var_value,acme,COOL_FEATURE,true)

define add_soong_config_var_value
$(eval $(strip $2) := $(strip $3)) \
$(call add_soong_config_var,$1,$2)
endef

# Soong config namespace variables manipulation.
#
# internal utility to define a namespace and a variable in it.
define soong_config_define_internal
$(if $(filter $1,$(SOONG_CONFIG_NAMESPACES)),,$(eval SOONG_CONFIG_NAMESPACES:=$(SOONG_CONFIG_NAMESPACES) $(strip $1))) \
$(if $(filter $2,$(SOONG_CONFIG_$(strip $1))),,$(eval SOONG_CONFIG_$(strip $1):=$(SOONG_CONFIG_$(strip $1)) $(strip $2)))
endef

# soong_config_set defines the variable in the given Soong config namespace
# and sets its value. If the namespace does not exist, it will be defined.
# $1 is the namespace. $2 is the variable name. $3 is the variable value.
# Ex: $(call soong_config_set,acme,COOL_FEATURE,true)
define soong_config_set
$(call soong_config_define_internal,$1,$2) \
$(eval SOONG_CONFIG_$(strip $1)_$(strip $2):=$(strip $3))
endef

# soong_config_append appends to the value of the variable in the given Soong
# config namespace. If the variable does not exist, it will be defined. If the
# namespace does not  exist, it will be defined.
# $1 is the namespace, $2 is the variable name, $3 is the value
define soong_config_append
$(call soong_config_define_internal,$1,$2) \
$(eval SOONG_CONFIG_$(strip $1)_$(strip $2):=$(SOONG_CONFIG_$(strip $1)_$(strip $2)) $(strip $3))
endef

# soong_config_append gets to the value of the variable in the given Soong
# config namespace. If the namespace or variables does not exist, an
# empty string will be returned.
# $1 is the namespace, $2 is the variable name
define soong_config_get
$(SOONG_CONFIG_$(strip $1)_$(strip $2))
endef

# Set the extensions used for various packages
COMMON_PACKAGE_SUFFIX := .zip
COMMON_JAVA_PACKAGE_SUFFIX := .jar
COMMON_ANDROID_PACKAGE_SUFFIX := .apk

ifdef TMPDIR
JAVA_TMPDIR_ARG := -Djava.io.tmpdir=$(TMPDIR)
else
JAVA_TMPDIR_ARG :=
endif

# These build broken variables are intended to be set in a buildspec file,
# while other build broken flags are expected to be set in a board config.
# These are build broken variables that are expected to apply across board
# configs, generally for cross-cutting features.

# Build broken variables that should be treated as booleans
_build_broken_bool_vars := \
  BUILD_BROKEN_USES_SOONG_PYTHON2_MODULES \

# Build broken variables that should be treated as lists
_build_broken_list_vars := \
  BUILD_BROKEN_PLUGIN_VALIDATION \

_build_broken_var_names := $(_build_broken_bool_vars)
_build_broken_var_names += $(_build_broken_list_vars)
$(foreach v,$(_build_broken_var_names),$(eval $(v) :=))

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

# Starting in Android U, non-VNDK devices not supported
# WARNING: DO NOT CHANGE: if you are downstream of AOSP, and you change this, without
# letting upstream know it's important to you, we may do cleanup which breaks this
# significantly. Please let us know if you are changing this.
ifndef BOARD_VNDK_VERSION
# READ WARNING - DO NOT CHANGE
BOARD_VNDK_VERSION := current
# READ WARNING - DO NOT CHANGE
endif

# ---------------------------------------------------------------
# Define most of the global variables.  These are the ones that
# are specific to the user's build configuration.
include $(BUILD_SYSTEM)/envsetup.mk


$(foreach var,$(_build_broken_bool_vars), \
  $(if $(filter-out true false,$($(var))), \
    $(error Valid values of $(var) are "true", "false", and "". Not "$($(var))")))

.KATI_READONLY := $(_build_broken_var_names)

# Returns true if it is a low memory device, otherwise it returns false.
define is-low-mem-device
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_PROPERTY_OVERRIDES)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_DEFAULT_PROPERTY_OVERRIDES)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_COMPATIBLE_PROPERTY)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_SYSTEM_DEFAULT_PROPERTIES)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_SYSTEM_EXT_PROPERTIES)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_PRODUCT_PROPERTIES)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_VENDOR_PROPERTIES)),true,\
$(if $(findstring ro.config.low_ram=true,$(PRODUCT_ODM_PROPERTIES)),true,false)))))))))
endef

# Set TARGET_MAX_PAGE_SIZE_SUPPORTED.
# TARGET_MAX_PAGE_SIZE_SUPPORTED indicates the alignment of the ELF segments.
ifdef PRODUCT_MAX_PAGE_SIZE_SUPPORTED
  TARGET_MAX_PAGE_SIZE_SUPPORTED := $(PRODUCT_MAX_PAGE_SIZE_SUPPORTED)
else ifeq ($(strip $(call is-low-mem-device)),true)
  # Low memory device will have 4096 binary alignment.
  TARGET_MAX_PAGE_SIZE_SUPPORTED := 4096
else
  # The default binary alignment for userspace is 4096.
  TARGET_MAX_PAGE_SIZE_SUPPORTED := 4096
  # When VSR vendor API level >= 34, binary alignment will be 65536.
  ifeq ($(call math_gt_or_eq,$(VSR_VENDOR_API_LEVEL),34),true)
    ifeq ($(TARGET_ARCH),arm64)
      TARGET_MAX_PAGE_SIZE_SUPPORTED := 65536
    endif
  endif
endif
.KATI_READONLY := TARGET_MAX_PAGE_SIZE_SUPPORTED

# Only arm64 and x86_64 archs supports TARGET_MAX_PAGE_SIZE_SUPPORTED greater than 4096.
ifneq ($(TARGET_MAX_PAGE_SIZE_SUPPORTED),4096)
  ifeq (,$(filter arm64 x86_64,$(TARGET_ARCH)))
    $(error TARGET_MAX_PAGE_SIZE_SUPPORTED=$(TARGET_MAX_PAGE_SIZE_SUPPORTED) is greater than 4096. Only supported in arm64 and x86_64 archs)
  endif
endif

# Boolean variable determining if AOSP is page size agnostic. This means
# that AOSP can use a kernel configured with 4k/16k/64k PAGE SIZES.
TARGET_NO_BIONIC_PAGE_SIZE_MACRO := false
ifdef PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO
  TARGET_NO_BIONIC_PAGE_SIZE_MACRO := $(PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO)
  ifeq ($(TARGET_NO_BIONIC_PAGE_SIZE_MACRO),true)
      ifneq ($(TARGET_MAX_PAGE_SIZE_SUPPORTED),65536)
          $(error TARGET_MAX_PAGE_SIZE_SUPPORTED has to be 65536 to support page size agnostic)
      endif
  endif
endif
.KATI_READONLY := TARGET_NO_BIONIC_PAGE_SIZE_MACRO

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
.KATI_READONLY := TARGET_DEVICE_KERNEL_HEADERS TARGET_BOARD_KERNEL_HEADERS TARGET_PRODUCT_KERNEL_HEADERS

# Commands to generate .toc file common to ELF .so files.
define _gen_toc_command_for_elf
$(hide) ($($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)READELF) -d $(1) | grep SONAME || echo "No SONAME for $1") > $(2)
$(hide) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)READELF) --dyn-syms $(1) | awk '{$$2=""; $$3=""; print}' >> $(2)
endef

# Commands to generate .toc file from Darwin dynamic library.
define _gen_toc_command_for_macho
$(hide) $(HOST_OTOOL) -l $(1) | grep LC_ID_DYLIB -A 5 > $(2)
$(hide) $(HOST_NM) -gP $(1) | cut -f1-2 -d" " | (grep -v U$$ >> $(2) || true)
endef

# Pick a Java compiler.
include $(BUILD_SYSTEM)/combo/javac.mk

ifeq ($(CALLED_FROM_SETUP),true)
include $(BUILD_SYSTEM)/ccache.mk
include $(BUILD_SYSTEM)/goma.mk
include $(BUILD_SYSTEM)/rbe.mk
endif

# GCC version selection
TARGET_GCC_VERSION := 4.9
ifdef TARGET_2ND_ARCH
2ND_TARGET_GCC_VERSION := 4.9
endif

# Normalize WITH_STATIC_ANALYZER
ifeq ($(strip $(WITH_STATIC_ANALYZER)),0)
  WITH_STATIC_ANALYZER :=
endif

# Unset WITH_TIDY_ONLY if global WITH_TIDY_ONLY is not true nor 1.
ifeq (,$(filter 1 true,$(WITH_TIDY_ONLY)))
  WITH_TIDY_ONLY :=
endif

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
# Whether we can expect a full build graph
ALLOW_MISSING_DEPENDENCIES := $(filter true,$(ALLOW_MISSING_DEPENDENCIES))
ifneq ($(TARGET_BUILD_APPS),)
ALLOW_MISSING_DEPENDENCIES := true
endif
ifeq ($(TARGET_BUILD_UNBUNDLED_IMAGE),true)
ALLOW_MISSING_DEPENDENCIES := true
endif
ifneq ($(filter true,$(SOONG_ALLOW_MISSING_DEPENDENCIES)),)
ALLOW_MISSING_DEPENDENCIES := true
endif
# Mac builds default to ALLOW_MISSING_DEPENDENCIES, at least until the host
# tools aren't enabled by default for Mac.
ifeq ($(HOST_OS),darwin)
  ALLOW_MISSING_DEPENDENCIES := true
endif
.KATI_READONLY := ALLOW_MISSING_DEPENDENCIES

TARGET_BUILD_USE_PREBUILT_SDKS :=
DISABLE_PREOPT :=
DISABLE_PREOPT_BOOT_IMAGES :=
ifneq (,$(TARGET_BUILD_APPS)$(TARGET_BUILD_UNBUNDLED_IMAGE))
  DISABLE_PREOPT := true
  # VSDK builds perform dexpreopt during merge_target_files build step.
  ifneq (true,$(BUILDING_WITH_VSDK))
    DISABLE_PREOPT_BOOT_IMAGES := true
  endif
endif
ifeq (true,$(TARGET_BUILD_UNBUNDLED))
  ifneq (true,$(UNBUNDLED_BUILD_SDKS_FROM_SOURCE))
    TARGET_BUILD_USE_PREBUILT_SDKS := true
  endif
endif

.KATI_READONLY := \
  TARGET_BUILD_USE_PREBUILT_SDKS \
  DISABLE_PREOPT \
  DISABLE_PREOPT_BOOT_IMAGES \

prebuilt_sdk_tools := prebuilts/sdk/tools
prebuilt_sdk_tools_bin := $(prebuilt_sdk_tools)/$(HOST_OS)/bin

prebuilt_build_tools := prebuilts/build-tools
prebuilt_build_tools_wrappers := prebuilts/build-tools/common/bin
prebuilt_build_tools_jars := prebuilts/build-tools/common/framework
prebuilt_build_tools_bin_noasan := $(prebuilt_build_tools)/$(HOST_PREBUILT_TAG)/bin
ifeq ($(filter address,$(SANITIZE_HOST)),)
prebuilt_build_tools_bin := $(prebuilt_build_tools_bin_noasan)
else
prebuilt_build_tools_bin := $(prebuilt_build_tools)/$(HOST_PREBUILT_TAG)/asan/bin
endif

USE_PREBUILT_SDK_TOOLS_IN_PLACE := true

# Work around for b/68406220
# This should match the soong version.
USE_D8 := true
.KATI_READONLY := USE_D8

#
# Tools that are prebuilts for TARGET_BUILD_USE_PREBUILT_SDKS
#
ifeq (,$(TARGET_BUILD_USE_PREBUILT_SDKS))
  AAPT := $(HOST_OUT_EXECUTABLES)/aapt
else # TARGET_BUILD_USE_PREBUILT_SDKS
  AAPT := $(prebuilt_sdk_tools_bin)/aapt
endif # TARGET_BUILD_USE_PREBUILT_SDKS

ifeq (,$(TARGET_BUILD_USE_PREBUILT_SDKS))
  # Use RenderScript prebuilts for unbundled builds
  LLVM_RS_CC := $(HOST_OUT_EXECUTABLES)/llvm-rs-cc
  BCC_COMPAT := $(HOST_OUT_EXECUTABLES)/bcc_compat
else
  LLVM_RS_CC := $(prebuilt_sdk_tools_bin)/llvm-rs-cc
  BCC_COMPAT := $(prebuilt_sdk_tools_bin)/bcc_compat
endif

prebuilt_sdk_tools :=
prebuilt_sdk_tools_bin :=

ACP := $(prebuilt_build_tools_bin)/acp
CKATI := $(prebuilt_build_tools_bin)/ckati
DEPMOD := $(HOST_OUT_EXECUTABLES)/depmod
FILESLIST := $(HOST_OUT_EXECUTABLES)/fileslist
FILESLIST_UTIL :=$= build/make/tools/fileslist_util.py
HOST_INIT_VERIFIER := $(HOST_OUT_EXECUTABLES)/host_init_verifier
XMLLINT := $(HOST_OUT_EXECUTABLES)/xmllint
ACONFIG := $(HOST_OUT_EXECUTABLES)/aconfig

# SOONG_ZIP is exported by Soong, but needs to be defined early for
# $OUT/dexpreopt.global.  It will be verified against the Soong version.
SOONG_ZIP := $(HOST_OUT_EXECUTABLES)/soong_zip

# ---------------------------------------------------------------
# Generic tools.

# These dependencies are now handled via dependencies on prebuilt_build_tool
BISON_DATA :=$=

YASM := prebuilts/misc/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/yasm/yasm

DOXYGEN:= doxygen
ifeq ($(HOST_OS),linux)
BREAKPAD_DUMP_SYMS := $(HOST_OUT_EXECUTABLES)/dump_syms
else
# For non-supported hosts, do not generate breakpad symbols.
BREAKPAD_GENERATE_SYMBOLS := false
endif
GZIP := prebuilts/build-tools/path/$(BUILD_OS)-$(HOST_PREBUILT_ARCH)/gzip
PROTOC := $(HOST_OUT_EXECUTABLES)/aprotoc$(HOST_EXECUTABLE_SUFFIX)
NANOPB_SRCS := $(HOST_OUT_EXECUTABLES)/protoc-gen-nanopb
MKBOOTFS := $(HOST_OUT_EXECUTABLES)/mkbootfs$(HOST_EXECUTABLE_SUFFIX)
MINIGZIP := $(GZIP)
LZ4 := $(HOST_OUT_EXECUTABLES)/lz4$(HOST_EXECUTABLE_SUFFIX)
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
APICHECK := $(HOST_OUT_JAVA_LIBRARIES)/metalava$(COMMON_JAVA_PACKAGE_SUFFIX)
FS_GET_STATS := $(HOST_OUT_EXECUTABLES)/fs_get_stats$(HOST_EXECUTABLE_SUFFIX)
MKEXTUSERIMG := $(HOST_OUT_EXECUTABLES)/mkuserimg_mke2fs
MKE2FS_CONF := system/extras/ext4_utils/mke2fs.conf
MKEROFS := $(HOST_OUT_EXECUTABLES)/mkfs.erofs
MKSQUASHFSUSERIMG := $(HOST_OUT_EXECUTABLES)/mksquashfsimage
MKF2FSUSERIMG := $(HOST_OUT_EXECUTABLES)/mkf2fsuserimg
SIMG2IMG := $(HOST_OUT_EXECUTABLES)/simg2img$(HOST_EXECUTABLE_SUFFIX)
E2FSCK := $(HOST_OUT_EXECUTABLES)/e2fsck$(HOST_EXECUTABLE_SUFFIX)
TUNE2FS := $(HOST_OUT_EXECUTABLES)/tune2fs$(HOST_EXECUTABLE_SUFFIX)
JARJAR := $(HOST_OUT_JAVA_LIBRARIES)/jarjar.jar
DATA_BINDING_COMPILER := $(HOST_OUT_JAVA_LIBRARIES)/databinding-compiler.jar
FAT16COPY := build/make/tools/fat16copy.py
CHECK_ELF_FILE := $(HOST_OUT_EXECUTABLES)/check_elf_file$(HOST_EXECUTABLE_SUFFIX)
LPMAKE := $(HOST_OUT_EXECUTABLES)/lpmake$(HOST_EXECUTABLE_SUFFIX)
ADD_IMG_TO_TARGET_FILES := $(HOST_OUT_EXECUTABLES)/add_img_to_target_files$(HOST_EXECUTABLE_SUFFIX)
BUILD_IMAGE := $(HOST_OUT_EXECUTABLES)/build_image$(HOST_EXECUTABLE_SUFFIX)
ifeq (,$(strip $(BOARD_CUSTOM_BUILD_SUPER_IMAGE)))
BUILD_SUPER_IMAGE := $(HOST_OUT_EXECUTABLES)/build_super_image$(HOST_EXECUTABLE_SUFFIX)
else
BUILD_SUPER_IMAGE := $(BOARD_CUSTOM_BUILD_SUPER_IMAGE)
endif
IMG_FROM_TARGET_FILES := $(HOST_OUT_EXECUTABLES)/img_from_target_files$(HOST_EXECUTABLE_SUFFIX)
UNPACK_BOOTIMG := $(HOST_OUT_EXECUTABLES)/unpack_bootimg
MAKE_RECOVERY_PATCH := $(HOST_OUT_EXECUTABLES)/make_recovery_patch$(HOST_EXECUTABLE_SUFFIX)
OTA_FROM_TARGET_FILES := $(HOST_OUT_EXECUTABLES)/ota_from_target_files$(HOST_EXECUTABLE_SUFFIX)
OTA_FROM_RAW_IMG := $(HOST_OUT_EXECUTABLES)/ota_from_raw_img$(HOST_EXECUTABLE_SUFFIX)
SPARSE_IMG := $(HOST_OUT_EXECUTABLES)/sparse_img$(HOST_EXECUTABLE_SUFFIX)
CHECK_PARTITION_SIZES := $(HOST_OUT_EXECUTABLES)/check_partition_sizes$(HOST_EXECUTABLE_SUFFIX)
SYMBOLS_MAP := $(HOST_OUT_EXECUTABLES)/symbols_map

PROGUARD_HOME := external/proguard
PROGUARD := $(PROGUARD_HOME)/bin/proguard.sh
PROGUARD_DEPS := $(PROGUARD) $(PROGUARD_HOME)/lib/proguard.jar
JAVATAGS := build/make/tools/java-event-log-tags.py
MERGETAGS := build/make/tools/merge-event-log-tags.py
APPEND2SIMG := $(HOST_OUT_EXECUTABLES)/append2simg
VERITY_SIGNER := $(HOST_OUT_EXECUTABLES)/verity_signer
BUILD_VERITY_METADATA := $(HOST_OUT_EXECUTABLES)/build_verity_metadata
BUILD_VERITY_TREE := $(HOST_OUT_EXECUTABLES)/build_verity_tree
FUTILITY := $(HOST_OUT_EXECUTABLES)/futility-host
VBOOT_SIGNER := $(HOST_OUT_EXECUTABLES)/vboot_signer

DEXDUMP := $(HOST_OUT_EXECUTABLES)/dexdump$(BUILD_EXECUTABLE_SUFFIX)
PROFMAN := $(HOST_OUT_EXECUTABLES)/profman

GEN_SBOM := $(HOST_OUT_EXECUTABLES)/generate-sbom

FINDBUGS_DIR := external/owasp/sanitizer/tools/findbugs/bin
FINDBUGS := $(FINDBUGS_DIR)/findbugs

JETIFIER := prebuilts/sdk/tools/jetifier/jetifier-standalone/bin/jetifier-standalone

EXTRACT_KERNEL := build/make/tools/extract_kernel.py

# Path to tools.jar
HOST_JDK_TOOLS_JAR := $(ANDROID_JAVA8_HOME)/lib/tools.jar

APICHECK_COMMAND := $(JAVA) -Xmx4g -jar $(APICHECK)

# Boolean variable determining if the allow list for compatible properties is enabled
PRODUCT_COMPATIBLE_PROPERTY := true
ifeq ($(PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE),false)
  $(error PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE is obsolete)
endif

.KATI_READONLY := \
    PRODUCT_COMPATIBLE_PROPERTY

# Boolean variable determining if Treble is fully enabled
PRODUCT_FULL_TREBLE := false
ifneq ($(PRODUCT_FULL_TREBLE_OVERRIDE),)
  PRODUCT_FULL_TREBLE := $(PRODUCT_FULL_TREBLE_OVERRIDE)
else ifeq ($(PRODUCT_SHIPPING_API_LEVEL),)
  #$(warning no product shipping level defined)
else ifneq ($(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),26),)
  PRODUCT_FULL_TREBLE := true
endif

# TODO(b/69865032): Make PRODUCT_NOTICE_SPLIT the default behavior and remove
#    references to it here and below.
ifdef PRODUCT_NOTICE_SPLIT_OVERRIDE
   $(error PRODUCT_NOTICE_SPLIT_OVERRIDE cannot be set.)
endif

requirements := \
    PRODUCT_TREBLE_LINKER_NAMESPACES \
    PRODUCT_ENFORCE_VINTF_MANIFEST \
    PRODUCT_NOTICE_SPLIT

# If it is overriden, then the requirement override is taken, otherwise it's
# PRODUCT_FULL_TREBLE
$(foreach req,$(requirements),$(eval \
    $(req) := $(if $($(req)_OVERRIDE),$($(req)_OVERRIDE),$(PRODUCT_FULL_TREBLE))))
# If the requirement is false for any reason, then it's not PRODUCT_FULL_TREBLE
$(foreach req,$(requirements),$(eval \
    PRODUCT_FULL_TREBLE := $(if $(filter false,$($(req))),false,$(PRODUCT_FULL_TREBLE))))

PRODUCT_FULL_TREBLE_OVERRIDE ?=
$(foreach req,$(requirements),$(eval $(req)_OVERRIDE ?=))

# TODO(b/114488870): disallow PRODUCT_FULL_TREBLE_OVERRIDE from being used.
.KATI_READONLY := \
    PRODUCT_FULL_TREBLE_OVERRIDE \
    $(foreach req,$(requirements),$(req)_OVERRIDE) \
    $(requirements) \
    PRODUCT_FULL_TREBLE \

$(KATI_obsolete_var $(foreach req,$(requirements),$(req)_OVERRIDE) \
    ,This should be referenced without the _OVERRIDE suffix.)

requirements :=

# Set default value of KEEP_VNDK.
ifeq ($(RELEASE_DEPRECATE_VNDK),true)
  KEEP_VNDK ?= false
else
  KEEP_VNDK ?= true
endif

# BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED can be true only if early-mount of
# partitions is supported. But the early-mount must be supported for full
# treble products, and so BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED should be set
# by default for full treble products.
ifeq ($(PRODUCT_FULL_TREBLE),true)
  BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED ?= true
endif

# Set BOARD_SYSTEMSDK_VERSIONS to the latest SystemSDK version starting from P-launching
# devices if unset.
ifndef BOARD_SYSTEMSDK_VERSIONS
  ifdef PRODUCT_SHIPPING_API_LEVEL
  ifneq ($(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),28),)
    ifeq (REL,$(PLATFORM_VERSION_CODENAME))
      BOARD_SYSTEMSDK_VERSIONS := $(PLATFORM_SDK_VERSION)
    else
      BOARD_SYSTEMSDK_VERSIONS := $(PLATFORM_VERSION_CODENAME)
    endif
  endif
  endif
endif

ifndef BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES
  BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES := current
else
  ifdef PRODUCT_SHIPPING_API_LEVEL
    ifneq ($(call math_lt,$(BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES),$(PRODUCT_SHIPPING_API_LEVEL)),)
      $(error BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES ($(BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES)) must be greater than or equal to PRODUCT_SHIPPING_API_LEVEL ($(PRODUCT_SHIPPING_API_LEVEL)))
    endif
  endif
endif
.KATI_READONLY := BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES

ifdef PRODUCT_SHIPPING_API_LEVEL
  board_api_level := $(firstword $(BOARD_API_LEVEL) $(BOARD_SHIPPING_API_LEVEL))
  ifneq (,$(board_api_level))
    min_systemsdk_version := $(call math_min,$(board_api_level),$(PRODUCT_SHIPPING_API_LEVEL))
  else
    min_systemsdk_version := $(PRODUCT_SHIPPING_API_LEVEL)
  endif
  ifneq ($(call numbers_less_than,$(min_systemsdk_version),$(BOARD_SYSTEMSDK_VERSIONS)),)
    $(error BOARD_SYSTEMSDK_VERSIONS ($(BOARD_SYSTEMSDK_VERSIONS)) must all be greater than or equal to BOARD_API_LEVEL, BOARD_SHIPPING_API_LEVEL or PRODUCT_SHIPPING_API_LEVEL ($(min_systemsdk_version)))
  endif
  ifneq ($(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),29),)
    ifneq ($(BOARD_OTA_FRAMEWORK_VBMETA_VERSION_OVERRIDE),)
      $(error When PRODUCT_SHIPPING_API_LEVEL >= 29, BOARD_OTA_FRAMEWORK_VBMETA_VERSION_OVERRIDE cannot be set)
    endif
  endif
endif

# The default key if not set as LOCAL_CERTIFICATE
ifdef PRODUCT_DEFAULT_DEV_CERTIFICATE
  DEFAULT_SYSTEM_DEV_CERTIFICATE := $(PRODUCT_DEFAULT_DEV_CERTIFICATE)
else
  DEFAULT_SYSTEM_DEV_CERTIFICATE := build/make/target/product/security/testkey
endif
.KATI_READONLY := DEFAULT_SYSTEM_DEV_CERTIFICATE

# Certificate for the NetworkStack sepolicy context
ifdef PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES
  MAINLINE_SEPOLICY_DEV_CERTIFICATES := $(PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES)
else
  MAINLINE_SEPOLICY_DEV_CERTIFICATES := $(dir $(DEFAULT_SYSTEM_DEV_CERTIFICATE))
endif
.KATI_READONLY := MAINLINE_SEPOLICY_DEV_CERTIFICATES

BUILD_NUMBER_FROM_FILE := $$(cat $(SOONG_OUT_DIR)/build_number.txt)
BUILD_HOSTNAME_FROM_FILE := $$(cat $(SOONG_OUT_DIR)/build_hostname.txt)
BUILD_DATETIME_FROM_FILE := $$(cat $(BUILD_DATETIME_FILE))

# SEPolicy versions

# PLATFORM_SEPOLICY_VERSION is a number of the form "NN.m" with "NN" mapping to
# PLATFORM_SDK_VERSION and "m" as a minor number which allows for SELinux
# changes independent of PLATFORM_SDK_VERSION.  This value will be set to
# 10000.0 to represent tip-of-tree development that is inherently unstable and
# thus designed not to work with any shipping vendor policy.  This is similar in
# spirit to how DEFAULT_APP_TARGET_SDK is set.
# The minor version ('m' component) must be updated every time a platform release
# is made which breaks compatibility with the previous platform sepolicy version,
# not just on every increase in PLATFORM_SDK_VERSION.  The minor version should
# be reset to 0 on every bump of the PLATFORM_SDK_VERSION.
sepolicy_major_vers := 34
sepolicy_minor_vers := 0

ifneq ($(sepolicy_major_vers), $(PLATFORM_SDK_VERSION))
$(error sepolicy_major_version does not match PLATFORM_SDK_VERSION, please update.)
endif

TOT_SEPOLICY_VERSION := 10000.0
ifneq (REL,$(PLATFORM_VERSION_CODENAME))
    PLATFORM_SEPOLICY_VERSION := $(TOT_SEPOLICY_VERSION)
else
    PLATFORM_SEPOLICY_VERSION := $(join $(addsuffix .,$(sepolicy_major_vers)), $(sepolicy_minor_vers))
endif
sepolicy_major_vers :=
sepolicy_minor_vers :=

# BOARD_SEPOLICY_VERS must take the format "NN.m" and contain the sepolicy
# version identifier corresponding to the sepolicy on which the non-platform
# policy is to be based. If unspecified, this will build against the current
# public platform policy in tree
ifndef BOARD_SEPOLICY_VERS
# The default platform policy version.
BOARD_SEPOLICY_VERS := $(PLATFORM_SEPOLICY_VERSION)
endif

# A list of SEPolicy versions, besides PLATFORM_SEPOLICY_VERSION, that the framework supports.
PLATFORM_SEPOLICY_COMPAT_VERSIONS := $(filter-out $(PLATFORM_SEPOLICY_VERSION), \
    29.0 \
    30.0 \
    31.0 \
    32.0 \
    33.0 \
    34.0 \
    )

.KATI_READONLY := \
    PLATFORM_SEPOLICY_COMPAT_VERSIONS \
    PLATFORM_SEPOLICY_VERSION \
    TOT_SEPOLICY_VERSION \

ifeq ($(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS),true)
  ifneq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
    $(error PRODUCT_USE_DYNAMIC_PARTITIONS must be true when PRODUCT_RETROFIT_DYNAMIC_PARTITIONS \
        is set)
  endif
  ifdef PRODUCT_SHIPPING_API_LEVEL
    ifeq (true,$(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),29))
      $(error Devices with shipping API level $(PRODUCT_SHIPPING_API_LEVEL) must not set \
          PRODUCT_RETROFIT_DYNAMIC_PARTITIONS)
    endif
  endif
endif

ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
    ifneq ($(PRODUCT_USE_DYNAMIC_PARTITION_SIZE),true)
        $(error PRODUCT_USE_DYNAMIC_PARTITION_SIZE must be true for devices with dynamic partitions)
    endif
endif

ifeq ($(PRODUCT_BUILD_SUPER_PARTITION),true)
    ifneq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
        $(error Can only build super partition for devices with dynamic partitions)
    endif
endif


ifeq ($(PRODUCT_USE_DYNAMIC_PARTITION_SIZE),true)

ifneq ($(BOARD_SYSTEMIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_SYSTEMIMAGE_PARTITION_SIZE and \
    BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_VENDORIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_VENDORIMAGE_PARTITION_SIZE and \
    BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_ODMIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_ODMIMAGE_PARTITION_SIZE and \
    BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_VENDOR_DLKMIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE and \
    BOARD_VENDOR_DLKMIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_ODM_DLKMIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_ODM_DLKMIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_ODM_DLKMIMAGE_PARTITION_SIZE and \
    BOARD_ODM_DLKMIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_SYSTEM_DLKMIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE and \
    BOARD_SYSTEM_DLKMIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_PRODUCTIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_PRODUCTIMAGE_PARTITION_SIZE and \
    BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

ifneq ($(BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE),)
ifneq ($(BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE),)
$(error Should not define BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE and \
    BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE together)
endif
endif

endif # PRODUCT_USE_DYNAMIC_PARTITION_SIZE

ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)

# BOARD_SUPER_PARTITION_GROUPS defines a list of "updatable groups". Each updatable group is a
# group of partitions that share the same pool of free spaces.
# For each group in BOARD_SUPER_PARTITION_GROUPS, a BOARD_{GROUP}_SIZE and
# BOARD_{GROUP}_PARTITION_PARTITION_LIST may be defined.
#     - BOARD_{GROUP}_SIZE: The maximum sum of sizes of all partitions in the group.
#       Must not be empty.
#     - BOARD_{GROUP}_PARTITION_PARTITION_LIST: the list of partitions that belongs to this group.
#       If empty, no partitions belong to this group, and the sum of sizes is effectively 0.
$(foreach group,$(call to-upper,$(BOARD_SUPER_PARTITION_GROUPS)), \
    $(eval BOARD_$(group)_SIZE := $(strip $(BOARD_$(group)_SIZE))) \
    $(if $(BOARD_$(group)_SIZE),,$(error BOARD_$(group)_SIZE must not be empty)) \
    $(eval .KATI_READONLY := BOARD_$(group)_SIZE) \
    $(eval BOARD_$(group)_PARTITION_LIST ?=) \
    $(eval .KATI_READONLY := BOARD_$(group)_PARTITION_LIST) \
)

# Define BOARD_SUPER_PARTITION_PARTITION_LIST, the sum of all BOARD_*_PARTITION_LIST
ifdef BOARD_SUPER_PARTITION_PARTITION_LIST
$(error BOARD_SUPER_PARTITION_PARTITION_LIST should not be defined, but computed from \
    BOARD_SUPER_PARTITION_GROUPS and BOARD_*_PARTITION_LIST)
endif
BOARD_SUPER_PARTITION_PARTITION_LIST := \
    $(foreach group,$(call to-upper,$(BOARD_SUPER_PARTITION_GROUPS)),$(BOARD_$(group)_PARTITION_LIST))
.KATI_READONLY := BOARD_SUPER_PARTITION_PARTITION_LIST

ifneq ($(BOARD_SUPER_PARTITION_SIZE),)
ifeq ($(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS),true)

# The metadata device must be specified manually for retrofitting.
ifeq ($(BOARD_SUPER_PARTITION_METADATA_DEVICE),)
$(error Must specify BOARD_SUPER_PARTITION_METADATA_DEVICE if PRODUCT_RETROFIT_DYNAMIC_PARTITIONS=true.)
endif

# The super partition block device list must be specified manually for retrofitting.
ifeq ($(BOARD_SUPER_PARTITION_BLOCK_DEVICES),)
$(error Must specify BOARD_SUPER_PARTITION_BLOCK_DEVICES if PRODUCT_RETROFIT_DYNAMIC_PARTITIONS=true.)
endif

# The metadata device must be included in the super partition block device list.
ifeq (,$(filter $(BOARD_SUPER_PARTITION_METADATA_DEVICE),$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)))
$(error BOARD_SUPER_PARTITION_METADATA_DEVICE is not listed in BOARD_SUPER_PARTITION_BLOCK_DEVICES.)
endif

# The metadata device must be supplied to init via the kernel command-line.
INTERNAL_KERNEL_CMDLINE += androidboot.super_partition=$(BOARD_SUPER_PARTITION_METADATA_DEVICE)

BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE := true

# If "vendor" is listed as one of the dynamic partitions but without its image available (e.g. an
# AOSP target built without vendor image), don't build the retrofit full OTA package. Because we
# won't be able to build meaningful super_* images for retrofitting purpose.
ifneq (,$(filter vendor,$(BOARD_SUPER_PARTITION_PARTITION_LIST)))
ifndef BUILDING_VENDOR_IMAGE
ifndef BOARD_PREBUILT_VENDORIMAGE
BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE :=
endif # BOARD_PREBUILT_VENDORIMAGE
endif # BUILDING_VENDOR_IMAGE
endif # BOARD_SUPER_PARTITION_PARTITION_LIST

else # PRODUCT_RETROFIT_DYNAMIC_PARTITIONS

# For normal devices, we populate BOARD_SUPER_PARTITION_BLOCK_DEVICES so the
# build can handle both cases consistently.
ifeq ($(BOARD_SUPER_PARTITION_METADATA_DEVICE),)
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
endif

ifeq ($(BOARD_SUPER_PARTITION_BLOCK_DEVICES),)
BOARD_SUPER_PARTITION_BLOCK_DEVICES := $(BOARD_SUPER_PARTITION_METADATA_DEVICE)
endif

# If only one super block device, default to super partition size.
ifeq ($(word 2,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)),)
BOARD_SUPER_PARTITION_$(call to-upper,$(strip $(BOARD_SUPER_PARTITION_BLOCK_DEVICES)))_DEVICE_SIZE ?= \
    $(BOARD_SUPER_PARTITION_SIZE)
endif

ifneq ($(BOARD_SUPER_PARTITION_METADATA_DEVICE),super)
INTERNAL_KERNEL_CMDLINE += androidboot.super_partition=$(BOARD_SUPER_PARTITION_METADATA_DEVICE)
endif
BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE :=

endif # PRODUCT_RETROFIT_DYNAMIC_PARTITIONS
endif # BOARD_SUPER_PARTITION_SIZE
BOARD_SUPER_PARTITION_BLOCK_DEVICES ?=
.KATI_READONLY := BOARD_SUPER_PARTITION_BLOCK_DEVICES
BOARD_SUPER_PARTITION_METADATA_DEVICE ?=
.KATI_READONLY := BOARD_SUPER_PARTITION_METADATA_DEVICE
BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE ?=
.KATI_READONLY := BOARD_BUILD_RETROFIT_DYNAMIC_PARTITIONS_OTA_PACKAGE

$(foreach device,$(call to-upper,$(BOARD_SUPER_PARTITION_BLOCK_DEVICES)), \
    $(eval BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE := $(strip $(BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE))) \
    $(if $(BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE),, \
        $(error BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE must not be empty)) \
    $(eval .KATI_READONLY := BOARD_SUPER_PARTITION_$(device)_DEVICE_SIZE))

endif # PRODUCT_USE_DYNAMIC_PARTITIONS

# By default, we build the hidden API csv files from source. You can use
# prebuilt hiddenapi files by setting BOARD_PREBUILT_HIDDENAPI_DIR to the name
# of a directory containing both prebuilt hiddenapi-flags.csv and
# hiddenapi-index.csv.
BOARD_PREBUILT_HIDDENAPI_DIR ?=
.KATI_READONLY := BOARD_PREBUILT_HIDDENAPI_DIR

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

# Flags for DEX2OAT
first_non_empty_of_three = $(if $(1),$(1),$(if $(2),$(2),$(3)))
DEX2OAT_TARGET_ARCH := $(TARGET_ARCH)
DEX2OAT_TARGET_CPU_VARIANT := $(call first_non_empty_of_three,$(TARGET_CPU_VARIANT),$(TARGET_ARCH_VARIANT),default)
DEX2OAT_TARGET_CPU_VARIANT_RUNTIME := $(call first_non_empty_of_three,$(TARGET_CPU_VARIANT_RUNTIME),$(TARGET_ARCH_VARIANT),default)
DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := default

ifdef TARGET_2ND_ARCH
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH := $(TARGET_2ND_ARCH)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT := $(call first_non_empty_of_three,$(TARGET_2ND_CPU_VARIANT),$(TARGET_2ND_ARCH_VARIANT),default)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT_RUNTIME := $(call first_non_empty_of_three,$(TARGET_2ND_CPU_VARIANT_RUNTIME),$(TARGET_2ND_ARCH_VARIANT),default)
$(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES := default
endif

# ###############################################################
# Collect a list of the SDK versions that we could compile against
# For use with the LOCAL_SDK_VERSION variable for include $(BUILD_PACKAGE)
# ###############################################################

HISTORICAL_SDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/sdk
HISTORICAL_NDK_VERSIONS_ROOT := $(TOPDIR)prebuilts/ndk

# The path where app can reference the support library resources.
ifdef TARGET_BUILD_USE_PREBUILT_SDKS
SUPPORT_LIBRARY_ROOT := $(HISTORICAL_SDK_VERSIONS_ROOT)/current/support
else
SUPPORT_LIBRARY_ROOT := frameworks/support
endif

get-sdk-version = $(if $(findstring _,$(1)),$(subst core_,,$(subst system_,,$(subst test_,,$(1)))),$(1))
get-sdk-api = $(if $(findstring _,$(1)),$(patsubst %_$(call get-sdk-version,$(1)),%,$(1)),public)
get-prebuilt-sdk-dir = $(HISTORICAL_SDK_VERSIONS_ROOT)/$(call get-sdk-version,$(1))/$(call get-sdk-api,$(1))

# Resolve LOCAL_SDK_VERSION to prebuilt module name, e.g.:
# 23 -> sdk_public_23_android
# system_current -> sdk_system_current_android
# $(1): An sdk version (LOCAL_SDK_VERSION)
# $(2): optional library name (default: android)
define resolve-prebuilt-sdk-module
$(if $(findstring _,$(1)),\
  sdk_$(1)_$(or $(2),android),\
  sdk_public_$(1)_$(or $(2),android))
endef

# Resolve LOCAL_SDK_VERSION to prebuilt android.jar
# $(1): LOCAL_SDK_VERSION
resolve-prebuilt-sdk-jar-path = $(call get-prebuilt-sdk-dir,$(1))/android.jar

# Resolve LOCAL_SDK_VERSION to prebuilt framework.aidl
# $(1): An sdk version (LOCAL_SDK_VERSION)
resolve-prebuilt-sdk-aidl-path = $(call get-prebuilt-sdk-dir,$(call get-sdk-version,$(1)))/framework.aidl

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

# This produces a list like "current/core current/public current/system 4/public"
TARGET_AVAILABLE_SDK_VERSIONS := $(wildcard $(HISTORICAL_SDK_VERSIONS_ROOT)/*/*/android.jar)
TARGET_AVAILABLE_SDK_VERSIONS := $(patsubst $(HISTORICAL_SDK_VERSIONS_ROOT)/%/android.jar,%,$(TARGET_AVAILABLE_SDK_VERSIONS))
# Strips and reorganizes the "public", "core", "system" and "test" subdirs.
TARGET_AVAILABLE_SDK_VERSIONS := $(subst /public,,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_AVAILABLE_SDK_VERSIONS := $(patsubst %/core,core_%,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_AVAILABLE_SDK_VERSIONS := $(patsubst %/system,system_%,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_AVAILABLE_SDK_VERSIONS := $(patsubst %/test,test_%,$(TARGET_AVAILABLE_SDK_VERSIONS))
# module-lib and system-server are not supported in Make.
TARGET_AVAILABLE_SDK_VERSIONS := $(filter-out %/module-lib %/system-server,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_AVAIALBLE_SDK_VERSIONS := $(call numerically_sort,$(TARGET_AVAILABLE_SDK_VERSIONS))

TARGET_SDK_VERSIONS_WITHOUT_JAVA_1_8_SUPPORT := $(call numbers_less_than,24,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_SDK_VERSIONS_WITHOUT_JAVA_1_9_SUPPORT := $(call numbers_less_than,30,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_SDK_VERSIONS_WITHOUT_JAVA_11_SUPPORT := $(call numbers_less_than,32,$(TARGET_AVAILABLE_SDK_VERSIONS))
TARGET_SDK_VERSIONS_WITHOUT_JAVA_17_SUPPORT := $(call numbers_less_than,34,$(TARGET_AVAILABLE_SDK_VERSIONS))

JAVA_LANGUAGE_VERSIONS_WITHOUT_SYSTEM_MODULES := 1.7 1.8

# This is the standard way to name a directory containing prebuilt target
# objects. E.g., prebuilt/$(TARGET_PREBUILT_TAG)/libc.so
TARGET_PREBUILT_TAG := android-$(TARGET_ARCH)
ifdef TARGET_2ND_ARCH
TARGET_2ND_PREBUILT_TAG := android-$(TARGET_2ND_ARCH)
endif

# Set up RS prebuilt variables for compatibility library

RS_PREBUILT_CLCORE := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/librsrt_$(TARGET_ARCH).bc
RS_PREBUILT_COMPILER_RT := prebuilts/sdk/renderscript/lib/$(TARGET_ARCH)/libcompiler_rt.a

# API Level lists for Renderscript Compat lib.
RSCOMPAT_32BIT_ONLY_API_LEVELS := 8 9 10 11 12 13 14 15 16 17 18 19 20
RSCOMPAT_NO_USAGEIO_API_LEVELS := 8 9 10 11 12 13

APPS_DEFAULT_VERSION_NAME := $(PLATFORM_VERSION)

# ANDROID_WARNING_ALLOWED_PROJECTS is generated by build/soong.
define find_warning_allowed_projects
    $(filter $(ANDROID_WARNING_ALLOWED_PROJECTS),$(1)/)
endef

GOMA_POOL :=
RBE_POOL :=
GOMA_OR_RBE_POOL :=
# When goma or RBE are enabled, kati will be passed --default_pool=local_pool to put
# most rules into the local pool.  Explicitly set the pool to "none" for rules that
# should be run outside the local pool, i.e. with -j500.
ifneq (,$(filter-out false,$(USE_GOMA)))
  GOMA_POOL := none
  GOMA_OR_RBE_POOL := none
else ifneq (,$(filter-out false,$(USE_RBE)))
  RBE_POOL := none
  GOMA_OR_RBE_POOL := none
endif
.KATI_READONLY := GOMA_POOL RBE_POOL GOMA_OR_RBE_POOL

JAVAC_NINJA_POOL :=
R8_NINJA_POOL :=
D8_NINJA_POOL :=

ifneq ($(filter-out false,$(USE_RBE)),)
  ifdef RBE_JAVAC
    JAVAC_NINJA_POOL := $(RBE_POOL)
  endif
  ifdef RBE_R8
    R8_NINJA_POOL := $(RBE_POOL)
  endif
  ifdef RBE_D8
    D8_NINJA_POOL := $(RBE_POOL)
  endif
endif

.KATI_READONLY := JAVAC_NINJA_POOL R8_NINJA_POOL D8_NINJA_POOL

# Soong modules that are known to have broken optional_uses_libs dependencies.
BUILD_WARNING_BAD_OPTIONAL_USES_LIBS_ALLOWLIST := LegacyCamera Gallery2

# These goals don't need to collect and include Android.mks/CleanSpec.mks
# in the source tree.
dont_bother_goals := out product-graph

# Make ANDROID Soong config variables visible to Android.mk files, for
# consistency with those defined in BoardConfig.mk files.
include $(BUILD_SYSTEM)/android_soong_config_vars.mk

ifeq ($(CALLED_FROM_SETUP),true)
include $(BUILD_SYSTEM)/ninja_config.mk
include $(BUILD_SYSTEM)/soong_config.mk
endif

-include external/ltp/android/ltp_package_list.mk
DEFAULT_DATA_OUT_MODULES := ltp $(ltp_packages)
.KATI_READONLY := DEFAULT_DATA_OUT_MODULES

include $(BUILD_SYSTEM)/dumpvar.mk

ifeq (true,$(FULL_SYSTEM_OPTIMIZE_JAVA))
ifeq (false,$(SYSTEM_OPTIMIZE_JAVA))
$(error SYSTEM_OPTIMIZE_JAVA must be enabled when FULL_SYSTEM_OPTIMIZE_JAVA is enabled)
endif
endif
