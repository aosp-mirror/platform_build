my_multilib_stem := $(LOCAL_MODULE_STEM_$(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT),64,32))
ifdef my_multilib_stem
  my_module_stem := $(my_multilib_stem)
else ifdef LOCAL_MODULE_STEM
  my_module_stem := $(LOCAL_MODULE_STEM)
else
  my_module_stem := $(LOCAL_MODULE)
endif

ifdef LOCAL_BUILT_MODULE_STEM
  my_built_module_stem := $(LOCAL_BUILT_MODULE_STEM)
else
  my_built_module_stem := $(my_module_stem)$(LOCAL_MODULE_SUFFIX)
endif

ifdef LOCAL_INSTALLED_MODULE_STEM
  my_installed_module_stem := $(LOCAL_INSTALLED_MODULE_STEM)
else
  my_installed_module_stem := $(my_module_stem)$(LOCAL_MODULE_SUFFIX)
endif
