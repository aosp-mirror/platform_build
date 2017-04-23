#
# Copyright (C) 2007 The Android Open Source Project
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

#
# Functions for including AndroidProducts.mk files
# PRODUCT_MAKEFILES is set up in AndroidProducts.mks.
# Format of PRODUCT_MAKEFILES:
# <product_name>:<path_to_the_product_makefile>
# If the <product_name> is the same as the base file name (without dir
# and the .mk suffix) of the product makefile, "<product_name>:" can be
# omitted.

# Search for AndroidProducts.mks in the given dir.
# $(1): the path to the dir
define _search-android-products-files-in-dir
$(sort $(shell test -d $(1) && find -L $(1) \
  -maxdepth 6 \
  -name .git -prune \
  -o -name AndroidProducts.mk -print))
endef

#
# Returns the list of all AndroidProducts.mk files.
# $(call ) isn't necessary.
#
define _find-android-products-files
$(foreach d, device vendor product,$(call _search-android-products-files-in-dir,$(d))) \
  $(SRC_TARGET_DIR)/product/AndroidProducts.mk
endef

#
# Returns the sorted concatenation of PRODUCT_MAKEFILES
# variables set in the given AndroidProducts.mk files.
# $(1): the list of AndroidProducts.mk files.
#
define get-product-makefiles
$(sort \
  $(foreach f,$(1), \
    $(eval PRODUCT_MAKEFILES :=) \
    $(eval LOCAL_DIR := $(patsubst %/,%,$(dir $(f)))) \
    $(eval include $(f)) \
    $(PRODUCT_MAKEFILES) \
   ) \
  $(eval PRODUCT_MAKEFILES :=) \
  $(eval LOCAL_DIR :=) \
 )
endef

#
# Returns the sorted concatenation of all PRODUCT_MAKEFILES
# variables set in all AndroidProducts.mk files.
# $(call ) isn't necessary.
#
define get-all-product-makefiles
$(call get-product-makefiles,$(_find-android-products-files))
endef

#
# Functions for including product makefiles
#

_product_var_list := \
    PRODUCT_NAME \
    PRODUCT_MODEL \
    PRODUCT_LOCALES \
    PRODUCT_AAPT_CONFIG \
    PRODUCT_AAPT_PREF_CONFIG \
    PRODUCT_AAPT_PREBUILT_DPI \
    PRODUCT_PACKAGES \
    PRODUCT_PACKAGES_PRUNE \
    PRODUCT_PACKAGES_DEBUG \
    PRODUCT_PACKAGES_DEBUG_PRUNE \
    PRODUCT_PACKAGES_ENG \
    PRODUCT_PACKAGES_ENG_PRUNE \
    PRODUCT_PACKAGES_TESTS \
    PRODUCT_PACKAGES_TESTS_PRUNE \
    PRODUCT_DEVICE \
    PRODUCT_MANUFACTURER \
    PRODUCT_BRAND \
    PRODUCT_PROPERTY_OVERRIDES \
    PRODUCT_DEFAULT_PROPERTY_OVERRIDES \
    PRODUCT_CHARACTERISTICS \
    PRODUCT_COPY_FILES \
    PRODUCT_COPY_FILES_PRUNE \
    PRODUCT_OTA_PUBLIC_KEYS \
    PRODUCT_EXTRA_RECOVERY_KEYS \
    PRODUCT_PACKAGE_OVERLAYS \
    DEVICE_PACKAGE_OVERLAYS \
    PRODUCT_ENFORCE_RRO_TARGETS \
    PRODUCT_SDK_ATREE_FILES \
    PRODUCT_SDK_ADDON_NAME \
    PRODUCT_SDK_ADDON_COPY_FILES \
    PRODUCT_SDK_ADDON_COPY_MODULES \
    PRODUCT_SDK_ADDON_DOC_MODULES \
    PRODUCT_SDK_ADDON_SYS_IMG_SOURCE_PROP \
    PRODUCT_DEFAULT_WIFI_CHANNELS \
    PRODUCT_DEFAULT_DEV_CERTIFICATE \
    PRODUCT_RESTRICT_VENDOR_FILES \
    PRODUCT_VENDOR_KERNEL_HEADERS \
    PRODUCT_BOOT_JARS \
    PRODUCT_SUPPORTS_BOOT_SIGNER \
    PRODUCT_BOOT_JARS_PRUNE \
    PRODUCT_SUPPORTS_VBOOT \
    PRODUCT_SUPPORTS_VERITY \
    PRODUCT_SUPPORTS_VERITY_FEC \
    PRODUCT_OEM_PROPERTIES \
    PRODUCT_SYSTEM_PROPERTY_BLACKLIST \
    PRODUCT_SYSTEM_SERVER_JARS \
    PRODUCT_VBOOT_SIGNING_KEY \
    PRODUCT_VBOOT_SIGNING_SUBKEY \
    PRODUCT_VERITY_SIGNING_KEY \
    PRODUCT_SYSTEM_VERITY_PARTITION \
    PRODUCT_VENDOR_VERITY_PARTITION \
    PRODUCT_DEX_PREOPT_MODULE_CONFIGS \
    PRODUCT_DEX_PREOPT_DEFAULT_FLAGS \
    PRODUCT_DEX_PREOPT_BOOT_FLAGS \
    PRODUCT_SANITIZER_MODULE_CONFIGS \
    PRODUCT_SYSTEM_BASE_FS_PATH \
    PRODUCT_VENDOR_BASE_FS_PATH \
    PRODUCT_SHIPPING_API_LEVEL \
    VENDOR_PRODUCT_RESTRICT_VENDOR_FILES \
    VENDOR_EXCEPTION_MODULES \
    VENDOR_EXCEPTION_PATHS \
    PRODUCT_ART_USE_READ_BARRIER \
    PRODUCT_IOT \



