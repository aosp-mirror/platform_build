# Clang flags for arm64 arch, target or host.

CLANG_CONFIG_arm64_EXTRA_ASFLAGS :=

CLANG_CONFIG_arm64_EXTRA_CFLAGS :=

CLANG_CONFIG_arm64_EXTRA_LDFLAGS :=

# Include common unknown flags
CLANG_CONFIG_arm64_UNKNOWN_CFLAGS := \
  $(CLANG_CONFIG_UNKNOWN_CFLAGS) \
  -fgcse-after-reload \
  -frerun-cse-after-loop \
  -frename-registers \
  -fno-strict-volatile-bitfields \
  -fno-align-jumps \
  -Wa,--noexecstack

# We don't have any arm64 flags to substitute yet.
define subst-clang-incompatible-arm64-flags
  $(1)
endef
