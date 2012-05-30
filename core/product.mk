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
#

#
# Returns the list of all AndroidProducts.mk files.
# $(call ) isn't necessary.
#
define _find-android-products-files
$(shell test -d device && find device -maxdepth 6 -name AndroidProducts.mk) \
  $(shell test -d vendor && find vendor -maxdepth 6 -name AndroidProducts.mk) \
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
    PRODUCT_PACKAGES \
    PRODUCT_DEVICE \
    PRODUCT_MANUFACTURER \
    PRODUCT_BRAND \
    PRODUCT_PROPERTY_OVERRIDES \
    PRODUCT_DEFAULT_PROPERTY_OVERRIDES \
    PRODUCT_CHARACTERISTICS \
    PRODUCT_COPY_FILES \
    PRODUCT_OTA_PUBLIC_KEYS \
    PRODUCT_EXTRA_RECOVERY_KEYS \
    PRODUCT_PACKAGE_OVERLAYS \
    DEVICE_PACKAGE_OVERLAYS \
    PRODUCT_TAGS \
    PRODUCT_SDK_ADDON_NAME \
    PRODUCT_SDK_ADDON_COPY_FILES \
    PRODUCT_SDK_ADDON_COPY_MODULES \
    PRODUCT_SDK_ADDON_DOC_MODULES \
    PRODUCT_DEFAULT_WIFI_CHANNELS \
    PRODUCT_DEFAULT_DEV_CERTIFICATE \
    PRODUCT_RESTRICT_VENDOR_FILES \
    PRODUCT_FACTORY_RAMDISK_MODULES \
    PRODUCT_VENDOR_KERNEL_HEADERS \


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
  $(foreach v,$(_product_var_list), \
      $(eval $(v) := $($(v)) $(INHERIT_TAG)$(strip $(1)))) \
  $(eval inherit_var := \
      PRODUCTS.$(strip $(word 1,$(_include_stack))).INHERITS_FROM) \
  $(eval $(inherit_var) := $(sort $($(inherit_var)) $(strip $(1)))) \
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
      $(if $(filter 2,$(words $(subst :,$(space),$(cf)))),, \
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
	TARGET_ARCH \
	TARGET_ARCH_VARIANT \
	TARGET_BOARD_PLATFORM \
	TARGET_BOARD_PLATFORM_GPU \
	TARGET_BOARD_KERNEL_HEADERS \
	TARGET_DEVICE_KERNEL_HEADERS \
	TARGET_PRODUCT_KERNEL_HEADERS \
	TARGET_BOOTLOADER_BOARD_NAME \
	TARGET_COMPRESS_MODULE_SYMBOLS \
	TARGET_NO_BOOTLOADER \
	TARGET_NO_KERNEL \
	TARGET_NO_RECOVERY \
	TARGET_NO_RADIOIMAGE \
	TARGET_HARDWARE_3D \
	TARGET_PROVIDES_INIT_RC \
	TARGET_CPU_ABI \
	TARGET_CPU_ABI2 \
	TARGET_CPU_SMP \


_product_stash_var_list += \
	BOARD_WPA_SUPPLICANT_DRIVER \
	BOARD_WLAN_DEVICE \
	BOARD_USES_GENERIC_AUDIO \
	BOARD_KERNEL_CMDLINE \
	BOARD_KERNEL_BASE \
	BOARD_HAVE_BLUETOOTH \
	BOARD_HAVE_BLUETOOTH_BCM \
	BOARD_VENDOR_QCOM_AMSS_VERSION \
	BOARD_VENDOR_USE_AKMD \
	BOARD_EGL_CFG \
	BOARD_BOOTIMAGE_PARTITION_SIZE \
	BOARD_RECOVERYIMAGE_PARTITION_SIZE \
	BOARD_SYSTEMIMAGE_PARTITION_SIZE \
	BOARD_USERDATAIMAGE_PARTITION_SIZE \
	BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE \
	BOARD_CACHEIMAGE_PARTITION_SIZE \
	BOARD_FLASH_BLOCK_SIZE \
	BOARD_SYSTEMIMAGE_PARTITION_SIZE \
	BOARD_VENDOR_QCOM_GPS_LOC_API_HARDWARE \
	BOARD_VENDOR_QCOM_GPS_LOC_API_AMSS_VERSION \
	BOARD_INSTALLER_CMDLINE \


_product_stash_var_list += \
	DEFAULT_SYSTEM_DEV_CERTIFICATE

#
# Stash vaues of the variables in _product_stash_var_list.
# $(1): Renamed prefix
#
define stash-product-vars
$(foreach v,$(_product_stash_var_list), \
        $(eval $(strip $(1))_$(call rot13,$(v)):=$$($$(v))) \
 )
endef

#
# Assert that the the variable stashed by stash-product-vars remains untouched.
# $(1): The prefix as supplied to stash-product-vars
#
define assert-product-vars
$(strip \
  $(eval changed_variables:=)
  $(foreach v,$(_product_stash_var_list), \
    $(if $(call streq,$($(v)),$($(strip $(1))_$(call rot13,$(v)))),, \
        $(eval $(warning $(v) has been modified: $($(v)))) \
        $(eval $(warning previous value: $($(strip $(1))_$(call rot13,$(v))))) \
        $(eval changed_variables := $(changed_variables) $(v))) \
   ) \
  $(if $(changed_variables),\
    $(eval $(error The following variables have been changed: $(changed_variables))),)
)
endef

define add-to-product-copy-files-if-exists
$(if $(wildcard $(word 1,$(subst :, ,$(1)))),$(1))
endef
