# We don't automatically set up rules to build executables for both
# TARGET_ARCH and TARGET_2ND_ARCH.
# By default, an executable is built for TARGET_ARCH.
# To build it for TARGET_2ND_ARCH in a 64bit product, use "LOCAL_32_BIT_ONLY := true".

ifeq ($(TARGET_PREFER_32_BIT),true)
ifneq ($(LOCAL_NO_2ND_ARCH),true)
LOCAL_32_BIT_ONLY := true
endif
endif

ifeq ($(TARGET_IS_64_BIT)|$(LOCAL_32_BIT_ONLY),true|true)
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
else
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif

LOCAL_NO_2ND_ARCH_MODULE_SUFFIX := true
include $(BUILD_SYSTEM)/executable_internal.mk
LOCAL_2ND_ARCH_VAR_PREFIX :=
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX :=