define dump-product
$(info ==== $(1) ====)\
$(foreach v,$(_product_var_list),\
$(info PRODUCTS.$(1).$(v) := $(PRODUCTS.$(1).$(v))))\
$(info --------)
endef

define dump-products
$(foreach p,$(PRODUCTS),$(call dump-product,$(p)))
endef

#
# $(1): product to inherit
#
# Does three things:
#  1. Inherits all of the variables from $1.
#  2. Records the inheritance in the .INHERITS_FROM variable
#  3. Records that we've visited this node, in ALL_PRODUCTS
#
define inherit-product
  $(if $(findstring ../,$(1)),\
    $(eval np := $(call normalize-paths,$(1))),\
    $(eval np := $(strip $(1))))\
  $(foreach v,$(_product_var_list), \
      $(eval $(v) := $($(v)) $(INHERIT_TAG)$(np))) \
  $(eval inherit_var := \
      PRODUCTS.$(strip $(word 1,$(_include_stack))).INHERITS_FROM) \
  $(eval $(inherit_var) := $(sort $($(inherit_var)) $(np))) \
  $(eval inherit_var:=) \
  $(eval ALL_PRODUCTS := $(sort $(ALL_PRODUCTS) $(word 1,$(_include_stack))))
endef


#
# Do inherit-product only if $(1) exists
#
define inherit-product-if-exists
  $(if $(wildcard $(1)),$(call inherit-product,$(1)),)
endef

#
# $(1): product makefile list
#
#TODO: check to make sure that products have all the necessary vars defined
define import-products
$(call import-nodes,PRODUCTS,$(1),$(_product_var_list))
endef


#
# Does various consistency checks on all of the known products.
# Takes no parameters, so $(call ) is not necessary.
#
define check-all-products
$(if ,, \
  $(eval _cap_names :=) \
  $(foreach p,$(PRODUCTS), \
    $(eval pn := $(strip $(PRODUCTS.$(p).PRODUCT_NAME))) \
    $(if $(pn),,$(error $(p): PRODUCT_NAME must be defined.)) \
    $(if $(filter $(pn),$(_cap_names)), \
      $(error $(p): PRODUCT_NAME must be unique; "$(pn)" already used by $(strip \
          $(foreach \
            pp,$(PRODUCTS),
              $(if $(filter $(pn),$(PRODUCTS.$(pp).PRODUCT_NAME)), \
                $(pp) \
               ))) \
       ) \
     ) \
    $(eval _cap_names += $(pn)) \
    $(if $(call is-c-identifier,$(pn)),, \
      $(error $(p): PRODUCT_NAME must be a valid C identifier, not "$(pn)") \
     ) \
    $(eval pb := $(strip $(PRODUCTS.$(p).PRODUCT_BRAND))) \
    $(if $(pb),,$(error $(p): PRODUCT_BRAND must be defined.)) \
    $(foreach cf,$(strip $(PRODUCTS.$(p).PRODUCT_COPY_FILES)), \
      $(if $(filter 2 3,$(words $(subst :,$(space),$(cf)))),, \
        $(error $(p): malformed COPY_FILE "$(cf)") \
       ) \
     ) \
   ) \
)
endef


