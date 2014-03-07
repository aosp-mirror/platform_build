#####################################################
## Shared definitions for all host test compilations.
#####################################################

LOCAL_CFLAGS += -DGTEST_OS_LINUX -DGTEST_HAS_STD_STRING -O0 -g
LOCAL_C_INCLUDES +=  external/gtest/include

LOCAL_STATIC_LIBRARIES += libgtest_host libgtest_main_host
LOCAL_SHARED_LIBRARIES +=

LOCAL_LDLIBS += -lpthread
