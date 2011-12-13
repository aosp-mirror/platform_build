# This file contains feature macro definitions specific to the
# base 'x86' platform ABI. This one must *strictly* match the NDK x86 ABI
# which mandates specific CPU extensions to be available.
#
# It is also used to build full_x86-eng / sdk_x86-eng platform images that
# are run in the emulator under KVM emulation (i.e. running directly on
# the host development machine's CPU).
#

# If your target device doesn't support the four following features, then
# it cannot be compatible with the NDK x86 ABI. You should define a new
# target arch variant (e.g. "x86-mydevice") and a corresponding file
# under build/core/combo/arch/x86/
#
ARCH_X86_HAVE_MMX   := true
ARCH_X86_HAVE_SSE   := true
ARCH_X86_HAVE_SSE2  := true
ARCH_X86_HAVE_SSE3  := true

# These features are optional and shall not be included in the base platform
# Otherwise, they sdk_x86-eng system images might fail to run on some
# developer machines.
#

ARCH_X86_HAVE_SSSE3 := false
ARCH_X86_HAVE_MOVBE := false
ARCH_X86_HAVE_POPCNT := false


# XXX: This flag is probably redundant, because it should be set by default
# by our toolchain binaries. However, there have been reports that this may
# not always work as intended, so keep it unless we have the time to check
# everything properly.

TARGET_GLOBAL_CFLAGS += -march=i686
