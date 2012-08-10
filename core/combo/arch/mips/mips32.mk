# Configuration for Android on MIPS.
# Generating binaries for MIPS32/soft-float/little-endian

arch_variant_cflags := \
    -EL \
    -march=mips32 \
    -mtune=mips32 \
    -mips32 \
    -msoft-float

arch_variant_ldflags := \
    -EL
