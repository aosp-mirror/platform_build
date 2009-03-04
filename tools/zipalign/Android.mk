# 
# Copyright 2008 The Android Open Source Project
#
# Zip alignment tool
#

LOCAL_PATH:= $(call my-dir)
include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
	ZipAlign.cpp

LOCAL_C_INCLUDES += external/zlib

LOCAL_STATIC_LIBRARIES := \
	libutils \
	libcutils

LOCAL_LDLIBS := -lz

ifeq ($(HOST_OS),linux)
LOCAL_LDLIBS += -lrt
endif

# dunno if we need this, but some of the other tools include it
ifeq ($(HOST_OS),windows)
ifeq ($(strip $(USE_CYGWIN),),)
LOCAL_LDLIBS += -lws2_32
endif
endif

LOCAL_MODULE := zipalign

include $(BUILD_HOST_EXECUTABLE)

