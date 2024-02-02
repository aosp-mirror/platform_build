##############################################
## Perform configuration steps for sanitizers.
##############################################

my_sanitize := $(strip $(LOCAL_SANITIZE))
my_sanitize_diag := $(strip $(LOCAL_SANITIZE_DIAG))

my_global_sanitize :=
my_global_sanitize_diag :=
ifdef LOCAL_IS_HOST_MODULE
  ifneq ($($(my_prefix)OS),windows)
    my_global_sanitize := $(strip $(SANITIZE_HOST))

    # SANITIZE_HOST=true is a deprecated way to say SANITIZE_HOST=address.
    my_global_sanitize := $(subst true,address,$(my_global_sanitize))
  endif
else
  my_global_sanitize := $(strip $(SANITIZE_TARGET))
  my_global_sanitize_diag := $(strip $(SANITIZE_TARGET_DIAG))
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

# Global integer sanitization doesn't support static modules.
ifeq ($(filter SHARED_LIBRARIES EXECUTABLES,$(LOCAL_MODULE_CLASS)),)
  my_global_sanitize := $(filter-out integer_overflow,$(my_global_sanitize))
  my_global_sanitize_diag := $(filter-out integer_overflow,$(my_global_sanitize_diag))
endif
ifeq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
  my_global_sanitize := $(filter-out integer_overflow,$(my_global_sanitize))
  my_global_sanitize_diag := $(filter-out integer_overflow,$(my_global_sanitize_diag))
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

# Disable global memtag_heap in excluded paths
ifneq ($(filter memtag_heap, $(my_global_sanitize)),)
  combined_exclude_paths := $(MEMTAG_HEAP_EXCLUDE_PATHS) \
                            $(PRODUCT_MEMTAG_HEAP_EXCLUDE_PATHS)

  ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_exclude_paths)),\
         $(filter $(dir)%,$(LOCAL_PATH)))),)
    my_global_sanitize := $(filter-out memtag_heap,$(my_global_sanitize))
    my_global_sanitize_diag := $(filter-out memtag_heap,$(my_global_sanitize_diag))
  endif
endif

# Disable global HWASan in excluded paths
ifneq ($(filter hwaddress, $(my_global_sanitize)),)
  combined_exclude_paths := $(HWASAN_EXCLUDE_PATHS) \
                            $(PRODUCT_HWASAN_EXCLUDE_PATHS)

  ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_exclude_paths)),\
         $(filter $(dir)%,$(LOCAL_PATH)))),)
    my_global_sanitize := $(filter-out hwaddress,$(my_global_sanitize))
    my_global_sanitize_diag := $(filter-out hwaddress,$(my_global_sanitize_diag))
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

# Enable CFI in included paths.
ifeq ($(filter cfi, $(my_sanitize)),)
  combined_include_paths := $(CFI_INCLUDE_PATHS) \
                            $(PRODUCT_CFI_INCLUDE_PATHS)
  combined_exclude_paths := $(CFI_EXCLUDE_PATHS) \
                            $(PRODUCT_CFI_EXCLUDE_PATHS)

  ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_include_paths)),\
         $(filter $(dir)%,$(LOCAL_PATH)))),)
    ifeq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_exclude_paths)),\
         $(filter $(dir)%,$(LOCAL_PATH)))),)
      my_sanitize := cfi $(my_sanitize)
    endif
  endif
endif

# Enable memtag_heap in included paths (for Arm64 only).
ifeq ($(filter memtag_heap, $(my_sanitize)),)
  ifneq ($(filter arm64,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
    combined_sync_include_paths := $(MEMTAG_HEAP_SYNC_INCLUDE_PATHS) \
                                   $(PRODUCT_MEMTAG_HEAP_SYNC_INCLUDE_PATHS)
    combined_async_include_paths := $(MEMTAG_HEAP_ASYNC_INCLUDE_PATHS) \
                                    $(PRODUCT_MEMTAG_HEAP_ASYNC_INCLUDE_PATHS)
    combined_exclude_paths := $(MEMTAG_HEAP_EXCLUDE_PATHS) \
                              $(PRODUCT_MEMTAG_HEAP_EXCLUDE_PATHS)
    ifneq ($(PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS),true)
      combined_sync_include_paths += $(PRODUCT_MEMTAG_HEAP_SYNC_DEFAULT_INCLUDE_PATHS)
      combined_async_include_paths += $(PRODUCT_MEMTAG_HEAP_ASYNC_DEFAULT_INCLUDE_PATHS)
    endif

    ifeq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_exclude_paths)),\
          $(filter $(dir)%,$(LOCAL_PATH)))),)
      ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_sync_include_paths)),\
             $(filter $(dir)%,$(LOCAL_PATH)))),)
        my_sanitize := memtag_heap $(my_sanitize)
        my_sanitize_diag := memtag_heap $(my_sanitize_diag)
      else ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_async_include_paths)),\
             $(filter $(dir)%,$(LOCAL_PATH)))),)
        my_sanitize := memtag_heap $(my_sanitize)
      endif
    endif
  endif
