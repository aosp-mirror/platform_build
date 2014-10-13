# Configuration for Linux on x86.
# Generating binaries for SandyBridge processors.
#
ARCH_X86_HAVE_SSSE3  := true
ARCH_X86_HAVE_SSE4   := true
ARCH_X86_HAVE_SSE4_1 := true
ARCH_X86_HAVE_SSE4_2 := true
ARCH_X86_HAVE_AES_NI := true
ARCH_X86_HAVE_AVX    := true
ARCH_X86_HAVE_POPCNT := true
ARCH_X86_HAVE_MOVBE  := false

# CFLAGS for this arch
arch_variant_cflags := \
	-march=corei7-avx \
	-mfpmath=sse \

