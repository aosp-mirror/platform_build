# Configuration for Linux on x86_64.
# Generating binaries for Haswell processors.
#
ARCH_X86_HAVE_SSSE3  := true
ARCH_X86_HAVE_SSE4   := true
ARCH_X86_HAVE_SSE4_1 := true
ARCH_X86_HAVE_SSE4_2 := true
ARCH_X86_HAVE_AES_NI := true
ARCH_X86_HAVE_AVX    := true

# CFLAGS for this arch
arch_variant_cflags := \
	-march=core-avx2
