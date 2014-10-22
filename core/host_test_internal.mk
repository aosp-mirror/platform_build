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

my_test_libcxx := false
ifeq (,$(TARGET_BUILD_APPS))
ifneq ($(filter $(strip $(LOCAL_CXX_STL)),libc++ libc++_static),)
my_test_libcxx := true
endif
endif

ifeq ($(my_test_libcxx),true)
LOCAL_STATIC_LIBRARIES += libgtest_libc++_host libgtest_main_libc++_host
else
LOCAL_STATIC_LIBRARIES += libgtest_host libgtest_main_host
LOCAL_SHARED_LIBRARIES +=
endif

