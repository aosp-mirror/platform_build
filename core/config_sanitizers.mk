##############################################
## Perform configuration steps for sanitizers.
##############################################

my_sanitize := $(strip $(LOCAL_SANITIZE))
my_sanitize_diag := $(strip $(LOCAL_SANITIZE_DIAG))

# SANITIZE_HOST is only in effect if the module is already using clang (host
# modules that haven't set `LOCAL_CLANG := false` and device modules that
# have set `LOCAL_CLANG := true`.
my_global_sanitize :=
ifeq ($(my_clang),true)
  ifdef LOCAL_IS_HOST_MODULE
    my_global_sanitize := $(strip $(SANITIZE_HOST))

    # SANITIZE_HOST=true is a deprecated way to say SANITIZE_HOST=address.
    my_global_sanitize := $(subst true,address,$(my_global_sanitize))
  else
    my_global_sanitize := $(strip $(SANITIZE_TARGET))
  endif
endif

ifneq ($(my_global_sanitize),)
  my_sanitize := $(my_global_sanitize) $(my_sanitize)
endif

# The sanitizer specified in the product configuration wins over the previous.
ifneq ($(SANITIZER.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG),)
  my_sanitize := $(SANITIZER.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG)
  ifeq ($(my_sanitize),never)
    my_sanitize :=
  endif
endif

