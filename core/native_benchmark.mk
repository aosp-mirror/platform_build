###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for native benchmarks are added.
###########################################
$(call record-module-type,NATIVE_BENCHMARK)

LOCAL_STATIC_LIBRARIES += libgoogle-benchmark

ifndef LOCAL_MULTILIB
ifndef LOCAL_32_BIT_ONLY
LOCAL_MULTILIB := both
endif
endif

include $(BUILD_EXECUTABLE)
