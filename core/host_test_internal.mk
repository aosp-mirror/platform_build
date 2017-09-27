#####################################################
## Shared definitions for all host test compilations.
#####################################################

ifeq ($(LOCAL_GTEST),true)
  LOCAL_CFLAGS_windows += -DGTEST_OS_WINDOWS
  LOCAL_CFLAGS_linux += -DGTEST_OS_LINUX
  LOCAL_CFLAGS_darwin += -DGTEST_OS_MAC

  LOCAL_CFLAGS += -DGTEST_HAS_STD_STRING -O0 -g

  LOCAL_STATIC_LIBRARIES += libgtest_main_host libgtest_host
endif

ifdef LOCAL_MODULE_PATH
$(error $(LOCAL_PATH): Do not set LOCAL_MODULE_PATH when building test $(LOCAL_MODULE))
endif

ifdef LOCAL_MODULE_PATH_32
$(error $(LOCAL_PATH): Do not set LOCAL_MODULE_PATH_32 when building test $(LOCAL_MODULE))
endif

ifdef LOCAL_MODULE_PATH_64
$(error $(LOCAL_PATH): Do not set LOCAL_MODULE_PATH_64 when building test $(LOCAL_MODULE))
endif

ifndef LOCAL_MODULE_RELATIVE_PATH
LOCAL_MODULE_RELATIVE_PATH := $(LOCAL_MODULE)
endif
