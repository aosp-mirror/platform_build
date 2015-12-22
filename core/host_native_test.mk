################################################
## A thin wrapper around BUILD_HOST_EXECUTABLE
## Common flags for host native tests are added.
################################################

include $(BUILD_SYSTEM)/host_test_internal.mk

needs_symlink :=
ifndef LOCAL_MULTILIB
  ifndef LOCAL_32_BIT_ONLY
    LOCAL_MULTILIB := both

    ifeq (,$(LOCAL_MODULE_STEM_32)$(LOCAL_MODULE_STEM_64))
      LOCAL_MODULE_STEM_32 := $(LOCAL_MODULE)32
      LOCAL_MODULE_STEM_64 := $(LOCAL_MODULE)64
      needs_symlink := true
    endif
  endif
endif

include $(BUILD_HOST_EXECUTABLE)

ifdef needs_symlink
include $(BUILD_SYSTEM)/executable_prefer_symlink.mk
needs_symlink :=
endif
