#
# Set up product-global definitions and include product-specific rules.
#

ifneq ($(strip $(TARGET_NO_BOOTLOADER)),true)
  INSTALLED_BOOTLOADER_MODULE := $(PRODUCT_OUT)/bootloader
  ifeq ($(strip $(TARGET_BOOTLOADER_IS_2ND)),true)
    INSTALLED_2NDBOOTLOADER_TARGET := $(PRODUCT_OUT)/2ndbootloader
  else
    INSTALLED_2NDBOOTLOADER_TARGET :=
  endif
else
  INSTALLED_BOOTLOADER_MODULE :=
  INSTALLED_2NDBOOTLOADER_TARGET :=
endif	# TARGET_NO_BOOTLOADER

ifneq ($(strip $(TARGET_NO_KERNEL)),true)
  INSTALLED_KERNEL_TARGET := $(PRODUCT_OUT)/kernel
else
  INSTALLED_KERNEL_TARGET :=
endif

# Use the add-radio-file function to add values to this variable.
INSTALLED_RADIOIMAGE_TARGET :=

ifeq (,$(wildcard $(TARGET_DEVICE_DIR)/AndroidBoard.mk))
  ifeq (,$(wildcard $(TARGET_DEVICE_DIR)/Android.mk))
    $(error Missing "$(TARGET_DEVICE_DIR)/AndroidBoard.mk")
  else
    # TODO: Remove this check after people have had a chance to switch,
    # after April 2009.
    $(error Please rename "$(TARGET_DEVICE_DIR)/Android.mk" to "$(TARGET_DEVICE_DIR)/AndroidBoard.mk")
  endif
endif
include $(TARGET_DEVICE_DIR)/AndroidBoard.mk

# Generate a file that contains various information about the
# device we're building for.  This file is typically packaged up
# with everything else.
#
# If the file "board-info.txt" appears in $(TARGET_DEVICE_DIR),
# it will be appended to the output file.
#
INSTALLED_ANDROID_INFO_TXT_TARGET := $(PRODUCT_OUT)/android-info.txt
board_info_txt := $(wildcard $(TARGET_DEVICE_DIR)/board-info.txt)
$(INSTALLED_ANDROID_INFO_TXT_TARGET): $(board_info_txt)
	$(call pretty,"Generated: ($@)")
ifdef board_info_txt
	$(hide) cat $< >> $@
else
	$(hide) echo "board=$(TARGET_BOOTLOADER_BOARD_NAME)" > $@
endif
