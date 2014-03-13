###########################################################
## Determine if a module can be built for an arch
##
## Inputs from module makefile:
## LOCAL_32_BIT_ONLY
## LOCAL_NO_2ND_ARCH
## LOCAL_MODULE_TARGET_ARCH
## LOCAL_MODULE_TARGET_ARCH_WARN
## LOCAL_MODULE_UNSUPPORTED_TARGET_ARCH
## LOCAL_MODULE_UNSUPPORTED_TARGET_ARCH_WARN
##
## Inputs from build system:
## TARGET_IS_64_BIT
## LOCAL_2ND_ARCH_VAR_PREFIX
##
## Outputs:
## my_module_arch_supported := (true|false)
###########################################################

my_module_arch_supported := true

ifeq ($(LOCAL_2ND_ARCH_VAR_PREFIX),)
ifeq ($(TARGET_IS_64_BIT)|$(LOCAL_32_BIT_ONLY),true|true)
my_module_arch_supported := false
else ifeq ($(call directory_is_64_bit_blacklisted,$(LOCAL_PATH)),true)
my_module_arch_supported := false
endif
else # LOCAL_2ND_ARCH_VAR_PREFIX
ifeq ($(LOCAL_NO_2ND_ARCH),true)
my_module_arch_supported := false
endif
endif # !LOCAL_2ND_ARCH_VAR_PREFIX

ifneq (,$(LOCAL_MODULE_TARGET_ARCH))
ifeq (,$(filter $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_TARGET_ARCH)))
my_module_arch_supported := false
endif
endif

ifneq (,$(LOCAL_MODULE_TARGET_ARCH_WARN))
ifeq (,$(filter $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_TARGET_ARCH_WARN)))
my_module_arch_supported := false
$(warning $(LOCAL_MODULE): architecture $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) not supported)
endif
endif

ifneq (,$(filter $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_UNSUPPORTED_TARGET_ARCH)))
my_module_arch_supported := false
endif

ifneq (,$(filter $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH),$(LOCAL_MODULE_UNSUPPORTED_TARGET_ARCH_WARN)))
my_module_arch_supported := false
$(warning $(LOCAL_MODULE): architecture $(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) unsupported)
endif
