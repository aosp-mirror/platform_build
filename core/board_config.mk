#
# Copyright (C) 2019 The Android Open Source Project
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

# ###############################################################
# This file includes BoardConfig.mk for the device being built,
# and checks the variable defined therein.
# ###############################################################

_board_strip_readonly_list :=
_board_strip_readonly_list += BOARD_BOOTLOADER_IN_UPDATE_PACKAGE
_board_strip_readonly_list += BOARD_EGL_CFG
_board_strip_readonly_list += BOARD_HAVE_BLUETOOTH
_board_strip_readonly_list += BOARD_INSTALLER_CMDLINE
_board_strip_readonly_list += BOARD_KERNEL_CMDLINE
_board_strip_readonly_list += BOARD_BOOT_HEADER_VERSION
_board_strip_readonly_list += BOARD_BOOTCONFIG
_board_strip_readonly_list += BOARD_KERNEL_BASE
_board_strip_readonly_list += BOARD_USES_GENERIC_AUDIO
_board_strip_readonly_list += BOARD_USES_RECOVERY_AS_BOOT
_board_strip_readonly_list += BOARD_VENDOR_USE_AKMD
_board_strip_readonly_list += BOARD_WPA_SUPPLICANT_DRIVER
_board_strip_readonly_list += BOARD_WLAN_DEVICE
_board_strip_readonly_list += TARGET_BOARD_PLATFORM
_board_strip_readonly_list += TARGET_BOARD_PLATFORM_GPU
_board_strip_readonly_list += TARGET_BOOTLOADER_BOARD_NAME
_board_strip_readonly_list += TARGET_FS_CONFIG_GEN
_board_strip_readonly_list += TARGET_NO_BOOTLOADER
_board_strip_readonly_list += TARGET_NO_KERNEL
_board_strip_readonly_list += TARGET_NO_RECOVERY
_board_strip_readonly_list += TARGET_NO_RADIOIMAGE
_board_strip_readonly_list += TARGET_HARDWARE_3D
_board_strip_readonly_list += WITH_DEXPREOPT

# Arch variables
_board_strip_readonly_list += TARGET_ARCH
_board_strip_readonly_list += TARGET_ARCH_VARIANT
_board_strip_readonly_list += TARGET_CPU_ABI
_board_strip_readonly_list += TARGET_CPU_ABI2
_board_strip_readonly_list += TARGET_CPU_VARIANT
_board_strip_readonly_list += TARGET_CPU_VARIANT_RUNTIME
_board_strip_readonly_list += TARGET_2ND_ARCH
_board_strip_readonly_list += TARGET_2ND_ARCH_VARIANT
_board_strip_readonly_list += TARGET_2ND_CPU_ABI
_board_strip_readonly_list += TARGET_2ND_CPU_ABI2
_board_strip_readonly_list += TARGET_2ND_CPU_VARIANT
_board_strip_readonly_list += TARGET_2ND_CPU_VARIANT_RUNTIME
# TARGET_ARCH_SUITE is an alternative arch configuration to TARGET_ARCH (and related variables),
# that can be used for soong-only builds to build for several architectures at once.
# Allowed values currently are "ndk" and "mainline_sdk".
_board_strip_readonly_list += TARGET_ARCH_SUITE

# File system variables
_board_strip_readonly_list += BOARD_FLASH_BLOCK_SIZE
_board_strip_readonly_list += BOARD_BOOTIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_RECOVERYIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_SYSTEMIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_USERDATAIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_CACHEIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_VENDORIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_PRODUCTIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_ODMIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_ODMIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_VENDOR_DLKMIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_ODM_DLKMIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_SYSTEM_DLKMIMAGE_PARTITION_SIZE
_board_strip_readonly_list += BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE
_board_strip_readonly_list += BOARD_PVMFWIMAGE_PARTITION_SIZE

# Logical partitions related variables.
_board_strip_readonly_list += BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_VENDOR_DLKMIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_ODM_DLKMIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_SYSTEM_DLKMIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE
_board_strip_readonly_list += BOARD_SUPER_PARTITION_SIZE
_board_strip_readonly_list += BOARD_SUPER_PARTITION_GROUPS

# Kernel related variables
_board_strip_readonly_list += BOARD_KERNEL_BINARIES
_board_strip_readonly_list += BOARD_KERNEL_MODULE_INTERFACE_VERSIONS

# Variables related to generic kernel image (GKI) and generic boot image
# - BOARD_USES_GENERIC_KERNEL_IMAGE is the global variable that defines if the
#   board uses GKI and generic boot image.
#   Update mechanism of the boot image is not enforced by this variable.
# - BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE controls whether the recovery image
#   contains a kernel or not.
# - BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT controls whether ramdisk
#   recovery resources are built to vendor_boot.
# - BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT controls whether recovery
#   resources are built as a standalone recovery ramdisk in vendor_boot.
# - BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT controls whether GSI AVB keys are
#   built to vendor_boot.
# - BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES controls whether boot images in $OUT are added
#   to target files package directly.
_board_strip_readonly_list += BOARD_USES_GENERIC_KERNEL_IMAGE
_board_strip_readonly_list += BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE
_board_strip_readonly_list += BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT
_board_strip_readonly_list += BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT
_board_strip_readonly_list += BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT
_board_strip_readonly_list += BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES

# Prebuilt image variables
_board_strip_readonly_list += BOARD_PREBUILT_INIT_BOOT_IMAGE

# Defines the list of logical vendor ramdisk names to build or include in vendor_boot.
_board_strip_readonly_list += BOARD_VENDOR_RAMDISK_FRAGMENTS

