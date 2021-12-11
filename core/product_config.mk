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
$(sort $(shell find $(2) -name "$(1)" -type f | $(SED_EXTENDED) "s:($(2)/?(.*)):\\1\\:$(3)/\\2:" | sed "s://:/:g"))
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
include $(BUILD_SYSTEM)/device.mk

# Read in all of the product definitions specified by the AndroidProducts.mk
# files in the tree.
all_product_configs := $(get-all-product-makefiles)

all_named_products :=

# Find the product config makefile for the current product.
# all_product_configs consists items like:
# <product_name>:<path_to_the_product_makefile>
# or just <path_to_the_product_makefile> in case the product name is the
# same as the base filename of the product config makefile.
current_product_makefile :=
all_product_makefiles :=
$(foreach f, $(all_product_configs),\
    $(eval _cpm_words := $(call _decode-product-name,$(f)))\
    $(eval _cpm_word1 := $(word 1,$(_cpm_words)))\
    $(eval _cpm_word2 := $(word 2,$(_cpm_words)))\
    $(eval all_product_makefiles += $(_cpm_word2))\
    $(eval all_named_products += $(_cpm_word1))\
    $(if $(filter $(TARGET_PRODUCT),$(_cpm_word1)),\
        $(eval current_product_makefile += $(_cpm_word2)),))
_cpm_words :=
_cpm_word1 :=
_cpm_word2 :=
current_product_makefile := $(strip $(current_product_makefile))
all_product_makefiles := $(strip $(all_product_makefiles))

load_all_product_makefiles :=
ifneq (,$(filter product-graph, $(MAKECMDGOALS)))
ifeq ($(ANDROID_PRODUCT_GRAPH),--all)
load_all_product_makefiles := true
endif
endif
ifneq (,$(filter dump-products,$(MAKECMDGOALS)))
ifeq ($(ANDROID_DUMP_PRODUCTS),all)
load_all_product_makefiles := true
endif
endif

ifneq ($(ALLOW_RULES_IN_PRODUCT_CONFIG),)
_product_config_saved_KATI_ALLOW_RULES := $(.KATI_ALLOW_RULES)
.KATI_ALLOW_RULES := $(ALLOW_RULES_IN_PRODUCT_CONFIG)
endif

ifeq ($(load_all_product_makefiles),true)
# Import all product makefiles.
$(call import-products, $(all_product_makefiles))
else
# Import just the current product.
ifndef current_product_makefile
$(error Can not locate config makefile for product "$(TARGET_PRODUCT)")
endif
ifneq (1,$(words $(current_product_makefile)))
$(error Product "$(TARGET_PRODUCT)" ambiguous: matches $(current_product_makefile))
endif
$(call import-products, $(current_product_makefile))
endif  # Import all or just the current product makefile

# Quick check
$(check-all-products)

ifeq ($(SKIP_ARTIFACT_PATH_REQUIREMENT_PRODUCTS_CHECK),)
# Import all the products that have made artifact path requirements, so that we can verify
# the artifacts they produce.
# These are imported after check-all-products because some of them might not be real products.
$(foreach makefile,$(ARTIFACT_PATH_REQUIREMENT_PRODUCTS),\
  $(if $(filter-out $(makefile),$(PRODUCTS)),$(eval $(call import-products,$(makefile))))\
)
endif

ifneq ($(ALLOW_RULES_IN_PRODUCT_CONFIG),)
.KATI_ALLOW_RULES := $(_saved_KATI_ALLOW_RULES)
_product_config_saved_KATI_ALLOW_RULES :=
endif

ifneq ($(filter dump-products, $(MAKECMDGOALS)),)
$(dump-products)
endif

# Convert a short name like "sooner" into the path to the product
# file defining that product.
#
INTERNAL_PRODUCT := $(call resolve-short-product-name, $(TARGET_PRODUCT))
ifneq ($(current_product_makefile),$(INTERNAL_PRODUCT))
$(error PRODUCT_NAME inconsistent in $(current_product_makefile) and $(INTERNAL_PRODUCT))
endif


############################################################################
# Strip and assign the PRODUCT_ variables.
$(call strip-product-vars)

current_product_makefile :=
all_product_makefiles :=
all_product_configs :=

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

# Replaces references to overridden boot jar modules in a boot jars variable.
# $(1): Name of a boot jars variable with <apex>:<jar> pairs.
define replace-boot-jar-module-overrides
  $(foreach pair,$(PRODUCT_BOOT_JAR_MODULE_OVERRIDES),\
    $(eval _rbjmo_from := $(call word-colon,1,$(pair)))\
    $(eval _rbjmo_to := $(call word-colon,2,$(pair)))\
    $(eval $(1) := $(patsubst $(_rbjmo_from):%,$(_rbjmo_to):%,$($(1)))))
endef

