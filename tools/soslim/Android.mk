# Copyright 2005 The Android Open Source Project
#
# Android.mk for soslim
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
LOCAL_CFLAGS += -DSTRIP_STATIC_SYMBOLS
LOCAL_CFLAGS += -DMOVE_SECTIONS_IN_RANGES

ifeq ($(HOST_OS),windows)
# Cygwin stat does not support ACCESSPERMS bitmask
LOCAL_CFLAGS += -DACCESSPERMS=0777
LOCAL_LDLIBS += -lintl
endif

LOCAL_SRC_FILES := \
        cmdline.c \
        common.c \
        debug.c \
        soslim.c \
        main.c \
        prelink_info.c \
        symfilter.c

LOCAL_C_INCLUDES:= \
	$(LOCAL_PATH)/ \
	external/elfutils/lib/ \
	external/elfutils/libelf/ \
	external/elfutils/libebl/ \
	external/elfcopy/

LOCAL_STATIC_LIBRARIES := libelfcopy libelf libebl libebl_arm #dl

LOCAL_MODULE := soslim

include $(BUILD_HOST_EXECUTABLE)
endif #TARGET_ARCH==arm
