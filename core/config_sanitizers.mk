##############################################
## Perform configuration steps for sanitizers.
##############################################

my_sanitize := $(strip $(LOCAL_SANITIZE))
my_sanitize_diag := $(strip $(LOCAL_SANITIZE_DIAG))

# SANITIZE_HOST is only in effect if the module is already using clang (host
# modules that haven't set `LOCAL_CLANG := false` and device modules that
# have set `LOCAL_CLANG := true`.
my_global_sanitize :=
my_global_sanitize_diag :=
ifeq ($(my_clang),true)
  ifdef LOCAL_IS_HOST_MODULE
    my_global_sanitize := $(strip $(SANITIZE_HOST))

    # SANITIZE_HOST=true is a deprecated way to say SANITIZE_HOST=address.
    my_global_sanitize := $(subst true,address,$(my_global_sanitize))
  else
    my_global_sanitize := $(strip $(SANITIZE_TARGET))
    my_global_sanitize_diag := $(strip $(SANITIZE_TARGET_DIAG))
  endif
endif

# Disable global integer_overflow in excluded paths.
ifneq ($(filter integer_overflow, $(my_global_sanitize)),)
  combined_exclude_paths := $(INTEGER_OVERFLOW_EXCLUDE_PATHS) \
                            $(PRODUCT_INTEGER_OVERFLOW_EXCLUDE_PATHS)

  ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_exclude_paths)),\
         $(filter $(dir)%,$(LOCAL_PATH)))),)
    my_global_sanitize := $(filter-out integer_overflow,$(my_global_sanitize))
    my_global_sanitize_diag := $(filter-out integer_overflow,$(my_global_sanitize_diag))
  endif
endif

# Disable global CFI in excluded paths
ifneq ($(filter cfi, $(my_global_sanitize)),)
  combined_exclude_paths := $(CFI_EXCLUDE_PATHS) \
                            $(PRODUCT_CFI_EXCLUDE_PATHS)

  ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_exclude_paths)),\
         $(filter $(dir)%,$(LOCAL_PATH)))),)
    my_global_sanitize := $(filter-out cfi,$(my_global_sanitize))
    my_global_sanitize_diag := $(filter-out cfi,$(my_global_sanitize_diag))
  endif
endif

ifneq ($(my_global_sanitize),)
  my_sanitize := $(my_global_sanitize) $(my_sanitize)
endif
ifneq ($(my_global_sanitize_diag),)
  my_sanitize_diag := $(my_global_sanitize_diag) $(my_sanitize_diag)
endif

# The sanitizer specified in the product configuration wins over the previous.
ifneq ($(SANITIZER.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG),)
  my_sanitize := $(SANITIZER.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG)
  ifeq ($(my_sanitize),never)
    my_sanitize :=
    my_sanitize_diag :=
  endif
endif

ifndef LOCAL_IS_HOST_MODULE
  # Add a filter point for 32-bit vs 64-bit sanitization (to lighten the burden)
  SANITIZE_TARGET_ARCH ?= $(TARGET_ARCH) $(TARGET_2ND_ARCH)
  ifeq ($(filter $(SANITIZE_TARGET_ARCH),$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
    my_sanitize :=
    my_sanitize_diag :=
  endif
endif

# Add a filter point based on module owner (to lighten the burden). The format is a space- or
# colon-separated list of owner names.
ifneq (,$(SANITIZE_NEVER_BY_OWNER))
  ifneq (,$(LOCAL_MODULE_OWNER))
    ifneq (,$(filter $(LOCAL_MODULE_OWNER),$(subst :, ,$(SANITIZE_NEVER_BY_OWNER))))
      $(warning Not sanitizing $(LOCAL_MODULE) based on module owner.)
      my_sanitize :=
      my_sanitize_diag :=
    endif
  endif
endif

# Don't apply sanitizers to NDK code.
ifdef LOCAL_SDK_VERSION
  my_sanitize :=
  my_global_sanitize :=
  my_sanitize_diag :=
endif

# Never always wins.
ifeq ($(LOCAL_SANITIZE),never)
  my_sanitize :=
  my_sanitize_diag :=
endif

# Enable CFI in included paths (for Arm64 only).
ifeq ($(filter cfi, $(my_sanitize)),)
  ifneq ($(filter arm64,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
    combined_include_paths := $(CFI_INCLUDE_PATHS) \
                              $(PRODUCT_CFI_INCLUDE_PATHS)

    ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_include_paths)),\
           $(filter $(dir)%,$(LOCAL_PATH)))),)
      my_sanitize := cfi $(my_sanitize)
      my_sanitize_diag := cfi $(my_sanitize_diag)
    endif
  endif
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

# Disable CFI for host targets
ifdef LOCAL_IS_HOST_MODULE
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
endif

# Support for local sanitize blacklist paths.
ifneq ($(my_sanitize)$(my_global_sanitize),)
  ifneq ($(LOCAL_SANITIZE_BLACKLIST),)
    my_cflags += -fsanitize-blacklist=$(LOCAL_PATH)/$(LOCAL_SANITIZE_BLACKLIST)
  endif
endif

# Disable integer_overflow if LOCAL_NOSANITIZE=integer.
ifneq ($(filter integer_overflow, $(my_global_sanitize) $(my_sanitize)),)
  ifneq ($(filter integer, $(strip $(LOCAL_NOSANITIZE))),)
    my_sanitize := $(filter-out integer_overflow,$(my_sanitize))
    my_sanitize_diag := $(filter-out integer_overflow,$(my_sanitize_diag))
  endif
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
  else
    my_shared_libraries += $(TSAN_RUNTIME_LIBRARY)
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
  my_cflags += -fsanitize-coverage=trace-pc-guard,indirect-calls,trace-cmp
  my_sanitize := $(filter-out coverage,$(my_sanitize))
