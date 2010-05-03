TARGET_COMPRESS_MODULE_SYMBOLS := false
TARGET_PRELINK_MODULE := false
TARGET_NO_RECOVERY := true
TARGET_HARDWARE_3D := false
BOARD_USES_GENERIC_AUDIO := true
USE_CAMERA_STUB := true
TARGET_PROVIDES_INIT_RC := true
USE_CUSTOM_RUNTIME_HEAP_MAX := "32M"
TARGET_CPU_ABI := x86
TARGET_USERIMAGES_USE_EXT2 := true
TARGET_BOOTIMAGE_USE_EXT2 := true
TARGET_USE_DISKINSTALLER := false

# For KVM
# BOARD_KERNEL_CMDLINE := console=tty0 console=ttyS1,115200n8 console=tty0 androidboot.hardware=generic_x86 vga=788

# For mrst_ref
BOARD_KERNEL_CMDLINE := init=/init pci=noearly console=ttyS0 console=ttyS1,115200n8 console=tty0 earlyprintk=mrst loglevel=8 notsc no_percpu_apbt androidboot.hardware=generic_x86 s0ix_latency=160

BOARD_BOOTIMAGE_MAX_SIZE := 8388608
