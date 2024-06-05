# ART configuration that has to be determined after product config is resolved.
#
# Inputs:
# PRODUCT_ENABLE_UFFD_GC: See comments in build/make/core/product.mk.
# OVERRIDE_ENABLE_UFFD_GC: Overrides PRODUCT_ENABLE_UFFD_GC. Can be passed from the commandline for
# debugging purposes.
# BOARD_API_LEVEL: See comments in build/make/core/main.mk.
# BOARD_SHIPPING_API_LEVEL: See comments in build/make/core/main.mk.
# PRODUCT_SHIPPING_API_LEVEL: See comments in build/make/core/product.mk.
#
# Outputs:
# ENABLE_UFFD_GC: Whether to use userfaultfd GC.

config_enable_uffd_gc := \
  $(firstword $(OVERRIDE_ENABLE_UFFD_GC) $(PRODUCT_ENABLE_UFFD_GC) default)

ifeq (,$(filter default true false,$(config_enable_uffd_gc)))
  $(error Unknown PRODUCT_ENABLE_UFFD_GC value: $(config_enable_uffd_gc))
endif

ENABLE_UFFD_GC := $(config_enable_uffd_gc)

# Create APEX_BOOT_JARS_EXCLUDED which is a list of jars to be removed from
# ApexBoorJars when built from mainline prebuilts.
# Note that RELEASE_APEX_BOOT_JARS_PREBUILT_EXCLUDED_LIST is the list of module names
# and library names of jars that need to be removed. We have to keep separated list per
# release config due to possibility of different prebuilt content.
#
# If a device has opted to not use google prebuilts (determined using
# PRODUCT_BUILD_IGNORE_APEX_CONTRIBUTION_CONTENTS), then no jars need to be removed.
# Example of products where PRODUCT_BUILD_IGNORE_APEX_CONTRIBUTION_CONTENTS is true are
# 1. aosp devices (they do not use google apexes)
# 2. hwasan devices (apex prebuilts are not compatible with these devices)
# 3. coverage builds
ifneq (true, $(PRODUCT_BUILD_IGNORE_APEX_CONTRIBUTION_CONTENTS))
  APEX_BOOT_JARS_EXCLUDED += $(RELEASE_APEX_BOOT_JARS_PREBUILT_EXCLUDED_LIST)
endif
