
CLANG := $(HOST_OUT_EXECUTABLES)/clang$(HOST_EXECUTABLE_SUFFIX)
CLANG_CXX := $(HOST_OUT_EXECUTABLES)/clang++$(HOST_EXECUTABLE_SUFFIX)
LLVM_AS := $(HOST_OUT_EXECUTABLES)/llvm-as$(HOST_EXECUTABLE_SUFFIX)
LLVM_LINK := $(HOST_OUT_EXECUTABLES)/llvm-link$(HOST_EXECUTABLE_SUFFIX)

# Clang flags for all host or target rules
CLANG_CONFIG_EXTRA_ASFLAGS :=
CLANG_CONFIG_EXTRA_CFLAGS :=
CLANG_CONFIG_EXTRA_CPPFLAGS :=
CLANG_CONFIG_EXTRA_LDFLAGS :=

CLANG_CONFIG_EXTRA_CFLAGS := \
  -D__compiler_offsetof=__builtin_offsetof

CLANG_CONFIG_UNKNOWN_CFLAGS := \
  -funswitch-loops \
  -Wno-psabi \
  -Wno-unused-but-set-variable \
  -Wno-unused-but-set-parameter

# Clang flags for all host rules
CLANG_CONFIG_HOST_EXTRA_ASFLAGS :=
CLANG_CONFIG_HOST_EXTRA_CFLAGS :=
CLANG_CONFIG_HOST_EXTRA_CPPFLAGS :=
CLANG_CONFIG_HOST_EXTRA_LDFLAGS :=

# Clang flags for all target rules
CLANG_CONFIG_TARGET_EXTRA_ASFLAGS :=
CLANG_CONFIG_TARGET_EXTRA_CFLAGS := -nostdlibinc
CLANG_CONFIG_TARGET_EXTRA_CPPFLAGS := -nostdlibinc
CLANG_CONFIG_TARGET_EXTRA_LDFLAGS :=

# HOST config
include $(BUILD_SYSTEM)/clang/HOST_$(HOST_ARCH).mk

# TARGET config
clang_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/clang/TARGET_$(TARGET_ARCH).mk

# TARGET_2ND_ARCH config
ifdef TARGET_2ND_ARCH
clang_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/clang/TARGET_$(TARGET_2ND_ARCH).mk
endif


# Clang compiler-specific libc headers
CLANG_CONFIG_EXTRA_HOST_C_INCLUDES := external/clang/lib/include
CLANG_CONFIG_EXTRA_TARGET_C_INCLUDES := external/clang/lib/include $(TARGET_OUT_HEADERS)/clang

# Address sanitizer clang config
ADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS := -fsanitize=address
ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS := -Wl,-u,__asan_preinit
ADDRESS_SANITIZER_CONFIG_EXTRA_SHARED_LIBRARIES := libdl libasan_preload
ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES := libasan

# This allows us to use the superset of functionality that compiler-rt
# provides to Clang (for supporting features like -ftrapv).
COMPILER_RT_CONFIG_EXTRA_STATIC_LIBRARIES := libcompiler_rt-extras
