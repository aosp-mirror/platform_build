###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for native benchmarks are added.
###########################################

LOCAL_STATIC_LIBRARIES += libgoogle-benchmark

LOCAL_MODULE_PATH_64 := $(TARGET_OUT_DATA_METRIC_TESTS)/$(LOCAL_MODULE)
LOCAL_MODULE_PATH_32 := $($(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_OUT_DATA_METRIC_TESTS)/$(LOCAL_MODULE)

ifndef LOCAL_MULTILIB
ifndef LOCAL_32_BIT_ONLY
LOCAL_MULTILIB := both
endif
endif

include $(BUILD_EXECUTABLE)
