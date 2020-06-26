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

#
# Returns the list of all AndroidProducts.mk files.
# $(call ) isn't necessary.
#
define _find-android-products-files
$(file <$(OUT_DIR)/.module_paths/AndroidProducts.mk.list) \
  $(SRC_TARGET_DIR)/product/AndroidProducts.mk
endef

#
# For entries returned by get-product-makefiles, decode an entry to a short
# product name. These either may be in the form of <name>:path/to/file.mk or
# path/to/<name>.mk
# $(1): The entry to decode
#
# Returns two words:
#   <name> <file>
#
define _decode-product-name
$(strip \
  $(eval _cpm_words := $(subst :,$(space),$(1))) \
  $(if $(word 2,$(_cpm_words)), \
    $(wordlist 1,2,$(_cpm_words)), \
    $(basename $(notdir $(1))) $(1)))
endef

#
# Validates the new common lunch choices -- ensures that they're in an
# appropriate form, and are paired with definitions of their products.
# $(1): The new list of COMMON_LUNCH_CHOICES
# $(2): The new list of PRODUCT_MAKEFILES
#
define _validate-common-lunch-choices
$(strip $(foreach choice,$(1),\
  $(eval _parts := $(subst -,$(space),$(choice))) \
  $(if $(call math_lt,$(words $(_parts)),2), \
    $(error $(LOCAL_DIR): $(choice): Invalid lunch choice)) \
  $(if $(call math_gt_or_eq,$(words $(_parts)),4), \
    $(error $(LOCAL_DIR): $(choice): Invalid lunch choice)) \
  $(if $(filter-out eng userdebug user,$(word 2,$(_parts))), \
    $(error $(LOCAL_DIR): $(choice): Invalid variant: $(word 2,$(_parts)))) \
  $(if $(filter-out $(foreach p,$(2),$(call _decode-product-name,$(p))),$(word 1,$(_parts))), \
    $(error $(LOCAL_DIR): $(word 1,$(_parts)): Product not defined in this file)) \
  ))
endef

