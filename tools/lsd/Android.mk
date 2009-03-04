# Copyright 2005 The Android Open Source Project
#
# Android.mk for lsd 
#

LOCAL_PATH:= $(call my-dir)

ifeq ($(TARGET_ARCH),arm)
include $(CLEAR_VARS)

LOCAL_LDLIBS += -ldl
LOCAL_CFLAGS += -O2 -g 
LOCAL_CFLAGS += -fno-function-sections -fno-data-sections -fno-inline 
LOCAL_CFLAGS += -Wall -Wno-unused-function #-Werror
LOCAL_CFLAGS += -DBIG_ENDIAN=1
LOCAL_CFLAGS += -DARM_SPECIFIC_HACKS
LOCAL_CFLAGS += -DSUPPORT_ANDROID_PRELINK_TAGS
LOCAL_CFLAGS += -DDEBUG

ifeq ($(HOST_OS),windows)
LOCAL_LDLIBS += -lintl
endif

LOCAL_SRC_FILES := \
        cmdline.c \
        debug.c \
        hash.c \
        lsd.c \
        main.c

LOCAL_C_INCLUDES:= \
	$(LOCAL_PATH)/ \
	external/elfutils/lib/ \
	external/elfutils/libelf/ \
	external/elfutils/libebl/

LOCAL_STATIC_LIBRARIES := libelf libebl libebl_arm #dl

LOCAL_MODULE := lsd

include $(BUILD_HOST_EXECUTABLE)
endif #TARGET_ARCH==arm

