#
# Copyright (C) 2008 The Android Open Source Project
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

# ---------------------------------------------------------------
# Generic functions
# TODO: Move these to definitions.make once we're able to include
# definitions.make before config.make.

###########################################################
## Return non-empty if $(1) is a C identifier; i.e., if it
## matches /^[a-zA-Z_][a-zA-Z0-9_]*$/.  We do this by first
## making sure that it isn't empty and doesn't start with
## a digit, then by removing each valid character.  If the
## final result is empty, then it was a valid C identifier.
##
## $(1): word to check
###########################################################

_ici_digits := 0 1 2 3 4 5 6 7 8 9
_ici_alphaunderscore := \
    a b c d e f g h i j k l m n o p q r s t u v w x y z \
    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z _
define is-c-identifier
$(strip \
  $(if $(1), \
    $(if $(filter $(addsuffix %,$(_ici_digits)),$(1)), \
     , \
      $(eval w := $(1)) \
      $(foreach c,$(_ici_digits) $(_ici_alphaunderscore), \
        $(eval w := $(subst $(c),,$(w))) \
       ) \
      $(if $(w),,TRUE) \
      $(eval w :=) \
     ) \
   ) \
 )
endef

# TODO: push this into the combo files; unfortunately, we don't even
# know HOST_OS at this point.
trysed := $(shell echo a | sed -E -e 's/a/b/' 2>/dev/null)
ifeq ($(trysed),b)
  SED_EXTENDED := sed -E
else
  trysed := $(shell echo c | sed -r -e 's/c/d/' 2>/dev/null)
  ifeq ($(trysed),d)
    SED_EXTENDED := sed -r
  else
    $(error Unknown sed version)
  endif
endif

###########################################################
## List all of the files in a subdirectory in a format
## suitable for PRODUCT_COPY_FILES and
## PRODUCT_SDK_ADDON_COPY_FILES
##
## $(1): Glob to match file name
## $(2): Source directory
## $(3): Target base directory
###########################################################

define find-copy-subdir-files
$(shell find $(2) -name "$(1)" -type f | $(SED_EXTENDED) "s:($(2)/?(.*)):\\1\\:$(3)/\\2:" | sed "s://:/:g" | sort)
endef

#
# Convert file file to the PRODUCT_COPY_FILES/PRODUCT_SDK_ADDON_COPY_FILES
# format: for each file F return $(F):$(PREFIX)/$(notdir $(F))
# $(1): files list
# $(2): prefix

define copy-files
$(foreach f,$(1),$(f):$(2)/$(notdir $(f)))
endef

#
# Convert the list of file names to the list of PRODUCT_COPY_FILES items
# $(1): from pattern
# $(2): to pattern
# $(3): file names
# E.g., calling product-copy-files-by-pattern with
#   (from/%, to/%, a b)
# returns
#   from/a:to/a from/b:to/b
define product-copy-files-by-pattern
$(join $(patsubst %,$(1),$(3)),$(patsubst %,:$(2),$(3)))
endef

# Return empty unless the board matches
define is-board-platform2
$(filter $(1), $(TARGET_BOARD_PLATFORM))
endef

# Return empty unless the board is in the list
define is-board-platform-in-list2
$(filter $(1),$(TARGET_BOARD_PLATFORM))
endef

# Return empty unless the board is QCOM
define is-vendor-board-qcom
$(if $(strip $(TARGET_BOARD_PLATFORM) $(QCOM_BOARD_PLATFORMS)),$(filter $(TARGET_BOARD_PLATFORM),$(QCOM_BOARD_PLATFORMS)),\
  $(error both TARGET_BOARD_PLATFORM=$(TARGET_BOARD_PLATFORM) and QCOM_BOARD_PLATFORMS=$(QCOM_BOARD_PLATFORMS)))
endef

# ---------------------------------------------------------------
# Check for obsolete PRODUCT- and APP- goals
ifeq ($(CALLED_FROM_SETUP),true)
product_goals := $(strip $(filter PRODUCT-%,$(MAKECMDGOALS)))
ifdef product_goals
  $(error The PRODUCT-* goal is no longer supported. Use `TARGET_PRODUCT=<product> m droid` instead)
