ifeq ($(LOCAL_IS_AUX_MODULE),)
include $(BUILD_SYSTEM)/aux_toolchain.mk
endif

ifeq ($(AUX_BUILD_NOT_COMPATIBLE),)

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := STATIC_LIBRARIES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := .a
endif

LOCAL_UNINSTALLABLE_MODULE := true

ifneq ($(strip $(LOCAL_MODULE_STEM)$(LOCAL_BUILT_MODULE_STEM)),)
$(error $(LOCAL_PATH): Cannot set module stem for a library)
endif

include $(BUILD_SYSTEM)/binary.mk

$(LOCAL_BUILT_MODULE) : PRIVATE_AR := $(AUX_AR)
$(LOCAL_BUILT_MODULE) : $(built_whole_libraries)
$(LOCAL_BUILT_MODULE) : $(all_objects)
	$(transform-o-to-aux-static-lib)

endif # AUX_BUILD_NOT_COMPATIBLE
