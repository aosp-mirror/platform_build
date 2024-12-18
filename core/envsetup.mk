# Variables we check:
#     HOST_BUILD_TYPE = { release debug }
#     TARGET_BUILD_TYPE = { release debug }
# and we output a bunch of variables, see the case statement at
# the bottom for the full list
#     OUT_DIR is also set to "out" if it's not already set.
#         this allows you to set it to somewhere else if you like
#     SCAN_EXCLUDE_DIRS is an optional, whitespace separated list of
#         directories that will also be excluded from full checkout tree
#         searches for source or make files, in addition to OUT_DIR.
#         This can be useful if you set OUT_DIR to be a different directory
#         than other outputs of your build system.

# Returns all words in $1 up to and including $2
define find_and_earlier
  $(strip $(if $(1),
    $(firstword $(1))
    $(if $(filter $(firstword $(1)),$(2)),,
      $(call find_and_earlier,$(wordlist 2,$(words $(1)),$(1)),$(2)))))
endef

#$(warning $(call find_and_earlier,A B C,A))
#$(warning $(call find_and_earlier,A B C,B))
#$(warning $(call find_and_earlier,A B C,C))
#$(warning $(call find_and_earlier,A B C,D))

# Runs a starlark file, and sets all the variables in its top-level
# variables_to_export_to_make variable as make variables.
#
# In order to avoid running starlark every time the stamp file is checked, we use
# $(KATI_shell_no_rerun). Then, to make sure that we actually do rerun kati when
# modifying the starlark files, we add the starlark files to the kati stamp file with
# $(KATI_extra_file_deps).
#
# Arguments:
#  $(1): A single starlark file to use as the entrypoint
#  $(2): An optional list of starlark files to NOT include as kati dependencies.
#  $(3): An optional list of extra flags to pass to rbcrun
define run-starlark
$(eval _starlark_results := $(OUT_DIR)/starlark_results/$(subst /,_,$(1)).mk)
$(KATI_shell_no_rerun mkdir -p $(OUT_DIR)/starlark_results && $(OUT_DIR)/rbcrun --mode=make $(3) $(1) >$(_starlark_results) && touch -t 200001010000 $(_starlark_results))
$(if $(filter-out 0,$(.SHELLSTATUS)),$(error Starlark failed to run))
$(eval include $(_starlark_results))
$(KATI_extra_file_deps $(filter-out $(2),$(LOADED_STARLARK_FILES)))
$(eval LOADED_STARLARK_FILES :=)
$(eval _starlark_results :=)
endef

# ---------------------------------------------------------------
# Release config
include $(BUILD_SYSTEM)/release_config.mk

# ---------------------------------------------------------------
# Set up version information
include $(BUILD_SYSTEM)/version_util.mk

# This used to be calculated, but is now fixed and not expected
# to change over time anymore. New code attempting to use a
# variable like IS_AT_LAST_* should instead use a
# build system flag.

ENABLED_VERSIONS := "OPR1 OPD1 OPD2 OPM1 OPM2 PPR1 PPD1 PPD2 PPM1 PPM2 QPR1 QP1A QP1B QP2A QP2B QD1A QD1B QD2A QD2B QQ1A QQ1B QQ2A QQ2B QQ3A QQ3B RP1A RP1B RP2A RP2B RD1A RD1B RD2A RD2B RQ1A RQ1B RQ2A RQ2B RQ3A RQ3B SP1A SP1B SP2A SP2B SD1A SD1B SD2A SD2B SQ1A SQ1B SQ2A SQ2B SQ3A SQ3B TP1A TP1B TP2A TP2B TD1A TD1B TD2A TD2B TQ1A TQ1B TQ2A TQ2B TQ3A TQ3B UP1A UP1B UP2A UP2B UD1A UD1B UD2A UD2B UQ1A UQ1B UQ2A UQ2B UQ3A UQ3B"

$(foreach v,$(ENABLED_VERSIONS), \
  $(eval IS_AT_LEAST_$(v) := true))

# ---------------------------------------------------------------
# If you update the build system such that the environment setup
# or buildspec.mk need to be updated, increment this number, and
# people who haven't re-run those will have to do so before they
# can build.  Make sure to also update the corresponding value in
# buildspec.mk.default and envsetup.sh.
CORRECT_BUILD_ENV_SEQUENCE_NUMBER := 13

# ---------------------------------------------------------------
# The product defaults to generic on hardware
ifeq ($(TARGET_PRODUCT),)
TARGET_PRODUCT := aosp_arm64
endif


# the variant -- the set of files that are included for a build
ifeq ($(strip $(TARGET_BUILD_VARIANT)),)
TARGET_BUILD_VARIANT := eng
endif

TARGET_BUILD_APPS ?=
TARGET_BUILD_UNBUNDLED_IMAGE ?=

# Set to true for an unbundled build, i.e. a build without
# support for platform targets like the system image. This also
# disables consistency checks that only apply to full platform
# builds.
TARGET_BUILD_UNBUNDLED ?=

# TARGET_BUILD_APPS implies unbundled build, otherwise we default
# to bundled (i.e. platform targets such as the system image are
# included).
ifneq ($(TARGET_BUILD_APPS),)
  TARGET_BUILD_UNBUNDLED := true
endif

# TARGET_BUILD_UNBUNDLED_IMAGE also implies unbundled build.
# (i.e. it targets to only unbundled image, such as the vendor image,
# ,or the product image). 
ifneq ($(TARGET_BUILD_UNBUNDLED_IMAGE),)
  TARGET_BUILD_UNBUNDLED := true
endif

.KATI_READONLY := \
  TARGET_PRODUCT \
  TARGET_BUILD_VARIANT \
  TARGET_BUILD_APPS \
  TARGET_BUILD_UNBUNDLED \
  TARGET_BUILD_UNBUNDLED_IMAGE \

# ---------------------------------------------------------------
# Set up configuration for host machine.  We don't do cross-
# compiles except for arm, so the HOST is whatever we are
# running on

# HOST_OS
ifneq (,$(findstring Linux,$(UNAME)))
  HOST_OS := linux
endif
ifneq (,$(findstring Darwin,$(UNAME)))
  HOST_OS := darwin
endif

ifeq ($(CALLED_FROM_SETUP),true)
  HOST_OS_EXTRA := $(shell uname -rsm)
  ifeq ($(HOST_OS),linux)
    ifneq ($(wildcard /etc/os-release),)
      HOST_OS_EXTRA += $(shell source /etc/os-release; echo $$PRETTY_NAME)
    endif
  else ifeq ($(HOST_OS),darwin)
    HOST_OS_EXTRA += $(shell sw_vers -productVersion)
  endif
  HOST_OS_EXTRA := $(subst $(space),-,$(HOST_OS_EXTRA))
endif

# BUILD_OS is the real host doing the build.
BUILD_OS := $(HOST_OS)

# We can do the cross-build only on Linux
ifeq ($(HOST_OS),linux)
  # Windows has been the default host_cross OS
  ifeq (,$(filter-out windows,$(HOST_CROSS_OS)))
    # We can only create static host binaries for Linux, so if static host
    # binaries are requested, turn off Windows cross-builds.
    ifeq ($(BUILD_HOST_static),)
      HOST_CROSS_OS := windows
      HOST_CROSS_ARCH := x86
      HOST_CROSS_2ND_ARCH := x86_64
      2ND_HOST_CROSS_IS_64_BIT := true
    endif
  else ifeq ($(HOST_CROSS_OS),linux_bionic)
    ifeq (,$(HOST_CROSS_ARCH))
      $(error HOST_CROSS_ARCH missing.)
    endif
  else
    $(error Unsupported HOST_CROSS_OS $(HOST_CROSS_OS))
  endif