endif
unbundled_goals := $(strip $(filter APP-%,$(MAKECMDGOALS)))
ifdef unbundled_goals
  $(error The APP-* goal is no longer supported. Use `TARGET_BUILD_APPS="<app>" m droid` instead)
endif # unbundled_goals
endif

# Default to building dalvikvm on hosts that support it...
ifeq ($(HOST_OS),linux)
# ... or if the if the option is already set
ifeq ($(WITH_HOST_DALVIK),)
  WITH_HOST_DALVIK := true
endif
endif

# ---------------------------------------------------------------
# Include the product definitions.
# We need to do this to translate TARGET_PRODUCT into its
# underlying TARGET_DEVICE before we start defining any rules.
#
include $(BUILD_SYSTEM)/node_fns.mk
include $(BUILD_SYSTEM)/product.mk

# Read all product definitions.
#
# Products are defined in AndroidProducts.mk files:
android_products_makefiles := $(file <$(OUT_DIR)/.module_paths/AndroidProducts.mk.list) \
  $(SRC_TARGET_DIR)/product/AndroidProducts.mk

# An AndroidProduct.mk file sets the following variables:
#   PRODUCT_MAKEFILES specifies product makefiles. Each item in this list
#     is either a <product>:path/to/file.mk, or just path/to/<product.mk>
#   COMMON_LUNCH_CHOICES specifies <product>-<variant> values to be shown
#     in the `lunch` menu
#   STARLARK_OPT_IN_PRODUCTS specifies products to use Starlark-based
#     product configuration by default

# Builds a list of first/second elements of each pair:
#   $(call _first,a:A b:B,:) returns 'a b'
#   $(call _second,a-A b-B,-) returns 'A B'
_first=$(filter-out $(2)%,$(subst $(2),$(space)$(2),$(1)))
_second=$(filter-out %$(2),$(subst $(2),$(2)$(space),$(1)))

# Returns <product>:<path> pair from a PRODUCT_MAKEFILE item.
# If an item is <product>:path/to/file.mk, return it as is,
# otherwise assume that an item is path/to/<product>.mk and
# return <product>:path/to/<product>.mk
_product-spec=$(strip $(if $(findstring :,$(1)),$(1),$(basename $(notdir $(1))):$(1)))

# Reads given AndroidProduct.mk file and sets the following variables:
#  ap_product_paths -- the list of <product>:<path> pairs
#  ap_common_lunch_choices -- the list of <product>-<build variant> items
#  ap_products_using_starlark_config -- the list of products using starlark config
# In addition, validates COMMON_LUNCH_CHOICES and STARLARK_OPT_IN_PRODUCTS values
define _read-ap-file
  $(eval PRODUCT_MAKEFILES :=) \
  $(eval COMMON_LUNCH_CHOICES :=) \
  $(eval STARLARK_OPT_IN_PRODUCTS := ) \
  $(eval ap_product_paths :=) \
  $(eval LOCAL_DIR := $(patsubst %/,%,$(dir $(f)))) \
  $(eval include $(f)) \
  $(foreach p, $(PRODUCT_MAKEFILES),$(eval ap_product_paths += $(call _product-spec,$(p)))) \
  $(eval ap_common_lunch_choices  := $(COMMON_LUNCH_CHOICES)) \
  $(eval ap_products_using_starlark_config := $(STARLARK_OPT_IN_PRODUCTS)) \
  $(eval _products := $(call _first,$(ap_product_paths),:)) \
  $(eval _bad := $(filter-out $(_products),$(call _first,$(ap_common_lunch_choices),-))) \
  $(if $(_bad),$(error COMMON_LUNCH_CHOICES contains products(s) not defined in this file: $(_bad))) \
  $(eval _bad := $(filter-out %-eng %-userdebug %-user,$(ap_common_lunch_choices))) \
  $(if $(_bad),$(error invalid variant in COMMON_LUNCH_CHOICES: $(_bad)))
  $(eval _bad := $(filter-out $(_products),$(ap_products_using_starlark_config))) \
  $(if $(_bad),$(error STARLARK_OPT_IN_PRODUCTS contains product(s) not defined in this file: $(_bad)))
