LOCAL_PATH := $(call my-dir)

file := $(TARGET_OUT_KEYLAYOUT)/tuttle2.kl
ALL_PREBUILT += $(file)
$(file) : $(LOCAL_PATH)/tuttle2.kl | $(ACP)
	$(transform-prebuilt-to-target)

include $(CLEAR_VARS)
LOCAL_SRC_FILES := tuttle2.kcm
include $(BUILD_KEY_CHAR_MAP)
