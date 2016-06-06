## Clang configurations.

LLVM_PREBUILTS_PATH := $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/bin
LLVM_RTLIB_PATH := $(LLVM_PREBUILTS_PATH)/../lib64/clang/$(LLVM_RELEASE_VERSION)/lib/linux/

# These will come from Soong, drop the environment versions
unexport CLANG
unexport CLANG_CXX
unexport CCC_CC
unexport CCC_CXX

CLANG_TBLGEN := $(BUILD_OUT_EXECUTABLES)/clang-tblgen$(BUILD_EXECUTABLE_SUFFIX)
LLVM_TBLGEN := $(BUILD_OUT_EXECUTABLES)/llvm-tblgen$(BUILD_EXECUTABLE_SUFFIX)

# RenderScript-specific tools
# These are tied to the version of LLVM directly in external/, so they might
# trail the host prebuilts being used for the rest of the build process.
RS_LLVM_PREBUILTS_VERSION := clang-2812033
RS_LLVM_PREBUILTS_BASE := prebuilts/clang/host
RS_LLVM_PREBUILTS_PATH := $(RS_LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(RS_LLVM_PREBUILTS_VERSION)/bin
RS_CLANG := $(RS_LLVM_PREBUILTS_PATH)/clang$(BUILD_EXECUTABLE_SUFFIX)
RS_LLVM_AS := $(RS_LLVM_PREBUILTS_PATH)/llvm-as$(BUILD_EXECUTABLE_SUFFIX)
RS_LLVM_LINK := $(RS_LLVM_PREBUILTS_PATH)/llvm-link$(BUILD_EXECUTABLE_SUFFIX)

CLANG_CONFIG_UNKNOWN_CFLAGS := \
  -finline-functions \
  -finline-limit=64 \
  -fno-canonical-system-headers \
  -Wno-clobbered \
  -fno-devirtualize \
  -fno-tree-sra \
  -fprefetch-loop-arrays \
  -funswitch-loops \
  -Werror=unused-but-set-parameter \
  -Werror=unused-but-set-variable \
  -Wmaybe-uninitialized \
  -Wno-error=clobbered \
  -Wno-error=maybe-uninitialized \
  -Wno-error=unused-but-set-parameter \
  -Wno-error=unused-but-set-variable \
  -Wno-free-nonheap-object \
  -Wno-literal-suffix \
  -Wno-maybe-uninitialized \
  -Wno-old-style-declaration \
  -Wno-psabi \
  -Wno-unused-but-set-parameter \
  -Wno-unused-but-set-variable \
  -Wno-unused-local-typedefs \
  -Wunused-but-set-parameter \
  -Wunused-but-set-variable \
  -fdiagnostics-color \
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
  -msynci \
  -mno-synci \
  -mno-fused-madd \
  -finline-limit=300 \
  -fno-inline-functions-called-once \
  -mfpmath=sse \
  -mbionic

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

ADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS := -fno-omit-frame-pointer
ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS := -Wl,-u,__asan_preinit

ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES := libasan

# This allows us to use the superset of functionality that compiler-rt
# provides to Clang (for supporting features like -ftrapv).
COMPILER_RT_CONFIG_EXTRA_STATIC_LIBRARIES := libcompiler_rt-extras

ifeq ($(HOST_PREFER_32_BIT),true)
# We don't have 32-bit prebuilt libLLVM/libclang, so force to build them from source.
FORCE_BUILD_LLVM_COMPONENTS := true
endif

include $(BUILD_SYSTEM)/clang/tidy.mk
