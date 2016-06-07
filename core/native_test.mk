###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for native tests are added.
###########################################

# TODO: enforce NATIVE_TESTS once current users are gone
ifndef LOCAL_MODULE_CLASS
LOCAL_MODULE_CLASS := NATIVE_TESTS
endif

include $(BUILD_SYSTEM)/target_test_internal.mk

ifndef LOCAL_MULTILIB
ifndef LOCAL_32_BIT_ONLY
LOCAL_MULTILIB := both
endif
endif

ifneq ($(LOCAL_MODULE_CLASS),NATIVE_TESTS)
$(warning $(LOCAL_PATH): $(LOCAL_MODULE): LOCAL_MODULE_CLASS should be NATIVE_TESTS with BUILD_NATIVE_TEST)
LOCAL_MODULE_PATH_64 := $(TARGET_OUT_DATA_NATIVE_TESTS)/$(LOCAL_MODULE)
LOCAL_MODULE_PATH_32 := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_NATIVE_TESTS)/$(LOCAL_MODULE)
endif

include $(BUILD_EXECUTABLE)