endif

# Enable HWASan in included paths.
ifeq ($(filter hwaddress, $(my_sanitize)),)
  combined_include_paths := $(HWASAN_INCLUDE_PATHS) \
                            $(PRODUCT_HWASAN_INCLUDE_PATHS)

  ifneq ($(strip $(foreach dir,$(subst $(comma),$(space),$(combined_include_paths)),\
         $(filter $(dir)%,$(LOCAL_PATH)))),)
    my_sanitize := hwaddress $(my_sanitize)
  endif
endif

# If CFI is disabled globally, remove it from my_sanitize.
ifeq ($(strip $(ENABLE_CFI)),false)
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
endif

# Also disable CFI and MTE if ASAN is enabled.
ifneq ($(filter address,$(my_sanitize)),)
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize := $(filter-out memtag_stack,$(my_sanitize))
  my_sanitize := $(filter-out memtag_globals,$(my_sanitize))
  my_sanitize := $(filter-out memtag_heap,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
endif

# Disable memtag for host targets. Host executables in AndroidMk files are
# deprecated, but some partners still have them floating around.
ifdef LOCAL_IS_HOST_MODULE
  my_sanitize := $(filter-out memtag_heap memtag_stack memtag_globals,$(my_sanitize))
  my_sanitize_diag := $(filter-out memtag_heap memtag_stack memtag_globals,$(my_sanitize_diag))
endif

# Disable sanitizers which need the UBSan runtime for host targets.
ifdef LOCAL_IS_HOST_MODULE
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_sanitize_diag := $(filter-out cfi,$(my_sanitize_diag))
  my_sanitize := $(filter-out signed-integer-overflow unsigned-integer-overflow integer_overflow,$(my_sanitize))
  my_sanitize_diag := $(filter-out signed-integer-overflow unsigned-integer-overflow integer_overflow,$(my_sanitize_diag))
endif

# Support for local sanitize blacklist paths.
ifneq ($(my_sanitize)$(my_global_sanitize),)
  ifneq ($(LOCAL_SANITIZE_BLOCKLIST),)
    my_cflags += -fsanitize-blacklist=$(LOCAL_PATH)/$(LOCAL_SANITIZE_BLOCKLIST)
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

ifneq ($(filter arm x86 x86_64,$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
  my_sanitize := $(filter-out hwaddress,$(my_sanitize))
  my_sanitize := $(filter-out memtag_heap,$(my_sanitize))
  my_sanitize := $(filter-out memtag_stack,$(my_sanitize))
  my_sanitize := $(filter-out memtag_globals,$(my_sanitize))
endif

ifneq ($(filter hwaddress,$(my_sanitize)),)
  my_sanitize := $(filter-out address,$(my_sanitize))
  my_sanitize := $(filter-out memtag_stack,$(my_sanitize))
  my_sanitize := $(filter-out memtag_globals,$(my_sanitize))
  my_sanitize := $(filter-out memtag_heap,$(my_sanitize))
  my_sanitize := $(filter-out thread,$(my_sanitize))
  my_sanitize := $(filter-out cfi,$(my_sanitize))
endif

ifneq ($(filter hwaddress,$(my_sanitize)),)
  my_shared_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)HWADDRESS_SANITIZER_RUNTIME_LIBRARY)
  ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
    ifeq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
      my_static_libraries := $(my_static_libraries) \
                             $($(LOCAL_2ND_ARCH_VAR_PREFIX)HWADDRESS_SANITIZER_STATIC_LIBRARY) \
                             libdl
    endif
  endif
endif

ifneq ($(filter memtag_heap memtag_stack memtag_globals,$(my_sanitize)),)
  ifneq ($(filter memtag_heap,$(my_sanitize_diag)),)
    my_cflags += -fsanitize-memtag-mode=sync
    my_sanitize_diag := $(filter-out memtag_heap,$(my_sanitize_diag))
  else
    my_cflags += -fsanitize-memtag-mode=async
  endif
endif

# Ignore SANITIZE_TARGET_DIAG=memtag_heap without SANITIZE_TARGET=memtag_heap
# This can happen if a condition above filters out memtag_heap from
# my_sanitize. It is easier to handle all of these cases here centrally.
ifneq ($(filter memtag_heap,$(my_sanitize_diag)),)
  my_sanitize_diag := $(filter-out memtag_heap,$(my_sanitize_diag))
endif

ifneq ($(filter memtag_heap,$(my_sanitize)),)
  my_cflags += -fsanitize=memtag-heap
  my_sanitize := $(filter-out memtag_heap,$(my_sanitize))
endif

ifneq ($(filter memtag_stack,$(my_sanitize)),)
  my_cflags += -fsanitize=memtag-stack
  my_cflags += -march=armv8a+memtag
  my_ldflags += -march=armv8a+memtag
  my_asflags += -march=armv8a+memtag
  my_sanitize := $(filter-out memtag_stack,$(my_sanitize))
endif

ifneq ($(filter memtag_globals,$(my_sanitize)),)
  my_cflags += -fsanitize=memtag-globals
  # TODO(mitchp): For now, enable memtag-heap with memtag-globals because the
  # linker isn't new enough
  # (https://reviews.llvm.org/differential/changeset/?ref=4243566).
  my_sanitize := $(filter-out memtag_globals,$(my_sanitize))
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

# Disable Scudo if ASan or TSan is enabled.
ifneq ($(filter address thread hwaddress,$(my_sanitize)),)
  my_sanitize := $(filter-out scudo,$(my_sanitize))
endif

# Or if disabled globally.
ifeq ($(PRODUCT_DISABLE_SCUDO),true)
  my_sanitize := $(filter-out scudo,$(my_sanitize))
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

ifneq ($(filter default-ub,$(my_sanitize)),)
  my_sanitize := $(CLANG_DEFAULT_UB_CHECKS)
endif

ifneq ($(filter fuzzer,$(my_sanitize)),)
  # SANITIZE_TARGET='fuzzer' actually means to create the fuzzer coverage
  # information, not to link against the fuzzer main().
  my_sanitize := $(filter-out fuzzer,$(my_sanitize))
  my_sanitize += fuzzer-no-link

  # TODO(b/131771163): Disable LTO for fuzzer builds. Note that Cfi causes
  # dependency on LTO.
  my_sanitize := $(filter-out cfi,$(my_sanitize))
  my_cflags += -fno-lto
  my_ldflags += -fno-lto

  # TODO(b/142430592): Upstream linker scripts for sanitizer runtime libraries
  # discard the sancov_lowest_stack symbol, because it's emulated TLS (and thus
  # doesn't match the linker script due to the "__emutls_v." prefix).
  my_cflags += -fno-sanitize-coverage=stack-depth
  my_ldflags += -fno-sanitize-coverage=stack-depth
endif

ifneq ($(filter integer_overflow,$(my_sanitize)),)
  # Respect LOCAL_NOSANITIZE for integer-overflow flags.
  ifeq ($(filter signed-integer-overflow, $(strip $(LOCAL_NOSANITIZE))),)
    my_sanitize += signed-integer-overflow
  endif
  ifeq ($(filter unsigned-integer-overflow, $(strip $(LOCAL_NOSANITIZE))),)
    my_sanitize += unsigned-integer-overflow
  endif
  my_cflags += $(INTEGER_OVERFLOW_EXTRA_CFLAGS)

  # Check for diagnostics mode.
  ifneq ($(filter integer_overflow,$(my_sanitize_diag)),)
    ifneq ($(filter SHARED_LIBRARIES EXECUTABLES,$(LOCAL_MODULE_CLASS)),)
      ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
        my_sanitize_diag += signed-integer-overflow
        my_sanitize_diag += unsigned-integer-overflow
      else
        $(call pretty-error,Make cannot apply integer overflow diagnostics to static binary.)
      endif
    else
      $(call pretty-error,Make cannot apply integer overflow diagnostics to static library.)
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
  my_asflags += -fsanitize=$(fsanitize_arg)

  # When fuzzing, we wish to crash with diagnostics on any bug.
  ifneq ($(filter fuzzer-no-link,$(my_sanitize)),)
    my_cflags += -fno-sanitize-trap=all
    my_cflags += -fno-sanitize-recover=all
    my_ldflags += -fsanitize=fuzzer-no-link
  else ifdef LOCAL_IS_HOST_MODULE
    my_cflags += -fno-sanitize-recover=all
    my_ldflags += -fsanitize=$(fsanitize_arg)
  else
    my_cflags += -fsanitize-trap=all
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
  my_asflags += $(CFI_EXTRA_ASFLAGS)
  # Only append the default visibility flag if -fvisibility has not already been
  # set to hidden.
  ifeq ($(filter -fvisibility=hidden,$(LOCAL_CFLAGS)),)
    my_cflags += -fvisibility=default
  endif
  my_ldflags += $(CFI_EXTRA_LDFLAGS)

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

    # Do not add unnecessary dependency in shared libraries.
    ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
      my_ldflags += -Wl,--as-needed
    endif

    ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
      ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
        my_linker := $($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_LINKER)
        # Make sure linker_asan get installed.
        $(LOCAL_INSTALLED_MODULE) : | $(PRODUCT_OUT)$($(LOCAL_2ND_ARCH_VAR_PREFIX)ADDRESS_SANITIZER_LINKER_FILE)
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

# If local module needs HWASAN, add compiler flags.
ifneq ($(filter hwaddress,$(my_sanitize)),)
  my_cflags += $(HWADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS)

  ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
    ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
      my_linker := /system/bin/linker_hwasan64
    endif
  endif

endif

# Use minimal diagnostics when integer overflow is enabled; never do it for HOST modules
ifeq ($(LOCAL_IS_HOST_MODULE),)
  # Pre-emptively add UBSAN minimal runtime incase a static library dependency requires it
  ifeq ($(filter STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
    ifndef LOCAL_SDK_VERSION
      my_static_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_MINIMAL_RUNTIME_LIBRARY)
      my_ldflags += -Wl,--exclude-libs,$($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_MINIMAL_RUNTIME_LIBRARY).a
    endif
  endif
  ifneq ($(filter unsigned-integer-overflow signed-integer-overflow integer,$(my_sanitize)),)
    ifeq ($(filter unsigned-integer-overflow signed-integer-overflow integer,$(my_sanitize_diag)),)
      ifeq ($(filter cfi,$(my_sanitize_diag)),)
        ifeq ($(filter address hwaddress fuzzer-no-link,$(my_sanitize)),)
          my_cflags += -fsanitize-minimal-runtime
          my_cflags += -fno-sanitize-trap=integer
          my_cflags += -fno-sanitize-recover=integer
        endif
      endif
    endif
  endif
endif

# For Scudo, we opt for the minimal runtime, unless some diagnostics are enabled.
ifneq ($(filter scudo,$(my_sanitize)),)
  ifeq ($(filter unsigned-integer-overflow signed-integer-overflow integer cfi,$(my_sanitize_diag)),)
    my_cflags += -fsanitize-minimal-runtime
  endif
  ifneq ($(filter -fsanitize-minimal-runtime,$(my_cflags)),)
    my_shared_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)SCUDO_MINIMAL_RUNTIME_LIBRARY)
  else
    my_shared_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)SCUDO_RUNTIME_LIBRARY)
  endif
