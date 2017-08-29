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

# Device Manifest
ifdef DEVICE_MANIFEST_FILE
# $(DEVICE_MANIFEST_FILE) can be a list of files
include $(CLEAR_VARS)
LOCAL_MODULE        := manifest.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT_VENDOR)

GEN := $(local-generated-sources-dir)/manifest.xml
$(GEN): PRIVATE_DEVICE_MANIFEST_FILE := $(DEVICE_MANIFEST_FILE)
$(GEN): $(DEVICE_MANIFEST_FILE) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	BOARD_SEPOLICY_VERS=$(BOARD_SEPOLICY_VERS) \
	$(HOST_OUT_EXECUTABLES)/assemble_vintf -o $@ \
		-i $(call normalize-path-list,$(PRIVATE_DEVICE_MANIFEST_FILE))

LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
BUILT_VENDOR_MANIFEST := $(LOCAL_BUILT_MODULE)
endif

# Device Compatibility Matrix
ifdef DEVICE_MATRIX_FILE
include $(CLEAR_VARS)
LOCAL_MODULE        := compatibility_matrix.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT_VENDOR)

GEN := $(local-generated-sources-dir)/compatibility_matrix.xml
$(GEN): $(DEVICE_MATRIX_FILE) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	# TODO(b/37342627): put BOARD_VNDK_VERSION & BOARD_VNDK_LIBRARIES into device matrix.
	$(HOST_OUT_EXECUTABLES)/assemble_vintf -i $< -o $@

LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
BUILT_VENDOR_MATRIX := $(LOCAL_BUILT_MODULE)
endif

# Framework Manifest
include $(CLEAR_VARS)
LOCAL_MODULE        := system_manifest.xml
LOCAL_MODULE_STEM   := manifest.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT)

GEN := $(local-generated-sources-dir)/manifest.xml

$(GEN): PRIVATE_FLAGS :=

# TODO(b/37954458), (b/37321309) remove check of PRODUCT_FULL_TREBLE after
# putting device compatibility matrices for non-treble devices.
ifeq ($(PRODUCT_FULL_TREBLE),true)
ifdef BUILT_VENDOR_MATRIX
$(GEN): $(BUILT_VENDOR_MATRIX)
$(GEN): PRIVATE_FLAGS += -c "$(BUILT_VENDOR_MATRIX)"
endif
endif

$(GEN): $(FRAMEWORK_MANIFEST_FILE) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	BOARD_SEPOLICY_VERS=$(BOARD_SEPOLICY_VERS) $(HOST_OUT_EXECUTABLES)/assemble_vintf -i $< -o $@ $(PRIVATE_FLAGS)

LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
BUILT_SYSTEM_MANIFEST := $(LOCAL_BUILT_MODULE)

# Framework Compatibility Matrix
include $(CLEAR_VARS)
LOCAL_MODULE        := system_compatibility_matrix.xml
LOCAL_MODULE_STEM   := compatibility_matrix.xml
LOCAL_MODULE_CLASS  := ETC
LOCAL_MODULE_PATH   := $(TARGET_OUT)

GEN := $(local-generated-sources-dir)/compatibility_matrix.xml

$(GEN): PRIVATE_FLAGS :=

# TODO(b/37954458), (b/37321309) remove check of PRODUCT_FULL_TREBLE after
# putting complete HAL manifests on non-treble devices.
ifeq ($(PRODUCT_FULL_TREBLE),true)
ifdef BUILT_VENDOR_MANIFEST
$(GEN): $(BUILT_VENDOR_MANIFEST)
$(GEN): PRIVATE_FLAGS += -c "$(BUILT_VENDOR_MANIFEST)"
endif
endif

ifeq (true,$(BOARD_AVB_ENABLE))
$(GEN): $(AVBTOOL)
# INTERNAL_AVB_SYSTEM_SIGNING_ARGS consists of BOARD_AVB_SYSTEM_KEY_PATH and
# BOARD_AVB_SYSTEM_ALGORITHM. We should add the dependency of key path, which
# is a file, here.
$(GEN): $(BOARD_AVB_SYSTEM_KEY_PATH)
# Use deferred assignment (=) instead of immediate assignment (:=).
# Otherwise, cannot get INTERNAL_AVB_SYSTEM_SIGNING_ARGS.
FRAMEWORK_VBMETA_VERSION = $$("$(AVBTOOL)" add_hashtree_footer \
                              --print_required_libavb_version \
                              $(INTERNAL_AVB_SYSTEM_SIGNING_ARGS) \
                              $(BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS))
else
FRAMEWORK_VBMETA_VERSION := 0.0
endif

# All kernel versions that the system image works with.
KERNEL_VERSIONS := 3.18 4.4 4.9
KERNEL_CONFIG_DATA := test/vts-testcase/kernel/config/data

$(GEN): $(foreach version,$(KERNEL_VERSIONS),\
	$(wildcard $(KERNEL_CONFIG_DATA)/android-$(version)/android-base*.cfg))
$(GEN): PRIVATE_FLAGS += $(foreach version,$(KERNEL_VERSIONS),\
	--kernel=$(version):$(call normalize-path-list,\
		$(wildcard $(KERNEL_CONFIG_DATA)/android-$(version)/android-base*.cfg)))

KERNEL_VERSIONS :=
KERNEL_CONFIG_DATA :=

$(GEN): $(FRAMEWORK_COMPATIBILITY_MATRIX_FILE) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	# TODO(b/37405869) (b/37715375) inject avb versions as well for devices that have avb enabled.
	POLICYVERS=$(POLICYVERS) \
		BOARD_SEPOLICY_VERS=$(BOARD_SEPOLICY_VERS) \
		FRAMEWORK_VBMETA_VERSION=$(FRAMEWORK_VBMETA_VERSION) \
		$(HOST_OUT_EXECUTABLES)/assemble_vintf -i $< -o $@ $(PRIVATE_FLAGS)
LOCAL_PREBUILT_MODULE_FILE := $(GEN)
include $(BUILD_PREBUILT)
BUILT_SYSTEM_COMPATIBILITY_MATRIX := $(LOCAL_BUILT_MODULE)