else ifeq ($(HOST_OS),darwin)
  HOST_CROSS_OS := darwin
  HOST_CROSS_ARCH := arm64
  HOST_CROSS_2ND_ARCH :=
endif

ifeq ($(HOST_OS),)
$(error Unable to determine HOST_OS from uname -sm: $(UNAME)!)
endif

# HOST_ARCH
ifneq (,$(findstring x86_64,$(UNAME)))
  HOST_ARCH := x86_64
  HOST_2ND_ARCH := x86
  HOST_IS_64_BIT := true
else
ifneq (,$(findstring i686,$(UNAME))$(findstring x86,$(UNAME)))
$(error Building on a 32-bit x86 host is not supported: $(UNAME)!)
endif
endif

ifeq ($(HOST_OS),darwin)
  # Mac no longer supports 32-bit executables
  HOST_2ND_ARCH :=
endif

HOST_2ND_ARCH_VAR_PREFIX := 2ND_
HOST_2ND_ARCH_MODULE_SUFFIX := _32
HOST_CROSS_2ND_ARCH_VAR_PREFIX := 2ND_
HOST_CROSS_2ND_ARCH_MODULE_SUFFIX := _64
TARGET_2ND_ARCH_VAR_PREFIX := 2ND_
.KATI_READONLY := \
  HOST_ARCH \
  HOST_2ND_ARCH \
  HOST_IS_64_BIT \
  HOST_2ND_ARCH_VAR_PREFIX \
  HOST_2ND_ARCH_MODULE_SUFFIX \
  HOST_CROSS_2ND_ARCH_VAR_PREFIX \
  HOST_CROSS_2ND_ARCH_MODULE_SUFFIX \
  TARGET_2ND_ARCH_VAR_PREFIX \

combo_target := HOST_
combo_2nd_arch_prefix :=
include $(BUILD_COMBOS)/select.mk

ifdef HOST_2ND_ARCH
  combo_2nd_arch_prefix := $(HOST_2ND_ARCH_VAR_PREFIX)
  include $(BUILD_SYSTEM)/combo/select.mk
endif

# Load the windows cross compiler under Linux
ifdef HOST_CROSS_OS
  combo_target := HOST_CROSS_
  combo_2nd_arch_prefix :=
  include $(BUILD_SYSTEM)/combo/select.mk

  ifdef HOST_CROSS_2ND_ARCH
    combo_2nd_arch_prefix := $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)
    include $(BUILD_SYSTEM)/combo/select.mk
  endif
endif

# on windows, the tools have .exe at the end, and we depend on the
# host config stuff being done first

BUILD_ARCH := $(HOST_ARCH)
BUILD_2ND_ARCH := $(HOST_2ND_ARCH)

ifeq ($(HOST_ARCH),)
$(error Unable to determine HOST_ARCH from uname -sm: $(UNAME)!)
endif

# the host build defaults to release, and it must be release or debug
ifeq ($(HOST_BUILD_TYPE),)
HOST_BUILD_TYPE := release
endif

ifneq ($(HOST_BUILD_TYPE),release)
ifneq ($(HOST_BUILD_TYPE),debug)
$(error HOST_BUILD_TYPE must be either release or debug, not '$(HOST_BUILD_TYPE)')
endif
endif

# We don't want to move all the prebuilt host tools to a $(HOST_OS)-x86_64 dir.
HOST_PREBUILT_ARCH := x86
# This is the standard way to name a directory containing prebuilt host
# objects. E.g., prebuilt/$(HOST_PREBUILT_TAG)/cc
# This must match the logic in get_host_prebuilt_prefix in envsetup.sh
HOST_PREBUILT_TAG := $(BUILD_OS)-$(HOST_PREBUILT_ARCH)

# TARGET_COPY_OUT_* are all relative to the staging directory, ie PRODUCT_OUT.
# Define them here so they can be used in product config files.
TARGET_COPY_OUT_SYSTEM := system
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
TARGET_COPY_OUT_SYSTEM_OTHER := system_other
TARGET_COPY_OUT_DATA := data
TARGET_COPY_OUT_ASAN := $(TARGET_COPY_OUT_DATA)/asan
TARGET_COPY_OUT_OEM := oem
TARGET_COPY_OUT_RAMDISK := ramdisk
TARGET_COPY_OUT_DEBUG_RAMDISK := debug_ramdisk
TARGET_COPY_OUT_VENDOR_DEBUG_RAMDISK := vendor_debug_ramdisk
TARGET_COPY_OUT_TEST_HARNESS_RAMDISK := test_harness_ramdisk
TARGET_COPY_OUT_ROOT := root
TARGET_COPY_OUT_RECOVERY := recovery
# The directory used for optional partitions depend on the BoardConfig, so
# they're defined to placeholder values here and swapped after reading the
# BoardConfig, to be either the partition dir, or a subdir within 'system'.
_vendor_path_placeholder := ||VENDOR-PATH-PH||
_product_path_placeholder := ||PRODUCT-PATH-PH||
_system_ext_path_placeholder := ||SYSTEM_EXT-PATH-PH||
_odm_path_placeholder := ||ODM-PATH-PH||
_vendor_dlkm_path_placeholder := ||VENDOR_DLKM-PATH-PH||
_odm_dlkm_path_placeholder := ||ODM_DLKM-PATH-PH||
_system_dlkm_path_placeholder := ||SYSTEM_DLKM-PATH-PH||
TARGET_COPY_OUT_VENDOR := $(_vendor_path_placeholder)
TARGET_COPY_OUT_VENDOR_RAMDISK := vendor_ramdisk
TARGET_COPY_OUT_VENDOR_KERNEL_RAMDISK := vendor_kernel_ramdisk
TARGET_COPY_OUT_PRODUCT := $(_product_path_placeholder)
# TODO(b/135957588) TARGET_COPY_OUT_PRODUCT_SERVICES will copy the target to
# product
TARGET_COPY_OUT_PRODUCT_SERVICES := $(_product_path_placeholder)
TARGET_COPY_OUT_SYSTEM_EXT := $(_system_ext_path_placeholder)
TARGET_COPY_OUT_ODM := $(_odm_path_placeholder)
TARGET_COPY_OUT_VENDOR_DLKM := $(_vendor_dlkm_path_placeholder)
TARGET_COPY_OUT_ODM_DLKM := $(_odm_dlkm_path_placeholder)
TARGET_COPY_OUT_SYSTEM_DLKM := $(_system_dlkm_path_placeholder)

# Returns the non-sanitized version of the path provided in $1.
define get_non_asan_path
$(patsubst $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/%,$(PRODUCT_OUT)/%,$1)
endef

#################################################################
# Set up minimal BOOTCLASSPATH list of jars to build/execute
# java code with dalvikvm/art.
# Jars present in the ART apex. These should match exactly the list of Java
# libraries in art-bootclasspath-fragment. The APEX variant name
# (com.android.art) is the same regardless which Soong module provides the ART
# APEX. See the long comment in build/soong/java/dexprepopt_bootjars.go for
# details.
ART_APEX_JARS := \
    com.android.art:core-oj \
    com.android.art:core-libart \
    com.android.art:okhttp \
    com.android.art:bouncycastle \
    com.android.art:apache-xml