# These are all variables used to build $(INSTALLED_MISC_INFO_TARGET)
# in build/make/core/Makefile. Their values get used in command line
# arguments, so they have to be stripped to make the ninja files stable.
_board_strip_list :=
_board_strip_list += BOARD_DTBOIMG_PARTITION_SIZE
_board_strip_list += BOARD_AVB_DTBO_KEY_PATH
_board_strip_list += BOARD_AVB_DTBO_ALGORITHM
_board_strip_list += BOARD_AVB_DTBO_ROLLBACK_INDEX_LOCATION
_board_strip_list += BOARD_AVB_PVMFW_KEY_PATH
_board_strip_list += BOARD_AVB_PVMFW_ALGORITHM
_board_strip_list += BOARD_AVB_PVMFW_ROLLBACK_INDEX_LOCATION
_board_strip_list += BOARD_PARTIAL_OTA_UPDATE_PARTITIONS_LIST
_board_strip_list += BOARD_AVB_VBMETA_VENDOR_ROLLBACK_INDEX_LOCATION
_board_strip_list += BOARD_AVB_VBMETA_VENDOR_ALGORITHM
_board_strip_list += BOARD_AVB_VBMETA_VENDOR_KEY_PATH
_board_strip_list += BOARD_AVB_VBMETA_VENDOR
_board_strip_list += BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX_LOCATION
_board_strip_list += BOARD_AVB_VBMETA_SYSTEM_ALGORITHM
_board_strip_list += BOARD_AVB_VBMETA_SYSTEM_KEY_PATH
_board_strip_list += BOARD_AVB_VBMETA_SYSTEM
_board_strip_list += BOARD_AVB_RECOVERY_KEY_PATH
_board_strip_list += BOARD_AVB_RECOVERY_ALGORITHM
_board_strip_list += BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION
_board_strip_list += BOARD_AVB_VENDOR_BOOT_KEY_PATH
_board_strip_list += BOARD_AVB_VENDOR_BOOT_ALGORITHM
_board_strip_list += BOARD_AVB_VENDOR_BOOT_ROLLBACK_INDEX_LOCATION
_board_strip_list += BOARD_AVB_VENDOR_KERNEL_BOOT_KEY_PATH
_board_strip_list += BOARD_AVB_VENDOR_KERNEL_BOOT_ALGORITHM
_board_strip_list += BOARD_AVB_VENDOR_KERNEL_BOOT_ROLLBACK_INDEX_LOCATION
_board_strip_list += BOARD_MKBOOTIMG_ARGS
_board_strip_list += BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE
_board_strip_list += BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE
_board_strip_list += ODM_MANIFEST_SKUS


_build_broken_var_list := \
  BUILD_BROKEN_CLANG_PROPERTY \
  BUILD_BROKEN_CLANG_ASFLAGS \
  BUILD_BROKEN_CLANG_CFLAGS \
  BUILD_BROKEN_DEPFILE \
  BUILD_BROKEN_DUP_RULES \
  BUILD_BROKEN_DUP_SYSPROP \
  BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES \
  BUILD_BROKEN_ENFORCE_SYSPROP_OWNER \
  BUILD_BROKEN_INPUT_DIR_MODULES \
  BUILD_BROKEN_MISSING_REQUIRED_MODULES \
  BUILD_BROKEN_OUTSIDE_INCLUDE_DIRS \
  BUILD_BROKEN_PREBUILT_ELF_FILES \
  BUILD_BROKEN_TREBLE_SYSPROP_NEVERALLOW \
  BUILD_BROKEN_USES_NETWORK \
  BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE \
  BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES \
  BUILD_BROKEN_INCORRECT_PARTITION_IMAGES \
  BUILD_BROKEN_GENRULE_SANDBOXING \

_build_broken_var_list += \
  $(foreach m,$(AVAILABLE_BUILD_MODULE_TYPES) \
              $(DEFAULT_WARNING_BUILD_MODULE_TYPES) \
              $(DEFAULT_ERROR_BUILD_MODULE_TYPES), \
    BUILD_BROKEN_USES_$(m))

_board_true_false_vars := $(_build_broken_var_list)
_board_strip_readonly_list += $(_build_broken_var_list) \
  BUILD_BROKEN_NINJA_USES_ENV_VARS

# Conditional to building on linux, as dex2oat currently does not work on darwin.
ifeq ($(HOST_OS),linux)
  WITH_DEXPREOPT ?= true
endif

# ###############################################################
# Broken build defaults
# ###############################################################
$(foreach v,$(_build_broken_var_list),$(eval $(v) :=))
BUILD_BROKEN_NINJA_USES_ENV_VARS :=

# Boards may be defined under $(SRC_TARGET_DIR)/board/$(TARGET_DEVICE)
# or under vendor/*/$(TARGET_DEVICE).  Search in both places, but
# make sure only one exists.
# Real boards should always be associated with an OEM vendor.
ifdef TARGET_DEVICE_DIR
  ifneq ($(origin TARGET_DEVICE_DIR),command line)
    $(error TARGET_DEVICE_DIR may not be set manually)
  endif
  board_config_mk := $(TARGET_DEVICE_DIR)/BoardConfig.mk
else
  board_config_mk := \
    $(strip $(sort $(wildcard \
      $(SRC_TARGET_DIR)/board/$(TARGET_DEVICE)/BoardConfig.mk \
      device/generic/goldfish/board/$(TARGET_DEVICE)/BoardConfig.mk \
      device/google/cuttlefish/board/$(TARGET_DEVICE)/BoardConfig.mk \
      $(shell test -d device && find -L device -maxdepth 4 -path '*/$(TARGET_DEVICE)/BoardConfig.mk') \
      $(shell test -d vendor && find -L vendor -maxdepth 4 -path '*/$(TARGET_DEVICE)/BoardConfig.mk') \
    )))
  ifeq ($(board_config_mk),)
    $(error No config file found for TARGET_DEVICE $(TARGET_DEVICE))
  endif
  ifneq ($(words $(board_config_mk)),1)
    $(error Multiple board config files for TARGET_DEVICE $(TARGET_DEVICE): $(board_config_mk))
  endif
  TARGET_DEVICE_DIR := $(patsubst %/,%,$(dir $(board_config_mk)))
  .KATI_READONLY := TARGET_DEVICE_DIR
endif

ifndef RBC_PRODUCT_CONFIG
include $(board_config_mk)
else
  $(shell mkdir -p $(OUT_DIR)/rbc)
  $(call dump-variables-rbc, $(OUT_DIR)/rbc/make_vars_pre_board_config.mk)

  $(shell $(OUT_DIR)/mk2rbc \
    --mode=write -r --outdir $(OUT_DIR)/rbc \
    --boardlauncher=$(OUT_DIR)/rbc/boardlauncher.rbc \
    --input_variables=$(OUT_DIR)/rbc/make_vars_pre_board_config.mk \
    --makefile_list=$(OUT_DIR)/.module_paths/configuration.list \
    $(board_config_mk))
  ifneq ($(.SHELLSTATUS),0)
    $(error board configuration converter failed: $(.SHELLSTATUS))
  endif

  $(shell build/soong/scripts/update_out $(OUT_DIR)/rbc/rbc_board_config_results.mk \
    $(OUT_DIR)/rbcrun --mode=rbc $(OUT_DIR)/rbc/boardlauncher.rbc)
  ifneq ($(.SHELLSTATUS),0)
    $(error board configuration runner failed: $(.SHELLSTATUS))
  endif

  include $(OUT_DIR)/rbc/rbc_board_config_results.mk
endif

ifneq (,$(and $(TARGET_ARCH),$(TARGET_ARCH_SUITE)))
  $(error $(board_config_mk) erroneously sets both TARGET_ARCH and TARGET_ARCH_SUITE)
endif
ifeq ($(TARGET_ARCH)$(TARGET_ARCH_SUITE),)
  $(error Target architectures not defined by board config: $(board_config_mk))
endif
ifeq ($(TARGET_CPU_ABI)$(TARGET_ARCH_SUITE),)
  $(error TARGET_CPU_ABI not defined by board config: $(board_config_mk))
