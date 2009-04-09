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
$(shell find $(2) -name "$(1)" | sed -E "s:($(2)/?(.*)):\\1\\:$(3)/\\2:" | sed "s://:/:g")
endef

# ---------------------------------------------------------------

# These are the valid values of TARGET_BUILD_VARIANT.  Also, if anything else is passed
# as the variant in the PRODUCT-$TARGET_BUILD_PRODUCT-$TARGET_BUILD_VARIANT form,
# it will be treated as a goal, and the eng variant will be used.
INTERNAL_VALID_VARIANTS := user userdebug eng tests

# ---------------------------------------------------------------
# Provide "PRODUCT-<prodname>-<goal>" targets, which lets you build
# a particular configuration without needing to set up the environment.
#
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

  # The build server wants to do make PRODUCT-dream-installclean
  # which really means TARGET_PRODUCT=dream make installclean.  
  ifneq ($(filter-out $(INTERNAL_VALID_VARIANTS),$(TARGET_BUILD_VARIANT)),)
	MAKECMDGOALS := $(MAKECMDGOALS) $(TARGET_BUILD_VARIANT)
	TARGET_BUILD_VARIANT := eng
    default_goal_substitution := 
  else
    default_goal_substitution := $(DEFAULT_GOAL)
  endif

  # Hack to make the linux build servers use dexpreopt.
  # OSX is still a little flaky.  Most engineers don't use this
  # type of target ("make PRODUCT-blah-user"), so this should
  # only tend to happen when using buildbot.
  # TODO: remove this and fix the matching lines in build/core/main.mk
  # once dexpreopt works better on OSX.
  ifeq ($(TARGET_BUILD_VARIANT),user)
    WITH_DEXPREOPT_buildbot := true
  endif

  # Replace the PRODUCT-* goal with the build goal that it refers to.
  # Note that this will ensure that it appears in the same relative
  # position, in case it matters.
  #
  # Note that modifying this will not affect the goals that make will
  # attempt to build, but it's important because we inspect this value
  # in certain situations (like for "make sdk").  
  #
  MAKECMDGOALS := $(patsubst $(goal_name),$(default_goal_substitution),$(MAKECMDGOALS))

  # Define a rule for the PRODUCT-* goal, and make it depend on the
  # patched-up command-line goals as well as any other goals that we
  # want to force.
  #
.PHONY: $(goal_name)
$(goal_name): $(MAKECMDGOALS)
endif
# else: Use the value set in the environment or buildspec.mk.

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
#
#TODO: when we start allowing direct pointers to product files,
#    guarantee that they're in this list.
$(call import-products, $(get-all-product-makefiles))
$(check-all-products)
#$(dump-products)
#$(error done)

# Convert a short name like "sooner" into the path to the product
# file defining that product.
#
INTERNAL_PRODUCT := $(call resolve-short-product-name, $(TARGET_PRODUCT))
#$(error TARGET_PRODUCT $(TARGET_PRODUCT) --> $(INTERNAL_PRODUCT))

# Find the device that this product maps to.
TARGET_DEVICE := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_DEVICE)

# Figure out which resoure configuration options to use for this
# product.
PRODUCT_LOCALES := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_LOCALES))
# TODO: also keep track of things like "port", "land" in product files.

# If CUSTOM_LOCALES contains any locales not already included
# in PRODUCT_LOCALES, add them to PRODUCT_LOCALES.
extra_locales := $(filter-out $(PRODUCT_LOCALES),$(CUSTOM_LOCALES))
ifneq (,$(extra_locales))
  $(info Adding CUSTOM_LOCALES [$(extra_locales)] to PRODUCT_LOCALES [$(PRODUCT_LOCALES)])
  PRODUCT_LOCALES += $(extra_locales)
  extra_locales :=
endif

# Assemble the list of options.
PRODUCT_AAPT_CONFIG := $(PRODUCT_LOCALES)

# Convert spaces to commas.
comma := ,
PRODUCT_AAPT_CONFIG := \
	$(subst $(space),$(comma),$(strip $(PRODUCT_AAPT_CONFIG)))

PRODUCT_BRAND := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_BRAND))

PRODUCT_MODEL := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_MODEL))
ifndef PRODUCT_MODEL
  PRODUCT_MODEL := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_NAME)) 
endif

PRODUCT_MANUFACTURER := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_MANUFACTURER))
ifndef PRODUCT_MANUFACTURER
  PRODUCT_MANUFACTURER := unknown
endif

# Which policy should this product use
PRODUCT_POLICY := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_POLICY))

# A list of words like <source path>:<destination path>.  The file at
# the source path should be copied to the destination path when building
# this product.  <destination path> is relative to $(PRODUCT_OUT), so
# it should look like, e.g., "system/etc/file.xml".  The rules
# for these copy steps are defined in config/Makefile.
PRODUCT_COPY_FILES := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_COPY_FILES))

# The HTML file containing the contributors to the project.
PRODUCT_CONTRIBUTORS_FILE := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_CONTRIBUTORS_FILE))

# A list of property assignments, like "key = value", with zero or more
# whitespace characters on either side of the '='.
PRODUCT_PROPERTY_OVERRIDES := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PROPERTY_OVERRIDES))

# Should we use the default resources or add any product specific overlays
PRODUCT_PACKAGE_OVERLAYS := \
	$(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGE_OVERLAYS))
DEVICE_PACKAGE_OVERLAYS := \
        $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).DEVICE_PACKAGE_OVERLAYS))

# An list of whitespace-separated words.
PRODUCT_TAGS := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_TAGS))

# Add the product-defined properties to the build properties.
ADDITIONAL_BUILD_PROPERTIES := \
	$(ADDITIONAL_BUILD_PROPERTIES) \
	$(PRODUCT_PROPERTY_OVERRIDES)

# Get the list of OTA public keys for the product.
OTA_PUBLIC_KEYS := \
	$(sort \
	    $(OTA_PUBLIC_KEYS) \
	    $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_OTA_PUBLIC_KEYS) \
	 )

# HACK: Not all products define OTA keys yet, and the -user build
# will fail if no keys are defined.
# TODO: Let a product opt out of needing OTA keys, and stop defaulting to
#       the test key as soon as possible.
ifeq (,$(strip $(OTA_PUBLIC_KEYS)))
  ifeq (,$(CALLED_FROM_SETUP))
    $(warning WARNING: adding test OTA key)
  endif
  OTA_PUBLIC_KEYS := $(SRC_TARGET_DIR)/product/security/testkey.x509.pem
endif

# ---------------------------------------------------------------
# Force the simulator to be the simulator, and make BUILD_TYPE
# default to debug.
ifeq ($(TARGET_PRODUCT),sim)
  TARGET_SIMULATOR := true
  ifeq (,$(strip $(TARGET_BUILD_TYPE)))
    TARGET_BUILD_TYPE := debug
  endif
  # dexpreopt doesn't work when building the simulator
  DISABLE_DEXPREOPT := true
endif
