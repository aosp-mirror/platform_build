###########################################################
## Standard rules for building a header library.
##
## Additional inputs from base_rules.make:
## None.
###########################################################

LOCAL_MODULE_CLASS := HEADER_LIBRARIES
LOCAL_UNINSTALLABLE_MODULE := true
ifneq ($(strip $(LOCAL_MODULE_STEM)$(LOCAL_BUILT_MODULE_STEM)),)
$(error $(LOCAL_PATH): Cannot set module stem for a library)
endif

ifeq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  ifdef LOCAL_USE_VNDK
    name_without_suffix := $(patsubst %.vendor,%,$(LOCAL_MODULE))
    ifneq ($(name_without_suffix),$(LOCAL_MODULE))
      SPLIT_VENDOR.$(LOCAL_MODULE_CLASS).$(name_without_suffix) := 1
    endif
    name_without_suffix :=
  endif
endif

include $(BUILD_SYSTEM)/binary.mk

ifneq ($(strip $(all_objects)),)
$(call pretty-error,Header libraries may not have any sources)
endif

$(LOCAL_BUILT_MODULE):
	$(hide) touch $@
