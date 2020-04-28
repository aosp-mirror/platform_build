# Configuration for Linux on ARM.
# Generating binaries for the ARMv8-a architecture
#
# Many libraries are not aware of armv8-a, and AArch32 is (almost) a superset
# of armv7-a-neon. So just let them think we are just like v7.
ARCH_ARM_HAVE_ARMV7A            := true
ARCH_ARM_HAVE_VFP               := true
ARCH_ARM_HAVE_VFP_D32           := true
ARCH_ARM_HAVE_NEON              := true
