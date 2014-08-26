# Clang flags for arm arch, target or host.

CLANG_CONFIG_arm_EXTRA_ASFLAGS := \
  -no-integrated-as

CLANG_CONFIG_arm_EXTRA_CFLAGS := \
  -no-integrated-as

CLANG_CONFIG_arm_EXTRA_CPPFLAGS := \
  -no-integrated-as

CLANG_CONFIG_arm_EXTRA_LDFLAGS := \
  -no-integrated-as

# Include common unknown flags
CLANG_CONFIG_arm_UNKNOWN_CFLAGS := \
  $(CLANG_CONFIG_UNKNOWN_CFLAGS) \
  -mthumb-interwork \
  -fgcse-after-reload \
  -frerun-cse-after-loop \
  -frename-registers \
  -fno-align-jumps \
  -fno-builtin-sin \
  -fno-caller-saves \
  -fno-early-inlining \
  -fno-move-loop-invariants \
  -fno-partial-inlining \
  -fno-strict-volatile-bitfields \
  -fno-tree-copy-prop \
  -fno-tree-loop-optimize \
  -Wa,--noexecstack

define subst-clang-incompatible-arm-flags
  $(subst -march=armv5te,-march=armv5t,\
  $(subst -march=armv5e,-march=armv5,\
  $(subst -mcpu=cortex-a15,-march=armv7-a,\
  $(1))))
endef
