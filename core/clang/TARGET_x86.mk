$(clang_2nd_arch_prefix)RS_TRIPLE := renderscript32-linux-androideabi
$(clang_2nd_arch_prefix)RS_TRIPLE_CFLAGS := -D__i386__
$(clang_2nd_arch_prefix)RS_COMPAT_TRIPLE := i686-linux-android

$(clang_2nd_arch_prefix)TARGET_LIBPROFILE_RT := $(LLVM_RTLIB_PATH)/libclang_rt.profile-i686-android.a
$(clang_2nd_arch_prefix)TARGET_LIBCRT_BUILTINS := $(LLVM_RTLIB_PATH)/libclang_rt.builtins-i686-android.a

# Address sanitizer clang config
$(clang_2nd_arch_prefix)ADDRESS_SANITIZER_LINKER := /system/bin/linker_asan
$(clang_2nd_arch_prefix)ADDRESS_SANITIZER_LINKER_FILE := /system/bin/bootstrap/linker_asan