# With EMMA_INSTRUMENT_FRAMEWORK=true the Core libraries depend on jacoco.
ifeq (true,$(EMMA_INSTRUMENT_FRAMEWORK))
  ART_APEX_JARS += com.android.art:jacocoagent
endif
#################################################################

# Dumps all variables that match [A-Z][A-Z0-9_]* (with a few exceptions)
# to the file at $(1). It is used to print only the variables that are
# likely to be relevant to the product or board configuration.
# Soong config variables are dumped as $(call soong_config_set) calls
# instead of the raw variable values, because mk2rbc can't read the
# raw ones. There is a final sed command on the output file to
# remove leading spaces because I couldn't figure out how to remove
# them in pure make code.
define dump-variables-rbc
$(eval _dump_variables_rbc_excluded := \
  BUILD_NUMBER \
  DATE \
  LOCAL_PATH \
  MAKEFILE_LIST \
  PRODUCTS \
  PRODUCT_COPY_OUT_% \
  RBC_PRODUCT_CONFIG \
  RBC_BOARD_CONFIG \
  SOONG_% \
  TARGET_RELEASE \
  TOPDIR \
  TRACE_BEGIN_SOONG \
  USER)
$(file >$(OUT_DIR)/dump-variables-rbc-temp.txt,$(subst $(space),$(newline),$(sort $(filter-out $(_dump_variables_rbc_excluded),$(.VARIABLES)))))
$(file >$(1),\
$(foreach v, $(shell grep -he "^[A-Z][A-Z0-9_]*$$" $(OUT_DIR)/dump-variables-rbc-temp.txt),\
$(v) := $(strip $($(v)))$(newline))\
$(foreach ns,$(sort $(SOONG_CONFIG_NAMESPACES)),\
$(foreach v,$(sort $(SOONG_CONFIG_$(ns))),\
$$(call soong_config_set,$(ns),$(v),$(SOONG_CONFIG_$(ns)_$(v)))$(newline))))
$(shell sed -i "s/^ *//g" $(1))
endef

# Read the product specs so we can get TARGET_DEVICE and other
# variables that we need in order to locate the output files.
include $(BUILD_SYSTEM)/product_config.mk

build_variant := $(filter-out eng user userdebug,$(TARGET_BUILD_VARIANT))
ifneq ($(build_variant)-$(words $(TARGET_BUILD_VARIANT)),-1)
$(warning bad TARGET_BUILD_VARIANT: $(TARGET_BUILD_VARIANT))
$(error must be empty or one of: eng user userdebug)
endif

SDK_HOST_ARCH := x86
TARGET_OS := linux

# Some board configuration files use $(PRODUCT_OUT)
TARGET_OUT_ROOT := $(OUT_DIR)/target
TARGET_PRODUCT_OUT_ROOT := $(TARGET_OUT_ROOT)/product
PRODUCT_OUT := $(TARGET_PRODUCT_OUT_ROOT)/$(TARGET_DEVICE)
.KATI_READONLY := TARGET_OUT_ROOT TARGET_PRODUCT_OUT_ROOT PRODUCT_OUT

include $(BUILD_SYSTEM)/board_config.mk

# the target build type defaults to release
ifneq ($(TARGET_BUILD_TYPE),debug)
TARGET_BUILD_TYPE := release
endif

include $(BUILD_SYSTEM)/product_validation_checks.mk

# ---------------------------------------------------------------
# figure out the output directories

SOONG_OUT_DIR := $(OUT_DIR)/soong

HOST_OUT_ROOT := $(OUT_DIR)/host

.KATI_READONLY := SOONG_OUT_DIR HOST_OUT_ROOT

# We want to avoid two host bin directories in multilib build.
HOST_OUT := $(HOST_OUT_ROOT)/$(HOST_OS)-$(HOST_PREBUILT_ARCH)

# Soong now installs to the same directory as Make.
SOONG_HOST_OUT := $(HOST_OUT)

HOST_CROSS_OUT := $(HOST_OUT_ROOT)/$(HOST_CROSS_OS)-$(HOST_CROSS_ARCH)

.KATI_READONLY := HOST_OUT SOONG_HOST_OUT HOST_CROSS_OUT

TARGET_COMMON_OUT_ROOT := $(TARGET_OUT_ROOT)/common
HOST_COMMON_OUT_ROOT := $(HOST_OUT_ROOT)/common

.KATI_READONLY := TARGET_COMMON_OUT_ROOT HOST_COMMON_OUT_ROOT

OUT_DOCS := $(TARGET_COMMON_OUT_ROOT)/docs
OUT_NDK_DOCS := $(TARGET_COMMON_OUT_ROOT)/ndk-docs
.KATI_READONLY := OUT_DOCS OUT_NDK_DOCS

$(call KATI_obsolete,BUILD_OUT,Use HOST_OUT instead)

BUILD_OUT_EXECUTABLES := $(HOST_OUT)/bin
SOONG_HOST_OUT_EXECUTABLES := $(SOONG_HOST_OUT)/bin
.KATI_READONLY := BUILD_OUT_EXECUTABLES SOONG_HOST_OUT_EXECUTABLES

HOST_OUT_EXECUTABLES := $(HOST_OUT)/bin
HOST_OUT_SHARED_LIBRARIES := $(HOST_OUT)/lib64
HOST_OUT_DYLIB_LIBRARIES := $(HOST_OUT)/lib64
HOST_OUT_RENDERSCRIPT_BITCODE := $(HOST_OUT_SHARED_LIBRARIES)
HOST_OUT_JAVA_LIBRARIES := $(HOST_OUT)/framework
HOST_OUT_SDK_ADDON := $(HOST_OUT)/sdk_addon
HOST_OUT_NATIVE_TESTS := $(HOST_OUT)/nativetest64
HOST_OUT_COVERAGE := $(HOST_OUT)/coverage
HOST_OUT_TESTCASES := $(HOST_OUT)/testcases
HOST_OUT_ETC := $(HOST_OUT)/etc
.KATI_READONLY := \
  HOST_OUT_EXECUTABLES \
  HOST_OUT_SHARED_LIBRARIES \
  HOST_OUT_RENDERSCRIPT_BITCODE \
  HOST_OUT_JAVA_LIBRARIES \
  HOST_OUT_SDK_ADDON \
  HOST_OUT_NATIVE_TESTS \
  HOST_OUT_COVERAGE \
  HOST_OUT_TESTCASES \
  HOST_OUT_ETC

HOST_CROSS_OUT_EXECUTABLES := $(HOST_CROSS_OUT)/bin
HOST_CROSS_OUT_SHARED_LIBRARIES := $(HOST_CROSS_OUT)/lib
HOST_CROSS_OUT_NATIVE_TESTS := $(HOST_CROSS_OUT)/nativetest
HOST_CROSS_OUT_COVERAGE := $(HOST_CROSS_OUT)/coverage
HOST_CROSS_OUT_TESTCASES := $(HOST_CROSS_OUT)/testcases
.KATI_READONLY := \
  HOST_CROSS_OUT_EXECUTABLES \
  HOST_CROSS_OUT_SHARED_LIBRARIES \
  HOST_CROSS_OUT_NATIVE_TESTS \
  HOST_CROSS_OUT_COVERAGE \
  HOST_CROSS_OUT_TESTCASES