endif

ifneq ($(MALLOC_IMPL),)
  $(warning *** Unsupported option MALLOC_IMPL defined by board config: $(board_config_mk).)
  $(error Use `MALLOC_SVELTE := true` to configure jemalloc for low-memory)
endif
board_config_mk :=

# Clean up and verify BoardConfig variables
$(foreach var,$(_board_strip_readonly_list),$(eval $(var) := $$(strip $$($(var)))))
$(foreach var,$(_board_strip_list),$(eval $(var) := $$(strip $$($(var)))))
$(foreach var,$(_board_true_false_vars), \
  $(if $(filter-out true false,$($(var))), \
    $(error Valid values of $(var) are "true", "false", and "". Not "$($(var))")))

include $(BUILD_SYSTEM)/board_config_wifi.mk

# Default *_CPU_VARIANT_RUNTIME to CPU_VARIANT if unspecified.
TARGET_CPU_VARIANT_RUNTIME := $(or $(TARGET_CPU_VARIANT_RUNTIME),$(TARGET_CPU_VARIANT))
TARGET_2ND_CPU_VARIANT_RUNTIME := $(or $(TARGET_2ND_CPU_VARIANT_RUNTIME),$(TARGET_2ND_CPU_VARIANT))

ifdef TARGET_ARCH
  # The combo makefiles check and set defaults for various CPU configuration
  combo_target := TARGET_
  combo_2nd_arch_prefix :=
  include $(BUILD_SYSTEM)/combo/select.mk
endif

ifdef TARGET_2ND_ARCH
  combo_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
  include $(BUILD_SYSTEM)/combo/select.mk
endif

.KATI_READONLY := $(_board_strip_readonly_list)

INTERNAL_KERNEL_CMDLINE := $(BOARD_KERNEL_CMDLINE)
ifneq (,$(BOARD_BOOTCONFIG))
  INTERNAL_KERNEL_CMDLINE += bootconfig
  INTERNAL_BOOTCONFIG := $(BOARD_BOOTCONFIG)
endif

ifneq ($(filter %64,$(TARGET_ARCH)),)
  TARGET_IS_64_BIT := true
endif

ifeq (,$(filter true,$(TARGET_SUPPORTS_32_BIT_APPS) $(TARGET_SUPPORTS_64_BIT_APPS)))
  TARGET_SUPPORTS_32_BIT_APPS := true
endif

# Quick check to warn about likely cryptic errors later in the build.
ifeq ($(TARGET_IS_64_BIT),true)
  ifeq (,$(filter true false,$(TARGET_SUPPORTS_64_BIT_APPS)))
    $(error Building a 32-bit-app-only product on a 64-bit device. \
      If this is intentional, set TARGET_SUPPORTS_64_BIT_APPS := false)
  endif
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
#
# Similarly, TARGET_NATIVE_BRIDGE_2ND_ABI for a 64 bit target is always
# 32 bits. Note that all CPU_ABIs are preferred over all NATIVE_BRIDGE_ABIs.
_target_native_bridge_abi_list_32_bit :=
_target_native_bridge_abi_list_64_bit :=

ifeq (,$(TARGET_CPU_ABI_LIST_64_BIT))
  ifeq (true|true,$(TARGET_IS_64_BIT)|$(TARGET_SUPPORTS_64_BIT_APPS))
    TARGET_CPU_ABI_LIST_64_BIT := $(TARGET_CPU_ABI) $(TARGET_CPU_ABI2)
    _target_native_bridge_abi_list_64_bit := $(TARGET_NATIVE_BRIDGE_ABI)
  endif
endif

# "arm64-v8a-hwasan", the ABI for libraries compiled with HWASAN, is supported
# in all builds with SANITIZE_TARGET=hwaddress.
ifneq ($(filter hwaddress,$(SANITIZE_TARGET)),)
  ifneq ($(filter arm64-v8a,$(TARGET_CPU_ABI_LIST_64_BIT)),)
    TARGET_CPU_ABI_LIST_64_BIT := arm64-v8a-hwasan $(TARGET_CPU_ABI_LIST_64_BIT)
  endif
endif

ifeq (,$(TARGET_CPU_ABI_LIST_32_BIT))
  ifneq (true,$(TARGET_IS_64_BIT))
    TARGET_CPU_ABI_LIST_32_BIT := $(TARGET_CPU_ABI) $(TARGET_CPU_ABI2)
    _target_native_bridge_abi_list_32_bit := $(TARGET_NATIVE_BRIDGE_ABI)
  else
    ifeq (true,$(TARGET_SUPPORTS_32_BIT_APPS))
      # For a 64 bit target, assume that the 2ND_CPU_ABI
      # is a 32 bit ABI.
      TARGET_CPU_ABI_LIST_32_BIT := $(TARGET_2ND_CPU_ABI) $(TARGET_2ND_CPU_ABI2)
      _target_native_bridge_abi_list_32_bit := $(TARGET_NATIVE_BRIDGE_2ND_ABI)
    endif
  endif
endif

# "ro.product.cpu.abilist" is a comma separated list of ABIs (in order
# of preference) that the target supports. If a TARGET_CPU_ABI_LIST
# is specified by the board configuration, we use that. If not, we
# build a list out of the TARGET_CPU_ABIs specified by the config.
# Add NATIVE_BRIDGE_ABIs at the end to keep order of preference.
ifeq (,$(TARGET_CPU_ABI_LIST))
  TARGET_CPU_ABI_LIST := $(TARGET_CPU_ABI_LIST_64_BIT) $(TARGET_CPU_ABI_LIST_32_BIT) \
                         $(_target_native_bridge_abi_list_64_bit) $(_target_native_bridge_abi_list_32_bit)
endif

# Add NATIVE_BRIDGE_ABIs at the end of 32 and 64 bit CPU_ABIs to keep order of preference.
TARGET_CPU_ABI_LIST_32_BIT += $(_target_native_bridge_abi_list_32_bit)
TARGET_CPU_ABI_LIST_64_BIT += $(_target_native_bridge_abi_list_64_bit)

# Strip whitespace from the ABI list string.
TARGET_CPU_ABI_LIST := $(subst $(space),$(comma),$(strip $(TARGET_CPU_ABI_LIST)))
TARGET_CPU_ABI_LIST_32_BIT := $(subst $(space),$(comma),$(strip $(TARGET_CPU_ABI_LIST_32_BIT)))
TARGET_CPU_ABI_LIST_64_BIT := $(subst $(space),$(comma),$(strip $(TARGET_CPU_ABI_LIST_64_BIT)))

