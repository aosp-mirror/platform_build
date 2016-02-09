###########################################################
## Determine if a module can be built for an arch
##
## Inputs from module makefile:
## my_prefix   TARGET_ or HOST_
## my_module_multilib
## LOCAL_MODULE_$(my_prefix)ARCH
## LOCAL_MODULE_$(my_prefix)ARCH_WARN
## LOCAL_MODULE_UNSUPPORTED_$(my_prefix)ARCH
## LOCAL_MODULE_UNSUPPORTED_$(my_prefix)ARCH_WARN
## LOCAL_IS_HOST_MODULE
## LOCAL_MODULE_HOST_OS
##
## Inputs from build system:
## $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT
## LOCAL_2ND_ARCH_VAR_PREFIX
##
## Outputs:
## my_module_arch_supported := (true|false)
###########################################################

my_module_arch_supported := true

ifeq ($(my_module_multilib),none)
my_module_arch_supported := false
endif

ifeq ($($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT)|$(my_module_multilib),true|32)
my_module_arch_supported := false
endif
ifeq ($($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT)|$(my_module_multilib),|64)
my_module_arch_supported := false
endif

ifneq ($(LOCAL_2ND_ARCH_VAR_PREFIX),)
ifeq ($(my_module_multilib),first)
my_module_arch_supported := false
endif
endif

ifneq (,$(LOCAL_MODULE_$(my_prefix)ARCH))
ifeq (,$(filter $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_$(my_prefix)ARCH)))
my_module_arch_supported := false
endif
endif

ifneq (,$(LOCAL_MODULE_$(my_prefix)ARCH_WARN))
ifeq (,$(filter $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_$(my_prefix)ARCH_WARN)))
my_module_arch_supported := false
$(warning $(LOCAL_MODULE): architecture $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) not supported)
endif
endif

ifneq (,$(filter $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_UNSUPPORTED_$(my_prefix)ARCH)))
my_module_arch_supported := false
endif

ifneq (,$(filter $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_UNSUPPORTED_$(my_prefix)ARCH_WARN)))
my_module_arch_supported := false
$(warning $(LOCAL_MODULE): architecture $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) unsupported)
endif

ifdef LOCAL_IS_HOST_MODULE
ifneq (,$(LOCAL_MODULE_HOST_OS))
  ifeq (,$(filter $($(my_prefix)OS),$(LOCAL_MODULE_HOST_OS)))
    my_module_arch_supported := false
  endif
else ifeq ($($(my_prefix)OS),windows)
  # If LOCAL_MODULE_HOST_OS is empty, only linux and darwin are supported
  my_module_arch_supported := false
endif
endif
