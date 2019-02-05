$(call record-module-type,HOST_EXECUTABLE)
LOCAL_IS_HOST_MODULE := true
my_prefix := HOST_
LOCAL_HOST_PREFIX :=
include $(BUILD_SYSTEM)/multilib.mk

ifndef LOCAL_MODULE_HOST_ARCH
ifndef my_module_multilib
# By default we only build host module for the first arch.
my_module_multilib := first
endif
endif

ifeq ($(my_module_multilib),both)
ifneq ($(LOCAL_MODULE_CLASS),NATIVE_TESTS)
ifeq ($(LOCAL_MODULE_PATH_32)$(LOCAL_MODULE_STEM_32),)
$(error $(LOCAL_PATH): LOCAL_MODULE_STEM_32 or LOCAL_MODULE_PATH_32 is required for LOCAL_MULTILIB := both for module $(LOCAL_MODULE))
endif
ifeq ($(LOCAL_MODULE_PATH_64)$(LOCAL_MODULE_STEM_64),)
$(error $(LOCAL_PATH): LOCAL_MODULE_STEM_64 or LOCAL_MODULE_PATH_64 is required for LOCAL_MULTILIB := both for module $(LOCAL_MODULE))
endif
endif
else #!LOCAL_MULTILIB == both
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX := true
endif

LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
include $(BUILD_SYSTEM)/host_executable_internal.mk
endif

ifdef HOST_2ND_ARCH
LOCAL_2ND_ARCH_VAR_PREFIX := $(HOST_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# Build for HOST_2ND_ARCH
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(BUILD_SYSTEM)/host_executable_internal.mk
endif
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif  # HOST_2ND_ARCH

LOCAL_NO_2ND_ARCH_MODULE_SUFFIX :=
my_module_arch_supported :=
