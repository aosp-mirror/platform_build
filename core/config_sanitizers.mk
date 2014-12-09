##############################################
## Perform configuration steps for sanitizers.
##############################################

# Configure SANITIZE_HOST.
ifdef LOCAL_IS_HOST_MODULE
ifeq ($(SANITIZE_HOST),true)
ifneq ($(strip $(LOCAL_CLANG)),false)
ifneq ($(strip $(LOCAL_ADDRESS_SANITIZER)),false)
    LOCAL_ADDRESS_SANITIZER := true
endif
endif
endif
endif

# Configure address sanitizer.
ifeq ($(strip $(LOCAL_ADDRESS_SANITIZER)),true)
  my_clang := true
  # Frame pointer based unwinder in ASan requires ARM frame setup.
  LOCAL_ARM_MODE := arm
  my_cflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS)
  my_ldflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS)
  ifdef LOCAL_IS_HOST_MODULE
      my_ldflags += -fsanitize=address
      # -nodefaultlibs (provided with libc++) prevents the driver from linking
      # libraries needed with -fsanitize=address. http://b/18650275
      my_ldlibs += -ldl -lpthread
  else
      my_shared_libraries += $(ADDRESS_SANITIZER_CONFIG_EXTRA_SHARED_LIBRARIES)
      my_static_libraries += $(ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES)
  endif
endif
