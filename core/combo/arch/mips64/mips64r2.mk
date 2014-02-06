# Configuration for Android on mips64r2.

ARCH_MIPS_HAS_FPU	:=true
ARCH_HAVE_ALIGNED_DOUBLES :=true
arch_variant_cflags := \
    -EL \
    -march=mips64r2 \
    -mtune=mips64r2 \
    -mips64r2 \
    -mhard-float \
    -msynci

arch_variant_ldflags := \
    -EL
