# Clang flags for mips64 arch, target or host.

CLANG_CONFIG_mips64_EXTRA_ASFLAGS :=
CLANG_CONFIG_mips64_EXTRA_CFLAGS :=
CLANG_CONFIG_mips64_EXTRA_LDFLAGS :=

# Include common unknown flags
CLANG_CONFIG_mips64_UNKNOWN_CFLAGS := \
  $(CLANG_CONFIG_UNKNOWN_CFLAGS) \
  -fno-strict-volatile-bitfields \
  -fgcse-after-reload \
  -frerun-cse-after-loop \
  -frename-registers \
  -msynci \
  -mno-synci \
  -mno-fused-madd

# Temporary workaround for Mips clang++ problem creating
#   relocated ptrs in read-only pic .gcc_exception_table;
#   permanent fix pending at http://reviews.llvm.org/D9669
CLANG_CONFIG_mips64_UNKNOWN_CFLAGS += -Wl,--warn-shared-textrel

# We don't have any mips64 flags to substitute yet.
define subst-clang-incompatible-mips64-flags
  $(1)
endef
