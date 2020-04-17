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
# and sanity-checks the variable defined therein.
# ###############################################################

_board_strip_readonly_list := \
  BOARD_EGL_CFG \
  BOARD_HAVE_BLUETOOTH \
  BOARD_INSTALLER_CMDLINE \
  BOARD_KERNEL_CMDLINE \
  BOARD_KERNEL_BASE \
  BOARD_USES_GENERIC_AUDIO \
  BOARD_USES_RECOVERY_AS_BOOT \
  BOARD_VENDOR_USE_AKMD \
  BOARD_WPA_SUPPLICANT_DRIVER \
  BOARD_WLAN_DEVICE \
  TARGET_ARCH \
  TARGET_ARCH_VARIANT \
  TARGET_CPU_ABI \
  TARGET_CPU_ABI2 \
  TARGET_CPU_VARIANT \
  TARGET_CPU_VARIANT_RUNTIME \
  TARGET_2ND_ARCH \
  TARGET_2ND_ARCH_VARIANT \
  TARGET_2ND_CPU_ABI \
  TARGET_2ND_CPU_ABI2 \
  TARGET_2ND_CPU_VARIANT \
  TARGET_2ND_CPU_VARIANT_RUNTIME \
  TARGET_BOARD_PLATFORM \
  TARGET_BOARD_PLATFORM_GPU \
  TARGET_BOOTLOADER_BOARD_NAME \
  TARGET_FS_CONFIG_GEN \
  TARGET_NO_BOOTLOADER \
  TARGET_NO_KERNEL \
  TARGET_NO_RECOVERY \
  TARGET_NO_RADIOIMAGE \
  TARGET_HARDWARE_3D \
  WITH_DEXPREOPT \

# File system variables
_board_strip_readonly_list += \
  BOARD_FLASH_BLOCK_SIZE \
  BOARD_BOOTIMAGE_PARTITION_SIZE \
  BOARD_RECOVERYIMAGE_PARTITION_SIZE \
  BOARD_SYSTEMIMAGE_PARTITION_SIZE \
  BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE \
  BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE \
  BOARD_USERDATAIMAGE_PARTITION_SIZE \
  BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE \
  BOARD_CACHEIMAGE_PARTITION_SIZE \
  BOARD_VENDORIMAGE_PARTITION_SIZE \
  BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE \
  BOARD_PRODUCTIMAGE_PARTITION_SIZE \
  BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE \
  BOARD_SYSTEM_EXTIMAGE_PARTITION_SIZE \
  BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE \
  BOARD_ODMIMAGE_PARTITION_SIZE \
  BOARD_ODMIMAGE_FILE_SYSTEM_TYPE \

# Logical partitions related variables.
_dynamic_partitions_var_list += \
  BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE \
  BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE \
  BOARD_ODMIMAGE_PARTITION_RESERVED_SIZE \
  BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE \
  BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE \
  BOARD_SUPER_PARTITION_SIZE \
  BOARD_SUPER_PARTITION_GROUPS \

_board_strip_readonly_list += $(_dynamic_partitions_var_list)

_build_broken_var_list := \
  BUILD_BROKEN_DUP_RULES \
  BUILD_BROKEN_OUTSIDE_INCLUDE_DIRS \
  BUILD_BROKEN_PREBUILT_ELF_FILES \
  BUILD_BROKEN_TREBLE_SYSPROP_NEVERALLOW \
  BUILD_BROKEN_USES_NETWORK \
  BUILD_BROKEN_VINTF_PRODUCT_COPY_FILES \

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
  WITH_DEXPREOPT := true
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
include $(board_config_mk)
ifeq ($(TARGET_ARCH),)
  $(error TARGET_ARCH not defined by board config: $(board_config_mk))
endif
ifneq ($(MALLOC_IMPL),)
  $(warning *** Unsupported option MALLOC_IMPL defined by board config: $(board_config_mk).)
  $(error Use `MALLOC_SVELTE := true` to configure jemalloc for low-memory)
endif
board_config_mk :=

# Clean up and verify BoardConfig variables
$(foreach var,$(_board_strip_readonly_list),$(eval $(var) := $$(strip $$($(var)))))
$(foreach var,$(_board_true_false_vars), \
  $(if $(filter-out true false,$($(var))), \
    $(error Valid values of $(var) are "true", "false", and "". Not "$($(var))")))

# Default *_CPU_VARIANT_RUNTIME to CPU_VARIANT if unspecified.
TARGET_CPU_VARIANT_RUNTIME := $(or $(TARGET_CPU_VARIANT_RUNTIME),$(TARGET_CPU_VARIANT))
TARGET_2ND_CPU_VARIANT_RUNTIME := $(or $(TARGET_2ND_CPU_VARIANT_RUNTIME),$(TARGET_2ND_CPU_VARIANT))

# The combo makefiles sanity-check and set defaults for various CPU configuration
combo_target := TARGET_
combo_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/combo/select.mk

ifdef TARGET_2ND_ARCH
  combo_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
  include $(BUILD_SYSTEM)/combo/select.mk
endif

.KATI_READONLY := $(_board_strip_readonly_list)

INTERNAL_KERNEL_CMDLINE := $(BOARD_KERNEL_CMDLINE)
ifeq ($(TARGET_CPU_ABI),)
  $(error No TARGET_CPU_ABI defined by board config: $(board_config_mk))
