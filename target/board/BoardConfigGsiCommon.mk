# BoardConfigGsiCommon.mk
#
# Common compile-time definitions for GSI
# Builds upon the mainline config.
#
# See device/generic/common/README.md for more details.
#

include build/make/target/board/BoardConfigMainlineCommon.mk

TARGET_NO_KERNEL := true

# This flag is set by mainline but isn't desired for GSI.
BOARD_USES_SYSTEM_OTHER_ODEX :=

# system.img is ext4/erofs and non-sparsed.
GSI_FILE_SYSTEM_TYPE ?= ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := $(GSI_FILE_SYSTEM_TYPE)
TARGET_USERIMAGES_SPARSE_EXT_DISABLED := true
TARGET_USERIMAGES_SPARSE_EROFS_DISABLED := true

# Enable system_dlkm image for creating a symlink in GSI to support
# the devices with system_dlkm partition
BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

# GSI also includes make_f2fs to support userdata parition in f2fs
# for some devices
TARGET_USERIMAGES_USE_F2FS := true

# Enable dynamic system image size and reserved 64MB in it.
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 67108864

# GSI forces product and system_ext packages to /system for now.
TARGET_COPY_OUT_PRODUCT := system/product
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE :=
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE :=

# Creates metadata partition mount point under root for
# the devices with metadata parition
BOARD_USES_METADATA_PARTITION := true

# Android Verified Boot (AVB):
#   Set the rollback index to zero, to prevent the device bootloader from
#   updating the last seen rollback index in the tamper-evident storage.
BOARD_AVB_ROLLBACK_INDEX := 0

# The chained vbmeta settings for boot images.
BOARD_AVB_BOOT_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_BOOT_ALGORITHM := SHA256_RSA4096
BOARD_AVB_BOOT_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_BOOT_ROLLBACK_INDEX_LOCATION := 2

# Enable AVB chained partition for system.
# https://android.googlesource.com/platform/external/avb/+/master/README.md
BOARD_AVB_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

# Using sha256 for dm-verity partitions. b/156162446
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += --hash_algorithm sha256

ifdef BUILDING_GSI
# super.img spec for GSI targets
BOARD_SUPER_PARTITION_SIZE := 3229614080
BOARD_SUPER_PARTITION_GROUPS := gsi_dynamic_partitions
BOARD_GSI_DYNAMIC_PARTITIONS_PARTITION_LIST := system
BOARD_GSI_DYNAMIC_PARTITIONS_SIZE := 3221225472
endif

# TODO(b/123695868, b/146149698):
#     This flag is set by mainline but isn't desired for GSI
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR :=

# GSI specific System Properties
ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
TARGET_SYSTEM_EXT_PROP := build/make/target/board/gsi_system_ext.prop
else
TARGET_SYSTEM_EXT_PROP := build/make/target/board/gsi_system_ext_user.prop
endif

# Set this to create /cache mount point for non-A/B devices that mounts /cache.
# The partition size doesn't matter, just to make build pass.
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_PARTITION_SIZE := 16777216

# Setup a vendor image to let PRODUCT_VENDOR_PROPERTIES does not affect GSI
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
