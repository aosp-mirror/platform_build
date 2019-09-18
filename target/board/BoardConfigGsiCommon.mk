# BoardConfigGsiCommon.mk
#
# Common compile-time definitions for GSI
# Builds upon the mainline config.
#

include build/make/target/board/BoardConfigMainlineCommon.mk

TARGET_NO_KERNEL := true

# This flag is set by mainline but isn't desired for GSI.
BOARD_USES_SYSTEM_OTHER_ODEX :=

# system.img is always ext4 with sparse option
# GSI also includes make_f2fs to support userdata parition in f2fs
# for some devices
TARGET_USERIMAGES_USE_F2FS := true

# Enable dynamic system image size and reserved 64MB in it.
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 67108864

# GSI forces product and system_ext packages to /system for now.
TARGET_COPY_OUT_PRODUCT := system/product
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE :=

# Creates metadata partition mount point under root for
# the devices with metadata parition
BOARD_USES_METADATA_PARTITION := true

# Android Verified Boot (AVB):
#   Set the rollback index to zero, to prevent the device bootloader from
#   updating the last seen rollback index in the tamper-evident storage.
BOARD_AVB_ROLLBACK_INDEX := 0

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

# Setup a vendor image to let PRODUCT_PROPERTY_OVERRIDES does not affect GSI
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4

# Disable 64 bit mediadrmserver
TARGET_ENABLE_MEDIADRM_64 :=