endef

# Build cumulative lists of all product specs/lunch choices/Starlark-based products.
product_paths :=
common_lunch_choices :=
products_using_starlark_config :=
$(foreach f,$(android_products_makefiles), \
    $(call _read-ap-file,$(f)) \
    $(eval product_paths += $(ap_product_paths)) \
    $(eval common_lunch_choices += $(ap_common_lunch_choices)) \
    $(eval products_using_starlark_config += $(ap_products_using_starlark_config)) \
)

# Dedup, extract product names, etc.
product_paths := $(sort $(product_paths))
all_named_products := $(sort $(call _first,$(product_paths),:))
current_product_makefile := $(call _second,$(filter $(TARGET_PRODUCT):%,$(product_paths)),:)
COMMON_LUNCH_CHOICES := $(sort $(common_lunch_choices))

# Check that there are no duplicate product names
$(foreach p,$(all_named_products), \
  $(if $(filter 1,$(words $(filter $(p):%,$(product_paths)))),, \
    $(error Product name must be unique, "$(p)" used by $(call _second,$(filter $(p):%,$(product_paths)),:))))

ifneq ($(ALLOW_RULES_IN_PRODUCT_CONFIG),)
_product_config_saved_KATI_ALLOW_RULES := $(.KATI_ALLOW_RULES)
.KATI_ALLOW_RULES := $(ALLOW_RULES_IN_PRODUCT_CONFIG)
endif

ifeq (,$(current_product_makefile))
  $(error Cannot locate config makefile for product "$(TARGET_PRODUCT)")
endif

ifneq (,$(filter $(TARGET_PRODUCT),$(products_using_starlark_config)))
  RBC_PRODUCT_CONFIG := true
endif

ifndef RBC_PRODUCT_CONFIG
$(call import-products, $(current_product_makefile))
else
  $(shell mkdir -p $(OUT_DIR)/rbc)
  $(call dump-variables-rbc, $(OUT_DIR)/rbc/make_vars_pre_product_config.mk)

  $(shell $(OUT_DIR)/mk2rbc \
    --mode=write -r --outdir $(OUT_DIR)/rbc \
    --launcher=$(OUT_DIR)/rbc/launcher.rbc \
    --input_variables=$(OUT_DIR)/rbc/make_vars_pre_product_config.mk \
    --makefile_list=$(OUT_DIR)/.module_paths/configuration.list \
    $(current_product_makefile))
  ifneq ($(.SHELLSTATUS),0)
    $(error product configuration converter failed: $(.SHELLSTATUS))
  endif

  $(shell build/soong/scripts/update_out $(OUT_DIR)/rbc/rbc_product_config_results.mk \
    $(OUT_DIR)/rbcrun --mode=rbc $(OUT_DIR)/rbc/launcher.rbc)
  ifneq ($(.SHELLSTATUS),0)
    $(error product configuration runner failed: $(.SHELLSTATUS))
  endif

  include $(OUT_DIR)/rbc/rbc_product_config_results.mk
endif

# This step was already handled in the RBC product configuration.
ifeq ($(RBC_PRODUCT_CONFIG)$(SKIP_ARTIFACT_PATH_REQUIREMENT_PRODUCTS_CHECK),)
# Import all the products that have made artifact path requirements, so that we can verify
# the artifacts they produce. They might be intermediate makefiles instead of real products.
$(foreach makefile,$(ARTIFACT_PATH_REQUIREMENT_PRODUCTS),\
  $(if $(filter-out $(makefile),$(PRODUCTS)),$(eval $(call import-products,$(makefile))))\
)
endif

INTERNAL_PRODUCT := $(current_product_makefile)
# Strip and assign the PRODUCT_ variables.
$(call strip-product-vars)

# Quick check
$(check-current-product)

