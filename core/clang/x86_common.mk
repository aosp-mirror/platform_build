ifeq ($(HOST_OS),darwin)
# nothing required here yet
endif

ifeq ($(HOST_OS),linux)

ifneq ($(strip $(BUILD_HOST_64bit)),)
# Needs to be updated along with gcc
HOST_ARCH_DESCRIPTOR_FOR_CLANG := x86_64-linux
else
# Needs to be updated along with gcc
HOST_ARCH_DESCRIPTOR_FOR_CLANG := i686-linux
endif

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_ASFLAGS := \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_CFLAGS :=

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_CPPFLAGS :=   \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/include/c++/4.6.x-google \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/include/c++/4.6.x-google/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG) \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/include/c++/4.6.x-google/backward \

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_LDFLAGS := \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot \
  -B$(HOST_TOOLCHAIN_FOR_CLANG)/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/bin \
  -B$(HOST_TOOLCHAIN_FOR_CLANG)/lib/gcc/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/4.6.x-google \
  -L$(HOST_TOOLCHAIN_FOR_CLANG)/lib/gcc/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/4.6.x-google

ifneq ($(strip $(BUILD_HOST_64bit)),)
# need to add lib64 if building 64-bit, otherwise lib
CLANG_CONFIG_x86_LINUX_HOST_EXTRA_LDFLAGS += -L$(HOST_TOOLCHAIN_FOR_CLANG)/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/lib64/
else
CLANG_CONFIG_x86_LINUX_HOST_EXTRA_LDFLAGS += -L$(HOST_TOOLCHAIN_FOR_CLANG)/$(HOST_ARCH_DESCRIPTOR_FOR_CLANG)/lib/
endif
endif # linux

ifeq ($(HOST_OS),windows)
# nothing required here yet
endif