HOST_OUT_INTERMEDIATES := $(HOST_OUT)/obj
HOST_OUT_NOTICE_FILES := $(HOST_OUT_INTERMEDIATES)/NOTICE_FILES
HOST_OUT_COMMON_INTERMEDIATES := $(HOST_COMMON_OUT_ROOT)/obj
HOST_OUT_FAKE := $(HOST_OUT)/fake_packages
.KATI_READONLY := \
  HOST_OUT_INTERMEDIATES \
  HOST_OUT_NOTICE_FILES \
  HOST_OUT_COMMON_INTERMEDIATES \
  HOST_OUT_FAKE

HOST_CROSS_OUT_INTERMEDIATES := $(HOST_CROSS_OUT)/obj
HOST_CROSS_OUT_NOTICE_FILES := $(HOST_CROSS_OUT_INTERMEDIATES)/NOTICE_FILES
.KATI_READONLY := \
  HOST_CROSS_OUT_INTERMEDIATES \
  HOST_CROSS_OUT_NOTICE_FILES

HOST_OUT_GEN := $(HOST_OUT)/gen
HOST_OUT_COMMON_GEN := $(HOST_COMMON_OUT_ROOT)/gen
.KATI_READONLY := \
  HOST_OUT_GEN \
  HOST_OUT_COMMON_GEN

HOST_CROSS_OUT_GEN := $(HOST_CROSS_OUT)/gen
.KATI_READONLY := HOST_CROSS_OUT_GEN