ifneq ($(ALLOW_RULES_IN_PRODUCT_CONFIG),)
.KATI_ALLOW_RULES := $(_saved_KATI_ALLOW_RULES)
_product_config_saved_KATI_ALLOW_RULES :=
endif

############################################################################

current_product_makefile :=

#############################################################################
# Check product include tag allowlist
BLUEPRINT_INCLUDE_TAGS_ALLOWLIST := \
  com.android.mainline_go \
  com.android.mainline \
  mainline_module_prebuilt_nightly \
  mainline_module_prebuilt_monthly_release
.KATI_READONLY := BLUEPRINT_INCLUDE_TAGS_ALLOWLIST
$(foreach include_tag,$(PRODUCT_INCLUDE_TAGS), \
	$(if $(filter $(include_tag),$(BLUEPRINT_INCLUDE_TAGS_ALLOWLIST)),,\
	$(call pretty-error, $(include_tag) is not in BLUEPRINT_INCLUDE_TAGS_ALLOWLIST: $(BLUEPRINT_INCLUDE_TAGS_ALLOWLIST))))
# Create default PRODUCT_INCLUDE_TAGS
ifeq (, $(PRODUCT_INCLUDE_TAGS))
# Soong analysis is global: even though a module might not be relevant to a specific product (e.g. build_tools for aosp_arm),
# we still analyse it.
# This means that in setups where we two have two prebuilts of module_sdk, we need a "default" to use in analysis
# This should be a no-op in aosp and internal since no Android.bp file contains blueprint_package_includes
# Use the big android one and main-based prebuilts by default
PRODUCT_INCLUDE_TAGS += com.android.mainline mainline_module_prebuilt_nightly
endif

# AOSP and Google products currently share the same `apex_contributions` in next.
# This causes issues when building <aosp_product>-next-userdebug in main.
# Create a temporary allowlist to ignore the google apexes listed in `contents` of apex_contributions of `next`
# *for aosp products*.
# TODO(b/308187268): Remove this denylist mechanism
# Use PRODUCT_PACKAGES to determine if this is an aosp product. aosp products do not use google signed apexes.
ignore_apex_contributions :=
ifeq (,$(findstring com.google.android.conscrypt,$(PRODUCT_PACKAGES)))
  ignore_apex_contributions := true
endif
ifeq (true,$(PRODUCT_MODULE_BUILD_FROM_SOURCE))
  ignore_apex_contributions := true
endif
ifeq (true, $(ignore_apex_contributions))
PRODUCT_BUILD_IGNORE_APEX_CONTRIBUTION_CONTENTS += \
  prebuilt_com.google.android.adservices \
  prebuilt_com.google.android.appsearch \
  prebuilt_com.google.android.art \
  prebuilt_com.google.android.btservices \
  prebuilt_com.google.android.configinfrastructure \
  prebuilt_com.google.android.conscrypt \
  prebuilt_com.google.android.devicelock \
  prebuilt_com.google.android.healthfitness \
  prebuilt_com.google.android.ipsec \
  prebuilt_com.google.android.media \
  prebuilt_com.google.android.mediaprovider \
  prebuilt_com.google.android.ondevicepersonalization \
  prebuilt_com.google.android.os.statsd \
  prebuilt_com.google.android.rkpd \
  prebuilt_com.google.android.scheduling \
  prebuilt_com.google.android.sdkext \
  prebuilt_com.google.android.tethering \
  prebuilt_com.google.android.uwb \
  prebuilt_com.google.android.wifi
endif

#############################################################################

# Quick check and assign default values

TARGET_DEVICE := $(PRODUCT_DEVICE)

# TODO: also keep track of things like "port", "land" in product files.

# Figure out which resoure configuration options to use for this
# product.
# If CUSTOM_LOCALES contains any locales not already included
# in PRODUCT_LOCALES, add them to PRODUCT_LOCALES.
extra_locales := $(filter-out $(PRODUCT_LOCALES),$(CUSTOM_LOCALES))
ifneq (,$(extra_locales))
  ifneq ($(CALLED_FROM_SETUP),true)
    # Don't spam stdout, because envsetup.sh may be scraping values from it.
    $(info Adding CUSTOM_LOCALES [$(extra_locales)] to PRODUCT_LOCALES [$(PRODUCT_LOCALES)])
  endif
  PRODUCT_LOCALES += $(extra_locales)
  extra_locales :=
