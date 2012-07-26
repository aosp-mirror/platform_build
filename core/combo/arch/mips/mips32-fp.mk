# Configuration for Android on MIPS.
# Generating binaries for MIPS32/hard-float/little-endian

ARCH_MIPS_HAS_FPU	:=true
ARCH_HAVE_ALIGNED_DOUBLES :=true
arch_variant_cflags := \
    -EL \
    -march=mips32 \
    -mtune=mips32 \
    -mips32 \
    -mhard-float

arch_variant_ldflags := \
    -EL
