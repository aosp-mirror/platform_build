###########################################################
## Standard rules for copying files that are prebuilt
##
## Additional inputs from base_rules.make:
## None.
##
###########################################################

ifdef LOCAL_IS_HOST_MODULE
include $(BUILD_SYSTEM)/prebuilt_internal.mk
else #!LOCAL_IS_HOST_MODULE
# check if primary arch is supported
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# primary arch is supported
include $(BUILD_SYSTEM)/prebuilt_internal.mk
else ifneq (,$(TARGET_2ND_ARCH))
# check if secondary arch is supported
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# secondary arch is supported
include $(BUILD_SYSTEM)/prebuilt_internal.mk
endif
endif # TARGET_2ND_ARCH
endif # !LOCAL_IS_HOST_MODULE

LOCAL_2ND_ARCH_VAR_PREFIX :=

my_module_arch_supported :=