endif

# Add PRODUCT_LOCALES to PRODUCT_AAPT_CONFIG
PRODUCT_AAPT_CONFIG := $(PRODUCT_LOCALES) $(PRODUCT_AAPT_CONFIG)

# Keep a copy of the space-separated config
PRODUCT_AAPT_CONFIG_SP := $(PRODUCT_AAPT_CONFIG)
PRODUCT_AAPT_CONFIG := $(subst $(space),$(comma),$(PRODUCT_AAPT_CONFIG))

###########################################################
## Add 'platform:' prefix to jars not in <apex>:<module> format.
##
## This makes sure that a jar corresponds to ConfigureJarList format of <apex> and <module> pairs
## where needed.
##
## $(1): a list of jars either in <module> or <apex>:<module> format
###########################################################

define qualify-platform-jars
  $(foreach jar,$(1),$(if $(findstring :,$(jar)),,platform:)$(jar))
endef

# Extra boot jars must be appended at the end after common boot jars.
PRODUCT_BOOT_JARS += $(PRODUCT_BOOT_JARS_EXTRA)

PRODUCT_BOOT_JARS := $(call qualify-platform-jars,$(PRODUCT_BOOT_JARS))

# b/191127295: force core-icu4j onto boot image. It comes from a non-updatable APEX jar, but has
# historically been part of the boot image; even though APEX jars are not meant to be part of the
# boot image.
# TODO(b/191686720): remove PRODUCT_APEX_BOOT_JARS to avoid a special handling of core-icu4j
# in make rules.
PRODUCT_APEX_BOOT_JARS := $(filter-out com.android.i18n:core-icu4j,$(PRODUCT_APEX_BOOT_JARS))
# All APEX jars come after /system and /system_ext jars, so adding core-icu4j at the end of the list
PRODUCT_BOOT_JARS += com.android.i18n:core-icu4j

# The extra system server jars must be appended at the end after common system server jars.
PRODUCT_SYSTEM_SERVER_JARS += $(PRODUCT_SYSTEM_SERVER_JARS_EXTRA)

PRODUCT_SYSTEM_SERVER_JARS := $(call qualify-platform-jars,$(PRODUCT_SYSTEM_SERVER_JARS))

# Sort APEX boot and system server jars. We use deterministic alphabetical order
# when constructing BOOTCLASSPATH and SYSTEMSERVERCLASSPATH definition on device
# after an update. Enforce it in the build system as well to avoid recompiling
# everything after an update due a change in the order.
PRODUCT_APEX_BOOT_JARS := $(sort $(PRODUCT_APEX_BOOT_JARS))
PRODUCT_APEX_SYSTEM_SERVER_JARS := $(sort $(PRODUCT_APEX_SYSTEM_SERVER_JARS))

PRODUCT_STANDALONE_SYSTEM_SERVER_JARS := \
  $(call qualify-platform-jars,$(PRODUCT_STANDALONE_SYSTEM_SERVER_JARS))

ifndef PRODUCT_SYSTEM_NAME
  PRODUCT_SYSTEM_NAME := $(PRODUCT_NAME)
endif
ifndef PRODUCT_SYSTEM_DEVICE
  PRODUCT_SYSTEM_DEVICE := $(PRODUCT_DEVICE)
endif
ifndef PRODUCT_SYSTEM_BRAND
  PRODUCT_SYSTEM_BRAND := $(PRODUCT_BRAND)
endif
ifndef PRODUCT_MODEL
  PRODUCT_MODEL := $(PRODUCT_NAME)
endif
ifndef PRODUCT_SYSTEM_MODEL
  PRODUCT_SYSTEM_MODEL := $(PRODUCT_MODEL)
endif

ifndef PRODUCT_MANUFACTURER
  PRODUCT_MANUFACTURER := unknown