# Check if config about image building is valid or not.
define check_image_config
  $(eval _uc_name := $(call to-upper,$(1))) \
  $(eval _lc_name := $(call to-lower,$(1))) \
  $(if $(filter $(_lc_name),$(TARGET_COPY_OUT_$(_uc_name))), \
    $(if $(BOARD_USES_$(_uc_name)IMAGE),, \
      $(error If TARGET_COPY_OUT_$(_uc_name) is '$(_lc_name)', either BOARD_PREBUILT_$(_uc_name)IMAGE or BOARD_$(_uc_name)IMAGE_FILE_SYSTEM_TYPE must be set)), \
  $(if $(BOARD_USES_$(_uc_name)IMAGE), \
    $(error TARGET_COPY_OUT_$(_uc_name) must be set to '$(_lc_name)' to use a $(_lc_name) image))) \
  $(eval _uc_name :=) \
  $(eval _lc_name :=)
endef

###########################################
# Configure whether we're building the system image
BUILDING_SYSTEM_IMAGE := true
ifeq ($(PRODUCT_BUILD_SYSTEM_IMAGE),)
  ifndef PRODUCT_USE_DYNAMIC_PARTITION_SIZE
    ifndef BOARD_SYSTEMIMAGE_PARTITION_SIZE
      BUILDING_SYSTEM_IMAGE :=
    endif
  endif
else ifeq ($(PRODUCT_BUILD_SYSTEM_IMAGE),false)
  BUILDING_SYSTEM_IMAGE :=
endif
.KATI_READONLY := BUILDING_SYSTEM_IMAGE

# Are we building a system_other image
BUILDING_SYSTEM_OTHER_IMAGE :=
ifeq ($(PRODUCT_BUILD_SYSTEM_OTHER_IMAGE),)
  ifdef BUILDING_SYSTEM_IMAGE
    ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
      BUILDING_SYSTEM_OTHER_IMAGE := true
    endif
  endif
else ifeq ($(PRODUCT_BUILD_SYSTEM_OTHER_IMAGE),true)
  BUILDING_SYSTEM_OTHER_IMAGE := true
  ifndef BUILDING_SYSTEM_IMAGE
    $(error PRODUCT_BUILD_SYSTEM_OTHER_IMAGE = true requires building the system image)
  endif
endif
.KATI_READONLY := BUILDING_SYSTEM_OTHER_IMAGE

# Are we building a cache image
BUILDING_CACHE_IMAGE :=
ifeq ($(PRODUCT_BUILD_CACHE_IMAGE),)
  ifdef BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE
    BUILDING_CACHE_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_CACHE_IMAGE),true)
  BUILDING_CACHE_IMAGE := true
  ifndef BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_CACHE_IMAGE set to true, but BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
.KATI_READONLY := BUILDING_CACHE_IMAGE

# Are we building a boot image
BUILDING_BOOT_IMAGE :=
ifeq ($(PRODUCT_BUILD_BOOT_IMAGE),)
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    BUILDING_BOOT_IMAGE :=
  else ifdef BOARD_PREBUILT_BOOTIMAGE
    BUILDING_BOOT_IMAGE :=
  else ifdef BOARD_BOOTIMAGE_PARTITION_SIZE
    BUILDING_BOOT_IMAGE := true
  else ifneq (,$(foreach kernel,$(BOARD_KERNEL_BINARIES),$(BOARD_$(call to-upper,$(kernel))_BOOTIMAGE_PARTITION_SIZE)))
    BUILDING_BOOT_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_BOOT_IMAGE),true)
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    $(warning *** PRODUCT_BUILD_BOOT_IMAGE is true, but so is BOARD_USES_RECOVERY_AS_BOOT.)
    $(warning *** Skipping building boot image.)
    BUILDING_BOOT_IMAGE :=
  else
    BUILDING_BOOT_IMAGE := true
  endif
endif
.KATI_READONLY := BUILDING_BOOT_IMAGE

# Are we building an init boot image
BUILDING_INIT_BOOT_IMAGE :=
ifeq ($(PRODUCT_BUILD_INIT_BOOT_IMAGE),)
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    BUILDING_INIT_BOOT_IMAGE :=
  else ifdef BOARD_PREBUILT_INIT_BOOT_IMAGE
    BUILDING_INIT_BOOT_IMAGE :=
  else ifdef BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE
    BUILDING_INIT_BOOT_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_INIT_BOOT_IMAGE),true)
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    $(error PRODUCT_BUILD_INIT_BOOT_IMAGE is true, but so is BOARD_USES_RECOVERY_AS_BOOT. Use only one option.)
  else
    BUILDING_INIT_BOOT_IMAGE := true
  endif
endif
.KATI_READONLY := BUILDING_INIT_BOOT_IMAGE

# Are we building a recovery image
BUILDING_RECOVERY_IMAGE :=
ifeq ($(PRODUCT_BUILD_RECOVERY_IMAGE),)
  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    BUILDING_RECOVERY_IMAGE := true
  else ifeq ($(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT),true)
    # Set to true to build recovery resources for vendor_boot
    BUILDING_RECOVERY_IMAGE := true
  else ifdef BOARD_RECOVERYIMAGE_PARTITION_SIZE
    ifeq (,$(filter true, $(TARGET_NO_KERNEL) $(TARGET_NO_RECOVERY)))
      BUILDING_RECOVERY_IMAGE := true
    endif
  endif
else ifeq ($(PRODUCT_BUILD_RECOVERY_IMAGE),true)
  BUILDING_RECOVERY_IMAGE := true
endif
.KATI_READONLY := BUILDING_RECOVERY_IMAGE

# Are we building a vendor boot image
BUILDING_VENDOR_BOOT_IMAGE :=
ifdef BOARD_BOOT_HEADER_VERSION
  ifneq ($(call math_gt_or_eq,$(BOARD_BOOT_HEADER_VERSION),3),)
    ifeq ($(PRODUCT_BUILD_VENDOR_BOOT_IMAGE),)
      BUILDING_VENDOR_BOOT_IMAGE := true
    else ifeq ($(PRODUCT_BUILD_VENDOR_BOOT_IMAGE),true)
      BUILDING_VENDOR_BOOT_IMAGE := true
    endif
  endif
endif
.KATI_READONLY := BUILDING_VENDOR_BOOT_IMAGE

# Are we building a vendor kernel boot image
BUILDING_VENDOR_KERNEL_BOOT_IMAGE :=
ifeq ($(PRODUCT_BUILD_VENDOR_KERNEL_BOOT_IMAGE),true)
  ifneq ($(BUILDING_VENDOR_BOOT_IMAGE),true)
    $(error BUILDING_VENDOR_BOOT_IMAGE is required, but BUILDING_VENDOR_BOOT_IMAGE is not true)
  endif
  ifndef BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE
    $(error BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE is required when PRODUCT_BUILD_VENDOR_KERNEL_BOOT_IMAGE is true)
  endif
  BUILDING_VENDOR_KERNEL_BOOT_IMAGE := true
