# Copyright 2005 The Android Open Source Project
#
# Android.mk for iself
#

LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CFLAGS += -O2 -g
LOCAL_CFLAGS += -fno-function-sections -fno-data-sections -fno-inline
LOCAL_CFLAGS += -Wall -Wno-unused-function #-Werror
LOCAL_CFLAGS += -DDEBUG

LOCAL_C_INCLUDES:= \
	$(LOCAL_PATH)/

LOCAL_SRC_FILES := \
	iself.c

LOCAL_MODULE := iself

include $(BUILD_HOST_EXECUTABLE)
