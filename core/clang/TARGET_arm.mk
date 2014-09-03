
include $(BUILD_SYSTEM)/clang/arm.mk

CLANG_CONFIG_arm_TARGET_TRIPLE := arm-linux-androideabi
CLANG_CONFIG_arm_TARGET_TOOLCHAIN_PREFIX := \
  $($(clang_2nd_arch_prefix)TARGET_TOOLCHAIN_ROOT)/$(CLANG_CONFIG_arm_TARGET_TRIPLE)/bin

CLANG_CONFIG_arm_TARGET_EXTRA_ASFLAGS := \
  $(CLANG_CONFIG_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_arm_EXTRA_ASFLAGS) \
  -target $(CLANG_CONFIG_arm_TARGET_TRIPLE) \
  -B$(CLANG_CONFIG_arm_TARGET_TOOLCHAIN_PREFIX)

CLANG_CONFIG_arm_TARGET_EXTRA_CFLAGS := \
  $(CLANG_CONFIG_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_arm_EXTRA_CFLAGS) \
  -target $(CLANG_CONFIG_arm_TARGET_TRIPLE) \
  $(CLANG_CONFIG_arm_TARGET_EXTRA_ASFLAGS)

CLANG_CONFIG_arm_TARGET_EXTRA_CPPFLAGS := \
  $(CLANG_CONFIG_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_arm_EXTRA_CPPFLAGS) \
  -target $(CLANG_CONFIG_arm_TARGET_TRIPLE)

CLANG_CONFIG_arm_TARGET_EXTRA_LDFLAGS := \
  $(CLANG_CONFIG_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_arm_EXTRA_LDFLAGS) \
  -target $(CLANG_CONFIG_arm_TARGET_TRIPLE) \
  -B$(CLANG_CONFIG_arm_TARGET_TOOLCHAIN_PREFIX)


define $(clang_2nd_arch_prefix)convert-to-clang-flags
  $(strip \
  $(call subst-clang-incompatible-arm-flags,\
  $(filter-out $(CLANG_CONFIG_arm_UNKNOWN_CFLAGS),\
  $(1))))
endef

$(clang_2nd_arch_prefix)CLANG_TARGET_GLOBAL_CFLAGS := \
  $(call $(clang_2nd_arch_prefix)convert-to-clang-flags,$($(clang_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS)) \
  $(CLANG_CONFIG_arm_TARGET_EXTRA_CFLAGS)

$(clang_2nd_arch_prefix)CLANG_TARGET_GLOBAL_CPPFLAGS := \
  $(call $(clang_2nd_arch_prefix)convert-to-clang-flags,$($(clang_2nd_arch_prefix)TARGET_GLOBAL_CPPFLAGS)) \
  $(CLANG_CONFIG_arm_TARGET_EXTRA_CPPFLAGS)

$(clang_2nd_arch_prefix)CLANG_TARGET_GLOBAL_LDFLAGS := \
  $(call $(clang_2nd_arch_prefix)convert-to-clang-flags,$($(clang_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS)) \
  $(CLANG_CONFIG_arm_TARGET_EXTRA_LDFLAGS)

$(clang_2nd_arch_prefix)RS_TRIPLE := armv7-none-linux-gnueabi
$(clang_2nd_arch_prefix)RS_TRIPLE_CFLAGS :=
RS_COMPAT_TRIPLE := armv7-none-linux-gnueabi
