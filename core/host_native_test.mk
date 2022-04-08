################################################
## A thin wrapper around BUILD_HOST_EXECUTABLE
## Common flags for host native tests are added.
################################################
$(call record-module-type,HOST_NATIVE_TEST)

ifdef LOCAL_MODULE_CLASS
ifneq ($(LOCAL_MODULE_CLASS),NATIVE_TESTS)
$(error $(LOCAL_PATH): LOCAL_MODULE_CLASS must be NATIVE_TESTS with BUILD_HOST_NATIVE_TEST)
endif
endif

LOCAL_MODULE_CLASS := NATIVE_TESTS

include $(BUILD_SYSTEM)/host_test_internal.mk

ifndef LOCAL_MULTILIB
ifndef LOCAL_32_BIT_ONLY
LOCAL_MULTILIB := both
endif
endif

include $(BUILD_HOST_EXECUTABLE)
