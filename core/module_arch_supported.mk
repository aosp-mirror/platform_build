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
##
## Inputs from build system:
## $(my_prefix)IS_64_BIT
## LOCAL_2ND_ARCH_VAR_PREFIX
##
## Outputs:
## my_module_arch_supported := (true|false)
###########################################################

my_module_arch_supported := true

ifeq ($(my_module_multilib),none)
my_module_arch_supported := false
endif

ifeq ($(LOCAL_2ND_ARCH_VAR_PREFIX),)
ifeq ($($(my_prefix)IS_64_BIT)|$(my_module_multilib),true|32)
my_module_arch_supported := false
else ifeq ($($(my_prefix)IS_64_BIT)|$(my_module_multilib),|64)
my_module_arch_supported := false
else ifeq ($(call directory_is_64_bit_blacklisted,$(LOCAL_PATH)),true)
my_module_arch_supported := false
endif
else # LOCAL_2ND_ARCH_VAR_PREFIX
ifeq ($(my_module_multilib),first)
my_module_arch_supported := false
else ifeq ($(my_module_multilib),64)
my_module_arch_supported := false
endif
endif # LOCAL_2ND_ARCH_VAR_PREFIX

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