#
# Returns the product makefile path for the product with the provided name
#
# $(1): short product name like "generic"
#
define _resolve-short-product-name
  $(eval pn := $(strip $(1)))
  $(eval p := \
      $(foreach p,$(PRODUCTS), \
          $(if $(filter $(pn),$(PRODUCTS.$(p).PRODUCT_NAME)), \
            $(p) \
       )) \
   )
  $(eval p := $(sort $(p)))
  $(if $(filter 1,$(words $(p))), \
    $(p), \
    $(if $(filter 0,$(words $(p))), \
      $(error No matches for product "$(pn)"), \
      $(error Product "$(pn)" ambiguous: matches $(p)) \
    ) \
  )
endef
define resolve-short-product-name
$(strip $(call _resolve-short-product-name,$(1)))
endef


_product_stash_var_list := $(_product_var_list) \
	PRODUCT_BOOTCLASSPATH \
	PRODUCT_SYSTEM_SERVER_CLASSPATH \
	TARGET_ARCH \
	TARGET_ARCH_VARIANT \
	TARGET_CPU_VARIANT \
	TARGET_BOARD_PLATFORM \
	TARGET_BOARD_PLATFORM_GPU \
	TARGET_BOARD_KERNEL_HEADERS \
	TARGET_DEVICE_KERNEL_HEADERS \
	TARGET_PRODUCT_KERNEL_HEADERS \
	TARGET_BOOTLOADER_BOARD_NAME \
	TARGET_NO_BOOTLOADER \
	TARGET_NO_KERNEL \
	TARGET_NO_RECOVERY \
	TARGET_NO_RADIOIMAGE \
	TARGET_HARDWARE_3D \
	TARGET_CPU_ABI \
	TARGET_CPU_ABI2 \


_product_stash_var_list += \
	BOARD_WPA_SUPPLICANT_DRIVER \
	BOARD_WLAN_DEVICE \
	BOARD_USES_GENERIC_AUDIO \
	BOARD_KERNEL_CMDLINE \
	BOARD_KERNEL_BASE \
	BOARD_HAVE_BLUETOOTH \
	BOARD_VENDOR_USE_AKMD \
	BOARD_EGL_CFG \
	BOARD_BOOTIMAGE_PARTITION_SIZE \
	BOARD_RECOVERYIMAGE_PARTITION_SIZE \
	BOARD_SYSTEMIMAGE_PARTITION_SIZE \
	BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE \
	BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE \
	BOARD_USERDATAIMAGE_PARTITION_SIZE \
	BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE \
	BOARD_CACHEIMAGE_PARTITION_SIZE \
	BOARD_FLASH_BLOCK_SIZE \
	BOARD_VENDORIMAGE_PARTITION_SIZE \
	BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE \
	BOARD_INSTALLER_CMDLINE \


_product_stash_var_list += \
	DEFAULT_SYSTEM_DEV_CERTIFICATE \
	WITH_DEXPREOPT \
	WITH_DEXPREOPT_BOOT_IMG_ONLY \
	WITH_DEXPREOPT_APP_IMAGE

#
# Mark the variables in _product_stash_var_list as readonly
#
define readonly-product-vars
$(foreach v,$(_product_stash_var_list), \
	$(eval $(v) ?=) \
	$(eval .KATI_READONLY := $(v)) \
 )
endef

define add-to-product-copy-files-if-exists
$(if $(wildcard $(word 1,$(subst :, ,$(1)))),$(1))
endef

# whitespace placeholder when we record module's dex-preopt config.
_PDPMC_SP_PLACE_HOLDER := |@SP@|
# Set up dex-preopt config for a module.
# $(1) list of module names
# $(2) the modules' dex-preopt config
define add-product-dex-preopt-module-config
$(eval _c := $(subst $(space),$(_PDPMC_SP_PLACE_HOLDER),$(strip $(2))))\
$(eval PRODUCT_DEX_PREOPT_MODULE_CONFIGS += \
  $(foreach m,$(1),$(m)=$(_c)))
endef

# whitespace placeholder when we record module's sanitizer config.
_PSMC_SP_PLACE_HOLDER := |@SP@|
# Set up sanitizer config for a module.
# $(1) list of module names
# $(2) the modules' sanitizer config
define add-product-sanitizer-module-config
$(eval _c := $(subst $(space),$(_PSMC_SP_PLACE_HOLDER),$(strip $(2))))\
$(eval PRODUCT_SANITIZER_MODULE_CONFIGS += \
  $(foreach m,$(1),$(m)=$(_c)))
endef
