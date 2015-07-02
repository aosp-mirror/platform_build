# Clang flags for mips arch, target or host.

CLANG_CONFIG_mips_EXTRA_ASFLAGS :=
CLANG_CONFIG_mips_EXTRA_CFLAGS :=
CLANG_CONFIG_mips_EXTRA_LDFLAGS :=

# Include common unknown flags
CLANG_CONFIG_mips_UNKNOWN_CFLAGS := \
  $(CLANG_CONFIG_UNKNOWN_CFLAGS) \
  -fno-strict-volatile-bitfields \
  -fgcse-after-reload \
  -frerun-cse-after-loop \
  -frename-registers \
  -msynci \
  -mno-synci \
  -mno-fused-madd

# Temporary workaround for Mips clang++ problem,  creates
#   relocated ptrs in read-only pic .gcc_exception_table;
#   permanent fix pending at http://reviews.llvm.org/D9669
CLANG_CONFIG_mips_UNKNOWN_CFLAGS += -Wl,--warn-shared-textrel

# We don't have any mips flags to substitute yet.
define subst-clang-incompatible-mips-flags
  $(1)
endef
