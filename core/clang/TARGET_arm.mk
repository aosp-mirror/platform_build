$(clang_2nd_arch_prefix)RS_TRIPLE := renderscript32-linux-androideabi
$(clang_2nd_arch_prefix)RS_TRIPLE_CFLAGS :=
$(clang_2nd_arch_prefix)RS_COMPAT_TRIPLE := armv7-none-linux-gnueabi

$(clang_2nd_arch_prefix)TARGET_LIBPROFILE_RT := $(LLVM_RTLIB_PATH)/libclang_rt.profile-arm-android.a

# Address sanitizer clang config
$(clang_2nd_arch_prefix)ADDRESS_SANITIZER_LINKER := /system/bin/linker_asan