# Out for HOST_2ND_ARCH
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_INTERMEDIATES := $(HOST_OUT)/obj32
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES := $(HOST_OUT)/lib
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_EXECUTABLES := $(HOST_OUT_EXECUTABLES)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_JAVA_LIBRARIES := $(HOST_OUT_JAVA_LIBRARIES)
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_NATIVE_TESTS := $(HOST_OUT)/nativetest
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_TESTCASES := $(HOST_OUT_TESTCASES)
.KATI_READONLY := \
  $(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_INTERMEDIATES \
  $(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_SHARED_LIBRARIES \
  $(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_EXECUTABLES \
  $(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_JAVA_LIBRARIES \
  $(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_NATIVE_TESTS \
  $(HOST_2ND_ARCH_VAR_PREFIX)HOST_OUT_TESTCASES

# The default host library path.
# It always points to the path where we build libraries in the default bitness.
HOST_LIBRARY_PATH := $(HOST_OUT_SHARED_LIBRARIES)
.KATI_READONLY := HOST_LIBRARY_PATH

# Out for HOST_CROSS_2ND_ARCH
$(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_INTERMEDIATES := $(HOST_CROSS_OUT)/obj64
$(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_SHARED_LIBRARIES := $(HOST_CROSS_OUT)/lib64
$(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_EXECUTABLES := $(HOST_CROSS_OUT_EXECUTABLES)
$(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_NATIVE_TESTS := $(HOST_CROSS_OUT)/nativetest64
.KATI_READONLY := \
  $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_INTERMEDIATES \
  $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_SHARED_LIBRARIES \
  $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_EXECUTABLES \
  $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_OUT_NATIVE_TESTS

ifneq ($(filter address,$(SANITIZE_TARGET)),)
  TARGET_OUT_INTERMEDIATES := $(PRODUCT_OUT)/obj_asan
else
  TARGET_OUT_INTERMEDIATES := $(PRODUCT_OUT)/obj
endif
TARGET_OUT_HEADERS := $(TARGET_OUT_INTERMEDIATES)/include
.KATI_READONLY := TARGET_OUT_INTERMEDIATES TARGET_OUT_HEADERS

ifneq ($(filter address,$(SANITIZE_TARGET)),)
  TARGET_OUT_COMMON_INTERMEDIATES := $(TARGET_COMMON_OUT_ROOT)/obj_asan
else
  TARGET_OUT_COMMON_INTERMEDIATES := $(TARGET_COMMON_OUT_ROOT)/obj
endif
.KATI_READONLY := TARGET_OUT_COMMON_INTERMEDIATES

TARGET_OUT_GEN := $(PRODUCT_OUT)/gen
TARGET_OUT_COMMON_GEN := $(TARGET_COMMON_OUT_ROOT)/gen
.KATI_READONLY := TARGET_OUT_GEN TARGET_OUT_COMMON_GEN

TARGET_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_SYSTEM)
.KATI_READONLY := TARGET_OUT
ifneq ($(filter address,$(SANITIZE_TARGET)),)
target_out_shared_libraries_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/system
ifeq ($(SANITIZE_LITE),true)
# When using SANITIZE_LITE, APKs must not be packaged with sanitized libraries, as they will not
# work with unsanitized app_process. For simplicity, generate APKs into /data/asan/.
target_out_app_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/system
else
target_out_app_base := $(TARGET_OUT)
endif
else
target_out_shared_libraries_base := $(TARGET_OUT)
target_out_app_base := $(TARGET_OUT)
endif

TARGET_OUT_EXECUTABLES := $(TARGET_OUT)/bin
TARGET_OUT_OPTIONAL_EXECUTABLES := $(TARGET_OUT)/xbin
ifeq ($(TARGET_IS_64_BIT),true)
# /system/lib always contains 32-bit libraries,
# and /system/lib64 (if present) always contains 64-bit libraries.
TARGET_OUT_SHARED_LIBRARIES := $(target_out_shared_libraries_base)/lib64
else
TARGET_OUT_SHARED_LIBRARIES := $(target_out_shared_libraries_base)/lib
endif
TARGET_OUT_RENDERSCRIPT_BITCODE := $(TARGET_OUT_SHARED_LIBRARIES)
TARGET_OUT_JAVA_LIBRARIES := $(TARGET_OUT)/framework
TARGET_OUT_APPS := $(target_out_app_base)/app
TARGET_OUT_APPS_PRIVILEGED := $(target_out_app_base)/priv-app
TARGET_OUT_KEYLAYOUT := $(TARGET_OUT)/usr/keylayout
TARGET_OUT_KEYCHARS := $(TARGET_OUT)/usr/keychars
TARGET_OUT_ETC := $(TARGET_OUT)/etc
TARGET_OUT_NOTICE_FILES := $(TARGET_OUT_INTERMEDIATES)/NOTICE_FILES
TARGET_OUT_FAKE := $(PRODUCT_OUT)/fake_packages
TARGET_OUT_TESTCASES := $(PRODUCT_OUT)/testcases
TARGET_OUT_FLAGS := $(TARGET_OUT_INTERMEDIATES)/FLAGS

.KATI_READONLY := \
  TARGET_OUT_EXECUTABLES \
  TARGET_OUT_OPTIONAL_EXECUTABLES \
  TARGET_OUT_SHARED_LIBRARIES \
  TARGET_OUT_RENDERSCRIPT_BITCODE \
  TARGET_OUT_JAVA_LIBRARIES \
  TARGET_OUT_APPS \
  TARGET_OUT_APPS_PRIVILEGED \
  TARGET_OUT_KEYLAYOUT \
  TARGET_OUT_KEYCHARS \
  TARGET_OUT_ETC \
  TARGET_OUT_NOTICE_FILES \
  TARGET_OUT_FAKE \
  TARGET_OUT_TESTCASES \
  TARGET_OUT_FLAGS

ifeq ($(SANITIZE_LITE),true)
# When using SANITIZE_LITE, APKs must not be packaged with sanitized libraries, as they will not
# work with unsanitized app_process. For simplicity, generate APKs into /data/asan/.
TARGET_OUT_SYSTEM_OTHER := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_SYSTEM_OTHER)
else
TARGET_OUT_SYSTEM_OTHER := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_SYSTEM_OTHER)
endif
.KATI_READONLY := TARGET_OUT_SYSTEM_OTHER

# Out for TARGET_2ND_ARCH
TARGET_2ND_ARCH_MODULE_SUFFIX := $(HOST_2ND_ARCH_MODULE_SUFFIX)
.KATI_READONLY := TARGET_2ND_ARCH_MODULE_SUFFIX

ifneq ($(filter address,$(SANITIZE_TARGET)),)
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES := $(PRODUCT_OUT)/obj_$(TARGET_2ND_ARCH)_asan
else
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES := $(PRODUCT_OUT)/obj_$(TARGET_2ND_ARCH)
endif
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES := $(target_out_shared_libraries_base)/lib
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_RENDERSCRIPT_BITCODE := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_EXECUTABLES := $(TARGET_OUT_EXECUTABLES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_APPS := $(TARGET_OUT_APPS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_APPS_PRIVILEGED := $(TARGET_OUT_APPS_PRIVILEGED)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_TESTCASES := $(TARGET_OUT_TESTCASES)
.KATI_READONLY := \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_RENDERSCRIPT_BITCODE \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_EXECUTABLES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_APPS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_APPS_PRIVILEGED \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_TESTCASES

MODULE_CLASS_APPS := app
MODULE_CLASS_EXECUTABLES := bin
MODULE_CLASS_JAVA_LIBRARIES := framework
MODULE_CLASS_NATIVE_TESTS := nativetest
MODULE_CLASS_METRIC_TESTS := benchmarktest
TARGET_OUT_DATA := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_DATA)
TARGET_OUT_DATA_EXECUTABLES := $(TARGET_OUT_EXECUTABLES)
TARGET_OUT_DATA_SHARED_LIBRARIES := $(TARGET_OUT_SHARED_LIBRARIES)
TARGET_OUT_DATA_JAVA_LIBRARIES := $(TARGET_OUT_DATA)/framework
TARGET_OUT_DATA_APPS := $(TARGET_OUT_DATA)/app
TARGET_OUT_DATA_KEYLAYOUT := $(TARGET_OUT_KEYLAYOUT)
TARGET_OUT_DATA_KEYCHARS := $(TARGET_OUT_KEYCHARS)
TARGET_OUT_DATA_ETC := $(TARGET_OUT_ETC)
ifeq ($(TARGET_IS_64_BIT),true)
TARGET_OUT_DATA_NATIVE_TESTS := $(TARGET_OUT_DATA)/nativetest64
TARGET_OUT_DATA_METRIC_TESTS := $(TARGET_OUT_DATA)/benchmarktest64
TARGET_OUT_VENDOR_NATIVE_TESTS := $(TARGET_OUT_DATA)/nativetest64$(TARGET_VENDOR_TEST_SUFFIX)
TARGET_OUT_VENDOR_METRIC_TESTS := $(TARGET_OUT_DATA)/benchmarktest64$(TARGET_VENDOR_TEST_SUFFIX)
else
TARGET_OUT_DATA_NATIVE_TESTS := $(TARGET_OUT_DATA)/nativetest
TARGET_OUT_DATA_METRIC_TESTS := $(TARGET_OUT_DATA)/benchmarktest
TARGET_OUT_VENDOR_NATIVE_TESTS := $(TARGET_OUT_DATA)/nativetest$(TARGET_VENDOR_TEST_SUFFIX)
TARGET_OUT_VENDOR_METRIC_TESTS := $(TARGET_OUT_DATA)/benchmarktest$(TARGET_VENDOR_TEST_SUFFIX)
endif
MODULE_CLASS_FAKE := fake_packages
TARGET_OUT_DATA_FAKE := $(TARGET_OUT_DATA)/fake_packages
.KATI_READONLY := \
  TARGET_OUT_DATA \
  TARGET_OUT_DATA_EXECUTABLES \
  TARGET_OUT_DATA_SHARED_LIBRARIES \
  TARGET_OUT_DATA_JAVA_LIBRARIES \
  TARGET_OUT_DATA_APPS \
  TARGET_OUT_DATA_KEYLAYOUT \
  TARGET_OUT_DATA_KEYCHARS \
  TARGET_OUT_DATA_ETC \
  TARGET_OUT_DATA_NATIVE_TESTS \
  TARGET_OUT_DATA_METRIC_TESTS \
  TARGET_OUT_VENDOR_NATIVE_TESTS \
  TARGET_OUT_VENDOR_METRIC_TESTS \
  TARGET_OUT_DATA_FAKE \
  MODULE_CLASS_APPS \
  MODULE_CLASS_EXECUTABLES \
  MODULE_CLASS_JAVA_LIBRARIES \
  MODULE_CLASS_NATIVE_TESTS \
  MODULE_CLASS_METRIC_TESTS \
  MODULE_CLASS_FAKE

$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_EXECUTABLES := $(TARGET_OUT_DATA_EXECUTABLES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_SHARED_LIBRARIES := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SHARED_LIBRARIES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_APPS := $(TARGET_OUT_DATA_APPS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_NATIVE_TESTS := $(TARGET_OUT_DATA)/nativetest
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_METRIC_TESTS := $(TARGET_OUT_DATA)/benchmarktest
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_NATIVE_TESTS := $(TARGET_OUT_DATA)/nativetest$(TARGET_VENDOR_TEST_SUFFIX)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_METRIC_TESTS := $(TARGET_OUT_DATA)/benchmarktest$(TARGET_VENDOR_TEST_SUFFIX)
.KATI_READONLY := \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_EXECUTABLES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_SHARED_LIBRARIES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_APPS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_NATIVE_TESTS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_METRIC_TESTS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_NATIVE_TESTS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_METRIC_TESTS \

TARGET_OUT_CACHE := $(PRODUCT_OUT)/cache
.KATI_READONLY := TARGET_OUT_CACHE

TARGET_OUT_VENDOR := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_VENDOR)
.KATI_READONLY := TARGET_OUT_VENDOR
ifneq ($(filter address,$(SANITIZE_TARGET)),)
target_out_vendor_shared_libraries_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_VENDOR)
ifeq ($(SANITIZE_LITE),true)
# When using SANITIZE_LITE, APKs must not be packaged with sanitized libraries, as they will not
# work with unsanitized app_process. For simplicity, generate APKs into /data/asan/.
target_out_vendor_app_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_VENDOR)
else
target_out_vendor_app_base := $(TARGET_OUT_VENDOR)
endif
else
target_out_vendor_shared_libraries_base := $(TARGET_OUT_VENDOR)
target_out_vendor_app_base := $(TARGET_OUT_VENDOR)
endif

TARGET_OUT_VENDOR_EXECUTABLES := $(TARGET_OUT_VENDOR)/bin
TARGET_OUT_VENDOR_OPTIONAL_EXECUTABLES := $(TARGET_OUT_VENDOR)/xbin
ifeq ($(TARGET_IS_64_BIT),true)
TARGET_OUT_VENDOR_SHARED_LIBRARIES := $(target_out_vendor_shared_libraries_base)/lib64
else
TARGET_OUT_VENDOR_SHARED_LIBRARIES := $(target_out_vendor_shared_libraries_base)/lib
endif
TARGET_OUT_VENDOR_RENDERSCRIPT_BITCODE := $(TARGET_OUT_VENDOR_SHARED_LIBRARIES)
TARGET_OUT_VENDOR_JAVA_LIBRARIES := $(TARGET_OUT_VENDOR)/framework
TARGET_OUT_VENDOR_APPS := $(target_out_vendor_app_base)/app
TARGET_OUT_VENDOR_APPS_PRIVILEGED := $(target_out_vendor_app_base)/priv-app
TARGET_OUT_VENDOR_ETC := $(TARGET_OUT_VENDOR)/etc
TARGET_OUT_VENDOR_FAKE := $(PRODUCT_OUT)/vendor_fake_packages
.KATI_READONLY := \
  TARGET_OUT_VENDOR_EXECUTABLES \
  TARGET_OUT_VENDOR_OPTIONAL_EXECUTABLES \
  TARGET_OUT_VENDOR_SHARED_LIBRARIES \
  TARGET_OUT_VENDOR_RENDERSCRIPT_BITCODE \
  TARGET_OUT_VENDOR_JAVA_LIBRARIES \
  TARGET_OUT_VENDOR_APPS \
  TARGET_OUT_VENDOR_APPS_PRIVILEGED \
  TARGET_OUT_VENDOR_ETC \
  TARGET_OUT_VENDOR_FAKE

$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_EXECUTABLES := $(TARGET_OUT_VENDOR_EXECUTABLES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES := $(target_out_vendor_shared_libraries_base)/lib
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_RENDERSCRIPT_BITCODE := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_APPS := $(TARGET_OUT_VENDOR_APPS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_APPS_PRIVILEGED := $(TARGET_OUT_VENDOR_APPS_PRIVILEGED)
.KATI_READONLY := \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_EXECUTABLES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_SHARED_LIBRARIES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_RENDERSCRIPT_BITCODE \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_APPS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_APPS_PRIVILEGED

TARGET_OUT_OEM := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_OEM)
TARGET_OUT_OEM_EXECUTABLES := $(TARGET_OUT_OEM)/bin
ifeq ($(TARGET_IS_64_BIT),true)
TARGET_OUT_OEM_SHARED_LIBRARIES := $(TARGET_OUT_OEM)/lib64
else
TARGET_OUT_OEM_SHARED_LIBRARIES := $(TARGET_OUT_OEM)/lib
endif
# We don't expect Java libraries in the oem.img.
# TARGET_OUT_OEM_JAVA_LIBRARIES:= $(TARGET_OUT_OEM)/framework
TARGET_OUT_OEM_APPS := $(TARGET_OUT_OEM)/app
TARGET_OUT_OEM_ETC := $(TARGET_OUT_OEM)/etc
.KATI_READONLY := \
  TARGET_OUT_OEM \
  TARGET_OUT_OEM_EXECUTABLES \
  TARGET_OUT_OEM_SHARED_LIBRARIES \
  TARGET_OUT_OEM_APPS \
  TARGET_OUT_OEM_ETC

$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_OEM_EXECUTABLES := $(TARGET_OUT_OEM_EXECUTABLES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_OEM_SHARED_LIBRARIES := $(TARGET_OUT_OEM)/lib
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_OEM_APPS := $(TARGET_OUT_OEM_APPS)
.KATI_READONLY := \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_OEM_EXECUTABLES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_OEM_SHARED_LIBRARIES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_OEM_APPS \

TARGET_OUT_ODM := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ODM)
ifneq ($(filter address,$(SANITIZE_TARGET)),)
target_out_odm_shared_libraries_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_OEM)
ifeq ($(SANITIZE_LITE),true)
# When using SANITIZE_LITE, APKs must not be packaged with sanitized libraries, as they will not
# work with unsanitized app_process. For simplicity, generate APKs into /data/asan/.
target_out_odm_app_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_OEM)
else
target_out_odm_app_base := $(TARGET_OUT_ODM)
endif
else
target_out_odm_shared_libraries_base := $(TARGET_OUT_ODM)
target_out_odm_app_base := $(TARGET_OUT_ODM)
endif

TARGET_OUT_ODM_EXECUTABLES := $(TARGET_OUT_ODM)/bin
TARGET_OUT_ODM_OPTIONAL_EXECUTABLES := $(TARGET_OUT_ODM)/xbin
ifeq ($(TARGET_IS_64_BIT),true)
TARGET_OUT_ODM_SHARED_LIBRARIES := $(target_out_odm_shared_libraries_base)/lib64
else
TARGET_OUT_ODM_SHARED_LIBRARIES := $(target_out_odm_shared_libraries_base)/lib
endif
TARGET_OUT_ODM_RENDERSCRIPT_BITCODE := $(TARGET_OUT_ODM_SHARED_LIBRARIES)
TARGET_OUT_ODM_JAVA_LIBRARIES := $(TARGET_OUT_ODM)/framework
TARGET_OUT_ODM_APPS := $(target_out_odm_app_base)/app
TARGET_OUT_ODM_APPS_PRIVILEGED := $(target_out_odm_app_base)/priv-app
TARGET_OUT_ODM_ETC := $(TARGET_OUT_ODM)/etc
TARGET_OUT_ODM_FAKE := $(PRODUCT_OUT)/odm_fake_packages
.KATI_READONLY := \
  TARGET_OUT_ODM \
  TARGET_OUT_ODM_EXECUTABLES \
  TARGET_OUT_ODM_OPTIONAL_EXECUTABLES \
  TARGET_OUT_ODM_SHARED_LIBRARIES \
  TARGET_OUT_ODM_RENDERSCRIPT_BITCODE \
  TARGET_OUT_ODM_JAVA_LIBRARIES \
  TARGET_OUT_ODM_APPS \
  TARGET_OUT_ODM_APPS_PRIVILEGED \
  TARGET_OUT_ODM_ETC \
  TARGET_OUT_ODM_FAKE

$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_EXECUTABLES := $(TARGET_OUT_ODM_EXECUTABLES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_SHARED_LIBRARIES := $(target_out_odm_shared_libraries_base)/lib
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_RENDERSCRIPT_BITCODE := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_SHARED_LIBRARIES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_APPS := $(TARGET_OUT_ODM_APPS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_APPS_PRIVILEGED := $(TARGET_OUT_ODM_APPS_PRIVILEGED)
.KATI_READONLY := \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_EXECUTABLES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_SHARED_LIBRARIES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_RENDERSCRIPT_BITCODE \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_APPS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_APPS_PRIVILEGED

TARGET_OUT_VENDOR_DLKM := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_VENDOR_DLKM)

TARGET_OUT_VENDOR_DLKM_ETC := $(TARGET_OUT_VENDOR_DLKM)/etc
.KATI_READONLY := \
  TARGET_OUT_VENDOR_DLKM_ETC

# Unlike other partitions, vendor_dlkm should only contain kernel modules.
TARGET_OUT_VENDOR_DLKM_EXECUTABLES :=
TARGET_OUT_VENDOR_DLKM_OPTIONAL_EXECUTABLES :=
TARGET_OUT_VENDOR_DLKM_SHARED_LIBRARIES :=
TARGET_OUT_VENDOR_DLKM_RENDERSCRIPT_BITCODE :=
TARGET_OUT_VENDOR_DLKM_JAVA_LIBRARIES :=
TARGET_OUT_VENDOR_DLKM_APPS :=
TARGET_OUT_VENDOR_DLKM_APPS_PRIVILEGED :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_EXECUTABLES :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_SHARED_LIBRARIES :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_RENDERSCRIPT_BITCODE :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_APPS :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_APPS_PRIVILEGED :=
$(KATI_obsolete_var \
    TARGET_OUT_VENDOR_DLKM_EXECUTABLES \
    TARGET_OUT_VENDOR_DLKM_OPTIONAL_EXECUTABLES \
    TARGET_OUT_VENDOR_DLKM_SHARED_LIBRARIES \
    TARGET_OUT_VENDOR_DLKM_RENDERSCRIPT_BITCODE \
    TARGET_OUT_VENDOR_DLKM_JAVA_LIBRARIES \
    TARGET_OUT_VENDOR_DLKM_APPS \
    TARGET_OUT_VENDOR_DLKM_APPS_PRIVILEGED \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_EXECUTABLES \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_SHARED_LIBRARIES \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_RENDERSCRIPT_BITCODE \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_APPS \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_VENDOR_DLKM_APPS_PRIVILEGED \
    , vendor_dlkm should not contain any executables, libraries, or apps)

TARGET_OUT_ODM_DLKM := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ODM_DLKM)

TARGET_OUT_ODM_DLKM_ETC := $(TARGET_OUT_ODM_DLKM)/etc
.KATI_READONLY := \
  TARGET_OUT_ODM_DLKM_ETC

# Unlike other partitions, odm_dlkm should only contain kernel modules.
TARGET_OUT_ODM_DLKM_EXECUTABLES :=
TARGET_OUT_ODM_DLKM_OPTIONAL_EXECUTABLES :=
TARGET_OUT_ODM_DLKM_SHARED_LIBRARIES :=
TARGET_OUT_ODM_DLKM_RENDERSCRIPT_BITCODE :=
TARGET_OUT_ODM_DLKM_JAVA_LIBRARIES :=
TARGET_OUT_ODM_DLKM_APPS :=
TARGET_OUT_ODM_DLKM_APPS_PRIVILEGED :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_EXECUTABLES :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_SHARED_LIBRARIES :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_RENDERSCRIPT_BITCODE :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_APPS :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_APPS_PRIVILEGED :=
$(KATI_obsolete_var \
    TARGET_OUT_ODM_DLKM_EXECUTABLES \
    TARGET_OUT_ODM_DLKM_OPTIONAL_EXECUTABLES \
    TARGET_OUT_ODM_DLKM_SHARED_LIBRARIES \
    TARGET_OUT_ODM_DLKM_RENDERSCRIPT_BITCODE \
    TARGET_OUT_ODM_DLKM_JAVA_LIBRARIES \
    TARGET_OUT_ODM_DLKM_APPS \
    TARGET_OUT_ODM_DLKM_APPS_PRIVILEGED \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_EXECUTABLES \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_SHARED_LIBRARIES \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_RENDERSCRIPT_BITCODE \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_APPS \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_ODM_DLKM_APPS_PRIVILEGED \
    , odm_dlkm should not contain any executables, libraries, or apps)

TARGET_OUT_SYSTEM_DLKM := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_SYSTEM_DLKM)

# Unlike other partitions, system_dlkm should only contain kernel modules.
TARGET_OUT_SYSTEM_DLKM_EXECUTABLES :=
TARGET_OUT_SYSTEM_DLKM_OPTIONAL_EXECUTABLES :=
TARGET_OUT_SYSTEM_DLKM_SHARED_LIBRARIES :=
TARGET_OUT_SYSTEM_DLKM_RENDERSCRIPT_BITCODE :=
TARGET_OUT_SYSTEM_DLKM_JAVA_LIBRARIES :=
TARGET_OUT_SYSTEM_DLKM_APPS :=
TARGET_OUT_SYSTEM_DLKM_APPS_PRIVILEGED :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_EXECUTABLES :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_SHARED_LIBRARIES :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_RENDERSCRIPT_BITCODE :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_APPS :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_APPS_PRIVILEGED :=
$(KATI_obsolete_var \
    TARGET_OUT_SYSTEM_DLKM_EXECUTABLES \
    TARGET_OUT_SYSTEM_DLKM_OPTIONAL_EXECUTABLES \
    TARGET_OUT_SYSTEM_DLKM_SHARED_LIBRARIES \
    TARGET_OUT_SYSTEM_DLKM_RENDERSCRIPT_BITCODE \
    TARGET_OUT_SYSTEM_DLKM_JAVA_LIBRARIES \
    TARGET_OUT_SYSTEM_DLKM_APPS \
    TARGET_OUT_SYSTEM_DLKM_APPS_PRIVILEGED \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_EXECUTABLES \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_SHARED_LIBRARIES \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_RENDERSCRIPT_BITCODE \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_APPS \
    $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_DLKM_APPS_PRIVILEGED \
    , system_dlkm should not contain any executables, libraries, or apps)

TARGET_OUT_PRODUCT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_PRODUCT)
TARGET_OUT_PRODUCT_EXECUTABLES := $(TARGET_OUT_PRODUCT)/bin
.KATI_READONLY := TARGET_OUT_PRODUCT
ifneq ($(filter address,$(SANITIZE_TARGET)),)
target_out_product_shared_libraries_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_PRODUCT)
ifeq ($(SANITIZE_LITE),true)
# When using SANITIZE_LITE, APKs must not be packaged with sanitized libraries, as they will not
# work with unsanitized app_process. For simplicity, generate APKs into /data/asan/.
target_out_product_app_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_PRODUCT)
else
target_out_product_app_base := $(TARGET_OUT_PRODUCT)
endif
else
target_out_product_shared_libraries_base := $(TARGET_OUT_PRODUCT)
target_out_product_app_base := $(TARGET_OUT_PRODUCT)
endif

ifeq ($(TARGET_IS_64_BIT),true)
TARGET_OUT_PRODUCT_SHARED_LIBRARIES := $(target_out_product_shared_libraries_base)/lib64
else
TARGET_OUT_PRODUCT_SHARED_LIBRARIES := $(target_out_product_shared_libraries_base)/lib
endif
TARGET_OUT_PRODUCT_JAVA_LIBRARIES := $(TARGET_OUT_PRODUCT)/framework
TARGET_OUT_PRODUCT_APPS := $(target_out_product_app_base)/app
TARGET_OUT_PRODUCT_APPS_PRIVILEGED := $(target_out_product_app_base)/priv-app
TARGET_OUT_PRODUCT_ETC := $(TARGET_OUT_PRODUCT)/etc
TARGET_OUT_PRODUCT_FAKE := $(TARGET_OUT_PRODUCT)/product_fake_packages
.KATI_READONLY := \
  TARGET_OUT_PRODUCT_EXECUTABLES \
  TARGET_OUT_PRODUCT_SHARED_LIBRARIES \
  TARGET_OUT_PRODUCT_JAVA_LIBRARIES \
  TARGET_OUT_PRODUCT_APPS \
  TARGET_OUT_PRODUCT_APPS_PRIVILEGED \
  TARGET_OUT_PRODUCT_ETC \
  TARGET_OUT_PRODUCT_FAKE

$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_EXECUTABLES := $(TARGET_OUT_PRODUCT_EXECUTABLES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_SHARED_LIBRARIES := $(target_out_product_shared_libraries_base)/lib
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_APPS := $(TARGET_OUT_PRODUCT_APPS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_APPS_PRIVILEGED := $(TARGET_OUT_PRODUCT_APPS_PRIVILEGED)
.KATI_READONLY := \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_EXECUTABLES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_SHARED_LIBRARIES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_APPS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_PRODUCT_APPS_PRIVILEGED

TARGET_OUT_SYSTEM_EXT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_SYSTEM_EXT)
ifneq ($(filter address,$(SANITIZE_TARGET)),)
target_out_system_ext_shared_libraries_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_SYSTEM_EXT)
ifeq ($(SANITIZE_LITE),true)
# When using SANITIZE_LITE, APKs must not be packaged with sanitized libraries, as they will not
# work with unsanitized app_process. For simplicity, generate APKs into /data/asan/.
target_out_system_ext_app_base := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ASAN)/$(TARGET_COPY_OUT_SYSTEM_EXT)
else
target_out_system_ext_app_base := $(TARGET_OUT_SYSTEM_EXT)
endif
else
target_out_system_ext_shared_libraries_base := $(TARGET_OUT_SYSTEM_EXT)
target_out_system_ext_app_base := $(TARGET_OUT_SYSTEM_EXT)
endif