ifndef LOCAL_IS_HOST_MODULE
  # Add a filter point for 32-bit vs 64-bit sanitization (to lighten the burden)
  SANITIZE_TARGET_ARCH ?= $(TARGET_ARCH) $(TARGET_2ND_ARCH)
  ifeq ($(filter $(SANITIZE_TARGET_ARCH),$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
    my_sanitize :=
  endif
endif

# Add a filter point based on module owner (to lighten the burden). The format is a space- or
# colon-separated list of owner names.
ifneq (,$(SANITIZE_NEVER_BY_OWNER))
  ifneq (,$(LOCAL_MODULE_OWNER))
    ifneq (,$(filter $(LOCAL_MODULE_OWNER),$(subst :, ,$(SANITIZE_NEVER_BY_OWNER))))
      $(warning Not sanitizing $(LOCAL_MODULE) based on module owner.)
      my_sanitize :=
    endif
  endif
endif

# Don't apply sanitizers to NDK code.
ifdef LOCAL_SDK_VERSION
  my_sanitize :=
  my_global_sanitize :=
endif

# Never always wins.
ifeq ($(LOCAL_SANITIZE),never)
  my_sanitize :=
endif

# If CFI is disabled globally, remove it from my_sanitize.
ifeq ($(strip $(ENABLE_CFI)),false)
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
endif

# Disable CFI for arm32 (b/35157333).
ifneq ($(filter arm,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
endif

# Also disable CFI if ASAN is enabled.
ifneq ($(filter address,$(my_sanitize)),)
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
endif

# CFI needs gold linker, and mips toolchain does not have one.
ifneq ($(filter mips mips64,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
endif

my_nosanitize = $(strip $(LOCAL_NOSANITIZE))
ifneq ($(my_nosanitize),)
  my_sanitize := $(filter-out $(my_nosanitize),$(my_sanitize))
endif

# TSAN is not supported on 32-bit architectures. For non-multilib cases, make
# its use an error. For multilib cases, don't use it for the 32-bit case.
ifneq ($(filter thread,$(my_sanitize)),)
  ifeq ($(my_32_64_bit_suffix),32)
    ifeq ($(my_module_multilib),both)
        my_sanitize := $(filter-out thread,$(my_sanitize))
    else
        $(error $(LOCAL_PATH): $(LOCAL_MODULE): TSAN cannot be used for 32-bit modules.)
    endif
  endif
endif

ifneq ($(filter safe-stack,$(my_sanitize)),)
  ifeq ($(my_32_64_bit_suffix),32)
    my_sanitize := $(filter-out safe-stack,$(my_sanitize))
  endif
endif

# Undefined symbols can occur if a non-sanitized library links
# sanitized static libraries. That's OK, because the executable
# always depends on the ASan runtime library, which defines these
# symbols.
ifneq ($(filter address thread,$(strip $(SANITIZE_TARGET))),)
  ifndef LOCAL_IS_HOST_MODULE
    ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
      ifeq ($(my_sanitize),)
        my_allow_undefined_symbols := true
      endif
    endif
  endif
endif

# Sanitizers can only be used with clang.
ifneq ($(my_clang),true)
  ifneq ($(my_sanitize),)
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): Use of sanitizers requires LOCAL_CLANG := true)
  endif
endif

ifneq ($(filter default-ub,$(my_sanitize)),)
  my_sanitize := $(CLANG_DEFAULT_UB_CHECKS)
endif

ifneq ($(filter coverage,$(my_sanitize)),)
  ifeq ($(filter address,$(my_sanitize)),)
    $(error $(LOCAL_PATH): $(LOCAL_MODULE): Use of 'coverage' also requires 'address')
  endif
  my_cflags += -fsanitize-coverage=edge,indirect-calls,8bit-counters,trace-cmp
  my_sanitize := $(filter-out coverage,$(my_sanitize))
endif

ifneq ($(my_sanitize),)
  fsanitize_arg := $(subst $(space),$(comma),$(my_sanitize))
  my_cflags += -fsanitize=$(fsanitize_arg)

  ifdef LOCAL_IS_HOST_MODULE
    my_cflags += -fno-sanitize-recover=all
    my_ldflags += -fsanitize=$(fsanitize_arg)
    my_ldlibs += -lrt -ldl
  else
    my_cflags += -fsanitize-trap=all
    my_cflags += -ftrap-function=abort
    ifneq ($(filter address thread,$(my_sanitize)),)
      my_cflags += -fno-sanitize-trap=address,thread
      my_shared_libraries += libdl
    endif
  endif
endif

ifneq ($(filter cfi,$(my_sanitize)),)
  # __cfi_check needs to be built as Thumb (see the code in linker_cfi.cpp).
  # LLVM is not set up to do this on a function basis, so force Thumb on the
  # entire module.
  LOCAL_ARM_MODE := thumb
  my_cflags += $(CFI_EXTRA_CFLAGS)
  my_ldflags += $(CFI_EXTRA_LDFLAGS)
  my_arflags += --plugin $(LLVM_PREBUILTS_PATH)/../lib64/LLVMgold.so
  # Workaround for b/33678192. CFI jumptables need Thumb2 codegen.  Revert when
  # Clang is updated past r290384.
  ifneq ($(filter arm,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
    my_ldflags += -march=armv7-a
  endif
endif

# If local or global modules need ASAN, add linker flags.
ifneq ($(filter address,$(my_global_sanitize) $(my_sanitize)),)
  my_ldflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS)
  ifdef LOCAL_IS_HOST_MODULE
    # -nodefaultlibs (provided with libc++) prevents the driver from linking
    # libraries needed with -fsanitize=address. http://b/18650275 (WAI)
    my_ldlibs += -lm -lpthread
    my_ldflags += -Wl,--no-as-needed
  else
    # Add asan libraries unless LOCAL_MODULE is the asan library.
    # ASan runtime library must be the first in the link order.
    ifeq (,$(filter $(LOCAL_MODULE),$($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_RUNTIME_LIBRARY)))
      my_shared_libraries := $($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_RUNTIME_LIBRARY) \
                             $(my_shared_libraries)
    endif
    ifeq (,$(filter $(LOCAL_MODULE),$(ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES)))
      my_static_libraries += $(ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES)
    endif

    # Do not add unnecessary dependency in shared libraries.
    ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
      my_ldflags += -Wl,--as-needed
    endif

    ifeq ($(LOCAL_MODULE_CLASS),EXECUTABLES)
      ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
        my_linker := $($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_LINKER)
        # Make sure linker_asan get installed.
        $(LOCAL_INSTALLED_MODULE) : | $(PRODUCT_OUT)$($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_LINKER)
      endif
    endif
  endif
endif

# If local module needs ASAN, add compiler flags.
ifneq ($(filter address,$(my_sanitize)),)
  # Frame pointer based unwinder in ASan requires ARM frame setup.
  LOCAL_ARM_MODE := arm
  my_cflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS)
  ifndef LOCAL_IS_HOST_MODULE
    my_cflags += -mllvm -asan-globals=0
  endif
endif

ifneq ($(filter undefined,$(my_sanitize)),)
  ifndef LOCAL_IS_HOST_MODULE
    $(error ubsan is not yet supported on the target)
  endif
endif

ifneq ($(strip $(LOCAL_SANITIZE_RECOVER)),)
  recover_arg := $(subst $(space),$(comma),$(LOCAL_SANITIZE_RECOVER)),
  my_cflags += -fsanitize-recover=$(recover_arg)
endif

ifneq ($(my_sanitize_diag),)
  notrap_arg := $(subst $(space),$(comma),$(my_sanitize_diag)),
  my_cflags += -fno-sanitize-trap=$(notrap_arg)
  # Diagnostic requires a runtime library, unless ASan or TSan are also enabled.
  ifeq ($(filter address thread,$(my_sanitize)),)
    # Does not have to be the first DT_NEEDED unlike ASan.
    my_shared_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_RUNTIME_LIBRARY)
  endif
endif
