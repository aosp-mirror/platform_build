# 
# Copyright 2008 The Android Open Source Project
#
# Zip alignment tool
#

LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
	ZipAlign.cpp \
	ZipEntry.cpp \
	ZipFile.cpp

LOCAL_C_INCLUDES += external/zlib

LOCAL_STATIC_LIBRARIES := \
	libutils \
	libcutils

ifeq ($(HOST_OS),linux)
LOCAL_LDLIBS += -lrt
endif

ifneq ($(strip $(USE_MINGW)),)
LOCAL_STATIC_LIBRARIES += libz
else
LOCAL_LDLIBS += -lz
endif

LOCAL_MODULE := zipalign

include $(BUILD_HOST_EXECUTABLE)

