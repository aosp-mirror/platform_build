# Copyright 2015 The Android Open Source Project
#
# The rest of files in this directory comes from
# https://github.com/bazelbuild/bazel/tree/master/third_party/ijar

LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)
LOCAL_CPP_EXTENSION := .cc
LOCAL_SRC_FILES := classfile.cc ijar.cc zip.cc
LOCAL_CFLAGS += -Wall -Werror
LOCAL_SHARED_LIBRARIES := libz-host
LOCAL_MODULE := ijar
# libc++ is not supported for TARGET_BUILD_APPS builds
LOCAL_CXX_STL := libstdc++
include $(BUILD_HOST_EXECUTABLE)
