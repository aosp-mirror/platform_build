#######################################################
## Shared definitions for all target test compilations.
#######################################################

LOCAL_CFLAGS += -DGTEST_OS_LINUX_ANDROID -DGTEST_HAS_STD_STRING

LOCAL_C_INCLUDES += external/gtest/include
ifneq ($(filter libc++,$(LOCAL_SHARED_LIBRARIES)),)
LOCAL_STATIC_LIBRARIES += libgtest_libc++ libgtest_main_libc++
else
LOCAL_STATIC_LIBRARIES += libgtest libgtest_main

ifndef LOCAL_SDK_VERSION
LOCAL_C_INCLUDES += bionic \
                    bionic/libstdc++/include \
                    external/stlport/stlport
LOCAL_SHARED_LIBRARIES += libstlport
LOCAL_STATIC_LIBRARIES += libstdc++
endif
endif

ifndef LOCAL_MODULE_PATH
LOCAL_MODULE_PATH := $(TARGET_OUT_DATA_NATIVE_TESTS)/$(LOCAL_MODULE)
endif
