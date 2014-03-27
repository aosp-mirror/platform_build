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

include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# prebuilts default to building for either architecture,
# the first if its supported, otherwise the second.
my_module_multilib := both
endif

# check if first arch is supported
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# first arch is supported
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