endif
ifndef PRODUCT_SYSTEM_MANUFACTURER
  PRODUCT_SYSTEM_MANUFACTURER := $(PRODUCT_MANUFACTURER)
endif

ifndef PRODUCT_CHARACTERISTICS
  TARGET_AAPT_CHARACTERISTICS := default
else
  TARGET_AAPT_CHARACTERISTICS := $(PRODUCT_CHARACTERISTICS)
endif

ifdef PRODUCT_DEFAULT_DEV_CERTIFICATE
  ifneq (1,$(words $(PRODUCT_DEFAULT_DEV_CERTIFICATE)))
    $(error PRODUCT_DEFAULT_DEV_CERTIFICATE='$(PRODUCT_DEFAULT_DEV_CERTIFICATE)', \
      only 1 certificate is allowed.)
  endif
endif

$(foreach pair,$(PRODUCT_APEX_BOOT_JARS), \
  $(eval jar := $(call word-colon,2,$(pair))) \
  $(if $(findstring $(jar), $(PRODUCT_BOOT_JARS)), \
    $(error A jar in PRODUCT_APEX_BOOT_JARS must not be in PRODUCT_BOOT_JARS, but $(jar) is)))

ENFORCE_SYSTEM_CERTIFICATE := $(PRODUCT_ENFORCE_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT)
ENFORCE_SYSTEM_CERTIFICATE_ALLOW_LIST := $(PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_ALLOW_LIST)

PRODUCT_OTA_PUBLIC_KEYS := $(sort $(PRODUCT_OTA_PUBLIC_KEYS))
PRODUCT_EXTRA_OTA_KEYS := $(sort $(PRODUCT_EXTRA_OTA_KEYS))
PRODUCT_EXTRA_RECOVERY_KEYS := $(sort $(PRODUCT_EXTRA_RECOVERY_KEYS))

PRODUCT_VALIDATION_CHECKS := $(sort $(PRODUCT_VALIDATION_CHECKS))

# Resolve and setup per-module dex-preopt configs.
DEXPREOPT_DISABLED_MODULES :=
# If a module has multiple setups, the first takes precedence.
_pdpmc_modules :=
$(foreach c,$(PRODUCT_DEX_PREOPT_MODULE_CONFIGS),\
  $(eval m := $(firstword $(subst =,$(space),$(c))))\
  $(if $(filter $(_pdpmc_modules),$(m)),,\
    $(eval _pdpmc_modules += $(m))\
    $(eval cf := $(patsubst $(m)=%,%,$(c)))\
    $(eval cf := $(subst $(_PDPMC_SP_PLACE_HOLDER),$(space),$(cf)))\
    $(if $(filter disable,$(cf)),\
      $(eval DEXPREOPT_DISABLED_MODULES += $(m)),\
      $(eval DEXPREOPT.$(TARGET_PRODUCT).$(m).CONFIG := $(cf)))))
_pdpmc_modules :=


# Resolve and setup per-module sanitizer configs.
# If a module has multiple setups, the first takes precedence.
_psmc_modules :=
$(foreach c,$(PRODUCT_SANITIZER_MODULE_CONFIGS),\
  $(eval m := $(firstword $(subst =,$(space),$(c))))\
  $(if $(filter $(_psmc_modules),$(m)),,\
    $(eval _psmc_modules += $(m))\
    $(eval cf := $(patsubst $(m)=%,%,$(c)))\
    $(eval cf := $(subst $(_PSMC_SP_PLACE_HOLDER),$(space),$(cf)))\
    $(eval SANITIZER.$(TARGET_PRODUCT).$(m).CONFIG := $(cf))))
_psmc_modules :=

# Reset ADB keys for non-debuggable builds
ifeq (,$(filter eng userdebug,$(TARGET_BUILD_VARIANT)))
  PRODUCT_ADB_KEYS :=
endif
ifneq ($(filter-out 0 1,$(words $(PRODUCT_ADB_KEYS))),)
  $(error Only one file may be in PRODUCT_ADB_KEYS: $(PRODUCT_ADB_KEYS))
endif

