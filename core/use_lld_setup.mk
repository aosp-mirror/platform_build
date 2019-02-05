#############################################################
## Set up flags based on LOCAL_USE_CLANG_LLD.
## Input variables: LOCAL_USE_CLANG_LLD
## Output variables: my_use_clang_lld
#############################################################

# Use LLD by default.
# Do not use LLD if LOCAL_USE_CLANG_LLD is false or 0
my_use_clang_lld := true
ifneq (,$(LOCAL_USE_CLANG_LLD))
  ifneq (,$(filter 0 false,$(LOCAL_USE_CLANG_LLD)))
    my_use_clang_lld := false
  endif
endif

# Do not use LLD for Darwin host executables or shared libraries.  See
# https://lld.llvm.org/AtomLLD.html for status of lld for Mach-O.
ifeq ($($(my_prefix)OS),darwin)
my_use_clang_lld := false
endif