endif

ifneq ($(strip $(LOCAL_SANITIZE_RECOVER)),)
  recover_arg := $(subst $(space),$(comma),$(LOCAL_SANITIZE_RECOVER)),
  my_cflags += -fsanitize-recover=$(recover_arg)
endif

ifneq ($(strip $(LOCAL_SANITIZE_NO_RECOVER)),)
  no_recover_arg := $(subst $(space),$(comma),$(LOCAL_SANITIZE_NO_RECOVER)),
  my_cflags += -fno-sanitize-recover=$(no_recover_arg)
endif

ifneq ($(my_sanitize_diag),)
  # TODO(vishwath): Add diagnostic support for static executables once
  # we switch to clang-4393122 (which adds the static ubsan runtime
  # that this depends on)
  ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
    notrap_arg := $(subst $(space),$(comma),$(my_sanitize_diag)),
    my_cflags += -fno-sanitize-trap=$(notrap_arg)
    # Diagnostic requires a runtime library, unless ASan or TSan are also enabled.
    ifeq ($(filter address thread scudo hwaddress,$(my_sanitize)),)
      # Does not have to be the first DT_NEEDED unlike ASan.
      my_shared_libraries += $($(LOCAL_2ND_ARCH_VAR_PREFIX)UBSAN_RUNTIME_LIBRARY)
    endif
  endif
endif

# http://b/119329758, Android core does not boot up with this sanitizer yet.
# Previously sanitized modules might not pass new implicit-integer-sign-change check.
# Disable this check unless it has been explicitly specified.
ifneq ($(findstring fsanitize,$(my_cflags)),)
  ifneq ($(findstring integer,$(my_cflags)),)
    ifeq ($(findstring sanitize=implicit-integer-sign-change,$(my_cflags)),)
      my_cflags += -fno-sanitize=implicit-integer-sign-change
    endif
  endif
endif

# http://b/177566116, libc++ may crash with this sanitizer.
# Disable this check unless it has been explicitly specified.
ifneq ($(findstring fsanitize,$(my_cflags)),)
  ifneq ($(findstring integer,$(my_cflags)),)
    ifeq ($(findstring sanitize=unsigned-shift-base,$(my_cflags)),)
      my_cflags += -fno-sanitize=unsigned-shift-base
    endif
  endif
endif
