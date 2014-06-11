my_prefix := HOST_
include $(BUILD_SYSTEM)/multilib.mk

ifndef LOCAL_MODULE_HOST_ARCH
ifndef my_module_multilib
ifeq ($(HOST_PREFER_32_BIT),true)
my_module_multilib := 32
else
# By default we only build host module for the first arch.
my_module_multilib := first
endif
endif
endif

LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
include $(BUILD_SYSTEM)/host_shared_library_internal.mk
endif

ifdef HOST_2ND_ARCH
LOCAL_2ND_ARCH_VAR_PREFIX := $(HOST_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# Build for HOST_2ND_ARCH
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(BUILD_SYSTEM)/host_shared_library_internal.mk
endif
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif  # HOST_2ND_ARCH

my_module_arch_supported :=

###########################################################
## Copy headers to the install tree
###########################################################
include $(BUILD_COPY_HEADERS)
