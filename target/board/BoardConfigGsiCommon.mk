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

# Enable dyanmic system image size and reserved 64MB in it.
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 67108864

# Android Verified Boot (AVB):
#   1) Sets BOARD_AVB_ENABLE to sign the GSI image.
#   2) Sets AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED (--flag 2) in
#      vbmeta.img to disable AVB verification.
#
# To disable AVB for GSI, use the vbmeta.img and the GSI together.
# To enable AVB for GSI, include the GSI public key into the device-specific
# vbmeta.img.
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flag 2

# Enable chain partition for system.
BOARD_AVB_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

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
