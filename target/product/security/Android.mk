LOCAL_PATH:= $(call my-dir)

#######################################
# adb key, if configured via PRODUCT_ADB_KEYS
ifdef PRODUCT_ADB_KEYS
  ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
    include $(CLEAR_VARS)
    LOCAL_MODULE := adb_keys
    LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0
    LOCAL_LICENSE_CONDITIONS := notice
    LOCAL_NOTICE_FILE := build/soong/licenses/LICENSE
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_OUT_PRODUCT_ETC)/security
    LOCAL_PREBUILT_MODULE_FILE := $(PRODUCT_ADB_KEYS)
    include $(BUILD_PREBUILT)
  endif
endif
