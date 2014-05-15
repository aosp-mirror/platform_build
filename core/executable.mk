# We don't automatically set up rules to build executables for both
# TARGET_ARCH and TARGET_2ND_ARCH.
# By default, an executable is built for TARGET_ARCH.
# To build it for TARGET_2ND_ARCH in a 64bit product, use "LOCAL_MULTILIB := 32"
# To build it for both set LOCAL_MULTILIB := both and specify
# LOCAL_MODULE_PATH_32 and LOCAL_MODULE_PATH_64 or LOCAL_MODULE_STEM_32 and
# LOCAL_MODULE_STEM_64

my_prefix := TARGET_
include $(BUILD_SYSTEM)/multilib.mk

ifeq ($(my_module_multilib),both)
ifeq ($(LOCAL_MODULE_PATH_32)$(LOCAL_MODULE_STEM_32),)
$(error $(LOCAL_PATH): LOCAL_MODULE_STEM_32 or LOCAL_MODULE_PATH_32 is required for LOCAL_MULTILIB := both for module $(LOCAL_MODULE))
endif
ifeq ($(LOCAL_MODULE_PATH_64)$(LOCAL_MODULE_STEM_64),)
$(error $(LOCAL_PATH): LOCAL_MODULE_STEM_64 or LOCAL_MODULE_PATH_64 is required for LOCAL_MULTILIB := both for module $(LOCAL_MODULE))
endif
else #!LOCAL_MULTILIB == both
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX := true
endif

# if TARGET_PREFER_32_BIT_EXECUTABLES is set, try to build 32-bit first
ifdef TARGET_2ND_ARCH
ifeq ($(TARGET_PREFER_32_BIT_EXECUTABLES),true)
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
else
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif
endif

my_skip_non_preferred_arch :=

# check if preferred arch is supported
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# first arch is supported
include $(BUILD_SYSTEM)/executable_internal.mk
ifneq ($(my_module_multilib),both)
my_skip_non_preferred_arch := true
endif
endif

# check if preferred arch was not supported or asked to build both
ifndef my_skip_non_preferred_arch
ifdef TARGET_2ND_ARCH

# check if the non-preferred arch is the primary or secondary
ifeq ($(TARGET_PREFER_32_BIT_EXECUTABLES),true)
LOCAL_2ND_ARCH_VAR_PREFIX :=
else
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
endif

# check if non-preferred arch is supported
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# non-preferred arch is supported
OVERRIDE_BUILT_MODULE_PATH :=
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_MODULE_STEM :=
LOCAL_BUILT_MODULE_STEM :=
LOCAL_INSTALLED_MODULE_STEM :=
LOCAL_INTERMEDIATE_TARGETS :=
include $(BUILD_SYSTEM)/executable_internal.mk
endif
endif # TARGET_2ND_ARCH
endif # !my_skip_non_preferred_arch || LOCAL_MULTILIB
LOCAL_2ND_ARCH_VAR_PREFIX :=
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX :=

my_module_arch_supported :=
