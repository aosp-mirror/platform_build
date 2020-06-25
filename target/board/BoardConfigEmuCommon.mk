# BoardConfigEmuCommon.mk
#
# Common compile-time definitions for emulator
#

HAVE_HTC_AUDIO_DRIVER := true
BOARD_USES_GENERIC_AUDIO := true
TARGET_BOOTLOADER_BOARD_NAME := goldfish_$(TARGET_ARCH)

# No Kernel
TARGET_NO_KERNEL := true

# no hardware camera
USE_CAMERA_STUB := true

NUM_FRAMEBUFFER_SURFACE_BUFFERS := 3

# Build OpenGLES emulation guest and host libraries
BUILD_EMULATOR_OPENGL := true
BUILD_QEMU_IMAGES := true

# Build and enable the OpenGL ES View renderer. When running on the emulator,
# the GLES renderer disables itself if host GL acceleration isn't available.
USE_OPENGL_RENDERER := true

# Emulator doesn't support sparse image format.
TARGET_USERIMAGES_SPARSE_EXT_DISABLED := true

ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
  # emulator is Non-A/B device
  AB_OTA_UPDATER := false

  # emulator needs super.img
  BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true

  # 3G + header
  BOARD_SUPER_PARTITION_SIZE := 3229614080
  BOARD_SUPER_PARTITION_GROUPS := emulator_dynamic_partitions

  ifeq ($(QEMU_USE_SYSTEM_EXT_PARTITIONS),true)
    BOARD_EMULATOR_DYNAMIC_PARTITIONS_PARTITION_LIST := \
        system \
        system_ext \
        product \
        vendor

    TARGET_COPY_OUT_PRODUCT := product
    BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
    TARGET_COPY_OUT_SYSTEM_EXT := system_ext
    BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
  else
    TARGET_COPY_OUT_PRODUCT := system/product
    TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
    BOARD_EMULATOR_DYNAMIC_PARTITIONS_PARTITION_LIST := \
        system \
        vendor
  endif

  # 3G
  BOARD_EMULATOR_DYNAMIC_PARTITIONS_SIZE := 3221225472

  # in build environment to speed up make -j
  ifeq ($(QEMU_DISABLE_AVB),true)
    BOARD_AVB_ENABLE := false
  endif
else ifeq ($(PRODUCT_USE_DYNAMIC_PARTITION_SIZE),true)
  # Enable dynamic system image size and reserved 64MB in it.
  BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 67108864
  BOARD_VENDORIMAGE_PARTITION_RESERVED_SIZE := 67108864
else
  BOARD_SYSTEMIMAGE_PARTITION_SIZE := 3221225472
  BOARD_VENDORIMAGE_PARTITION_SIZE := 146800640
endif

#vendor boot
TARGET_NO_VENDOR_BOOT := false
BOARD_INCLUDE_DTB_IN_BOOTIMG := false
BOARD_BOOT_HEADER_VERSION := 3
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 0x06000000

# Enable chain partition for system.
BOARD_AVB_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_SYSTEM_ROLLBACK_INDEX := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION := 1

BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_FLASH_BLOCK_SIZE := 512
DEVICE_MATRIX_FILE   := device/generic/goldfish/compatibility_matrix.xml

BOARD_SEPOLICY_DIRS += device/generic/goldfish/sepolicy/common
