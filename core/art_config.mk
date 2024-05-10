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
# If the value is "default", it will be mangled by post_process_props.py.
ADDITIONAL_PRODUCT_PROPERTIES += ro.dalvik.vm.enable_uffd_gc=$(config_enable_uffd_gc)

# Create APEX_BOOT_JARS_EXCLUDED which is a list of jars to be removed from
# ApexBoorJars when built from mainline prebuilts.
# soong variables indicate whether the prebuilt is enabled:
# - $(m)_module/source_build for art and TOGGLEABLE_PREBUILT_MODULES
# - ANDROID/module_build_from_source for other mainline modules
# Note that RELEASE_APEX_BOOT_JARS_PREBUILT_EXCLUDED_LIST is the list of module names
# and library names of jars that need to be removed. We have to keep separated list per
# release config due to possibility of different prebuilt content.
APEX_BOOT_JARS_EXCLUDED :=
$(foreach pair, $(RELEASE_APEX_BOOT_JARS_PREBUILT_EXCLUDED_LIST),\
  $(eval m := $(subst com.android.,,$(call word-colon,1,$(pair)))) \
  $(if $(call soong_config_get,$(m)_module,source_build), \
    $(if $(filter true,$(call soong_config_get,$(m)_module,source_build)),, \
      $(eval APEX_BOOT_JARS_EXCLUDED += $(pair))), \
    $(if $(filter true,$(call soong_config_get,ANDROID,module_build_from_source)),, \
      $(eval APEX_BOOT_JARS_EXCLUDED += $(pair)))))
