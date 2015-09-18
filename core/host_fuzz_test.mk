################################################
## A thin wrapper around BUILD_HOST_EXECUTABLE
## Common flags for host fuzz tests are added.
################################################

LOCAL_CFLAGS += -fsanitize-coverage=edge,indirect-calls,8bit-counters,trace-cmp
LOCAL_STATIC_LIBRARIES += libLLVMFuzzer

include $(BUILD_HOST_EXECUTABLE)
