#####################################################
## Shared definitions for all host test compilations.
#####################################################

LOCAL_CFLAGS_windows += -DGTEST_OS_WINDOWS
LOCAL_CFLAGS_linux += -DGTEST_OS_LINUX
LOCAL_LDLIBS_linux += -lpthread
LOCAL_CFLAGS_darwin += -DGTEST_OS_LINUX
LOCAL_LDLIBS_darwin += -lpthread

LOCAL_CFLAGS += -DGTEST_HAS_STD_STRING -O0 -g
LOCAL_C_INCLUDES +=  external/gtest/include

LOCAL_STATIC_LIBRARIES += libgtest_main_host libgtest_host
