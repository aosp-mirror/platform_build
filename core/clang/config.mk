## Clang configurations.

LLVM_RTLIB_PATH := $(LLVM_PREBUILTS_PATH)/../lib64/clang/$(LLVM_RELEASE_VERSION)/lib/linux/

CLANG_TBLGEN := $(BUILD_OUT_EXECUTABLES)/clang-tblgen$(BUILD_EXECUTABLE_SUFFIX)
LLVM_TBLGEN := $(BUILD_OUT_EXECUTABLES)/llvm-tblgen$(BUILD_EXECUTABLE_SUFFIX)

define convert-to-clang-flags
$(strip $(filter-out $(CLANG_CONFIG_UNKNOWN_CFLAGS),$(1)))
endef

CLANG_DEFAULT_UB_CHECKS := \
  bool \
  integer-divide-by-zero \
  return \
  returns-nonnull-attribute \
  shift-exponent \
  unreachable \
  vla-bound \

# TODO(danalbert): The following checks currently have compiler performance
# issues.
# CLANG_DEFAULT_UB_CHECKS += alignment
# CLANG_DEFAULT_UB_CHECKS += bounds
# CLANG_DEFAULT_UB_CHECKS += enum
# CLANG_DEFAULT_UB_CHECKS += float-cast-overflow
# CLANG_DEFAULT_UB_CHECKS += float-divide-by-zero
# CLANG_DEFAULT_UB_CHECKS += nonnull-attribute
# CLANG_DEFAULT_UB_CHECKS += null
# CLANG_DEFAULT_UB_CHECKS += shift-base
# CLANG_DEFAULT_UB_CHECKS += signed-integer-overflow

# TODO(danalbert): Fix UB in libc++'s __tree so we can turn this on.
# https://llvm.org/PR19302
# http://reviews.llvm.org/D6974
# CLANG_DEFAULT_UB_CHECKS += object-size

# HOST config
clang_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/clang/HOST_$(HOST_ARCH).mk

# HOST_2ND_ARCH config
ifdef HOST_2ND_ARCH
clang_2nd_arch_prefix := $(HOST_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/clang/HOST_$(HOST_2ND_ARCH).mk
endif

ifdef HOST_CROSS_ARCH
clang_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/clang/HOST_CROSS_$(HOST_CROSS_ARCH).mk
ifdef HOST_CROSS_2ND_ARCH
clang_2nd_arch_prefix := $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/clang/HOST_CROSS_$(HOST_CROSS_2ND_ARCH).mk
endif
endif

# TARGET config
clang_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/clang/TARGET_$(TARGET_ARCH).mk

# TARGET_2ND_ARCH config
ifdef TARGET_2ND_ARCH
clang_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/clang/TARGET_$(TARGET_2ND_ARCH).mk
endif

# This allows us to use the superset of functionality that compiler-rt
# provides to Clang (for supporting features like -ftrapv).
COMPILER_RT_CONFIG_EXTRA_STATIC_LIBRARIES := libcompiler_rt-extras

# A list of projects that are allowed to set LOCAL_CLANG to false.
# INTERNAL_LOCAL_CLANG_EXCEPTION_PROJECTS is defined later in other config.mk.
LOCAL_CLANG_EXCEPTION_PROJECTS = \
  bionic/tests/ \
  device/google/contexthub/ \
  device/huawei/angler/ \
  device/lge/bullhead/ \
  external/gentoo/integration/ \
  hardware/qcom/ \
  test/vts/hals/camera/bullhead/ \
  test/vts/hals/etc/libqdutils/ \
  vendor/huawei/angler/ \
  vendor/lge/bullhead/ \
  $(INTERNAL_LOCAL_CLANG_EXCEPTION_PROJECTS)

# Find $1 in the exception project list.
define find_in_local_clang_exception_projects
$(subst $(space),, \
  $(foreach project,$(LOCAL_CLANG_EXCEPTION_PROJECTS), \
    $(if $(filter $(project)%,$(1)),$(project)) \
  ) \
)
endef

include $(BUILD_SYSTEM)/clang/tidy.mk
