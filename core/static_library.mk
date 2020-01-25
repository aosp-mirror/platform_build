$(call record-module-type,STATIC_LIBRARY)
ifdef LOCAL_IS_HOST_MODULE
  $(call pretty-error,BUILD_STATIC_LIBRARY is incompatible with LOCAL_IS_HOST_MODULE. Use BUILD_HOST_STATIC_LIBRARY instead)
endif
my_prefix := TARGET_
include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# libraries default to building for both architecturess
my_module_multilib := both
endif

LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
include $(BUILD_SYSTEM)/static_library_internal.mk
endif

ifdef TARGET_2ND_ARCH

LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
# Build for TARGET_2ND_ARCH
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(BUILD_SYSTEM)/static_library_internal.mk

endif

LOCAL_2ND_ARCH_VAR_PREFIX :=

endif # TARGET_2ND_ARCH

my_module_arch_supported :=

###########################################################
## Copy headers to the install tree
###########################################################
include $(BUILD_COPY_HEADERS)
