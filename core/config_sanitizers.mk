##############################################
## Perform configuration steps for sanitizers.
##############################################

my_sanitize := $(strip $(LOCAL_SANITIZE))

# Keep compatibility for LOCAL_ADDRESS_SANITIZER until all targets have moved to
# `LOCAL_SANITIZE := address`.
ifeq ($(strip $(LOCAL_ADDRESS_SANITIZER)),true)
  my_sanitize += address
endif

# And `LOCAL_SANITIZE := never`.
ifeq ($(strip $(LOCAL_ADDRESS_SANITIZER)),false)
  my_sanitize := never
endif

# Don't apply sanitizers to NDK code.
ifdef LOCAL_SDK_VERSION
  my_sanitize := never
endif

# Configure SANITIZE_HOST.
ifdef LOCAL_IS_HOST_MODULE
  ifeq ($(my_sanitize),)
    my_sanitize := $(strip $(SANITIZE_HOST))

    # SANTIZIZE_HOST=true is a deprecated way to say SANITIZE_HOST=address.
    ifeq ($(my_sanitize),true)
      my_sanitize := address
    endif

    # SANITIZE_HOST is only in effect if the module is already using clang (host
    # modules that haven't set `LOCAL_CLANG := false` and device modules that
    # have set `LOCAL_CLANG := true`.
    ifneq ($(my_clang),true)
      my_sanitize :=
    endif
  endif
endif

ifeq ($(my_sanitize),never)
  my_sanitize :=
endif

# Sanitizers can only be used with clang.
ifneq ($(my_clang),true)
  ifneq ($(my_sanitize),)
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): Use of sanitizers requires LOCAL_CLANG := true)
  endif
endif

ifneq ($(filter default-ub,$(my_sanitize)),)
  my_sanitize := $(CLANG_DEFAULT_UB_CHECKS)
  my_ldlibs += -ldl

  ifdef LOCAL_IS_HOST_MODULE
    my_cflags += -fno-sanitize-recover=all
  else
    my_cflags += -fsanitize-undefined-trap-on-error
  endif
endif

ifneq ($(my_sanitize),)
  fsanitize_arg := $(subst $(space),$(comma),$(my_sanitize)),
  my_cflags += -fsanitize=$(fsanitize_arg)

  ifdef LOCAL_IS_HOST_MODULE
    my_ldflags += -fsanitize=$(fsanitize_arg)
  endif
endif

ifneq ($(filter address,$(my_sanitize)),)
  # Frame pointer based unwinder in ASan requires ARM frame setup.
  LOCAL_ARM_MODE := arm
  my_cflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS)
  my_ldflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS)
  ifdef LOCAL_IS_HOST_MODULE
    # -nodefaultlibs (provided with libc++) prevents the driver from linking
    # libraries needed with -fsanitize=address. http://b/18650275 (WAI)
    my_ldlibs += -lm -ldl -lpthread
    my_ldflags += -Wl,--no-as-needed
  else
    # ASan runtime library must be the first in the link order.
    my_shared_libraries := $($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_RUNTIME_LIBRARY) \
                           $(my_shared_libraries) \
                           $(ADDRESS_SANITIZER_CONFIG_EXTRA_SHARED_LIBRARIES)
    my_static_libraries += $(ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES)
    my_ldflags += -Wl,-rpath,$($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_RPATH)
  endif
endif

ifneq ($(filter undefined,$(my_sanitize)),)
  ifdef LOCAL_IS_HOST_MODULE
    my_ldlibs += -ldl
  else
    $(error ubsan is not yet supported on the target)
  endif
endif
