RS_TRIPLE := renderscript64-linux-android
RS_TRIPLE_CFLAGS :=
RS_COMPAT_TRIPLE := aarch64-linux-android

TARGET_LIBPROFILE_RT := $(LLVM_RTLIB_PATH)/libclang_rt.profile-aarch64-android.a
TARGET_LIBCRT_BUILTINS := $(LLVM_RTLIB_PATH)/libclang_rt.builtins-aarch64-android.a

# Address sanitizer clang config
ADDRESS_SANITIZER_LINKER := /system/bin/linker_asan64
ADDRESS_SANITIZER_LINKER_FILE := /system/bin/bootstrap/linker_asan64
