# BoardConfigGsiCommon.mk
#
# Common compile-time definitions for GSI
#

# GSIs always use ext4.
TARGET_USERIMAGES_USE_EXT4 := true
# GSIs are historically released in sparse format.
# Some vendors' bootloaders don't work properly with raw format images. So
# we explicit specify this need below (even though it's the current default).
TARGET_USERIMAGES_SPARSE_EXT_DISABLED := false
TARGET_USES_MKE2FS := true

# Android Verified Boot (AVB):
#   Builds a special vbmeta.img that disables AVB verification.
#   Otherwise, AVB will prevent the device from booting the generic system.img.
#   Also checks that BOARD_AVB_ENABLE is not set, to prevent adding verity
#   metadata into system.img.
ifeq ($(BOARD_AVB_ENABLE),true)
$(error BOARD_AVB_ENABLE cannot be set for GSI)
endif
BOARD_BUILD_DISABLED_VBMETAIMAGE := true

ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
# GSI is always userdebug and needs a couple of properties taking precedence
# over those set by the vendor.
TARGET_SYSTEM_PROP := build/make/target/board/gsi_system.prop
endif
BOARD_VNDK_VERSION := current

# system-as-root is mandatory from Android P
TARGET_NO_RECOVERY := true
BOARD_BUILD_SYSTEM_ROOT_IMAGE := true

# 64 bits binder interface is mandatory from Android P
TARGET_USES_64_BIT_BINDER := true

# Android generic system image always create metadata partition
BOARD_USES_METADATA_PARTITION := true

# Set this to create /cache mount point for non-A/B devices that mounts /cache.
# The partition size doesn't matter, just to make build pass.
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_PARTITION_SIZE := 16777216

# Audio: must using XML format for Treblized devices
USE_XML_AUDIO_POLICY_CONF := 1
