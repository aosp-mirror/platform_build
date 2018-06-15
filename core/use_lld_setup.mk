#############################################################
## Set up flags based on USE_CLANG_LLD and LOCAL_USE_CLANG_LLD.
## Input variables: USE_CLANG_LLD,LOCAL_USE_CLANG_LLD.
## Output variables: my_use_clang_lld
#############################################################

# Use LLD by default.
# Do not use LLD if LOCAL_USE_CLANG_LLD is false or 0,
# of if LOCAL_USE_CLANG_LLD is not set and USE_CLANG_LLD is 0 or false.
my_use_clang_lld := true
ifneq (,$(LOCAL_USE_CLANG_LLD))
  ifneq (,$(filter 0 false,$(LOCAL_USE_CLANG_LLD)))
    my_use_clang_lld := false
  endif
else
  ifneq (,$(filter 0 false,$(USE_CLANG_LLD)))
    my_use_clang_lld := false
  endif
endif

# Do not use LLD for Darwin host executables or shared libraries.
# See https://lld.llvm.org/AtomLLD.html for status of lld for Mach-O.
ifeq ($(LOCAL_IS_HOST_MODULE),true)
  ifeq ($(HOST_OS),darwin)
    my_use_clang_lld := false
  endif
endif
