# At the moment, use the same settings than the one
# for armv5te, since TARGET_ARCH_VARIANT := armv5te-vfp
# will only be used to select an optimized VFP-capable assembly
# interpreter loop for Dalvik.
#
include $(BUILD_SYSTEM)/combo/arch/armv5te.mk

