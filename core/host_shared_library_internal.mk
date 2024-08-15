###########################################################
## Standard rules for building a normal shared library.
##
## Additional inputs from base_rules.make:
## None.
##
## LOCAL_MODULE_SUFFIX will be set for you.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $($(my_prefix)SHLIB_SUFFIX)
endif
ifneq ($(strip $(LOCAL_MODULE_STEM)$(LOCAL_BUILT_MODULE_STEM)),)
$(error $(LOCAL_PATH): Cannot set module stem for a library)
endif

ifdef host-shared-library-hook
$(call host-shared-library-hook)
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

ifdef USE_HOST_MUSL
  my_crtbegin := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)HOST_OBJECT_libc_musl_crtbegin_so)
  my_crtend := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)HOST_OBJECT_libc_musl_crtend_so)
  my_libcrt_builtins := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LIBCRT_BUILTINS)
endif

$(LOCAL_BUILT_MODULE): PRIVATE_CRTBEGIN := $(my_crtbegin)
$(LOCAL_BUILT_MODULE): PRIVATE_CRTEND := $(my_crtend)
$(LOCAL_BUILT_MODULE): PRIVATE_LIBCRT_BUILTINS := $(my_libcrt_builtins)
$(LOCAL_BUILT_MODULE): $(my_crtbegin) $(my_crtend) $(my_libcrt_builtins)

$(LOCAL_BUILT_MODULE): \
        $(all_objects) \
        $(all_libraries) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-host-o-to-shared-lib)

$(if $(my_register_name),$(eval ALL_MODULES.$(my_register_name).MAKE_MODULE_TYPE:=HOST_SHARED_LIBRARY))

endif  # skip_build_from_source
