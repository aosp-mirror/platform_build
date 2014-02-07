# Clang flags for x86 arch, target or host.

CLANG_CONFIG_x86_EXTRA_ASFLAGS := \
  -msse3
CLANG_CONFIG_x86_EXTRA_CFLAGS :=
CLANG_CONFIG_x86_EXTRA_LDFLAGS :=

# Include common unknown flags
CLANG_CONFIG_x86_UNKNOWN_CFLAGS := \
  $(CLANG_CONFIG_UNKNOWN_CFLAGS) \
  -finline-limit=300 \
  -fno-inline-functions-called-once \
  -mfpmath=sse \
  -mbionic

# We don't have any x86 flags to substitute yet.
define subst-clang-incompatible-x86-flags
  $(1)
endef
