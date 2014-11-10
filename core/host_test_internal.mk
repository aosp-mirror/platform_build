#####################################################
## Shared definitions for all host test compilations.
#####################################################

ifeq ($(HOST_OS),windows)
LOCAL_CFLAGS += -DGTEST_OS_WINDOWS
else
LOCAL_CFLAGS += -DGTEST_OS_LINUX
LOCAL_LDLIBS += -lpthread
endif

LOCAL_CFLAGS += -DGTEST_HAS_STD_STRING -O0 -g
LOCAL_C_INCLUDES +=  external/gtest/include

LOCAL_STATIC_LIBRARIES += libgtest_host libgtest_main_host
