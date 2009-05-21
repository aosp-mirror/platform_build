# config.mk
# 
# Product-specific compile-time definitions.
#

# Don't try prelinking or compressing the shared libraries
# used by the simulator.  The host OS won't know what to do
# with them, and they may not even be ELF files.
#
# These definitions override the defaults in config/config.make.
TARGET_COMPRESS_MODULE_SYMBOLS := false
TARGET_PRELINK_MODULE := false

# Don't try to build a bootloader.
TARGET_NO_BOOTLOADER := true

# Don't bother with a kernel
TARGET_NO_KERNEL := true

# The simulator does not support native code at all
TARGET_CPU_ABI := none

#the simulator partially emulates the original HTC /dev/eac audio interface
HAVE_HTC_AUDIO_DRIVER := true
BOARD_USES_GENERIC_AUDIO := true