else ifeq ($(PRODUCT_BUILD_VENDOR_KERNEL),)
  ifdef BOARD_VENDOR_KERNEL_BOOTIMAGE_PARTITION_SIZE
    ifeq ($(BUILDING_VENDOR_BOOT_IMAGE),true)
      BUILDING_VENDOR_KERNEL_BOOT_IMAGE := true
    endif
  endif
endif # end of PRODUCT_BUILD_VENDOR_KERNEL_BOOT_IMAGE
.KATI_READONLY := BUILDING_VENDOR_KERNEL_BOOT_IMAGE

# Are we building a ramdisk image
BUILDING_RAMDISK_IMAGE := true
ifeq ($(PRODUCT_BUILD_RAMDISK_IMAGE),)
  # TODO: Be smarter about this. This probably only needs to happen when one of the follow is true:
  #  BUILDING_BOOT_IMAGE
  #  BUILDING_RECOVERY_IMAGE
else ifeq ($(PRODUCT_BUILD_RAMDISK_IMAGE),false)
  BUILDING_RAMDISK_IMAGE :=
endif
.KATI_READONLY := BUILDING_RAMDISK_IMAGE

# Are we building a debug vendor_boot image
BUILDING_DEBUG_VENDOR_BOOT_IMAGE :=
# Can't build vendor_boot-debug.img if we're not building a ramdisk.
ifndef BUILDING_RAMDISK_IMAGE
  ifeq ($(PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE),true)
    $(warning PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE is true, but we're not building a ramdisk image. \
      Skip building the debug vendor_boot image.)
  endif
# Can't build vendor_boot-debug.img if we're not building a vendor_boot.img.
else ifndef BUILDING_VENDOR_BOOT_IMAGE
  ifeq ($(PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE),true)
    $(warning PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE is true, but we're not building a vendor_boot image. \
      Skip building the debug vendor_boot image.)
  endif
else
  ifeq ($(PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE),)
    BUILDING_DEBUG_VENDOR_BOOT_IMAGE := true
  else ifeq ($(PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE),true)
    BUILDING_DEBUG_VENDOR_BOOT_IMAGE := true
  endif
endif
.KATI_READONLY := BUILDING_DEBUG_VENDOR_BOOT_IMAGE

_has_boot_img_artifact :=
ifneq ($(strip $(TARGET_NO_KERNEL)),true)
  ifdef BUILDING_BOOT_IMAGE
    _has_boot_img_artifact := true
  endif
  # BUILDING_RECOVERY_IMAGE && BOARD_USES_RECOVERY_AS_BOOT implies that
  # recovery is being built with the file name *boot.img*, which still counts
  # as "building boot.img".
  ifdef BUILDING_RECOVERY_IMAGE
    ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
      _has_boot_img_artifact := true
    endif
  endif
endif

# Are we building a debug boot image
BUILDING_DEBUG_BOOT_IMAGE :=
# Can't build boot-debug.img if we're not building a ramdisk.
ifndef BUILDING_RAMDISK_IMAGE
  ifeq ($(PRODUCT_BUILD_DEBUG_BOOT_IMAGE),true)
    $(warning PRODUCT_BUILD_DEBUG_BOOT_IMAGE is true, but we're not building a ramdisk image. \
      Skip building the debug boot image.)
  endif
# Can't build boot-debug.img if we're not building a boot.img.
else ifndef _has_boot_img_artifact
  ifeq ($(PRODUCT_BUILD_DEBUG_BOOT_IMAGE),true)
    $(warning PRODUCT_BUILD_DEBUG_BOOT_IMAGE is true, but we're not building a boot image. \
      Skip building the debug boot image.)
  endif
else ifdef BUILDING_INIT_BOOT_IMAGE
  ifeq ($(PRODUCT_BUILD_DEBUG_BOOT_IMAGE),true)
    $(warning PRODUCT_BUILD_DEBUG_BOOT_IMAGE is true, but we don't have a ramdisk in the boot image. \
      Skip building the debug boot image.)
  endif
else
  ifeq ($(PRODUCT_BUILD_DEBUG_BOOT_IMAGE),)
    BUILDING_DEBUG_BOOT_IMAGE := true
    # Don't build boot-debug.img if we're already building vendor_boot-debug.img.
    ifdef BUILDING_DEBUG_VENDOR_BOOT_IMAGE
      BUILDING_DEBUG_BOOT_IMAGE :=
    endif
  else ifeq ($(PRODUCT_BUILD_DEBUG_BOOT_IMAGE),true)
    BUILDING_DEBUG_BOOT_IMAGE := true
  endif
endif
.KATI_READONLY := BUILDING_DEBUG_BOOT_IMAGE
_has_boot_img_artifact :=

# Are we building a userdata image
BUILDING_USERDATA_IMAGE :=
ifeq ($(PRODUCT_BUILD_USERDATA_IMAGE),)
  ifdef BOARD_USERDATAIMAGE_PARTITION_SIZE
    BUILDING_USERDATA_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_USERDATA_IMAGE),true)
  BUILDING_USERDATA_IMAGE := true
endif
.KATI_READONLY := BUILDING_USERDATA_IMAGE

# Are we building a vbmeta image
BUILDING_VBMETA_IMAGE := true
ifeq ($(PRODUCT_BUILD_VBMETA_IMAGE),false)
  BUILDING_VBMETA_IMAGE :=
endif
.KATI_READONLY := BUILDING_VBMETA_IMAGE

# Are we building a super_empty image
BUILDING_SUPER_EMPTY_IMAGE :=
ifeq ($(PRODUCT_BUILD_SUPER_EMPTY_IMAGE),)
  ifeq (true,$(PRODUCT_USE_DYNAMIC_PARTITIONS))
    ifneq ($(BOARD_SUPER_PARTITION_SIZE),)
      BUILDING_SUPER_EMPTY_IMAGE := true
    endif
  endif
else ifeq ($(PRODUCT_BUILD_SUPER_EMPTY_IMAGE),true)
  ifneq (true,$(PRODUCT_USE_DYNAMIC_PARTITIONS))
    $(error PRODUCT_BUILD_SUPER_EMPTY_IMAGE set to true, but PRODUCT_USE_DYNAMIC_PARTITIONS is not true)
  endif
  ifeq ($(BOARD_SUPER_PARTITION_SIZE),)
    $(error PRODUCT_BUILD_SUPER_EMPTY_IMAGE set to true, but BOARD_SUPER_PARTITION_SIZE is not defined)
  endif
  BUILDING_SUPER_EMPTY_IMAGE := true
endif
.KATI_READONLY := BUILDING_SUPER_EMPTY_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_VENDOR
ifeq ($(TARGET_COPY_OUT_VENDOR),$(_vendor_path_placeholder))
  TARGET_COPY_OUT_VENDOR := system/vendor
else ifeq ($(filter vendor system/vendor,$(TARGET_COPY_OUT_VENDOR)),)
  $(error TARGET_COPY_OUT_VENDOR must be either 'vendor' or 'system/vendor', seeing '$(TARGET_COPY_OUT_VENDOR)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_vendor_path_placeholder),$(TARGET_COPY_OUT_VENDOR),$(PRODUCT_COPY_FILES))

BOARD_USES_VENDORIMAGE :=
ifdef BOARD_PREBUILT_VENDORIMAGE
  BOARD_USES_VENDORIMAGE := true
endif
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_VENDORIMAGE := true
endif
# TODO(b/137169253): For now, some AOSP targets build with prebuilt vendor image.
# But target's BOARD_PREBUILT_VENDORIMAGE is not filled.
ifeq ($(TARGET_COPY_OUT_VENDOR),vendor)
  BOARD_USES_VENDORIMAGE := true
else ifdef BOARD_USES_VENDORIMAGE
  $(error TARGET_COPY_OUT_VENDOR must be set to 'vendor' to use a vendor image)
endif
.KATI_READONLY := BOARD_USES_VENDORIMAGE

BUILDING_VENDOR_IMAGE :=
ifeq ($(PRODUCT_BUILD_VENDOR_IMAGE),)
  ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
    BUILDING_VENDOR_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_VENDOR_IMAGE),true)
  BUILDING_VENDOR_IMAGE := true
  ifndef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_VENDOR_IMAGE set to true, but BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_VENDORIMAGE
  BUILDING_VENDOR_IMAGE :=
endif
.KATI_READONLY := BUILDING_VENDOR_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_PRODUCT
ifeq ($(TARGET_COPY_OUT_PRODUCT),$(_product_path_placeholder))
TARGET_COPY_OUT_PRODUCT := system/product
else ifeq ($(filter product system/product,$(TARGET_COPY_OUT_PRODUCT)),)
$(error TARGET_COPY_OUT_PRODUCT must be either 'product' or 'system/product', seeing '$(TARGET_COPY_OUT_PRODUCT)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_product_path_placeholder),$(TARGET_COPY_OUT_PRODUCT),$(PRODUCT_COPY_FILES))

BOARD_USES_PRODUCTIMAGE :=
ifdef BOARD_PREBUILT_PRODUCTIMAGE
  BOARD_USES_PRODUCTIMAGE := true
endif
ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_PRODUCTIMAGE := true
endif
$(call check_image_config,product)
.KATI_READONLY := BOARD_USES_PRODUCTIMAGE

BUILDING_PRODUCT_IMAGE :=
ifeq ($(PRODUCT_BUILD_PRODUCT_IMAGE),)
  ifdef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
    BUILDING_PRODUCT_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_PRODUCT_IMAGE),true)
  BUILDING_PRODUCT_IMAGE := true
  ifndef BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_PRODUCT_IMAGE set to true, but BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_PRODUCTIMAGE
  BUILDING_PRODUCT_IMAGE :=
endif
.KATI_READONLY := BUILDING_PRODUCT_IMAGE

###########################################
# TODO(b/135957588) TARGET_COPY_OUT_PRODUCT_SERVICES will be set to
# TARGET_COPY_OUT_PRODUCT as a workaround.
TARGET_COPY_OUT_PRODUCT_SERVICES := $(TARGET_COPY_OUT_PRODUCT)

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_SYSTEM_EXT
ifeq ($(TARGET_COPY_OUT_SYSTEM_EXT),$(_system_ext_path_placeholder))
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
else ifeq ($(filter system_ext system/system_ext,$(TARGET_COPY_OUT_SYSTEM_EXT)),)
$(error TARGET_COPY_OUT_SYSTEM_EXT must be either 'system_ext' or 'system/system_ext', seeing '$(TARGET_COPY_OUT_SYSTEM_EXT)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_system_ext_path_placeholder),$(TARGET_COPY_OUT_SYSTEM_EXT),$(PRODUCT_COPY_FILES))

BOARD_USES_SYSTEM_EXTIMAGE :=
ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
  BOARD_USES_SYSTEM_EXTIMAGE := true
endif
ifdef BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_SYSTEM_EXTIMAGE := true
endif
$(call check_image_config,system_ext)
.KATI_READONLY := BOARD_USES_SYSTEM_EXTIMAGE

BUILDING_SYSTEM_EXT_IMAGE :=
ifeq ($(PRODUCT_BUILD_SYSTEM_EXT_IMAGE),)
  ifdef BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE
    BUILDING_SYSTEM_EXT_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_SYSTEM_EXT_IMAGE),true)
  BUILDING_SYSTEM_EXT_IMAGE := true
  ifndef BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_SYSTEM_EXT_IMAGE set to true, but BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
  BUILDING_SYSTEM_EXT_IMAGE :=