ifeq ($(TARGET_IS_64_BIT),true)
TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES := $(target_out_system_ext_shared_libraries_base)/lib64
else
TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES := $(target_out_system_ext_shared_libraries_base)/lib
endif
TARGET_OUT_SYSTEM_EXT_JAVA_LIBRARIES:= $(TARGET_OUT_SYSTEM_EXT)/framework
TARGET_OUT_SYSTEM_EXT_APPS := $(target_out_system_ext_app_base)/app
TARGET_OUT_SYSTEM_EXT_APPS_PRIVILEGED := $(target_out_system_ext_app_base)/priv-app
TARGET_OUT_SYSTEM_EXT_ETC := $(TARGET_OUT_SYSTEM_EXT)/etc
TARGET_OUT_SYSTEM_EXT_EXECUTABLES := $(TARGET_OUT_SYSTEM_EXT)/bin
TARGET_OUT_SYSTEM_EXT_FAKE := $(PRODUCT_OUT)/system_ext_fake_packages
.KATI_READONLY := \
  TARGET_OUT_SYSTEM_EXT_EXECUTABLES \
  TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES \
  TARGET_OUT_SYSTEM_EXT_JAVA_LIBRARIES \
  TARGET_OUT_SYSTEM_EXT_APPS \
  TARGET_OUT_SYSTEM_EXT_APPS_PRIVILEGED \
  TARGET_OUT_SYSTEM_EXT_ETC \
  TARGET_OUT_SYSTEM_EXT_FAKE