endif
ifneq ($(filter %64,$(TARGET_ARCH)),)
  TARGET_IS_64_BIT := true
endif

ifeq (,$(filter true,$(TARGET_SUPPORTS_32_BIT_APPS) $(TARGET_SUPPORTS_64_BIT_APPS)))
  TARGET_SUPPORTS_32_BIT_APPS := true
endif

# Sanity check to warn about likely cryptic errors later in the build.
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
  ifeq ($(TARGET_IS_64_BIT)|$(TARGET_PREFER_32_BIT_APPS),true|true)
    TARGET_CPU_ABI_LIST := $(TARGET_CPU_ABI_LIST_32_BIT) $(TARGET_CPU_ABI_LIST_64_BIT) \
                           $(_target_native_bridge_abi_list_32_bit) $(_target_native_bridge_abi_list_64_bit)
  else
    TARGET_CPU_ABI_LIST := $(TARGET_CPU_ABI_LIST_64_BIT) $(TARGET_CPU_ABI_LIST_32_BIT) \
                           $(_target_native_bridge_abi_list_64_bit) $(_target_native_bridge_abi_list_32_bit)
  endif
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
# Now we can substitute with the real value of TARGET_COPY_OUT_RAMDISK
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
TARGET_COPY_OUT_RAMDISK := $(TARGET_COPY_OUT_ROOT)
endif

###########################################
# Now we can substitute with the real value of TARGET_COPY_OUT_DEBUG_RAMDISK
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
TARGET_COPY_OUT_DEBUG_RAMDISK := debug_ramdisk/first_stage_ramdisk
TARGET_COPY_OUT_VENDOR_DEBUG_RAMDISK := vendor_debug_ramdisk/first_stage_ramdisk
TARGET_COPY_OUT_TEST_HARNESS_RAMDISK := test_harness_ramdisk/first_stage_ramdisk
endif

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
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
  BUILDING_BOOT_IMAGE :=
else ifeq ($(PRODUCT_BUILD_BOOT_IMAGE),)
  ifdef BOARD_BOOTIMAGE_PARTITION_SIZE
    BUILDING_BOOT_IMAGE := true
  endif
else ifeq ($(PRODUCT_BUILD_BOOT_IMAGE),true)
  BUILDING_BOOT_IMAGE := true
endif
.KATI_READONLY := BUILDING_BOOT_IMAGE

# Are we building a recovery image
BUILDING_RECOVERY_IMAGE :=
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
  BUILDING_RECOVERY_IMAGE := true
else ifeq ($(PRODUCT_BUILD_RECOVERY_IMAGE),)
  ifdef BOARD_RECOVERYIMAGE_PARTITION_SIZE
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
    ifneq ($(TARGET_NO_VENDOR_BOOT),true)
      BUILDING_VENDOR_BOOT_IMAGE := true
    endif
  endif
endif
.KATI_READONLY := BUILDING_VENDOR_BOOT_IMAGE

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

# Sanity check for building generic OTA packages. Currently it only supports A/B OTAs.
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

ifdef BOARD_VNDK_VERSION
  ifneq ($(BOARD_VNDK_VERSION),current)
    $(call check_vndk_version,$(BOARD_VNDK_VERSION))
  endif
  TARGET_VENDOR_TEST_SUFFIX := /vendor
else
  TARGET_VENDOR_TEST_SUFFIX :=
endif

###########################################
# APEXes are by default flattened, i.e. non-updatable.
# It can be unflattened (and updatable) by inheriting from
# updatable_apex.mk
#
# APEX flattening can also be forcibly enabled (resp. disabled) by
# setting OVERRIDE_TARGET_FLATTEN_APEX to true (resp. false), e.g. by
# setting the OVERRIDE_TARGET_FLATTEN_APEX environment variable.
ifdef OVERRIDE_TARGET_FLATTEN_APEX
  TARGET_FLATTEN_APEX := $(OVERRIDE_TARGET_FLATTEN_APEX)
else
  ifeq (,$(TARGET_FLATTEN_APEX))
    TARGET_FLATTEN_APEX := true
  endif
endif

ifeq (,$(TARGET_BUILD_APPS))
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
# Handle BUILD_BROKEN_USES_BUILD_*

$(foreach m,$(DEFAULT_WARNING_BUILD_MODULE_TYPES),\
  $(if $(filter false,$(BUILD_BROKEN_USES_$(m))),\
    $(KATI_obsolete_var $(m),Please convert to Soong),\
    $(KATI_deprecated_var $(m),Please convert to Soong)))

$(if $(filter true,$(BUILD_BROKEN_USES_BUILD_COPY_HEADERS)),\
  $(KATI_deprecated_var BUILD_COPY_HEADERS,See $(CHANGES_URL)#copy_headers),\
  $(KATI_obsolete_var BUILD_COPY_HEADERS,See $(CHANGES_URL)#copy_headers))

$(foreach m,$(filter-out BUILD_COPY_HEADERS,$(DEFAULT_ERROR_BUILD_MODULE_TYPES)),\
  $(if $(filter true,$(BUILD_BROKEN_USES_$(m))),\
    $(KATI_deprecated_var $(m),Please convert to Soong),\
    $(KATI_obsolete_var $(m),Please convert to Soong)))
