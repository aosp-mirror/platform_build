
include $(BUILD_SYSTEM)/clang/x86.mk

CLANG_CONFIG_x86_TARGET_TRIPLE := i686-linux-android
# NOTE: There is no i686-linux-android prebuilt, so we must hardcode the
# x86_64 target instead.
CLANG_CONFIG_x86_TARGET_TOOLCHAIN_PREFIX := \
  $($(clang_2nd_arch_prefix)TARGET_TOOLCHAIN_ROOT)/x86_64-linux-android/bin

CLANG_CONFIG_x86_TARGET_EXTRA_ASFLAGS := \
  $(CLANG_CONFIG_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_x86_EXTRA_ASFLAGS) \
  -target $(CLANG_CONFIG_x86_TARGET_TRIPLE) \
  -B$(CLANG_CONFIG_x86_TARGET_TOOLCHAIN_PREFIX)

CLANG_CONFIG_x86_TARGET_EXTRA_CFLAGS := \
  $(CLANG_CONFIG_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_x86_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_x86_TARGET_EXTRA_ASFLAGS) \
  -fno-optimize-sibling-calls \
  -mstackrealign

# http://llvm.org/bugs/show_bug.cgi?id=15086,
# llvm tail call optimization is wrong for x86.
# -mstackrealign is needed to realign stack in native code
# that could be called from JNI, so that movaps instruction
# will work on assumed stack aligned local variables.

CLANG_CONFIG_x86_TARGET_EXTRA_CONLYFLAGS := \
  $(CLANG_CONFIG_EXTRA_CONLYFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_CONLYFLAGS) \
  $(CLANG_CONFIG_x86_EXTRA_CONLYFLAGS)

CLANG_CONFIG_x86_TARGET_EXTRA_CPPFLAGS := \
  $(CLANG_CONFIG_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_x86_EXTRA_CPPFLAGS) \

CLANG_CONFIG_x86_TARGET_EXTRA_LDFLAGS := \
  $(CLANG_CONFIG_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_x86_EXTRA_LDFLAGS) \
  -target $(CLANG_CONFIG_x86_TARGET_TRIPLE) \
  -B$(CLANG_CONFIG_x86_TARGET_TOOLCHAIN_PREFIX)


define $(clang_2nd_arch_prefix)convert-to-clang-flags
  $(strip \
  $(call subst-clang-incompatible-x86-flags,\
  $(filter-out $(CLANG_CONFIG_x86_UNKNOWN_CFLAGS),\
  $(1))))
endef

$(clang_2nd_arch_prefix)CLANG_TARGET_GLOBAL_CFLAGS := \
  $(call $(clang_2nd_arch_prefix)convert-to-clang-flags,$($(clang_2nd_arch_prefix)TARGET_GLOBAL_CFLAGS)) \
  $(CLANG_CONFIG_x86_TARGET_EXTRA_CFLAGS)

$(clang_2nd_arch_prefix)CLANG_TARGET_GLOBAL_CONLYFLAGS := \
  $(call $(clang_2nd_arch_prefix)convert-to-clang-flags,$($(clang_2nd_arch_prefix)TARGET_GLOBAL_CONLYFLAGS)) \
  $(CLANG_CONFIG_x86_TARGET_EXTRA_CONLYFLAGS)

$(clang_2nd_arch_prefix)CLANG_TARGET_GLOBAL_CPPFLAGS := \
  $(call $(clang_2nd_arch_prefix)convert-to-clang-flags,$($(clang_2nd_arch_prefix)TARGET_GLOBAL_CPPFLAGS)) \
  $(CLANG_CONFIG_x86_TARGET_EXTRA_CPPFLAGS)

$(clang_2nd_arch_prefix)CLANG_TARGET_GLOBAL_LDFLAGS := \
  $(call $(clang_2nd_arch_prefix)convert-to-clang-flags,$($(clang_2nd_arch_prefix)TARGET_GLOBAL_LDFLAGS)) \
  $(CLANG_CONFIG_x86_TARGET_EXTRA_LDFLAGS)

$(clang_2nd_arch_prefix)RS_TRIPLE := armv7-none-linux-gnueabi
$(clang_2nd_arch_prefix)RS_TRIPLE_CFLAGS := -D__i386__
$(clang_2nd_arch_prefix)RS_COMPAT_TRIPLE := i686-linux-android

$(clang_2nd_arch_prefix)TARGET_LIBPROFILE_RT := $(LLVM_RTLIB_PATH)/libclang_rt.profile-i686-android.a