# Show a warning wall of text if non-compliance-GSI products set this option.
ifdef PRODUCT_INSTALL_DEBUG_POLICY_TO_SYSTEM_EXT
  ifeq (,$(filter gsi_arm gsi_arm64 gsi_x86 gsi_x86_64 gsi_car_arm64 gsi_car_x86_64 gsi_tv_arm gsi_tv_arm64,$(PRODUCT_NAME)))
    $(warning PRODUCT_INSTALL_DEBUG_POLICY_TO_SYSTEM_EXT is set but \
      PRODUCT_NAME ($(PRODUCT_NAME)) doesn't look like a GSI for compliance \
      testing. This is a special configuration for compliance GSI, so do make \
      sure you understand the security implications before setting this \
      option. If you don't know what this option does, then you probably \
      shouldn't set this.)
  endif
endif

ifndef PRODUCT_USE_DYNAMIC_PARTITIONS
  PRODUCT_USE_DYNAMIC_PARTITIONS := $(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS)
endif

# All requirements of PRODUCT_USE_DYNAMIC_PARTITIONS falls back to
# PRODUCT_USE_DYNAMIC_PARTITIONS if not defined.
ifndef PRODUCT_USE_DYNAMIC_PARTITION_SIZE
  PRODUCT_USE_DYNAMIC_PARTITION_SIZE := $(PRODUCT_USE_DYNAMIC_PARTITIONS)
endif

ifndef PRODUCT_BUILD_SUPER_PARTITION
  PRODUCT_BUILD_SUPER_PARTITION := $(PRODUCT_USE_DYNAMIC_PARTITIONS)
endif

ifeq ($(PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS),)
  ifdef PRODUCT_SHIPPING_API_LEVEL
    ifeq (true,$(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),29))
      PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := true
    endif
  endif
endif

ifeq ($(PRODUCT_SET_DEBUGFS_RESTRICTIONS),)
  ifdef PRODUCT_SHIPPING_API_LEVEL
    ifeq (true,$(call math_gt_or_eq,$(PRODUCT_SHIPPING_API_LEVEL),31))
      PRODUCT_SET_DEBUGFS_RESTRICTIONS := true
    endif
  endif
endif

# If build command defines OVERRIDE_PRODUCT_EXTRA_VNDK_VERSIONS,
# override PRODUCT_EXTRA_VNDK_VERSIONS with it.
ifdef OVERRIDE_PRODUCT_EXTRA_VNDK_VERSIONS
  PRODUCT_EXTRA_VNDK_VERSIONS := $(OVERRIDE_PRODUCT_EXTRA_VNDK_VERSIONS)
endif

###########################################
# APEXes are by default not compressed
#
# APEX compression can be forcibly enabled (resp. disabled) by
# setting OVERRIDE_PRODUCT_COMPRESSED_APEX to true (resp. false), e.g. by
# setting the OVERRIDE_PRODUCT_COMPRESSED_APEX environment variable.
ifdef OVERRIDE_PRODUCT_COMPRESSED_APEX
  PRODUCT_COMPRESSED_APEX := $(OVERRIDE_PRODUCT_COMPRESSED_APEX)
endif

$(KATI_obsolete_var OVERRIDE_PRODUCT_EXTRA_VNDK_VERSIONS \
    ,Use PRODUCT_EXTRA_VNDK_VERSIONS instead)

# If build command defines OVERRIDE_PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE,
# override PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE with it unless it is
# defined as `false`. If the value is `false` clear
# PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE
# OVERRIDE_PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE can be used for
# testing only.
ifdef OVERRIDE_PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE
  ifeq (false,$(OVERRIDE_PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE))
    PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE :=
  else
    PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE := $(OVERRIDE_PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE)
  endif
else ifeq ($(PRODUCT_SHIPPING_API_LEVEL),)
  # No shipping level defined. Enforce the product interface by default.
  PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE := true
else ifeq ($(call math_gt,$(PRODUCT_SHIPPING_API_LEVEL),29),true)
  # Enforce product interface if PRODUCT_SHIPPING_API_LEVEL is greater than 29.
  PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE := true
endif

