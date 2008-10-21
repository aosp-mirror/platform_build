###########################################################
## Standard rules for building a static library.
##
## Additional inputs from base_rules.make:
## None.
##
## LOCAL_MODULE_SUFFIX will be set for you.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := STATIC_LIBRARIES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := .a
endif
LOCAL_UNINSTALLABLE_MODULE := true

include $(BUILD_SYSTEM)/binary.mk

ifeq ($(LOCAL_RAW_STATIC_LIBRARY),true)
LOCAL_RAW_STATIC_LIBRARY:=
$(all_objects) : TARGET_PROJECT_INCLUDES := 
$(all_objects) : TARGET_C_INCLUDES := 
$(all_objects) : TARGET_GLOBAL_CFLAGS := 
$(all_objects) : TARGET_GLOBAL_CPPFLAGS := 
endif

$(LOCAL_BUILT_MODULE): $(all_objects)
	$(transform-o-to-static-lib)
