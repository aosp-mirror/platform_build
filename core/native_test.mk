###########################################
## A thin wrapper around BUILD_EXECUTABLE
## Common flags for native tests are added.
###########################################

LOCAL_CFLAGS += -DGTEST_OS_LINUX_ANDROID -DGTEST_HAS_STD_STRING

LOCAL_C_INCLUDES += external/gtest/include
LOCAL_STATIC_LIBRARIES += libgtest libgtest_main

ifndef LOCAL_SDK_VERSION
LOCAL_C_INCLUDES += bionic \
                    bionic/libstdc++/include \
                    external/stlport/stlport
LOCAL_SHARED_LIBRARIES += libstlport
endif

ifndef LOCAL_MODULE_PATH
LOCAL_MODULE_PATH := $(TARGET_OUT_DATA_NATIVE_TESTS)/$(LOCAL_MODULE)
endif

include $(BUILD_EXECUTABLE)
