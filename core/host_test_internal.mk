#####################################################
## Shared definitions for all host test compilations.
#####################################################

LOCAL_CFLAGS += -DGTEST_OS_LINUX -DGTEST_HAS_STD_STRING -O0 -g
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

LOCAL_LDLIBS += -lpthread
