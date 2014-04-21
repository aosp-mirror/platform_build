ifeq ($(HOST_OS),darwin)
# nothing required here yet
endif

ifeq ($(HOST_OS),linux)

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_ASFLAGS := \
  --gcc-toolchain=$(HOST_TOOLCHAIN_FOR_CLANG) \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_CFLAGS := \
  --gcc-toolchain=$(HOST_TOOLCHAIN_FOR_CLANG) \

ifneq ($(strip $(BUILD_HOST_64bit)),)
CLANG_CONFIG_x86_LINUX_HOST_EXTRA_CPPFLAGS :=   \
  --gcc-toolchain=$(HOST_TOOLCHAIN_FOR_CLANG) \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/include/c++/4.6 \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/include/c++/4.6/x86_64-linux \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/include/c++/4.6/backward \

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_LDFLAGS := \
  --gcc-toolchain=$(HOST_TOOLCHAIN_FOR_CLANG) \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot \
  -B$(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/bin \
  -B$(HOST_TOOLCHAIN_FOR_CLANG)/lib/gcc/x86_64-linux/4.6 \
  -L$(HOST_TOOLCHAIN_FOR_CLANG)/lib/gcc/x86_64-linux/4.6 \
  -L$(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/lib64/
else
CLANG_CONFIG_x86_LINUX_HOST_EXTRA_CPPFLAGS :=   \
  --gcc-toolchain=$(HOST_TOOLCHAIN_FOR_CLANG) \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/include/c++/4.6 \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/include/c++/4.6/x86_64-linux/32 \
  -isystem $(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/include/c++/4.6/backward \

CLANG_CONFIG_x86_LINUX_HOST_EXTRA_LDFLAGS := \
  --gcc-toolchain=$(HOST_TOOLCHAIN_FOR_CLANG) \
  --sysroot=$(HOST_TOOLCHAIN_FOR_CLANG)/sysroot \
  -B$(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/bin \
  -B$(HOST_TOOLCHAIN_FOR_CLANG)/lib/gcc/x86_64-linux/4.6/32 \
  -L$(HOST_TOOLCHAIN_FOR_CLANG)/lib/gcc/x86_64-linux/4.6/32 \
  -L$(HOST_TOOLCHAIN_FOR_CLANG)/x86_64-linux/lib32/
endif
endif

ifeq ($(HOST_OS),windows)
# nothing required here yet
endif