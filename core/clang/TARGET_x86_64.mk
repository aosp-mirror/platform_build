RS_TRIPLE := renderscript64-linux-android
RS_TRIPLE_CFLAGS := -D__x86_64__
RS_COMPAT_TRIPLE := x86_64-linux-android

TARGET_LIBPROFILE_RT := $(LLVM_RTLIB_PATH)/libclang_rt.profile-x86_64-android.a
TARGET_LIBCRT_BUILTINS := $(LLVM_RTLIB_PATH)/libclang_rt.builtins-x86_64-android.a

# Address sanitizer clang config
ADDRESS_SANITIZER_LINKER := /system/bin/linker_asan64
ADDRESS_SANITIZER_LINKER_FILE := /system/bin/bootstrap/linker_asan64
