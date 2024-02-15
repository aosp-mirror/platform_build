#
# Set up product-global definitions and include product-specific rules.
#

LOCAL_PATH := $(call my-dir)

-include $(TARGET_DEVICE_DIR)/AndroidBoard.mk

# Generate a file that contains various information about the
# device we're building for.  This file is typically packaged up
# with everything else.
#
# The following logic is used to find the contents of the info file:
#   1. TARGET_BOARD_INFO_FILES (can be set in BoardConfig.mk) will be combined.
#   2. TARGET_BOARD_INFO_FILE (can be set in BoardConfig.mk) will be used.
#   3. $(TARGET_DEVICE_DIR)/board-info.txt will be used if present.
#
# Specifying both TARGET_BOARD_INFO_FILES and TARGET_BOARD_INFO_FILE is an
# error.
#
INSTALLED_ANDROID_INFO_TXT_TARGET := $(PRODUCT_OUT)/android-info.txt
ifdef TARGET_BOARD_INFO_FILES
  ifdef TARGET_BOARD_INFO_FILE
    $(warning Both TARGET_BOARD_INFO_FILES and TARGET_BOARD_INFO_FILE are defined.)
    $(warning Using $(TARGET_BOARD_INFO_FILES) rather than $(TARGET_BOARD_INFO_FILE) for android-info.txt)
  endif
  board_info_txt := $(call intermediates-dir-for,PACKAGING,board-info)/board-info.txt
$(board_info_txt): $(TARGET_BOARD_INFO_FILES)
	$(hide) cat $(TARGET_BOARD_INFO_FILES) > $@
else ifdef TARGET_BOARD_INFO_FILE
  board_info_txt := $(TARGET_BOARD_INFO_FILE)
else
  board_info_txt := $(wildcard $(TARGET_DEVICE_DIR)/board-info.txt)
endif

CHECK_RADIO_VERSIONS := $(HOST_OUT_EXECUTABLES)/check_radio_versions$(HOST_EXECUTABLE_SUFFIX)
$(INSTALLED_ANDROID_INFO_TXT_TARGET): $(board_info_txt) $(CHECK_RADIO_VERSIONS)
	$(hide) $(CHECK_RADIO_VERSIONS) \
		--board_info_txt $(board_info_txt) \
		--board_info_check $(BOARD_INFO_CHECK)
	$(call pretty,"Generated: ($@)")
ifdef board_info_txt
	$(hide) grep -v '#' $< > $@
else ifdef TARGET_BOOTLOADER_BOARD_NAME
	$(hide) echo "board=$(TARGET_BOOTLOADER_BOARD_NAME)" > $@
else
	$(hide) echo "" > $@
endif

$(call declare-0p-target,$(INSTALLED_ANDROID_INFO_TXT_TARGET))

# Copy compatibility metadata to the device.

# Device Manifest
ifdef DEVICE_MANIFEST_FILE
# $(DEVICE_MANIFEST_FILE) can be a list of files
include $(CLEAR_VARS)
LOCAL_MODULE        := vendor_manifest.xml
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0 legacy_not_a_contribution
LOCAL_LICENSE_CONDITIONS := by_exception_only not_allowed notice
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
endif

# DEVICE_MANIFEST_SKUS: a list of SKUS where DEVICE_MANIFEST_<sku>_FILES is defined.
ifdef DEVICE_MANIFEST_SKUS

# Install /vendor/etc/vintf/manifest_$(sku).xml
# $(1): sku
define _add_device_sku_manifest
my_fragment_files_var := DEVICE_MANIFEST_$$(call to-upper,$(1))_FILES
ifndef $$(my_fragment_files_var)
$$(error $(1) is in DEVICE_MANIFEST_SKUS but $$(my_fragment_files_var) is not defined)
endif
my_fragment_files := $$($$(my_fragment_files_var))
include $$(CLEAR_VARS)
LOCAL_MODULE := vendor_manifest_$(1).xml
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0 legacy_not_a_contribution
LOCAL_LICENSE_CONDITIONS := by_exception_only not_allowed notice
LOCAL_MODULE_STEM := manifest_$(1).xml
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT_VENDOR)/etc/vintf

GEN := $$(local-generated-sources-dir)/manifest_$(1).xml
$$(GEN): PRIVATE_SRC_FILES := $$(my_fragment_files)
$$(GEN): $$(my_fragment_files) $$(HOST_OUT_EXECUTABLES)/assemble_vintf
	BOARD_SEPOLICY_VERS=$$(BOARD_SEPOLICY_VERS) \
	PRODUCT_ENFORCE_VINTF_MANIFEST=$$(PRODUCT_ENFORCE_VINTF_MANIFEST) \
	PRODUCT_SHIPPING_API_LEVEL=$$(PRODUCT_SHIPPING_API_LEVEL) \
	$$(HOST_OUT_EXECUTABLES)/assemble_vintf -o $$@ \
		-i $$(call normalize-path-list,$$(PRIVATE_SRC_FILES))

LOCAL_PREBUILT_MODULE_FILE := $$(GEN)
include $$(BUILD_PREBUILT)
my_fragment_files_var :=
my_fragment_files :=
endef

$(foreach sku, $(DEVICE_MANIFEST_SKUS), $(eval $(call _add_device_sku_manifest,$(sku))))
_add_device_sku_manifest :=

endif # DEVICE_MANIFEST_SKUS

# ODM manifest
ifdef ODM_MANIFEST_FILES
# ODM_MANIFEST_FILES is a list of files that is combined and installed as the default ODM manifest.
include $(CLEAR_VARS)
LOCAL_MODULE := odm_manifest.xml
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0 legacy_not_a_contribution
LOCAL_LICENSE_CONDITIONS := by_exception_only not_allowed notice
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
LOCAL_LICENSE_KINDS := SPDX-license-identifier-Apache-2.0 legacy_not_a_contribution
LOCAL_LICENSE_CONDITIONS := by_exception_only not_allowed notice
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
