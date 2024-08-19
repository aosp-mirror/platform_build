###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for native tests are added.
###########################################
$(call record-module-type,NATIVE_TEST)

ifdef LOCAL_MODULE_CLASS
ifneq ($(LOCAL_MODULE_CLASS),NATIVE_TESTS)
$(error $(LOCAL_PATH): LOCAL_MODULE_CLASS must be NATIVE_TESTS with BUILD_HOST_NATIVE_TEST)
endif
endif

LOCAL_MODULE_CLASS := NATIVE_TESTS

include $(BUILD_SYSTEM)/target_test_internal.mk

ifndef LOCAL_MULTILIB
ifndef LOCAL_32_BIT_ONLY
LOCAL_MULTILIB := both
endif
endif

include $(BUILD_EXECUTABLE)

$(if $(my_register_name),$(eval ALL_MODULES.$(my_register_name).MAKE_MODULE_TYPE:=NATIVE_TEST))