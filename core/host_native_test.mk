################################################
## A thin wrapper around BUILD_HOST_EXECUTABLE
## Common flags for host native tests are added.
################################################

LOCAL_CFLAGS += -DGTEST_OS_LINUX -DGTEST_HAS_STD_STRING -O0 -g
LOCAL_C_INCLUDES +=  \
    external/gtest/include

LOCAL_STATIC_LIBRARIES += libgtest_host libgtest_main_host
LOCAL_SHARED_LIBRARIES +=

include $(BUILD_HOST_EXECUTABLE)
