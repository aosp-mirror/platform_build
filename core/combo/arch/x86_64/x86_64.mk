# This file contains feature macro definitions specific to the
# base 'x86_64' platform ABI.
#
# It is also used to build full_x86_64-eng / sdk_x86_64-eng  platform images
# that are run in the emulator under KVM emulation (i.e. running directly on
# the host development machine's CPU).

ARCH_X86_HAVE_SSSE3 := true
ARCH_X86_HAVE_MOVBE := false # Only supported on Atom.
ARCH_X86_HAVE_POPCNT := true
ARCH_X86_HAVE_SSE4 := true
ARCH_X86_HAVE_SSE4_1 := true
ARCH_X86_HAVE_SSE4_2 := true
ARCH_X86_HAVE_AVX := false
ARCH_X86_HAVE_AVX2 := false
ARCH_X86_HAVE_AVX512 := false
