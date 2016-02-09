LOCAL_IS_HOST_MODULE := true
my_prefix := HOST_
LOCAL_HOST_PREFIX :=
include $(BUILD_SYSTEM)/multilib.mk

ifndef LOCAL_MODULE_HOST_ARCH
ifndef my_module_multilib
ifeq ($(HOST_PREFER_32_BIT),true)
my_module_multilib := 32
else
# libraries default to building for both architecturess
my_module_multilib := both
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

ifdef HOST_CROSS_OS
my_prefix := HOST_CROSS_
LOCAL_HOST_PREFIX := $(my_prefix)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# Build for Windows
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_MODULE_SUFFIX :=
# We don't want makefiles using the cross-compiled host tool
saved_LOCAL_INSTALLED_MODULE := $(LOCAL_INSTALLED_MODULE)
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(BUILD_SYSTEM)/host_shared_library_internal.mk
LOCAL_INSTALLED_MODULE := $(saved_LOCAL_INSTALLED_MODULE)
endif

ifdef HOST_CROSS_2ND_ARCH
LOCAL_2ND_ARCH_VAR_PREFIX := $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# Build for HOST_CROSS_2ND_ARCH
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_MODULE_SUFFIX :=
# We don't want makefiles using the cross-compiled host tool
saved_LOCAL_INSTALLED_MODULE := $(LOCAL_INSTALLED_MODULE)
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(BUILD_SYSTEM)/host_shared_library_internal.mk
LOCAL_INSTALLED_MODULE := $(saved_LOCAL_INSTALLED_MODULE)
endif
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif
LOCAL_HOST_PREFIX :=
endif

my_module_arch_supported :=

###########################################################
## Copy headers to the install tree
###########################################################
include $(BUILD_COPY_HEADERS)
