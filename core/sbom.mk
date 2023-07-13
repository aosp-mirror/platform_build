# For SBOM generation
# This is included by base_rules.mk and is not necessary to be included in other .mk files
# unless a .mk file changes its installed file after including base_rules.mk.

ifdef my_register_name
  # ALL_INSTALLED_FILES.$(installed_file).STATIC_LIBRARIES: list of module name of static libraries, e.g. libc++demangle libclang_rt.builtins, for primary arch
  # ALL_INSTALLED_FILES.$(installed_file).WHOLE_STATIC_LIBRARIES: list of module name of static libraries, e.g. libc++demangle_32 libclang_rt.builtins_32, for 2nd arch.
  ifneq (, $(strip $(ALL_MODULES.$(my_register_name).INSTALLED)))
    $(foreach installed_file,$(ALL_MODULES.$(my_register_name).INSTALLED),\
      $(eval ALL_INSTALLED_FILES.$(installed_file) := $(my_register_name))\
      $(eval ALL_INSTALLED_FILES.$(installed_file).STATIC_LIBRARIES := $(foreach l,$(strip $(sort $(LOCAL_STATIC_LIBRARIES))),$l$(if $(LOCAL_2ND_ARCH_VAR_PREFIX),$($(my_prefix)2ND_ARCH_MODULE_SUFFIX))))\
      $(eval ALL_INSTALLED_FILES.$(installed_file).WHOLE_STATIC_LIBRARIES := $(foreach l,$(strip $(sort $(LOCAL_WHOLE_STATIC_LIBRARIES))),$l$(if $(LOCAL_2ND_ARCH_VAR_PREFIX),$($(my_prefix)2ND_ARCH_MODULE_SUFFIX))))\
    )
  endif
  ifeq (STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS))
  ALL_STATIC_LIBRARIES.$(my_register_name).STATIC_LIBRARIES := $(foreach l,$(strip $(sort $(LOCAL_STATIC_LIBRARIES))),$l$($(my_prefix)2ND_ARCH_MODULE_SUFFIX))
  ALL_STATIC_LIBRARIES.$(my_register_name).WHOLE_STATIC_LIBRARIES := $(foreach l,$(strip $(sort $(LOCAL_WHOLE_STATIC_LIBRARIES))),$l$($(my_prefix)2ND_ARCH_MODULE_SUFFIX))
  ifdef LOCAL_SOONG_MODULE_TYPE
    ALL_STATIC_LIBRARIES.$(my_register_name).BUILT_FILE := $(LOCAL_PREBUILT_MODULE_FILE)
  endif
  endif
endif