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

# These are the valid values of TARGET_BUILD_VARIANT.  Also, if anything else is passed
# as the variant in the PRODUCT-$TARGET_BUILD_PRODUCT-$TARGET_BUILD_VARIANT form,
# it will be treated as a goal, and the eng variant will be used.
INTERNAL_VALID_VARIANTS := user userdebug eng

# ---------------------------------------------------------------
# Provide "PRODUCT-<prodname>-<goal>" targets, which lets you build
# a particular configuration without needing to set up the environment.
#
ifeq ($(CALLED_FROM_SETUP),true)
product_goals := $(strip $(filter PRODUCT-%,$(MAKECMDGOALS)))
ifdef product_goals
  # Scrape the product and build names out of the goal,
  # which should be of the form PRODUCT-<productname>-<buildname>.
  #
  ifneq ($(words $(product_goals)),1)
    $(error Only one PRODUCT-* goal may be specified; saw "$(product_goals)")
  endif
  goal_name := $(product_goals)
  product_goals := $(patsubst PRODUCT-%,%,$(product_goals))
  product_goals := $(subst -, ,$(product_goals))
  ifneq ($(words $(product_goals)),2)
    $(error Bad PRODUCT-* goal "$(goal_name)")
  endif

  # The product they want
  TARGET_PRODUCT := $(word 1,$(product_goals))

  # The variant they want
  TARGET_BUILD_VARIANT := $(word 2,$(product_goals))

  ifeq ($(TARGET_BUILD_VARIANT),tests)
    $(error "tests" has been deprecated as a build variant. Use it as a build goal instead.)
  endif

  # The build server wants to do make PRODUCT-dream-sdk
  # which really means TARGET_PRODUCT=dream make sdk.
  ifneq ($(filter-out $(INTERNAL_VALID_VARIANTS),$(TARGET_BUILD_VARIANT)),)
    override MAKECMDGOALS := $(MAKECMDGOALS) $(TARGET_BUILD_VARIANT)
    TARGET_BUILD_VARIANT := userdebug
    default_goal_substitution :=
  else
    default_goal_substitution := droid
  endif

  # Replace the PRODUCT-* goal with the build goal that it refers to.
  # Note that this will ensure that it appears in the same relative
  # position, in case it matters.
  override MAKECMDGOALS := $(patsubst $(goal_name),$(default_goal_substitution),$(MAKECMDGOALS))
endif
endif # CALLED_FROM_SETUP
# else: Use the value set in the environment or buildspec.mk.

# ---------------------------------------------------------------
# Provide "APP-<appname>" targets, which lets you build
# an unbundled app.
#
ifeq ($(CALLED_FROM_SETUP),true)
unbundled_goals := $(strip $(filter APP-%,$(MAKECMDGOALS)))
ifdef unbundled_goals
  ifneq ($(words $(unbundled_goals)),1)
    $(error Only one APP-* goal may be specified; saw "$(unbundled_goals)")
  endif
  TARGET_BUILD_APPS := $(strip $(subst -, ,$(patsubst APP-%,%,$(unbundled_goals))))
  ifneq ($(filter droid,$(MAKECMDGOALS)),)
    override MAKECMDGOALS := $(patsubst $(unbundled_goals),,$(MAKECMDGOALS))
  else
    override MAKECMDGOALS := $(patsubst $(unbundled_goals),droid,$(MAKECMDGOALS))
  endif
endif # unbundled_goals
endif

# Now that we've parsed APP-* and PRODUCT-*, mark these as readonly
TARGET_BUILD_APPS ?=
.KATI_READONLY := \
  TARGET_PRODUCT \
  TARGET_BUILD_VARIANT \
  TARGET_BUILD_APPS

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

# Import all the products that have made artifact path requirements, so that we can verify
# the artifacts they produce.
$(foreach makefile,$(ARTIFACT_PATH_REQUIREMENT_PRODUCTS),\
  $(if $(filter-out $(makefile),$(PRODUCTS)),$(eval $(call import-products,$(makefile))))\
)

# Sanity check
$(check-all-products)

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
current_product_makefile :=
all_product_makefiles :=
all_product_configs :=

############################################################################
# Strip and assign the PRODUCT_ variables.
$(call strip-product-vars)

#############################################################################
# Sanity check and assign default values

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

ENFORCE_SYSTEM_CERTIFICATE := $(PRODUCT_ENFORCE_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT)
ENFORCE_SYSTEM_CERTIFICATE_WHITELIST := $(PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_WHITELIST)

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
PRODUCT_BUILD_$(1)_IMAGE := $$(firstword $$(PRODUCT_BUILD_$(1)_IMAGE))
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
    PRODUCT_SERVICES \
    ODM \
    CACHE \
    RAMDISK \
    USERDATA, \
  $(eval $(call product-build-image-config,$(image))))

product-build-image-config :=

$(call readonly-product-vars)
