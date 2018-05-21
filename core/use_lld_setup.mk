#############################################################
## Set up flags based on USE_CLANG_LLD and LOCAL_USE_CLANG_LLD.
## Input variables: USE_CLANG_LLD,LOCAL_USE_CLANG_LLD.
## Output variables: my_use_clang_lld
#############################################################

# Use LLD only if it's not disabled by LOCAL_USE_CLANG_LLD,
# and enabled by LOCAL_USE_CLANG_LLD or USE_CLANG_LLD.
my_use_clang_lld := false
ifeq (,$(filter 0 false,$(LOCAL_USE_CLANG_LLD)))
  ifneq (,$(filter 1 true,$(LOCAL_USE_CLANG_LLD) $(USE_CLANG_LLD)))
    my_use_clang_lld := true
  endif
endif

# Do not use LLD for Darwin host executables or shared libraries.
# See https://lld.llvm.org/AtomLLD.html for status of lld for Mach-O.
ifeq ($(LOCAL_IS_HOST_MODULE),true)
  ifeq ($(HOST_OS),darwin)
    my_use_clang_lld := false
  endif
endif
