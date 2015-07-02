# Configuration for Android on Ingenic xb4780/Xburst MIPS CPU.
# Generating binaries for MIPS32R2/hard-float/little-endian without
# support for the Madd family of instructions.

ARCH_MIPS_HAS_FPU :=true
ARCH_HAVE_ALIGNED_DOUBLES :=true
arch_variant_cflags := \
    -mips32r2 \
    -mfp32 \
    -modd-spreg \
    -mno-fused-madd \
    -Wa,-mmxu \
    -mno-synci

arch_variant_ldflags := \
    -Wl,-melf32ltsmip
