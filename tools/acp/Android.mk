# Copyright 2005 The Android Open Source Project
#
# Custom version of cp.

LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
    acp.c

LOCAL_STATIC_LIBRARIES := libhost
LOCAL_MODULE := acp
LOCAL_ACP_UNAVAILABLE := true
LOCAL_CXX_STL := none

include $(BUILD_HOST_EXECUTABLE)
