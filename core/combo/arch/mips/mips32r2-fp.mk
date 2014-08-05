# Configuration for Android on MIPS.
# Generating binaries for MIPS32R2/hard-float/little-endian

ARCH_MIPS_HAS_FPU	:=true
ARCH_HAVE_ALIGNED_DOUBLES :=true
arch_variant_cflags := \
    -mips32r2 \
    -mfp32 \
    -modd-spreg \
    -msynci

arch_variant_ldflags := \
    -Wl,-melf32ltsmip