$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_EXECUTABLES := $(TARGET_OUT_SYSTEM_EXT_EXECUTABLES)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES := $(target_out_system_ext_shared_libraries_base)/lib
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_APPS := $(TARGET_OUT_SYSTEM_EXT_APPS)
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_APPS_PRIVILEGED := $(TARGET_OUT_SYSTEM_EXT_APPS_PRIVILEGED)
.KATI_READONLY := \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_EXECUTABLES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_SHARED_LIBRARIES \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_APPS \
  $(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_SYSTEM_EXT_APPS_PRIVILEGED

TARGET_OUT_BREAKPAD := $(PRODUCT_OUT)/breakpad
.KATI_READONLY := TARGET_OUT_BREAKPAD

TARGET_OUT_UNSTRIPPED := $(PRODUCT_OUT)/symbols
TARGET_OUT_EXECUTABLES_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)/system/bin
TARGET_OUT_SHARED_LIBRARIES_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)/system/lib
TARGET_OUT_VENDOR_SHARED_LIBRARIES_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)/$(TARGET_COPY_OUT_VENDOR)/lib
TARGET_ROOT_OUT_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)
TARGET_ROOT_OUT_BIN_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)/bin
TARGET_OUT_COVERAGE := $(PRODUCT_OUT)/coverage
.KATI_READONLY := \
  TARGET_OUT_UNSTRIPPED \
  TARGET_OUT_EXECUTABLES_UNSTRIPPED \
  TARGET_OUT_SHARED_LIBRARIES_UNSTRIPPED \
  TARGET_OUT_VENDOR_SHARED_LIBRARIES_UNSTRIPPED \
  TARGET_ROOT_OUT_UNSTRIPPED \
  TARGET_ROOT_OUT_BIN_UNSTRIPPED \
  TARGET_OUT_COVERAGE

