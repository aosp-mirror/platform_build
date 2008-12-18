LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_SRC_FILES := fs_get_stats.c

LOCAL_MODULE := fs_get_stats

include $(BUILD_HOST_EXECUTABLE)
