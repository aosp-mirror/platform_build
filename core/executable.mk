# We don't automatically set up rules to build executables for both
# TARGET_ARCH and TARGET_2ND_ARCH.
# By default, an executable is built for TARGET_ARCH.
# To build it for TARGET_2ND_ARCH in a 64bit product, use "LOCAL_32_BIT_ONLY := true".

ifeq ($(TARGET_PREFER_32_BIT),true)
ifneq ($(LOCAL_NO_2ND_ARCH),true)
LOCAL_32_BIT_ONLY := true
endif
endif

LOCAL_NO_2ND_ARCH_MODULE_SUFFIX := true

# check if primary arch is supported
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# primary arch is supported
include $(BUILD_SYSTEM)/executable_internal.mk
else ifneq (,$(TARGET_2ND_ARCH))
# check if secondary arch is supported
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# secondary arch is supported
include $(BUILD_SYSTEM)/executable_internal.mk
endif
endif # TARGET_2ND_ARCH

LOCAL_2ND_ARCH_VAR_PREFIX :=
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX :=

my_module_arch_supported :=
