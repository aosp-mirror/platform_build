ifeq ($(strip $(llvm_arch)),)
  $(error "$$(llvm_arch) should be defined.")
endif

ifeq ($(strip $(CLANG_CONFIG_$(llvm_arch)_TARGET_TRIPLE)),)
  $(error "$$(CLANG_CONFIG_$(llvm_arch)_TARGET_TRIPLE) should be defined.")
endif

ifeq ($(strip $(CLANG_CONFIG_$(llvm_arch)_TARGET_TOOLCHAIN_PREFIX)),)
CLANG_CONFIG_$(llvm_arch)_TARGET_TOOLCHAIN_PREFIX := \
  $(TARGET_TOOLCHAIN_ROOT)/$(CLANG_CONFIG_$(llvm_arch)_TARGET_TRIPLE)/bin
endif

# Include common unknown flags
CLANG_CONFIG_$(llvm_arch)_UNKNOWN_CFLAGS += \
  $(CLANG_CONFIG_UNKNOWN_CFLAGS)

# Clang extra flags for host
CLANG_CONFIG_$(llvm_arch)_HOST_EXTRA_ASFLAGS := \
  $(CLANG_CONFIG_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_HOST_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_ASFLAGS)

ifneq ($(strip $(CLANG_CONFIG_$(llvm_arch)_HOST_TRIPLE)),)
CLANG_CONFIG_$(llvm_arch)_HOST_EXTRA_ASFLAGS += \
  -target $(CLANG_CONFIG_$(llvm_arch)_HOST_TRIPLE)
endif

CLANG_CONFIG_$(llvm_arch)_HOST_EXTRA_CFLAGS := \
  $(CLANG_CONFIG_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_HOST_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_HOST_EXTRA_ASFLAGS)

CLANG_CONFIG_$(llvm_arch)_HOST_EXTRA_CPPFLAGS := \
  $(CLANG_CONFIG_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_HOST_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_CPPFLAGS)

CLANG_CONFIG_$(llvm_arch)_HOST_EXTRA_LDFLAGS := \
  $(CLANG_CONFIG_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_HOST_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_LDFLAGS)

ifneq ($(strip $(CLANG_CONFIG_$(llvm_arch)_HOST_TRIPLE)),)
CLANG_CONFIG_$(llvm_arch)_HOST_EXTRA_LDFLAGS += \
  -target $(CLANG_CONFIG_$(llvm_arch)_HOST_TRIPLE)
endif

# Clang extra flags for target
CLANG_CONFIG_$(llvm_arch)_TARGET_EXTRA_ASFLAGS := \
  $(CLANG_CONFIG_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_ASFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_ASFLAGS) \
  -target $(CLANG_CONFIG_$(llvm_arch)_TARGET_TRIPLE) \
  -B$(CLANG_CONFIG_$(llvm_arch)_TARGET_TOOLCHAIN_PREFIX)

CLANG_CONFIG_$(llvm_arch)_TARGET_EXTRA_CFLAGS := \
  $(CLANG_CONFIG_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_CFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_TARGET_EXTRA_ASFLAGS)

CLANG_CONFIG_$(llvm_arch)_TARGET_EXTRA_CPPFLAGS := \
  $(CLANG_CONFIG_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_CPPFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_CPPFLAGS)

CLANG_CONFIG_$(llvm_arch)_TARGET_EXTRA_LDFLAGS := \
  $(CLANG_CONFIG_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_TARGET_EXTRA_LDFLAGS) \
  $(CLANG_CONFIG_$(llvm_arch)_EXTRA_LDFLAGS) \
  -target $(CLANG_CONFIG_$(llvm_arch)_TARGET_TRIPLE) \
  -B$(CLANG_CONFIG_$(llvm_arch)_TARGET_TOOLCHAIN_PREFIX)

llvm_arch :=
