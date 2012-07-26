# Configuration for Android on MIPS.
# Generating binaries for MIPS32R2/soft-float/little-endian/dsp

ARCH_MIPS_HAS_DSP  	:=true
ARCH_MIPS_DSP_REV	:=2

arch_variant_cflags := \
    -EL \
    -march=mips32r2 \
    -mtune=mips32r2 \
    -mips32r2 \
    -msoft-float \
    -mdspr2

arch_variant_ldflags := \
    -EL
