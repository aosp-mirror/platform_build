CLANG := $(HOST_OUT_EXECUTABLES)/clang$(HOST_EXECUTABLE_SUFFIX)
LLVM_LINK := $(HOST_OUT_EXECUTABLES)/llvm-link$(HOST_EXECUTABLE_SUFFIX)

define do-clang-flags-subst
  TARGET_GLOBAL_CLANG_FLAGS := $(subst $(1),$(2),$(TARGET_GLOBAL_CLANG_FLAGS))
  HOST_GLOBAL_CLANG_FLAGS := $(subst $(1),$(2),$(HOST_GLOBAL_CLANG_FLAGS))
endef

define clang-flags-subst
  $(eval $(call do-clang-flags-subst,$(1),$(2)))
endef


# These seem to cause warnings on clang/LLVM.
CLANG_CONFIG_UNKNOWN_CFLAGS := \
  -mthumb-interwork \
  -fgcse-after-reload \
  -frerun-cse-after-loop \
  -frename-registers \
  -funswitch-loops \
  -Wa,--noexecstack \
  -mfpu=vfpv3-d16

# Workaround a SIGSEGV in Lol
CLANG_CONFIG_UNKNOWN_CFLAGS += -g

# remove unknown flags to define CLANG_FLAGS
TARGET_GLOBAL_CLANG_FLAGS += $(filter-out $(CLANG_CONFIG_UNKNOWN_CFLAGS),$(TARGET_GLOBAL_CFLAGS))
HOST_GLOBAL_CLANG_FLAGS += $(filter-out $(CLANG_CONFIG_UNKNOWN_CFLAGS),$(HOST_GLOBAL_CFLAGS))

# llvm does not yet support -march=armv5e nor -march=armv5te, fall back to armv5 or armv5t
$(call clang-flags-subst,-march=armv5te,-march=armv5t)
$(call clang-flags-subst,-march=armv5e,-march=armv5)
