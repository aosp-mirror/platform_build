# Clang flags for x86_64 arch, target or host.

CLANG_CONFIG_x86_64_EXTRA_ASFLAGS :=
CLANG_CONFIG_x86_64_EXTRA_CFLAGS :=
CLANG_CONFIG_x86_64_EXTRA_LDFLAGS :=

# Include common unknown flags
CLANG_CONFIG_x86_64_UNKNOWN_CFLAGS := \
  $(CLANG_CONFIG_UNKNOWN_CFLAGS) \
  -finline-limit=300 \
  -fno-inline-functions-called-once \
  -mfpmath=sse \
  -mbionic

# We don't have any x86_64 flags to substitute yet.
define subst-clang-incompatible-x86_64-flags
  $(1)
endef