#
# Returns the sorted concatenation of PRODUCT_MAKEFILES
# variables set in the given AndroidProducts.mk files.
# $(1): the list of AndroidProducts.mk files.
#
# As a side-effect, COMMON_LUNCH_CHOICES will be set to a
# union of all of the COMMON_LUNCH_CHOICES definitions within
# each AndroidProducts.mk file.
#
define get-product-makefiles
$(sort \
  $(eval _COMMON_LUNCH_CHOICES :=) \
  $(foreach f,$(1), \
    $(eval PRODUCT_MAKEFILES :=) \
    $(eval COMMON_LUNCH_CHOICES :=) \
    $(eval LOCAL_DIR := $(patsubst %/,%,$(dir $(f)))) \
    $(eval include $(f)) \
    $(call _validate-common-lunch-choices,$(COMMON_LUNCH_CHOICES),$(PRODUCT_MAKEFILES)) \
    $(eval _COMMON_LUNCH_CHOICES += $(COMMON_LUNCH_CHOICES)) \
    $(PRODUCT_MAKEFILES) \
   ) \
  $(eval PRODUCT_MAKEFILES :=) \
  $(eval LOCAL_DIR :=) \
  $(eval COMMON_LUNCH_CHOICES := $(sort $(_COMMON_LUNCH_CHOICES))) \
  $(eval _COMMON_LUNCH_CHOICES :=) \
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

# Variables that are meant to hold only a single value.
# - The value set in the current makefile takes precedence over inherited values
# - If multiple inherited makefiles set the var, the first-inherited value wins
_product_single_value_vars :=

# Variables that are lists of values.
_product_list_vars :=

_product_single_value_vars += PRODUCT_NAME
_product_single_value_vars += PRODUCT_MODEL

# The resoure configuration options to use for this product.
_product_list_vars += PRODUCT_LOCALES
_product_list_vars += PRODUCT_AAPT_CONFIG
_product_list_vars += PRODUCT_AAPT_PREF_CONFIG
_product_list_vars += PRODUCT_AAPT_PREBUILT_DPI
_product_list_vars += PRODUCT_HOST_PACKAGES
_product_list_vars += PRODUCT_PACKAGES
_product_list_vars += PRODUCT_PACKAGES_DEBUG
_product_list_vars += PRODUCT_PACKAGES_DEBUG_ASAN
# Packages included only for eng/userdebug builds, when building with EMMA_INSTRUMENT=true
_product_list_vars += PRODUCT_PACKAGES_DEBUG_JAVA_COVERAGE
_product_list_vars += PRODUCT_PACKAGES_ENG
_product_list_vars += PRODUCT_PACKAGES_TESTS

# The device that this product maps to.
_product_single_value_vars += PRODUCT_DEVICE
_product_single_value_vars += PRODUCT_MANUFACTURER
_product_single_value_vars += PRODUCT_BRAND

# These PRODUCT_SYSTEM_* flags, if defined, are used in place of the
# corresponding PRODUCT_* flags for the sysprops on /system.
_product_single_value_vars += \
    PRODUCT_SYSTEM_NAME \
    PRODUCT_SYSTEM_MODEL \
    PRODUCT_SYSTEM_DEVICE \
    PRODUCT_SYSTEM_BRAND \
    PRODUCT_SYSTEM_MANUFACTURER \

# A list of property assignments, like "key = value", with zero or more
# whitespace characters on either side of the '='.
_product_list_vars += PRODUCT_PROPERTY_OVERRIDES

# A list of property assignments, like "key = value", with zero or more
# whitespace characters on either side of the '='.
# used for adding properties to default.prop
_product_list_vars += PRODUCT_DEFAULT_PROPERTY_OVERRIDES

# A list of property assignments, like "key = value", with zero or more
# whitespace characters on either side of the '='.
# used for adding properties to build.prop of product partition
_product_list_vars += PRODUCT_PRODUCT_PROPERTIES

# A list of property assignments, like "key = value", with zero or more
# whitespace characters on either side of the '='.
# used for adding properties to build.prop of system_ext and odm partitions
_product_list_vars += PRODUCT_SYSTEM_EXT_PROPERTIES
_product_list_vars += PRODUCT_ODM_PROPERTIES

# The characteristics of the product, which among other things is passed to aapt
_product_single_value_vars += PRODUCT_CHARACTERISTICS

# A list of words like <source path>:<destination path>[:<owner>].
# The file at the source path should be copied to the destination path
# when building  this product.  <destination path> is relative to
# $(PRODUCT_OUT), so it should look like, e.g., "system/etc/file.xml".
# The rules for these copy steps are defined in build/make/core/Makefile.
# The optional :<owner> is used to indicate the owner of a vendor file.
_product_list_vars += PRODUCT_COPY_FILES

# The OTA key(s) specified by the product config, if any.  The names
# of these keys are stored in the target-files zip so that post-build
# signing tools can substitute them for the test key embedded by
# default.
_product_list_vars += PRODUCT_OTA_PUBLIC_KEYS
_product_list_vars += PRODUCT_EXTRA_RECOVERY_KEYS

# Should we use the default resources or add any product specific overlays
_product_list_vars += PRODUCT_PACKAGE_OVERLAYS
_product_list_vars += DEVICE_PACKAGE_OVERLAYS

# Resource overlay list which must be excluded from enforcing RRO.
_product_list_vars += PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS

# Package list to apply enforcing RRO.
_product_list_vars += PRODUCT_ENFORCE_RRO_TARGETS

# Packages to skip auto-generating RROs for when PRODUCT_ENFORCE_RRO_TARGETS is set to *.
_product_list_vars += PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS

_product_list_vars += PRODUCT_SDK_ATREE_FILES
_product_list_vars += PRODUCT_SDK_ADDON_NAME
_product_list_vars += PRODUCT_SDK_ADDON_COPY_FILES
_product_list_vars += PRODUCT_SDK_ADDON_COPY_MODULES
_product_list_vars += PRODUCT_SDK_ADDON_DOC_MODULES
_product_list_vars += PRODUCT_SDK_ADDON_SYS_IMG_SOURCE_PROP

# which Soong namespaces to export to Make
_product_list_vars += PRODUCT_SOONG_NAMESPACES

_product_list_vars += PRODUCT_DEFAULT_WIFI_CHANNELS
_product_list_vars += PRODUCT_DEFAULT_DEV_CERTIFICATE
_product_list_vars += PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES
_product_list_vars += PRODUCT_RESTRICT_VENDOR_FILES

# The list of product-specific kernel header dirs
_product_list_vars += PRODUCT_VENDOR_KERNEL_HEADERS

# A list of module names of BOOTCLASSPATH (jar files)
_product_list_vars += PRODUCT_BOOT_JARS

# A list of extra BOOTCLASSPATH jars (to be appended after common jars).
# Products that include device-specific makefiles before AOSP makefiles should use this
# instead of PRODUCT_BOOT_JARS, so that device-specific jars go after common jars.
_product_list_vars += PRODUCT_BOOT_JARS_EXTRA

_product_list_vars += PRODUCT_SUPPORTS_BOOT_SIGNER
_product_list_vars += PRODUCT_SUPPORTS_VBOOT
_product_list_vars += PRODUCT_SUPPORTS_VERITY
_product_list_vars += PRODUCT_SUPPORTS_VERITY_FEC
_product_list_vars += PRODUCT_OEM_PROPERTIES

# A list of property assignments, like "key = value", with zero or more
# whitespace characters on either side of the '='.
# used for adding properties to default.prop of system partition
_product_list_vars += PRODUCT_SYSTEM_DEFAULT_PROPERTIES

_product_list_vars += PRODUCT_SYSTEM_PROPERTY_BLACKLIST
_product_list_vars += PRODUCT_VENDOR_PROPERTY_BLACKLIST
_product_list_vars += PRODUCT_SYSTEM_SERVER_APPS
_product_list_vars += PRODUCT_SYSTEM_SERVER_JARS
# List of system_server jars delivered via apex. Format = <apex name>:<jar name>.
_product_list_vars += PRODUCT_UPDATABLE_SYSTEM_SERVER_JARS

# Additional system server jars to be appended at the end of the common list.
# This is necessary to avoid jars reordering due to makefile inheritance order.
_product_list_vars += PRODUCT_SYSTEM_SERVER_JARS_EXTRA

# All of the apps that we force preopt, this overrides WITH_DEXPREOPT.
_product_list_vars += PRODUCT_ALWAYS_PREOPT_EXTRACTED_APK
_product_list_vars += PRODUCT_DEXPREOPT_SPEED_APPS
_product_list_vars += PRODUCT_LOADED_BY_PRIVILEGED_MODULES
_product_single_value_vars += PRODUCT_VBOOT_SIGNING_KEY
_product_single_value_vars += PRODUCT_VBOOT_SIGNING_SUBKEY
_product_single_value_vars += PRODUCT_VERITY_SIGNING_KEY
_product_single_value_vars += PRODUCT_SYSTEM_VERITY_PARTITION
_product_single_value_vars += PRODUCT_VENDOR_VERITY_PARTITION
_product_single_value_vars += PRODUCT_PRODUCT_VERITY_PARTITION
_product_single_value_vars += PRODUCT_SYSTEM_EXT_VERITY_PARTITION
_product_single_value_vars += PRODUCT_ODM_VERITY_PARTITION
_product_single_value_vars += PRODUCT_SYSTEM_SERVER_DEBUG_INFO
_product_single_value_vars += PRODUCT_OTHER_JAVA_DEBUG_INFO

# Per-module dex-preopt configs.
_product_list_vars += PRODUCT_DEX_PREOPT_MODULE_CONFIGS
_product_list_vars += PRODUCT_DEX_PREOPT_DEFAULT_COMPILER_FILTER
_product_list_vars += PRODUCT_DEX_PREOPT_DEFAULT_FLAGS
_product_list_vars += PRODUCT_DEX_PREOPT_BOOT_FLAGS
_product_list_vars += PRODUCT_DEX_PREOPT_PROFILE_DIR
_product_list_vars += PRODUCT_DEX_PREOPT_GENERATE_DM_FILES
_product_list_vars += PRODUCT_DEX_PREOPT_NEVER_ALLOW_STRIPPING
_product_list_vars += PRODUCT_DEX_PREOPT_RESOLVE_STARTUP_STRINGS

# Boot image options.
_product_single_value_vars += \
    PRODUCT_USE_PROFILE_FOR_BOOT_IMAGE \
    PRODUCT_DEX_PREOPT_BOOT_IMAGE_PROFILE_LOCATION \
    PRODUCT_USES_DEFAULT_ART_CONFIG \

_product_list_vars += PRODUCT_SYSTEM_SERVER_COMPILER_FILTER
# Per-module sanitizer configs
_product_list_vars += PRODUCT_SANITIZER_MODULE_CONFIGS
_product_single_value_vars += PRODUCT_SYSTEM_BASE_FS_PATH
_product_single_value_vars += PRODUCT_VENDOR_BASE_FS_PATH
_product_single_value_vars += PRODUCT_PRODUCT_BASE_FS_PATH
_product_single_value_vars += PRODUCT_SYSTEM_EXT_BASE_FS_PATH
_product_single_value_vars += PRODUCT_ODM_BASE_FS_PATH

# The first API level this product shipped with
_product_single_value_vars += PRODUCT_SHIPPING_API_LEVEL

_product_list_vars += VENDOR_PRODUCT_RESTRICT_VENDOR_FILES
_product_list_vars += VENDOR_EXCEPTION_MODULES
_product_list_vars += VENDOR_EXCEPTION_PATHS
# Whether the product wants to ship libartd. For rules and meaning, see art/Android.mk.
_product_single_value_vars += PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD

# Make this art variable visible to soong_config.mk.
_product_single_value_vars += PRODUCT_ART_USE_READ_BARRIER

# Add reserved headroom to a system image.
_product_single_value_vars += PRODUCT_SYSTEM_HEADROOM

# Whether to save disk space by minimizing java debug info
_product_single_value_vars += PRODUCT_MINIMIZE_JAVA_DEBUG_INFO

# Whether any paths are excluded from sanitization when SANITIZE_TARGET=integer_overflow
_product_list_vars += PRODUCT_INTEGER_OVERFLOW_EXCLUDE_PATHS

_product_single_value_vars += PRODUCT_ADB_KEYS

# Whether any paths should have CFI enabled for components
_product_list_vars += PRODUCT_CFI_INCLUDE_PATHS

# Whether any paths are excluded from sanitization when SANITIZE_TARGET=cfi
_product_list_vars += PRODUCT_CFI_EXCLUDE_PATHS

# Whether the Scudo hardened allocator is disabled platform-wide
_product_single_value_vars += PRODUCT_DISABLE_SCUDO

# A flag to override PRODUCT_COMPATIBLE_PROPERTY
_product_single_value_vars += PRODUCT_COMPATIBLE_PROPERTY_OVERRIDE

# List of extra VNDK versions to be included
_product_list_vars += PRODUCT_EXTRA_VNDK_VERSIONS

# VNDK version of product partition. It can be 'current' if the product
# partitions uses PLATFORM_VNDK_VERSION.
_product_single_value_var += PRODUCT_PRODUCT_VNDK_VERSION

# Whether the list of allowed of actionable compatible properties should be disabled or not
_product_single_value_vars += PRODUCT_ACTIONABLE_COMPATIBLE_PROPERTY_DISABLE

_product_single_value_vars += PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS
_product_single_value_vars += PRODUCT_ENFORCE_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT
_product_list_vars += PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_ALLOW_LIST
_product_list_vars += PRODUCT_ARTIFACT_PATH_REQUIREMENT_HINT
_product_list_vars += PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST

# List of modules that should be forcefully unmarked from being LOCAL_PRODUCT_MODULE, and hence
# installed on /system directory by default.
_product_list_vars += PRODUCT_FORCE_PRODUCT_MODULES_TO_SYSTEM_PARTITION

# When this is true, dynamic partitions is retrofitted on a device that has
# already been launched without dynamic partitions. Otherwise, the device
# is launched with dynamic partitions.
# This flag implies PRODUCT_USE_DYNAMIC_PARTITIONS.
_product_single_value_vars += PRODUCT_RETROFIT_DYNAMIC_PARTITIONS

# Other dynamic partition feature flags.PRODUCT_USE_DYNAMIC_PARTITION_SIZE and
# PRODUCT_BUILD_SUPER_PARTITION default to the value of PRODUCT_USE_DYNAMIC_PARTITIONS.
_product_single_value_vars += \
    PRODUCT_USE_DYNAMIC_PARTITIONS \
    PRODUCT_USE_DYNAMIC_PARTITION_SIZE \
    PRODUCT_BUILD_SUPER_PARTITION \

# If set, kernel configuration requirements are present in OTA package (and will be enforced
# during OTA). Otherwise, kernel configuration requirements are enforced in VTS.
# Devices that checks the running kernel (instead of the kernel in OTA package) should not
# set this variable to prevent OTA failures.
_product_list_vars += PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS

# If set to true, this product builds a generic OTA package, which installs generic system images
# onto matching devices. The product may only build a subset of system images (e.g. only
# system.img), so devices need to install the package in a system-only OTA manner.
_product_single_value_vars += PRODUCT_BUILD_GENERIC_OTA_PACKAGE

_product_list_vars += PRODUCT_MANIFEST_PACKAGE_NAME_OVERRIDES
_product_list_vars += PRODUCT_PACKAGE_NAME_OVERRIDES
_product_list_vars += PRODUCT_CERTIFICATE_OVERRIDES

# Controls for whether different partitions are built for the current product.
_product_single_value_vars += PRODUCT_BUILD_SYSTEM_IMAGE
_product_single_value_vars += PRODUCT_BUILD_SYSTEM_OTHER_IMAGE
_product_single_value_vars += PRODUCT_BUILD_VENDOR_IMAGE
_product_single_value_vars += PRODUCT_BUILD_PRODUCT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_SYSTEM_EXT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_ODM_IMAGE
_product_single_value_vars += PRODUCT_BUILD_CACHE_IMAGE
_product_single_value_vars += PRODUCT_BUILD_RAMDISK_IMAGE
_product_single_value_vars += PRODUCT_BUILD_USERDATA_IMAGE
_product_single_value_vars += PRODUCT_BUILD_RECOVERY_IMAGE
_product_single_value_vars += PRODUCT_BUILD_BOOT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_VBMETA_IMAGE

# List of boot jars delivered via apex
_product_list_vars += PRODUCT_UPDATABLE_BOOT_JARS

# Whether the product would like to check prebuilt ELF files.
_product_single_value_vars += PRODUCT_CHECK_ELF_FILES

# If set, device uses virtual A/B.
_product_single_value_vars += PRODUCT_VIRTUAL_AB_OTA

# If set, device retrofits virtual A/B.
_product_single_value_vars += PRODUCT_VIRTUAL_AB_OTA_RETROFIT

# If set, forcefully generate a non-A/B update package.
# Note: A device configuration should inherit from virtual_ab_ota_plus_non_ab.mk
# instead of setting this variable directly.
# Note: Use TARGET_OTA_ALLOW_NON_AB in the build system because
# TARGET_OTA_ALLOW_NON_AB takes the value of AB_OTA_UPDATER into account.
_product_single_value_vars += PRODUCT_OTA_FORCE_NON_AB_PACKAGE

# If set, Java module in product partition cannot use hidden APIs.
_product_single_value_vars += PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE

_product_single_value_vars += PRODUCT_INSTALL_EXTRA_FLATTENED_APEXES

.KATI_READONLY := _product_single_value_vars _product_list_vars
_product_var_list :=$= $(_product_single_value_vars) $(_product_list_vars)

define dump-product
$(warning ==== $(1) ====)\
$(foreach v,$(_product_var_list),\
$(warning PRODUCTS.$(1).$(v) := $(call get-product-var,$(1),$(v))))\
$(warning --------)
endef

define dump-products
$(foreach p,$(PRODUCTS),$(call dump-product,$(p)))
endef

#
# Functions for including product makefiles
#

#
# $(1): product to inherit
#
# To be called from product makefiles, and is later evaluated during the import-nodes
# call below. It does three things:
#  1. Inherits all of the variables from $1.
#  2. Records the inheritance in the .INHERITS_FROM variable
#  3. Records the calling makefile in PARENT_PRODUCT_FILES
#
# (2) and (3) can be used together to reconstruct the include hierarchy
# See e.g. product-graph.mk for an example of this.
#
define inherit-product
  $(if $(findstring ../,$(1)),\
    $(eval np := $(call normalize-paths,$(1))),\
    $(eval np := $(strip $(1))))\
  $(foreach v,$(_product_var_list), \
      $(eval $(v) := $($(v)) $(INHERIT_TAG)$(np))) \
  $(eval current_mk := $(strip $(word 1,$(_include_stack)))) \
  $(eval inherit_var := PRODUCTS.$(current_mk).INHERITS_FROM) \
  $(eval $(inherit_var) := $(sort $($(inherit_var)) $(np))) \
  $(eval PARENT_PRODUCT_FILES := $(sort $(PARENT_PRODUCT_FILES) $(current_mk)))
endef

# Specifies a number of path prefixes, relative to PRODUCT_OUT, where the
# product makefile hierarchy rooted in the current node places its artifacts.
# Creating artifacts outside the specified paths will cause a build-time error.
define require-artifacts-in-path
  $(eval current_mk := $(strip $(word 1,$(_include_stack)))) \
  $(eval PRODUCTS.$(current_mk).ARTIFACT_PATH_REQUIREMENTS := $(strip $(1))) \
  $(eval PRODUCTS.$(current_mk).ARTIFACT_PATH_ALLOWED_LIST := $(strip $(2))) \
  $(eval ARTIFACT_PATH_REQUIREMENT_PRODUCTS := \
    $(sort $(ARTIFACT_PATH_REQUIREMENT_PRODUCTS) $(current_mk)))
endef

# Makes including non-existent modules in PRODUCT_PACKAGES an error.
# $(1): list of non-existent modules to allow.
define enforce-product-packages-exist
  $(eval current_mk := $(strip $(word 1,$(_include_stack)))) \
  $(eval PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST := true) \
  $(eval PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST := $(1)) \
  $(eval .KATI_READONLY := PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST) \
  $(eval .KATI_READONLY := PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST)
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
$(call import-nodes,PRODUCTS,$(1),$(_product_var_list),$(_product_single_value_vars))
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

# BoardConfig variables that are also inherited in product mks. Should ideally
# be cleaned up to not be product variables.
_readonly_late_variables := \
  DEVICE_PACKAGE_OVERLAYS \
  WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY \

# Modified internally in the build system
_readonly_late_variables += \
  PRODUCT_COPY_FILES \
  PRODUCT_DEX_PREOPT_NEVER_ALLOW_STRIPPING \
  PRODUCT_DEX_PREOPT_BOOT_FLAGS \

_readonly_early_variables := $(filter-out $(_readonly_late_variables),$(_product_var_list))

#
# Mark the variables in _product_stash_var_list as readonly
#
define readonly-variables
$(foreach v,$(1), \
  $(eval $(v) ?=) \
  $(eval .KATI_READONLY := $(v)) \
 )
endef
define readonly-product-vars
$(call readonly-variables,$(_readonly_early_variables))
endef

define readonly-final-product-vars
$(call readonly-variables,$(_readonly_late_variables))
endef

# Macro re-defined inside strip-product-vars.
get-product-var = $(PRODUCTS.$(strip $(1)).$(2))
#
# Strip the variables in _product_var_list and a few build-system
# internal variables, and assign the ones for the current product
# to a shorthand that is more convenient to read from elsewhere.
#
define strip-product-vars
$(foreach v,\
  $(_product_var_list) \
    PRODUCT_ENFORCE_PACKAGES_EXIST \
    PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST, \
  $(eval $(v) := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).$(v)))) \
  $(eval get-product-var = $$(if $$(filter $$(1),$$(INTERNAL_PRODUCT)),$$($$(2)),$$(PRODUCTS.$$(strip $$(1)).$$(2)))) \
  $(KATI_obsolete_var PRODUCTS.$(INTERNAL_PRODUCT).$(v),Use $(v) instead) \
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
