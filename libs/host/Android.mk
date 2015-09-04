LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES:= \
    CopyFile.c

LOCAL_CFLAGS_darwin += -DMACOSX_RSRC

LOCAL_MODULE:= libhost
LOCAL_MODULE_HOST_OS := darwin linux windows
LOCAL_C_INCLUDES := $(LOCAL_PATH)/include
LOCAL_CXX_STL := none

# acp uses libhost, so we can't use
# acp to install libhost.
LOCAL_ACP_UNAVAILABLE:= true

include $(BUILD_HOST_STATIC_LIBRARY)

# Include toolchain prebuilt modules if they exist.
-include $(TARGET_TOOLCHAIN_ROOT)/toolchain.mk
