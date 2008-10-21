# Copyright 2007 The Android Open Source Project
#
# Copies files into the directory structure described by a manifest

LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
	atree.cpp \
	files.cpp \
	fs.cpp

LOCAL_STATIC_LIBRARIES := \
	libhost
LOCAL_C_INCLUDES := build/libs/host/include

LOCAL_MODULE := atree

include $(BUILD_HOST_EXECUTABLE)

