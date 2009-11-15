# Configuration for Linux on ARM.
# Generating binaries for the ARMv4T architecture and higher
#
# Supporting armv4 (without thumb) does not make much sense since
# it's mostly an obsoleted instruction set architecture (only available
# in StrongArm and arm8). Supporting armv4 will require a lot of conditional
# code in assembler source since the bx (branch and exchange) instruction is
# not supported.
#
$(warning ARMv4t support is currently a work in progress. It does not work right now!)
ARCH_ARM_HAVE_THUMB_SUPPORT := false
ARCH_ARM_HAVE_THUMB_INTERWORKING := false
ARCH_ARM_HAVE_64BIT_DATA := false
ARCH_ARM_HAVE_HALFWORD_MULTIPLY := false
ARCH_ARM_HAVE_CLZ := false
ARCH_ARM_HAVE_FFS := false

DEFAULT_TARGET_CPU := arm920t

# Note: Hard coding the 'tune' value here is probably not ideal,
# and a better solution should be found in the future.
#
arch_variant_cflags := -march=armv4t -mtune=arm920t -D__ARM_ARCH_4T__
