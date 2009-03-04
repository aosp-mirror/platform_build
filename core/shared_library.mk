###########################################################
## Standard rules for building a normal shared library.
##
## Additional inputs from base_rules.make:
## None.
##
## LOCAL_MODULE_SUFFIX will be set for you.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $(TARGET_SHLIB_SUFFIX)
endif
ifeq ($(strip $(LOCAL_PRELINK_MODULE)),)
LOCAL_PRELINK_MODULE := $(strip $(TARGET_PRELINK_MODULE))
endif
ifneq ($(strip $(OVERRIDE_BUILT_MODULE_PATH)),)
$(error $(LOCAL_PATH): Illegal use of OVERRIDE_BUILT_MODULE_PATH)
endif

# Put the built targets of all shared libraries in a common directory
# to simplify the link line.
OVERRIDE_BUILT_MODULE_PATH := $(TARGET_OUT_INTERMEDIATE_LIBRARIES)

include $(BUILD_SYSTEM)/dynamic_binary.mk

$(linked_module): $(all_objects) $(all_libraries) \
                  $(LOCAL_ADDITIONAL_DEPENDENCIES) \
                  $(TARGET_CRTBEGIN_SO_O) $(TARGET_CRTEND_SO_O)
	$(transform-o-to-shared-lib)
