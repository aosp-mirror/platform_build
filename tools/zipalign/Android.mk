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

LOCAL_C_INCLUDES += external/zlib \
	external/zopfli/src

LOCAL_STATIC_LIBRARIES := \
	libandroidfw \
	libutils \
	libcutils \
	liblog \
	libzopfli

LOCAL_LDLIBS_linux += -lrt

LOCAL_STATIC_LIBRARIES_windows += libz
LOCAL_LDLIBS_linux += -lz
LOCAL_LDLIBS_darwin += -lz

ifneq ($(strip $(BUILD_HOST_static)),)
LOCAL_LDLIBS += -lpthread
endif # BUILD_HOST_static

LOCAL_MODULE := zipalign
LOCAL_MODULE_HOST_OS := darwin linux windows

include $(BUILD_HOST_EXECUTABLE)
