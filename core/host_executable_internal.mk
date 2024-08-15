###########################################################
## Standard rules for building an executable file.
##
## Additional inputs from base_rules.make:
## None.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := EXECUTABLES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $($(my_prefix)EXECUTABLE_SUFFIX)
endif

ifdef host-executable-hook
$(call host-executable-hook)
endif

skip_build_from_source :=
ifdef LOCAL_PREBUILT_MODULE_FILE
ifeq (,$(call if-build-from-source,$(LOCAL_MODULE),$(LOCAL_PATH)))
include $(BUILD_SYSTEM)/prebuilt_internal.mk
skip_build_from_source := true
endif
endif

ifndef skip_build_from_source

include $(BUILD_SYSTEM)/binary.mk

my_host_libprofile_rt := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LIBPROFILE_RT)
$(LOCAL_BUILT_MODULE): PRIVATE_HOST_LIBPROFILE_RT := $(my_host_libprofile_rt)

my_libdir := $(notdir $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_SHARED_LIBRARIES))
ifeq ($(LOCAL_MODULE_CLASS),NATIVE_TESTS)
$(LOCAL_BUILT_MODULE): PRIVATE_RPATHS := ../../$(my_libdir) ../../../$(my_libdir)
else
$(LOCAL_BUILT_MODULE): PRIVATE_RPATHS := ../$(my_libdir) $(my_libdir)
endif
my_libdir :=

my_crtbegin :=
my_crtend :=
my_libcrt_builtins :=
ifdef USE_HOST_MUSL
  my_crtbegin := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)HOST_OBJECT_libc_musl_crtbegin_dynamic)
  my_crtend := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)HOST_OBJECT_libc_musl_crtend)
  my_libcrt_builtins := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LIBCRT_BUILTINS)
  $(LOCAL_BUILT_MODULE): PRIVATE_LDFLAGS += -Wl,--no-dynamic-linker
endif

$(LOCAL_BUILT_MODULE): PRIVATE_CRTBEGIN := $(my_crtbegin)
$(LOCAL_BUILT_MODULE): PRIVATE_CRTEND := $(my_crtend)
$(LOCAL_BUILT_MODULE): PRIVATE_LIBCRT_BUILTINS := $(my_libcrt_builtins)
$(LOCAL_BUILT_MODULE): $(my_crtbegin) $(my_crtend) $(my_libcrt_builtins)

$(LOCAL_BUILT_MODULE): $(all_objects) $(all_libraries) $(CLANG_CXX)
	$(transform-host-o-to-executable)

$(if $(my_register_name),$(eval ALL_MODULES.$(my_register_name).MAKE_MODULE_TYPE:=HOST_EXECUTABLE))

endif  # skip_build_from_source