endif

ifneq ($(filter integer_overflow,$(my_sanitize)),)
  ifneq ($(filter SHARED_LIBRARIES EXECUTABLES,$(LOCAL_MODULE_CLASS)),)
    ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)

      # Respect LOCAL_NOSANITIZE for integer-overflow flags.
      ifeq ($(filter signed-integer-overflow, $(strip $(LOCAL_NOSANITIZE))),)
        my_sanitize += signed-integer-overflow
      endif
      ifeq ($(filter unsigned-integer-overflow, $(strip $(LOCAL_NOSANITIZE))),)
        my_sanitize += unsigned-integer-overflow
      endif
      my_cflags += $(INTEGER_OVERFLOW_EXTRA_CFLAGS)

      # Check for diagnostics mode (on by default).
      ifneq ($(filter integer_overflow,$(my_sanitize_diag)),)
        my_sanitize_diag += signed-integer-overflow
        my_sanitize_diag += unsigned-integer-overflow
      endif
    endif
  endif
  my_sanitize := $(filter-out integer_overflow,$(my_sanitize))
endif

# Makes sure integer_overflow diagnostics is removed from the diagnostics list
# even if integer_overflow is not set for some reason.
ifneq ($(filter integer_overflow,$(my_sanitize_diag)),)
  my_sanitize_diag := $(filter-out integer_overflow,$(my_sanitize_diag))
endif

ifneq ($(my_sanitize),)
  fsanitize_arg := $(subst $(space),$(comma),$(my_sanitize))
  my_cflags += -fsanitize=$(fsanitize_arg)

  ifdef LOCAL_IS_HOST_MODULE
    my_cflags += -fno-sanitize-recover=all
    my_ldflags += -fsanitize=$(fsanitize_arg)
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
  # Only append the default visibility flag if -fvisibility has not already been
  # set to hidden.
  ifeq ($(filter -fvisibility=hidden,$(LOCAL_CFLAGS)),)
    my_cflags += -fvisibility=default
  endif
  my_ldflags += $(CFI_EXTRA_LDFLAGS)
  my_arflags += --plugin $(LLVM_PREBUILTS_PATH)/../lib64/LLVMgold.so

  ifeq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
        my_ldflags := $(filter-out -fsanitize-cfi-cross-dso,$(my_ldflags))
        my_cflags := $(filter-out -fsanitize-cfi-cross-dso,$(my_cflags))
  else
        # Apply the version script to non-static executables
        my_ldflags += -Wl,--version-script,build/soong/cc/config/cfi_exports.map
        LOCAL_ADDITIONAL_DEPENDENCIES += build/soong/cc/config/cfi_exports.map
  endif
endif

# If local or global modules need ASAN, add linker flags.
ifneq ($(filter address,$(my_global_sanitize) $(my_sanitize)),)
  my_ldflags += $(ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS)
  ifdef LOCAL_IS_HOST_MODULE
    # -nodefaultlibs (provided with libc++) prevents the driver from linking
    # libraries needed with -fsanitize=address. http://b/18650275 (WAI)
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

# Use minimal diagnostics when integer overflow is enabled; never do it for HOST or AUX modules
ifeq ($(LOCAL_IS_HOST_MODULE)$(LOCAL_IS_AUX_MODULE),)
  # Pre-emptively add UBSAN minimal runtime incase a static library dependency requires it
  ifeq ($(filter STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
    ifndef LOCAL_SDK_VERSION
      my_static_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_MINIMAL_RUNTIME_LIBRARY)
      my_ldflags += -Wl,--exclude-libs,$($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_MINIMAL_RUNTIME_LIBRARY).a
    endif
  endif
  ifneq ($(filter unsigned-integer-overflow signed-integer-overflow integer,$(my_sanitize)),)
    ifeq ($(filter unsigned-integer-overflow signed-integer overflow integer,$(my_sanitize_diag)),)
      ifeq ($(filter cfi,$(my_sanitize_diag)),)
        ifeq ($(filter address,$(my_sanitize)),)
          my_cflags += -fsanitize-minimal-runtime
          my_cflags += -fno-sanitize-trap=integer
          my_cflags += -fno-sanitize-recover=integer
        endif
      endif
    endif
  endif
endif

ifneq ($(strip $(LOCAL_SANITIZE_RECOVER)),)
  recover_arg := $(subst $(space),$(comma),$(LOCAL_SANITIZE_RECOVER)),
  my_cflags += -fsanitize-recover=$(recover_arg)
endif

ifneq ($(my_sanitize_diag),)
  # TODO(vishwath): Add diagnostic support for static executables once
  # we switch to clang-4393122 (which adds the static ubsan runtime
  # that this depends on)
  ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
    notrap_arg := $(subst $(space),$(comma),$(my_sanitize_diag)),
    my_cflags += -fno-sanitize-trap=$(notrap_arg)
    # Diagnostic requires a runtime library, unless ASan or TSan are also enabled.
    ifeq ($(filter address thread,$(my_sanitize)),)
      # Does not have to be the first DT_NEEDED unlike ASan.
      my_shared_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_RUNTIME_LIBRARY)
    endif
  endif
endif