$(KATI_obsolete_var OVERRIDE_PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE,Use PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE instead)

# From Android V, Define PRODUCT_PRODUCT_VNDK_VERSION as current by default.
# This is required to make all devices have product variants.
ifndef PRODUCT_PRODUCT_VNDK_VERSION
  PRODUCT_PRODUCT_VNDK_VERSION := current
endif

ifdef PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS
    $(error PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS is deprecated, consider using RRO for \
      $(PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS))
endif

# Get the board API level.
board_api_level := $(PLATFORM_SDK_VERSION)
ifdef BOARD_API_LEVEL
  board_api_level := $(BOARD_API_LEVEL)
else ifdef BOARD_SHIPPING_API_LEVEL
  # Vendors with GRF must define BOARD_SHIPPING_API_LEVEL for the vendor API level.
  board_api_level := $(BOARD_SHIPPING_API_LEVEL)
endif

# Calculate the VSR vendor API level.
VSR_VENDOR_API_LEVEL := $(board_api_level)

ifdef PRODUCT_SHIPPING_API_LEVEL
  VSR_VENDOR_API_LEVEL := $(call math_min,$(PRODUCT_SHIPPING_API_LEVEL),$(board_api_level))
endif
.KATI_READONLY := VSR_VENDOR_API_LEVEL

# Boolean variable determining if vendor seapp contexts is enforced
CHECK_VENDOR_SEAPP_VIOLATIONS := false
ifneq ($(call math_gt,$(VSR_VENDOR_API_LEVEL),34),)
  CHECK_VENDOR_SEAPP_VIOLATIONS := true
else ifneq ($(PRODUCT_CHECK_VENDOR_SEAPP_VIOLATIONS),)
  CHECK_VENDOR_SEAPP_VIOLATIONS := $(PRODUCT_CHECK_VENDOR_SEAPP_VIOLATIONS)
endif
.KATI_READONLY := CHECK_VENDOR_SEAPP_VIOLATIONS

# Boolean variable determining if selinux labels of /dev are enforced
CHECK_DEV_TYPE_VIOLATIONS := false
ifneq ($(call math_gt,$(VSR_VENDOR_API_LEVEL),35),)
  CHECK_DEV_TYPE_VIOLATIONS := true
else ifneq ($(PRODUCT_CHECK_DEV_TYPE_VIOLATIONS),)
  CHECK_DEV_TYPE_VIOLATIONS := $(PRODUCT_CHECK_DEV_TYPE_VIOLATIONS)
endif
.KATI_READONLY := CHECK_DEV_TYPE_VIOLATIONS

define product-overrides-config
$$(foreach rule,$$(PRODUCT_$(1)_OVERRIDES),\
    $$(if $$(filter 2,$$(words $$(subst :,$$(space),$$(rule)))),,\
        $$(error Rule "$$(rule)" in PRODUCT_$(1)_OVERRIDE is not <module_name>:<new_value>)))
endef

$(foreach var, \
    MANIFEST_PACKAGE_NAME \
    PACKAGE_NAME \
    CERTIFICATE, \
  $(eval $(call product-overrides-config,$(var))))

# Macro to use below. $(1) is the name of the partition
define product-build-image-config
ifneq ($$(filter-out true false,$$(PRODUCT_BUILD_$(1)_IMAGE)),)
    $$(error Invalid PRODUCT_BUILD_$(1)_IMAGE: $$(PRODUCT_BUILD_$(1)_IMAGE) -- true false and empty are supported)
endif
endef

# Copy and check the value of each PRODUCT_BUILD_*_IMAGE variable
$(foreach image, \
    PVMFW \
    SYSTEM \
    SYSTEM_OTHER \
    VENDOR \
    PRODUCT \
    SYSTEM_EXT \
    ODM \
    VENDOR_DLKM \
    ODM_DLKM \
    SYSTEM_DLKM \
    CACHE \
    RAMDISK \
    USERDATA \
    BOOT \
    RECOVERY, \
  $(eval $(call product-build-image-config,$(image))))

product-build-image-config :=

$(call readonly-product-vars)