endif
.KATI_READONLY := BUILDING_SYSTEM_EXT_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_VENDOR_DLKM
ifeq ($(TARGET_COPY_OUT_VENDOR_DLKM),$(_vendor_dlkm_path_placeholder))
  TARGET_COPY_OUT_VENDOR_DLKM := $(TARGET_COPY_OUT_VENDOR)/vendor_dlkm
else ifeq ($(filter vendor_dlkm system/vendor/vendor_dlkm vendor/vendor_dlkm,$(TARGET_COPY_OUT_VENDOR_DLKM)),)
  $(error TARGET_COPY_OUT_VENDOR_DLKM must be either 'vendor_dlkm', 'system/vendor/vendor_dlkm' or 'vendor/vendor_dlkm', seeing '$(TARGET_COPY_OUT_VENDOR_DLKM)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_vendor_dlkm_path_placeholder),$(TARGET_COPY_OUT_VENDOR_DLKM),$(PRODUCT_COPY_FILES))

BOARD_USES_VENDOR_DLKMIMAGE :=
ifdef BOARD_PREBUILT_VENDOR_DLKMIMAGE
  BOARD_USES_VENDOR_DLKMIMAGE := true
endif
ifdef BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_VENDOR_DLKMIMAGE := true
endif
$(call check_image_config,vendor_dlkm)

BUILDING_VENDOR_DLKM_IMAGE :=
ifeq ($(PRODUCT_BUILD_VENDOR_DLKM_IMAGE),)
  ifdef BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE
    BUILDING_VENDOR_DLKM_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_VENDOR_DLKM_IMAGE),true)
  BUILDING_VENDOR_DLKM_IMAGE := true
  ifndef BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_VENDOR_DLKM_IMAGE set to true, but BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_VENDOR_DLKMIMAGE
  BUILDING_VENDOR_DLKM_IMAGE :=
endif
.KATI_READONLY := BUILDING_VENDOR_DLKM_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_ODM
ifeq ($(TARGET_COPY_OUT_ODM),$(_odm_path_placeholder))
  TARGET_COPY_OUT_ODM := $(TARGET_COPY_OUT_VENDOR)/odm
