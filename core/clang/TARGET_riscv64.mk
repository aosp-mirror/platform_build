RS_TRIPLE := renderscript64-linux-android
RS_TRIPLE_CFLAGS := -D__riscv64__
RS_COMPAT_TRIPLE := riscv64-linux-android

TARGET_LIBPROFILE_RT := $(LLVM_RTLIB_PATH)/libclang_rt.profile-riscv64-android.a
TARGET_LIBCRT_BUILTINS := $(LLVM_RTLIB_PATH)/libclang_rt.builtins-riscv64-android.a
TARGET_LIBUNWIND := $(LLVM_RTLIB_PATH)/riscv64/libunwind.a

# Address sanitizer clang config
ADDRESS_SANITIZER_LINKER := /system/bin/linker_asan64
ADDRESS_SANITIZER_LINKER_FILE := /system/bin/bootstrap/linker_asan64

PREBUILT_LIBCXX_ARCH_DIR := riscv64
