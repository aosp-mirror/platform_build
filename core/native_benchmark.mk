###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for native benchmarks are added.
###########################################

LOCAL_STATIC_LIBRARIES += libbenchmark libbase

ifndef LOCAL_MODULE_PATH
LOCAL_MODULE_PATH := $(TARGET_OUT_DATA_NATIVE_TESTS)/$(LOCAL_MODULE)
endif

include $(BUILD_EXECUTABLE)
