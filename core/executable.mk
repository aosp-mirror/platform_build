# We don't automatically set up rules to build executables for both
# TARGET_ARCH and TARGET_2ND_ARCH.
# By default, an executable is built for TARGET_ARCH.
# To build it for TARGET_2ND_ARCH in a 64bit product, use "LOCAL_32BIT_ONLY := true".

ifeq ($(TARGET_IS_64_BIT)|$(LOCAL_32BIT_ONLY),true|true)
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
else
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif

include $(BUILD_SYSTEM)/executable_internal.mk
LOCAL_2ND_ARCH_VAR_PREFIX :=
