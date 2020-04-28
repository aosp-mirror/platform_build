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
	$(hide) build/make/tools/check_radio_versions.py $< $(BOARD_INFO_CHECK)
	$(call pretty,"Generated: ($@)")
ifdef board_info_txt
	$(hide) grep -v '#' $< > $@
else
	$(hide) echo "board=$(TARGET_BOOTLOADER_BOARD_NAME)" > $@
endif

# Copy compatibility metadata to the device.

# Device Manifest
ifdef DEVICE_MANIFEST_FILE
# $(DEVICE_MANIFEST_FILE) can be a list of files
include $(CLEAR_VARS)
LOCAL_MODULE        := device_manifest.xml
LOCAL_MODULE_STEM   := manifest.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT_VENDOR)/etc/vintf

GEN := $(local-generated-sources-dir)/manifest.xml
$(GEN): PRIVATE_DEVICE_MANIFEST_FILE := $(DEVICE_MANIFEST_FILE)
$(GEN): $(DEVICE_MANIFEST_FILE) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	BOARD_SEPOLICY_VERS=$(BOARD_SEPOLICY_VERS) \
	PRODUCT_ENFORCE_VINTF_MANIFEST=$(PRODUCT_ENFORCE_VINTF_MANIFEST) \
	PRODUCT_SHIPPING_API_LEVEL=$(PRODUCT_SHIPPING_API_LEVEL) \
	$(HOST_OUT_EXECUTABLES)/assemble_vintf -o $@ \
		-i $(call normalize-path-list,$(PRIVATE_DEVICE_MANIFEST_FILE))

LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
BUILT_VENDOR_MANIFEST := $(LOCAL_BUILT_MODULE)
endif

# ODM manifest
ifdef ODM_MANIFEST_FILES
# ODM_MANIFEST_FILES is a list of files that is combined and installed as the default ODM manifest.
include $(CLEAR_VARS)
LOCAL_MODULE := odm_manifest.xml
LOCAL_MODULE_STEM := manifest.xml
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_RELATIVE_PATH := vintf
LOCAL_ODM_MODULE := true

GEN := $(local-generated-sources-dir)/manifest.xml
$(GEN): PRIVATE_SRC_FILES := $(ODM_MANIFEST_FILES)
$(GEN): $(ODM_MANIFEST_FILES) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	# Set VINTF_IGNORE_TARGET_FCM_VERSION to true because it should only be in device manifest.
	VINTF_IGNORE_TARGET_FCM_VERSION=true \
	$(HOST_OUT_EXECUTABLES)/assemble_vintf -o $@ \
		-i $(call normalize-path-list,$(PRIVATE_SRC_FILES))

LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
endif # ODM_MANIFEST_FILES

# ODM_MANIFEST_SKUS: a list of SKUS where ODM_MANIFEST_<sku>_FILES are defined.
ifdef ODM_MANIFEST_SKUS

# Install /odm/etc/vintf/manifest_$(sku).xml
# $(1): sku
define _add_odm_sku_manifest
my_fragment_files_var := ODM_MANIFEST_$$(call to-upper,$(1))_FILES
ifndef $$(my_fragment_files_var)
$$(error $(1) is in ODM_MANIFEST_SKUS but $$(my_fragment_files_var) is not defined)
endif
my_fragment_files := $$($$(my_fragment_files_var))
include $$(CLEAR_VARS)
LOCAL_MODULE := odm_manifest_$(1).xml
LOCAL_MODULE_STEM := manifest_$(1).xml
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_RELATIVE_PATH := vintf
LOCAL_ODM_MODULE := true
GEN := $$(local-generated-sources-dir)/manifest_$(1).xml
$$(GEN): PRIVATE_SRC_FILES := $$(my_fragment_files)
$$(GEN): $$(my_fragment_files) $$(HOST_OUT_EXECUTABLES)/assemble_vintf
	VINTF_IGNORE_TARGET_FCM_VERSION=true \
	$$(HOST_OUT_EXECUTABLES)/assemble_vintf -o $$@ \
		-i $$(call normalize-path-list,$$(PRIVATE_SRC_FILES))
LOCAL_PREBUILT_MODULE_FILE := $$(GEN)
include $$(BUILD_PREBUILT)
my_fragment_files_var :=
my_fragment_files :=
endef

$(foreach sku, $(ODM_MANIFEST_SKUS), $(eval $(call _add_odm_sku_manifest,$(sku))))
_add_odm_sku_manifest :=

endif # ODM_MANIFEST_SKUS
