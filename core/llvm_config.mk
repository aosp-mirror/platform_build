CLANG := $(HOST_OUT_EXECUTABLES)/clang$(HOST_EXECUTABLE_SUFFIX)
CLANG_CXX := $(HOST_OUT_EXECUTABLES)/clang++$(HOST_EXECUTABLE_SUFFIX)
LLVM_AS := $(HOST_OUT_EXECUTABLES)/llvm-as$(HOST_EXECUTABLE_SUFFIX)
LLVM_LINK := $(HOST_OUT_EXECUTABLES)/llvm-link$(HOST_EXECUTABLE_SUFFIX)

# Clang flags for all host or target rules
CLANG_CONFIG_EXTRA_ASFLAGS :=
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

# ARM
llvm_arch := arm
CLANG_CONFIG_arm_EXTRA_ASFLAGS :=
CLANG_CONFIG_arm_EXTRA_CFLAGS := \
  -mllvm -arm-enable-ehabi
CLANG_CONFIG_arm_EXTRA_LDFLAGS :=
CLANG_CONFIG_arm_UNKNOWN_CFLAGS := \
  -mthumb-interwork \
  -fgcse-after-reload \
  -frerun-cse-after-loop \
  -frename-registers \
  -fno-builtin-sin \
  -fno-strict-volatile-bitfields \
  -fno-align-jumps \
  -Wa,--noexecstack

CLANG_CONFIG_arm_HOST_TRIPLE :=
CLANG_CONFIG_arm_TARGET_TRIPLE := arm-linux-androideabi

include $(BUILD_SYSTEM)/llvm_config_define_clang_flags.mk

# MIPS
llvm_arch := mips
CLANG_CONFIG_mips_EXTRA_ASFLAGS :=
CLANG_CONFIG_mips_EXTRA_CFLAGS :=
CLANG_CONFIG_mips_EXTRA_LDFLAGS :=
CLANG_CONFIG_mips_UNKNOWN_CFLAGS := \
  -EL \
  -mips32 \
  -mips32r2 \
  -mhard-float \
  -fno-strict-volatile-bitfields \
  -fgcse-after-reload \
  -frerun-cse-after-loop \
  -frename-registers \
  -march=mips32r2 \
  -mtune=mips32r2 \
  -march=mips32 \
  -mtune=mips32 \
  -msynci \
  -mno-fused-madd

CLANG_CONFIG_mips_HOST_TRIPLE :=
CLANG_CONFIG_mips_TARGET_TRIPLE := mipsel-linux-android

include $(BUILD_SYSTEM)/llvm_config_define_clang_flags.mk

# X86
llvm_arch := x86
CLANG_CONFIG_x86_EXTRA_ASFLAGS := \
  -msse3
CLANG_CONFIG_x86_EXTRA_CFLAGS :=
CLANG_CONFIG_x86_EXTRA_LDFLAGS :=
CLANG_CONFIG_x86_UNKNOWN_CFLAGS := \
  -finline-limit=300 \
  -fno-inline-functions-called-once \
  -mfpmath=sse \
  -mbionic

ifeq ($(HOST_OS),linux)
CLANG_CONFIG_x86_HOST_TRIPLE := i686-linux-gnu
endif
ifeq ($(HOST_OS),darwin)
CLANG_CONFIG_x86_HOST_TRIPLE := i686-apple-darwin
endif
ifeq ($(HOST_OS),windows)
CLANG_CONFIG_x86_HOST_TRIPLE := i686-pc-mingw32
endif

CLANG_CONFIG_x86_TARGET_TRIPLE := i686-linux-android
CLANG_CONFIG_x86_TARGET_TOOLCHAIN_PREFIX := \
  $(TARGET_TOOLCHAIN_ROOT)/x86_64-linux-android/bin

include $(BUILD_SYSTEM)/llvm_config_define_clang_flags.mk

# X86_64
llvm_arch := x86_64
CLANG_CONFIG_x86_64_EXTRA_ASFLAGS := \
CLANG_CONFIG_x86_64_EXTRA_CFLAGS :=
CLANG_CONFIG_x86_64_EXTRA_LDFLAGS := \
CLANG_CONFIG_x86_64_UNKNOWN_CFLAGS := \
  -finline-limit=300 \
  -fno-inline-functions-called-once \
  -mfpmath=sse \
  -mbionic

ifeq ($(HOST_OS),linux)
CLANG_CONFIG_x86_64_HOST_TRIPLE := x86_64-linux-gnu
endif
ifeq ($(HOST_OS),darwin)
CLANG_CONFIG_x86_64_HOST_TRIPLE := x86_64-apple-darwin
endif
ifeq ($(HOST_OS),windows)
CLANG_CONFIG_x86_64_HOST_TRIPLE := x86_64-pc-mingw64
endif
CLANG_CONFIG_x86_64_TARGET_TRIPLE := x86_64-linux-android

include $(BUILD_SYSTEM)/llvm_config_define_clang_flags.mk

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

# Macros to convert gcc flags to clang flags
define subst-clang-incompatible-flags
  $(subst -march=armv5te,-march=armv5t,\
  $(subst -march=armv5e,-march=armv5,\
  $(subst -mcpu=cortex-a15,-march=armv7-a,\
  $(1))))
endef

define convert-to-host-clang-flags
  $(strip \
  $(call subst-clang-incompatible-flags,\
  $(filter-out $(CLANG_CONFIG_$(HOST_ARCH)_UNKNOWN_CFLAGS),\
  $(1))))
endef

define convert-to-clang-flags
  $(strip \
  $(call subst-clang-incompatible-flags,\
  $(filter-out $(CLANG_CONFIG_$(TARGET_ARCH)_UNKNOWN_CFLAGS),\
  $(1))))
endef

# Define clang global flags
define get-clang-host-global-flags
  $(call convert-to-host-clang-flags,$(HOST_GLOBAL_$(1))) $(CLANG_CONFIG_$(HOST_ARCH)_HOST_EXTRA_$(1))
endef

define get-clang-global-flags
  $(call convert-to-clang-flags,$(TARGET_GLOBAL_$(1))) $(CLANG_CONFIG_$(TARGET_ARCH)_TARGET_EXTRA_$(1))
endef

CLANG_HOST_GLOBAL_CFLAGS := $(call get-clang-host-global-flags,CFLAGS)
CLANG_HOST_GLOBAL_CPPFLAGS := $(call get-clang-host-global-flags,CPPFLAGS)
CLANG_HOST_GLOBAL_LDFLAGS := $(call get-clang-host-global-flags,LDFLAGS)

CLANG_TARGET_GLOBAL_CFLAGS := $(call get-clang-global-flags,CFLAGS)
CLANG_TARGET_GLOBAL_CPPFLAGS := $(call get-clang-global-flags,CPPFLAGS)
CLANG_TARGET_GLOBAL_LDFLAGS := $(call get-clang-global-flags,LDFLAGS)

# Renderscript clang target triple
ifeq ($(TARGET_ARCH),arm)
  RS_TRIPLE := armv7-none-linux-gnueabi
endif
ifeq ($(TARGET_ARCH),mips)
  RS_TRIPLE := mipsel-unknown-linux
endif
ifeq ($(TARGET_ARCH),x86)
  RS_TRIPLE := i686-unknown-linux
endif
ifeq ($(TARGET_ARCH),x86_64)
  RS_TRIPLE := x86_64-unknown-linux
endif
