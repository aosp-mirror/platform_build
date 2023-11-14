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
  $(firstword $(OVERRIDE_ENABLE_UFFD_GC) $(PRODUCT_ENABLE_UFFD_GC))

ifeq (,$(filter-out default,$(config_enable_uffd_gc)))
  ENABLE_UFFD_GC := true

  # Disable userfaultfd GC if the device doesn't support it (i.e., if
  # `min(ro.board.api_level ?? ro.board.first_api_level ?? MAX_VALUE,
  #      ro.product.first_api_level ?? ro.build.version.sdk ?? MAX_VALUE) < 31`)
  # This logic aligns with how `ro.vendor.api_level` is calculated in
  # `system/core/init/property_service.cpp`.
  # We omit the check on `ro.build.version.sdk` here because we are on the latest build system.
  board_api_level := $(firstword $(BOARD_API_LEVEL) $(BOARD_SHIPPING_API_LEVEL))
  ifneq (,$(board_api_level))
    ifeq (true,$(call math_lt,$(board_api_level),31))
      ENABLE_UFFD_GC := false
    endif
  endif

  ifneq (,$(PRODUCT_SHIPPING_API_LEVEL))
    ifeq (true,$(call math_lt,$(PRODUCT_SHIPPING_API_LEVEL),31))
      ENABLE_UFFD_GC := false
    endif
  endif
else ifeq (true,$(config_enable_uffd_gc))
  ENABLE_UFFD_GC := true
else ifeq (false,$(config_enable_uffd_gc))
  ENABLE_UFFD_GC := false
else
  $(error Unknown PRODUCT_ENABLE_UFFD_GC value: $(config_enable_uffd_gc))
endif

ADDITIONAL_PRODUCT_PROPERTIES += ro.dalvik.vm.enable_uffd_gc=$(ENABLE_UFFD_GC)

# Create APEX_BOOT_JARS_EXCLUDED which is a list of jars to be removed from
# ApexBoorJars when built from mainline prebuilts.
# soong variables indicate whether the prebuilt is enabled:
# - $(m)_module/source_build for art and TOGGLEABLE_PREBUILT_MODULES
# - ANDROID/module_build_from_source for other mainline modules
APEX_BOOT_JARS_EXCLUDED :=
$(foreach pair, $(PRODUCT_APEX_BOOT_JARS_FOR_SOURCE_BUILD_ONLY),\
  $(eval m := $(subst com.android.,,$(call word-colon,1,$(pair)))) \
  $(if $(call soong_config_get,$(m)_module,source_build), \
    $(if $(filter true,$(call soong_config_get,$(m)_module,source_build)),, \
      $(eval APEX_BOOT_JARS_EXCLUDED += $(pair))), \
    $(if $(filter true,$(call soong_config_get,ANDROID,module_build_from_source)),, \
      $(eval APEX_BOOT_JARS_EXCLUDED += $(pair)))))
