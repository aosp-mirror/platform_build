# Copyright 2005 The Android Open Source Project
#
# Custom version of cp.

LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
	acp.c

ifeq ($(HOST_OS),cygwin)
LOCAL_CFLAGS += -DWIN32_EXE
endif
ifeq ($(HOST_OS),darwin)
LOCAL_CFLAGS += -DMACOSX_RSRC
endif
ifeq ($(HOST_OS),linux)
endif

LOCAL_STATIC_LIBRARIES := libhost
LOCAL_C_INCLUDES := build/libs/host/include
LOCAL_MODULE := acp
LOCAL_ACP_UNAVAILABLE := true

include $(BUILD_HOST_EXECUTABLE)

