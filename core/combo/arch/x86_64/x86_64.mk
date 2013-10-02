# This file contains feature macro definitions specific to the
# base 'x86_64' platform ABI. This one must *strictly* match the NDK x86_64 ABI
# which mandates specific CPU extensions to be available.
#
# It is also used to build full_x86_64-eng / sdk_x86_64-eng  platform images
# that are run in the emulator under KVM emulation (i.e. running directly on
# the host development machine's CPU).
#

# These features are optional and shall not be included in the base platform
# Otherwise, they sdk_x86_64-eng system images might fail to run on some
# developer machines.
#

ARCH_X86_HAVE_SSSE3 := true
ARCH_X86_HAVE_MOVBE := false
ARCH_X86_HAVE_POPCNT := true

# CFLAGS for this arch
arch_variant_cflags := \
    -march=x86-64

