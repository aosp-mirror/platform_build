# Configuration for Android on MIPS.
# Generating binaries for MIPS32R2/hard-float/little-endian/dsp

ARCH_MIPS_HAS_DSP  	:=true
ARCH_MIPS_DSP_REV	:=2
ARCH_MIPS_HAS_FPU       :=true
ARCH_HAVE_ALIGNED_DOUBLES :=true
arch_variant_cflags := \
    -EL \
    -march=mips32r2 \
    -mtune=mips32r2 \
    -mips32r2 \
    -mhard-float \
    -mdspr2 \
    -msynci

arch_variant_ldflags := \
    -EL
