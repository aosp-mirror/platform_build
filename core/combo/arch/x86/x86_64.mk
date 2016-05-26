# This file is used as the second (32-bit) architecture when building a generic
# x86_64 64-bit platform image. (full_x86_64-eng / sdk_x86_64-eng)
#
# The generic 'x86' variant cannot be used, since it resets some flags used
# by the 'x86_64' variant.

ARCH_X86_HAVE_SSSE3 := true
ARCH_X86_HAVE_MOVBE := false # Only supported on Atom.
ARCH_X86_HAVE_POPCNT := true
ARCH_X86_HAVE_SSE4 := true
ARCH_X86_HAVE_SSE4_1 := true
ARCH_X86_HAVE_SSE4_2 := true
