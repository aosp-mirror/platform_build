# Configuration for Linux on x86_64.
# Generating binaries for SandyBridge processors.
#
ARCH_X86_HAVE_SSSE3  := true
ARCH_X86_HAVE_SSE4_1 := true
ARCH_X86_HAVE_SSE4_2 := true
ARCH_X86_HAVE_AVX    := true

# CFLAGS for this arch
arch_variant_cflags := \
	-march=corei7-avx
