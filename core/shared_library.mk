$(call record-module-type,SHARED_LIBRARY)
ifdef LOCAL_IS_HOST_MODULE
  $(call pretty-error,BUILD_SHARED_LIBRARY is incompatible with LOCAL_IS_HOST_MODULE. Use BUILD_HOST_SHARED_LIBRARY instead.)
endif
my_prefix := TARGET_
include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
# libraries default to building for both architecturess
my_module_multilib := both
endif

ifeq ($(my_module_multilib),both)
ifneq ($(LOCAL_MODULE_PATH),)
ifneq ($(TARGET_2ND_ARCH),)
$(error $(LOCAL_MODULE): LOCAL_MODULE_PATH for shared libraries is unsupported in multiarch builds, use LOCAL_MODULE_RELATIVE_PATH instead)
endif
endif

ifneq ($(LOCAL_UNSTRIPPED_PATH),)
ifneq ($(TARGET_2ND_ARCH),)
$(error $(LOCAL_MODULE): LOCAL_UNSTRIPPED_PATH for shared libraries is unsupported in multiarch builds)
endif
endif
endif # my_module_multilib == both


LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
include $(BUILD_SYSTEM)/shared_library_internal.mk
endif

ifdef TARGET_2ND_ARCH

LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
# Build for TARGET_2ND_ARCH
LOCAL_BUILT_MODULE :=
LOCAL_INSTALLED_MODULE :=
LOCAL_INTERMEDIATE_TARGETS :=

include $(BUILD_SYSTEM)/shared_library_internal.mk

endif

LOCAL_2ND_ARCH_VAR_PREFIX :=

endif # TARGET_2ND_ARCH

my_module_arch_supported :=

###########################################################
## Copy headers to the install tree
###########################################################
ifdef LOCAL_COPY_HEADERS
$(call pretty-warning,LOCAL_COPY_HEADERS is deprecated. See $(CHANGES_URL)#copy_headers)
include $(BUILD_SYSTEM)/copy_headers.mk
endif