TARGET_RAMDISK_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_RAMDISK)
TARGET_RAMDISK_OUT_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)
TARGET_DEBUG_RAMDISK_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_DEBUG_RAMDISK)
TARGET_VENDOR_DEBUG_RAMDISK_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_VENDOR_DEBUG_RAMDISK)
TARGET_TEST_HARNESS_RAMDISK_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_TEST_HARNESS_RAMDISK)

TARGET_SYSTEM_DLKM_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_SYSTEM_DLKM)
.KATI_READONLY := TARGET_SYSTEM_DLKM_OUT

TARGET_VENDOR_RAMDISK_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_VENDOR_RAMDISK)
TARGET_VENDOR_KERNEL_RAMDISK_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_VENDOR_KERNEL_RAMDISK)

TARGET_ROOT_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_ROOT)
TARGET_ROOT_OUT_BIN := $(TARGET_ROOT_OUT)/bin
TARGET_ROOT_OUT_ETC := $(TARGET_ROOT_OUT)/etc
TARGET_ROOT_OUT_USR := $(TARGET_ROOT_OUT)/usr
.KATI_READONLY := \
  TARGET_ROOT_OUT \
  TARGET_ROOT_OUT_BIN \
  TARGET_ROOT_OUT_ETC \
  TARGET_ROOT_OUT_USR

TARGET_RECOVERY_OUT := $(PRODUCT_OUT)/$(TARGET_COPY_OUT_RECOVERY)
TARGET_RECOVERY_ROOT_OUT := $(TARGET_RECOVERY_OUT)/root
.KATI_READONLY := \
  TARGET_RECOVERY_OUT \
  TARGET_RECOVERY_ROOT_OUT

TARGET_SYSLOADER_OUT := $(PRODUCT_OUT)/sysloader
TARGET_SYSLOADER_ROOT_OUT := $(TARGET_SYSLOADER_OUT)/root
TARGET_SYSLOADER_SYSTEM_OUT := $(TARGET_SYSLOADER_OUT)/root/system
.KATI_READONLY := \
  TARGET_SYSLOADER_OUT \
  TARGET_SYSLOADER_ROOT_OUT \
  TARGET_SYSLOADER_SYSTEM_OUT

TARGET_INSTALLER_OUT := $(PRODUCT_OUT)/installer
TARGET_INSTALLER_DATA_OUT := $(TARGET_INSTALLER_OUT)/data
TARGET_INSTALLER_ROOT_OUT := $(TARGET_INSTALLER_OUT)/root
TARGET_INSTALLER_SYSTEM_OUT := $(TARGET_INSTALLER_OUT)/root/system
.KATI_READONLY := \
  TARGET_INSTALLER_OUT \
  TARGET_INSTALLER_DATA_OUT \
  TARGET_INSTALLER_ROOT_OUT \
  TARGET_INSTALLER_SYSTEM_OUT

COMMON_MODULE_CLASSES := TARGET_NOTICE_FILES HOST_NOTICE_FILES HOST_JAVA_LIBRARIES
PER_ARCH_MODULE_CLASSES := SHARED_LIBRARIES STATIC_LIBRARIES EXECUTABLES GYP RENDERSCRIPT_BITCODE NATIVE_TESTS HEADER_LIBRARIES RLIB_LIBRARIES DYLIB_LIBRARIES
.KATI_READONLY := COMMON_MODULE_CLASSES PER_ARCH_MODULE_CLASSES

ifeq ($(CALLED_FROM_SETUP),true)
PRINT_BUILD_CONFIG ?= true
endif