$(call replace-boot-jar-module-overrides,PRODUCT_BOOT_JARS)
$(call replace-boot-jar-module-overrides,PRODUCT_UPDATABLE_BOOT_JARS)
$(call replace-boot-jar-module-overrides,ART_APEX_JARS)

# The extra system server jars must be appended at the end after common system server jars.
PRODUCT_SYSTEM_SERVER_JARS += $(PRODUCT_SYSTEM_SERVER_JARS_EXTRA)

PRODUCT_SYSTEM_SERVER_JARS := $(call qualify-platform-jars,$(PRODUCT_SYSTEM_SERVER_JARS))

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

$(foreach pair,$(PRODUCT_UPDATABLE_BOOT_JARS), \
  $(eval jar := $(call word-colon,2,$(pair))) \
  $(if $(findstring $(jar), $(PRODUCT_BOOT_JARS)), \
    $(error A jar in PRODUCT_UPDATABLE_BOOT_JARS must not be in PRODUCT_BOOT_JARS, but $(jar) is)))

ENFORCE_SYSTEM_CERTIFICATE := $(PRODUCT_ENFORCE_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT)
ENFORCE_SYSTEM_CERTIFICATE_ALLOW_LIST := $(PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_ALLOW_LIST)

PRODUCT_OTA_PUBLIC_KEYS := $(sort $(PRODUCT_OTA_PUBLIC_KEYS))
PRODUCT_EXTRA_RECOVERY_KEYS := $(sort $(PRODUCT_EXTRA_RECOVERY_KEYS))

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
ifeq (,$(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
  PRODUCT_ADB_KEYS :=
endif
ifneq ($(filter-out 0 1,$(words $(PRODUCT_ADB_KEYS))),)
  $(error Only one file may be in PRODUCT_ADB_KEYS: $(PRODUCT_ADB_KEYS))
endif

ifdef PRODUCT_INSTALL_DEBUG_POLICY_TO_SYSTEM_EXT
  ifeq (,$(filter gsi_arm gsi_arm64 gsi_x86 gsi_x86_64,$(PRODUCT_NAME)))
    $(error Only GSI products are allowed to set PRODUCT_INSTALL_DEBUG_POLICY_TO_SYSTEM_EXT)
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

ifdef PRODUCT_SHIPPING_API_LEVEL
  ifneq (,$(call math_gt_or_eq,29,$(PRODUCT_SHIPPING_API_LEVEL)))
    PRODUCT_PACKAGES += $(PRODUCT_PACKAGES_SHIPPING_API_LEVEL_29)
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
  # No shipping level defined
else ifeq ($(call math_gt,$(PRODUCT_SHIPPING_API_LEVEL),29),true)
  # Enforce product interface if PRODUCT_SHIPPING_API_LEVEL is greater than 29.
  PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE := true
endif

$(KATI_obsolete_var OVERRIDE_PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE,Use PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE instead)

# If build command defines PRODUCT_USE_PRODUCT_VNDK_OVERRIDE as `false`,
# PRODUCT_PRODUCT_VNDK_VERSION will not be defined automatically.
# PRODUCT_USE_PRODUCT_VNDK_OVERRIDE can be used for testing only.
PRODUCT_USE_PRODUCT_VNDK := false
ifneq ($(PRODUCT_USE_PRODUCT_VNDK_OVERRIDE),)
  PRODUCT_USE_PRODUCT_VNDK := $(PRODUCT_USE_PRODUCT_VNDK_OVERRIDE)
else ifeq ($(PRODUCT_SHIPPING_API_LEVEL),)
  # No shipping level defined
else ifeq ($(call math_gt,$(PRODUCT_SHIPPING_API_LEVEL),29),true)
  # Enforce product interface for VNDK if PRODUCT_SHIPPING_API_LEVEL is greater
  # than 29.
  PRODUCT_USE_PRODUCT_VNDK := true
endif

ifeq ($(PRODUCT_USE_PRODUCT_VNDK),true)
  ifndef PRODUCT_PRODUCT_VNDK_VERSION
    PRODUCT_PRODUCT_VNDK_VERSION := current
  endif
endif

$(KATI_obsolete_var PRODUCT_USE_PRODUCT_VNDK,Use PRODUCT_PRODUCT_VNDK_VERSION instead)
$(KATI_obsolete_var PRODUCT_USE_PRODUCT_VNDK_OVERRIDE,Use PRODUCT_PRODUCT_VNDK_VERSION instead)

ifdef PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS
    $(error PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS is deprecated, consider using RRO for \
      $(PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS))
endif

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
    SYSTEM \
    SYSTEM_OTHER \
    VENDOR \
    PRODUCT \
    SYSTEM_EXT \
    ODM \
    VENDOR_DLKM \
    ODM_DLKM \
    CACHE \
    RAMDISK \
    USERDATA \
    BOOT \
    RECOVERY, \
  $(eval $(call product-build-image-config,$(image))))

product-build-image-config :=

$(call readonly-product-vars)