else ifeq ($(filter odm system/vendor/odm vendor/odm,$(TARGET_COPY_OUT_ODM)),)
  $(error TARGET_COPY_OUT_ODM must be either 'odm', 'system/vendor/odm' or 'vendor/odm', seeing '$(TARGET_COPY_OUT_ODM)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_odm_path_placeholder),$(TARGET_COPY_OUT_ODM),$(PRODUCT_COPY_FILES))

BOARD_USES_ODMIMAGE :=
ifdef BOARD_PREBUILT_ODMIMAGE
  BOARD_USES_ODMIMAGE := true
endif
ifdef BOARD_ODMIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_ODMIMAGE := true
endif
$(call check_image_config,odm)

BUILDING_ODM_IMAGE :=
ifeq ($(PRODUCT_BUILD_ODM_IMAGE),)
  ifdef BOARD_ODMIMAGE_FILE_SYSTEM_TYPE
    BUILDING_ODM_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_ODM_IMAGE),true)
  BUILDING_ODM_IMAGE := true
  ifndef BOARD_ODMIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_ODM_IMAGE set to true, but BOARD_ODMIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_ODMIMAGE
  BUILDING_ODM_IMAGE :=
endif
.KATI_READONLY := BUILDING_ODM_IMAGE


###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_ODM_DLKM
ifeq ($(TARGET_COPY_OUT_ODM_DLKM),$(_odm_dlkm_path_placeholder))
  TARGET_COPY_OUT_ODM_DLKM := $(TARGET_COPY_OUT_VENDOR)/odm_dlkm
else ifeq ($(filter odm_dlkm system/vendor/odm_dlkm vendor/odm_dlkm,$(TARGET_COPY_OUT_ODM_DLKM)),)
  $(error TARGET_COPY_OUT_ODM_DLKM must be either 'odm_dlkm', 'system/vendor/odm_dlkm' or 'vendor/odm_dlkm', seeing '$(TARGET_COPY_OUT_ODM_DLKM)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_odm_dlkm_path_placeholder),$(TARGET_COPY_OUT_ODM_DLKM),$(PRODUCT_COPY_FILES))

BOARD_USES_ODM_DLKMIMAGE :=
ifdef BOARD_PREBUILT_ODM_DLKMIMAGE
  BOARD_USES_ODM_DLKMIMAGE := true
endif
ifdef BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_ODM_DLKMIMAGE := true
endif
$(call check_image_config,odm_dlkm)

BUILDING_ODM_DLKM_IMAGE :=
ifeq ($(PRODUCT_BUILD_ODM_DLKM_IMAGE),)
  ifdef BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE
    BUILDING_ODM_DLKM_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_ODM_DLKM_IMAGE),true)
  BUILDING_ODM_DLKM_IMAGE := true
  ifndef BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_ODM_DLKM_IMAGE set to true, but BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_ODM_DLKMIMAGE
  BUILDING_ODM_DLKM_IMAGE :=
endif
.KATI_READONLY := BUILDING_ODM_DLKM_IMAGE

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_SYSTEM_DLKM
ifeq ($(TARGET_COPY_OUT_SYSTEM_DLKM),$(_system_dlkm_path_placeholder))
  TARGET_COPY_OUT_SYSTEM_DLKM := $(TARGET_COPY_OUT_SYSTEM)/system_dlkm
else ifeq ($(filter system_dlkm system/system_dlkm,$(TARGET_COPY_OUT_SYSTEM_DLKM)),)
  $(error TARGET_COPY_OUT_SYSTEM_DLKM must be either 'system_dlkm' or 'system/system_dlkm', seeing '$(TARGET_COPY_OUT_ODM_DLKM)'.)
endif
PRODUCT_COPY_FILES := $(subst $(_system_dlkm_path_placeholder),$(TARGET_COPY_OUT_SYSTEM_DLKM),$(PRODUCT_COPY_FILES))

BOARD_USES_SYSTEM_DLKMIMAGE :=
ifdef BOARD_PREBUILT_SYSTEM_DLKMIMAGE
  BOARD_USES_SYSTEM_DLKMIMAGE := true
endif
ifdef BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE
  BOARD_USES_SYSTEM_DLKMIMAGE := true
endif
$(call check_image_config,system_dlkm)

BUILDING_SYSTEM_DLKM_IMAGE :=
ifeq ($(PRODUCT_BUILD_SYSTEM_DLKM_IMAGE),)
  ifdef BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE
    BUILDING_SYSTEM_DLKM_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_SYSTEM_DLKM_IMAGE),true)
  BUILDING_SYSTEM_DLKM_IMAGE := true
  ifndef BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE
    $(error PRODUCT_BUILD_SYSTEM_DLKM_IMAGE set to true, but BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE not defined)
  endif
endif
ifdef BOARD_PREBUILT_SYSTEM_DLKMIMAGE
  BUILDING_SYSTEM_DLKM_IMAGE :=
endif
.KATI_READONLY := BUILDING_SYSTEM_DLKM_IMAGE

BOARD_USES_PVMFWIMAGE :=
ifeq ($(PRODUCT_BUILD_PVMFW_IMAGE),true)
  BOARD_USES_PVMFWIMAGE := true
endif
.KATI_READONLY := BOARD_USES_PVMFWIMAGE

###########################################
# Ensure consistency among TARGET_RECOVERY_UPDATER_LIBS, AB_OTA_UPDATER, and PRODUCT_OTA_FORCE_NON_AB_PACKAGE.
TARGET_RECOVERY_UPDATER_LIBS ?=
AB_OTA_UPDATER ?=
.KATI_READONLY := TARGET_RECOVERY_UPDATER_LIBS AB_OTA_UPDATER

# Ensure that if PRODUCT_OTA_FORCE_NON_AB_PACKAGE == true, then AB_OTA_UPDATER must be true
ifeq ($(PRODUCT_OTA_FORCE_NON_AB_PACKAGE),true)
  ifneq ($(AB_OTA_UPDATER),true)
    $(error AB_OTA_UPDATER must be set to true when PRODUCT_OTA_FORCE_NON_AB_PACKAGE is true)
  endif
endif

# In some configurations, A/B and non-A/B may coexist. Check TARGET_OTA_ALLOW_NON_AB
# to see if non-A/B is supported.
TARGET_OTA_ALLOW_NON_AB := false
ifneq ($(AB_OTA_UPDATER),true)
  TARGET_OTA_ALLOW_NON_AB := true
else ifeq ($(PRODUCT_OTA_FORCE_NON_AB_PACKAGE),true)
  TARGET_OTA_ALLOW_NON_AB := true
endif
.KATI_READONLY := TARGET_OTA_ALLOW_NON_AB

ifneq ($(TARGET_OTA_ALLOW_NON_AB),true)
  ifneq ($(strip $(TARGET_RECOVERY_UPDATER_LIBS)),)
    $(error Do not use TARGET_RECOVERY_UPDATER_LIBS when using TARGET_OTA_ALLOW_NON_AB)
  endif
endif

