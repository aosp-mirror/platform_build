$(call record-module-type,HEADER_LIBRARY)
ifdef LOCAL_IS_HOST_MODULE
  my_prefix := HOST_
  LOCAL_HOST_PREFIX :=
else
  my_prefix := TARGET_
endif
include $(BUILD_SYSTEM)/multilib.mk

ifndef my_module_multilib
  # libraries default to building for both architecturess
  my_module_multilib := both
endif

LOCAL_2ND_ARCH_VAR_PREFIX :=
include $(BUILD_SYSTEM)/module_arch_supported.mk

ifeq ($(my_module_arch_supported),true)
  include $(BUILD_SYSTEM)/header_library_internal.mk
endif

ifdef $(my_prefix)2ND_ARCH
  LOCAL_2ND_ARCH_VAR_PREFIX := $($(my_prefix)2ND_ARCH_VAR_PREFIX)
  include $(BUILD_SYSTEM)/module_arch_supported.mk

  ifeq ($(my_module_arch_supported),true)
    # Build for 2ND_ARCH
    OVERRIDE_BUILT_MODULE_PATH :=
    LOCAL_BUILT_MODULE :=
    LOCAL_INSTALLED_MODULE :=
    LOCAL_INTERMEDIATE_TARGETS :=
    include $(BUILD_SYSTEM)/header_library_internal.mk
  endif
  LOCAL_2ND_ARCH_VAR_PREFIX :=
endif # 2ND_ARCH

ifdef LOCAL_IS_HOST_MODULE
  ifdef HOST_CROSS_OS
    my_prefix := HOST_CROSS_
    LOCAL_HOST_PREFIX := $(my_prefix)

    include $(BUILD_SYSTEM)/module_arch_supported.mk

    ifeq ($(my_module_arch_supported),true)
      # Build for 2ND_ARCH
      OVERRIDE_BUILT_MODULE_PATH :=
      LOCAL_BUILT_MODULE :=
      LOCAL_INSTALLED_MODULE :=
      LOCAL_INTERMEDIATE_TARGETS :=
      include $(BUILD_SYSTEM)/header_library_internal.mk
    endif

    ifdef HOST_CROSS_2ND_ARCH
      LOCAL_2ND_ARCH_VAR_PREFIX := $(HOST_CROSS_2ND_ARCH_VAR_PREFIX)
      include $(BUILD_SYSTEM)/module_arch_supported.mk

      ifeq ($(my_module_arch_supported),true)
        # Build for HOST_CROSS_2ND_ARCH
        OVERRIDE_BUILT_MODULE_PATH :=
        LOCAL_BUILT_MODULE :=
        LOCAL_INSTALLED_MODULE :=
        LOCAL_INTERMEDIATE_TARGETS :=
        include $(BUILD_SYSTEM)/header_library_internal.mk
      endif
      LOCAL_2ND_ARCH_VAR_PREFIX :=
    endif

    LOCAL_HOST_PREFIX :=
  endif
endif

my_module_arch_supported :=
