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

include $(BUILD_SYSTEM)/binary.mk

ifneq ($(strip $(all_objects)),)
$(call pretty-error,Header libraries may not have any sources)
endif

$(LOCAL_BUILT_MODULE):
	$(hide) touch $@
