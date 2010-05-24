# config.mk
# 
# Product-specific compile-time definitions.
#

# The generic product target doesn't have any hardware-specific pieces.
TARGET_NO_BOOTLOADER := true
TARGET_NO_KERNEL := true
HAVE_HTC_AUDIO_DRIVER := true

# no hardware camera
USE_CAMERA_STUB := true
