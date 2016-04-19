###########################################################
## Standard rules for copying files that are prebuilt
##
## Additional inputs from base_rules.make:
## None.
##
###########################################################

ifdef LOCAL_IS_HOST_MODULE
  my_prefix := HOST_
  LOCAL_HOST_PREFIX :=
else
  my_prefix := TARGET_
endif

include $(BUILD_SYSTEM)/multilib.mk

my_skip_non_preferred_arch :=

# check if first arch is supported
LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# first arch is supported
include $(BUILD_SYSTEM)/prebuilt_internal.mk
ifneq ($(my_module_multilib),both)
my_skip_non_preferred_arch := true
endif # $(my_module_multilib)
# For apps, we don't want to set up the prebuilt apk rule twice even if "LOCAL_MULTILIB := both".
ifeq (APPS,$(LOCAL_MODULE_CLASS))
my_skip_non_preferred_arch := true
endif
endif # $(my_module_arch_supported)

ifndef my_skip_non_preferred_arch
ifneq (,$($(my_prefix)2ND_ARCH))
# check if secondary arch is supported
LOCAL_2ND_ARCH_VAR_PREFIX := $($(my_prefix)2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# secondary arch is supported
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=
include $(BUILD_SYSTEM)/prebuilt_internal.mk
endif # $(my_module_arch_supported)
endif # $($(my_prefix)2ND_ARCH)
endif # $(my_skip_non_preferred_arch) not true

LOCAL_2ND_ARCH_VAR_PREFIX :=

ifdef LOCAL_IS_HOST_MODULE
ifdef HOST_CROSS_OS
ifneq (,$(filter EXECUTABLES STATIC_LIBRARIES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)))
my_prefix := HOST_CROSS_
LOCAL_HOST_PREFIX := $(my_prefix)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# host cross compilation is supported
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=
include $(BUILD_SYSTEM)/prebuilt_internal.mk
endif
LOCAL_HOST_PREFIX :=
endif

ifdef HOST_CROSS_2ND_ARCH
my_prefix := HOST_CROSS_
LOCAL_2ND_ARCH_VAR_PREFIX := $($(my_prefix)2ND_ARCH_VAR_PREFIX)
LOCAL_HOST_PREFIX := $(my_prefix)
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=
include $(BUILD_SYSTEM)/prebuilt_internal.mk
endif
LOCAL_HOST_PREFIX :=
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif
endif
endif

my_module_arch_supported :=
