#
# Set up product-global definitions and include product-specific rules.
#

LOCAL_PATH := $(call my-dir)

-include $(TARGET_DEVICE_DIR)/AndroidBoard.mk

# Generate a file that contains various information about the
# device we're building for.  This file is typically packaged up
# with everything else.
#
# If TARGET_BOARD_INFO_FILE (which can be set in BoardConfig.mk) is
# defined, it is used, otherwise board-info.txt is looked for in
# $(TARGET_DEVICE_DIR).
#
INSTALLED_ANDROID_INFO_TXT_TARGET := $(PRODUCT_OUT)/android-info.txt
board_info_txt := $(TARGET_BOARD_INFO_FILE)
ifndef board_info_txt
board_info_txt := $(wildcard $(TARGET_DEVICE_DIR)/board-info.txt)
endif
$(INSTALLED_ANDROID_INFO_TXT_TARGET): $(board_info_txt)
	$(hide) build/tools/check_radio_versions.py $< $(BOARD_INFO_CHECK)
	$(call pretty,"Generated: ($@)")
ifdef board_info_txt
	$(hide) grep -v '#' $< > $@
else
	$(hide) echo "board=$(TARGET_BOOTLOADER_BOARD_NAME)" > $@
endif

# Copy compatibility metadata to the device.

ifdef DEVICE_MANIFEST_FILE
include $(CLEAR_VARS)
LOCAL_MODULE        := manifest.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT_VENDOR)

GEN := $(local-generated-sources-dir)/manifest.xml
$(GEN): $(DEVICE_MANIFEST_FILE) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	BOARD_SEPOLICY_VERS=$(BOARD_SEPOLICY_VERS) $(HOST_OUT_EXECUTABLES)/assemble_vintf -i $< -o $@

LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
BUILT_VENDOR_MANIFEST := $(LOCAL_BUILT_MODULE)
endif

ifdef DEVICE_MATRIX_FILE
include $(CLEAR_VARS)
LOCAL_MODULE        := matrix.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT_VENDOR)
LOCAL_PREBUILT_MODULE_FILE := $(DEVICE_MATRIX_FILE)
include $(BUILD_PREBUILT)
BUILT_VENDOR_MATRIX := $(LOCAL_BUILT_MODULE)
endif

include $(CLEAR_VARS)
LOCAL_MODULE        := system_manifest.xml
LOCAL_MODULE_STEM   := manifest.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT)

GEN := $(local-generated-sources-dir)/manifest.xml
$(GEN): $(FRAMEWORK_MANIFEST_FILE) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	BOARD_SEPOLICY_VERS=$(BOARD_SEPOLICY_VERS) $(HOST_OUT_EXECUTABLES)/assemble_vintf -i $< -o $@

LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
BUILT_SYSTEM_MANIFEST := $(LOCAL_BUILT_MODULE)
