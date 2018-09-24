LOCAL_PATH:= $(call my-dir)

#######################################
# verity_key
include $(CLEAR_VARS)

LOCAL_MODULE := verity_key
LOCAL_SRC_FILES := $(LOCAL_MODULE)
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)

include $(BUILD_PREBUILT)

#######################################
# apex_debug_key for eng/userdebug
ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
  include $(CLEAR_VARS)

  LOCAL_MODULE := apex_debug_key
  LOCAL_SRC_FILES := $(LOCAL_MODULE)
  LOCAL_MODULE_CLASS := ETC
  LOCAL_MODULE_PATH := $(TARGET_OUT)/etc/security/apex

  include $(BUILD_PREBUILT)
endif

#######################################
# adb key, if configured via PRODUCT_ADB_KEYS
ifdef PRODUCT_ADB_KEYS
  ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
    include $(CLEAR_VARS)
    LOCAL_MODULE := adb_keys
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)
    LOCAL_PREBUILT_MODULE_FILE := $(PRODUCT_ADB_KEYS)
    include $(BUILD_PREBUILT)
  endif
endif