# For Non A/B full OTA, disable brotli compression.
ifeq ($(TARGET_OTA_ALLOW_NON_AB),true)
  BOARD_NON_AB_OTA_DISABLE_COMPRESSION := true
endif

# Quick check for building generic OTA packages. Currently it only supports A/B OTAs.
ifeq ($(PRODUCT_BUILD_GENERIC_OTA_PACKAGE),true)
  ifneq ($(AB_OTA_UPDATER),true)
    $(error PRODUCT_BUILD_GENERIC_OTA_PACKAGE with 'AB_OTA_UPDATER != true' is not supported)
  endif
endif

ifdef BOARD_PREBUILT_DTBIMAGE_DIR
  ifneq ($(BOARD_INCLUDE_DTB_IN_BOOTIMG),true)
    $(error BOARD_PREBUILT_DTBIMAGE_DIR with 'BOARD_INCLUDE_DTB_IN_BOOTIMG != true' is not supported)
  endif
endif

# Check BOARD_VNDK_VERSION
define check_vndk_version
  $(eval vndk_path := prebuilts/vndk/v$(1)) \
  $(if $(wildcard $(vndk_path)/*/Android.bp),,$(error VNDK version $(1) not found))
endef

ifeq ($(BOARD_VNDK_VERSION),$(PLATFORM_VNDK_VERSION))
  $(error BOARD_VNDK_VERSION is equal to PLATFORM_VNDK_VERSION; use BOARD_VNDK_VERSION := current)
endif
ifneq ($(BOARD_VNDK_VERSION),current)
  $(call check_vndk_version,$(BOARD_VNDK_VERSION))
endif
TARGET_VENDOR_TEST_SUFFIX := /vendor

ifeq (,$(TARGET_BUILD_UNBUNDLED))
ifdef PRODUCT_EXTRA_VNDK_VERSIONS
  $(foreach v,$(PRODUCT_EXTRA_VNDK_VERSIONS),$(call check_vndk_version,$(v)))
endif
endif

# Ensure that BOARD_SYSTEMSDK_VERSIONS are all within PLATFORM_SYSTEMSDK_VERSIONS
_unsupported_systemsdk_versions := $(filter-out $(PLATFORM_SYSTEMSDK_VERSIONS),$(BOARD_SYSTEMSDK_VERSIONS))
ifneq (,$(_unsupported_systemsdk_versions))
  $(error System SDK versions '$(_unsupported_systemsdk_versions)' in BOARD_SYSTEMSDK_VERSIONS are not supported.\
          Supported versions are $(PLATFORM_SYSTEMSDK_VERSIONS))
endif

###########################################
# BOARD_API_LEVEL for vendor API surface
ifdef RELEASE_BOARD_API_LEVEL
  ifdef BOARD_API_LEVEL
    $(error BOARD_API_LEVEL must not set manully. The build system automatically sets this value.)
  endif
  BOARD_API_LEVEL := $(RELEASE_BOARD_API_LEVEL)
  .KATI_READONLY := BOARD_API_LEVEL

  ifdef RELEASE_BOARD_API_LEVEL_FROZEN
    BOARD_API_LEVEL_FROZEN := true
    .KATI_READONLY := BOARD_API_LEVEL_FROZEN
  endif
endif

###########################################
# Handle BUILD_BROKEN_USES_BUILD_*

$(foreach m,$(DEFAULT_WARNING_BUILD_MODULE_TYPES),\
  $(if $(filter false,$(BUILD_BROKEN_USES_$(m))),\
    $(KATI_obsolete_var $(m),Please convert to Soong),\
    $(KATI_deprecated_var $(m),Please convert to Soong)))

$(if $(filter true,$(BUILD_BROKEN_USES_BUILD_COPY_HEADERS)),\
  $(KATI_deprecated_var BUILD_COPY_HEADERS,See $(CHANGES_URL)\#copy_headers),\
  $(KATI_obsolete_var BUILD_COPY_HEADERS,See $(CHANGES_URL)\#copy_headers))

$(foreach m,$(filter-out BUILD_COPY_HEADERS,$(DEFAULT_ERROR_BUILD_MODULE_TYPES)),\
  $(if $(filter true,$(BUILD_BROKEN_USES_$(m))),\
    $(KATI_deprecated_var $(m),Please convert to Soong),\
    $(KATI_obsolete_var $(m),Please convert to Soong)))

ifndef BUILDING_RECOVERY_IMAGE
  ifeq (true,$(BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE))
    $(error Should not set BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE if not building recovery image)
  endif
endif

ifndef BUILDING_VENDOR_BOOT_IMAGE
  ifeq (true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT))
    $(error Should not set BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT if not building vendor_boot image)
  endif
  ifdef BOARD_VENDOR_RAMDISK_FRAGMENTS
    $(error Should not set BOARD_VENDOR_RAMDISK_FRAGMENTS if not building vendor_boot image)
  endif
else # BUILDING_VENDOR_BOOT_IMAGE
  ifneq (,$(call math_lt,$(BOARD_BOOT_HEADER_VERSION),4))
    ifdef BOARD_VENDOR_RAMDISK_FRAGMENTS
      $(error Should not set BOARD_VENDOR_RAMDISK_FRAGMENTS if \
        BOARD_BOOT_HEADER_VERSION is less than 4)
    endif
    ifeq (true,$(BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT))
      $(error Should not set BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT if \
        BOARD_BOOT_HEADER_VERSION is less than 4)
    endif
  endif
endif # BUILDING_VENDOR_BOOT_IMAGE

ifneq ($(words $(BOARD_VENDOR_RAMDISK_FRAGMENTS)),$(words $(sort $(BOARD_VENDOR_RAMDISK_FRAGMENTS))))
  $(error BOARD_VENDOR_RAMDISK_FRAGMENTS has duplicate entries: $(BOARD_VENDOR_RAMDISK_FRAGMENTS))
endif

ifeq (true,$(BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT))
  ifneq (true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT))
    $(error Should not set BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT if \
      BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT is not set)
  endif
endif

# If BOARD_USES_GENERIC_KERNEL_IMAGE is set, BOARD_USES_RECOVERY_AS_BOOT must not be set.
# Devices without a dedicated recovery partition uses BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT to
# build recovery into vendor_boot.
ifeq (true,$(BOARD_USES_GENERIC_KERNEL_IMAGE))
  ifeq (true,$(BOARD_USES_RECOVERY_AS_BOOT))
    $(error BOARD_USES_RECOVERY_AS_BOOT cannot be true if BOARD_USES_GENERIC_KERNEL_IMAGE is true. \
      Use BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT instead)
  endif
endif

ifeq (true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT))
  ifeq (true,$(BOARD_USES_RECOVERY_AS_BOOT))
    $(error BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT and BOARD_USES_RECOVERY_AS_BOOT cannot be \
      both true. Recovery resources should be installed to either boot or vendor_boot, but not both)
  endif
endif
