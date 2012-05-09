CLANG := $(HOST_OUT_EXECUTABLES)/clang$(HOST_EXECUTABLE_SUFFIX)
CLANG_CXX := $(HOST_OUT_EXECUTABLES)/clang++$(HOST_EXECUTABLE_SUFFIX)
LLVM_AS := $(HOST_OUT_EXECUTABLES)/llvm-as$(HOST_EXECUTABLE_SUFFIX)
LLVM_LINK := $(HOST_OUT_EXECUTABLES)/llvm-link$(HOST_EXECUTABLE_SUFFIX)

define do-clang-flags-subst
  TARGET_GLOBAL_CLANG_FLAGS := $(subst $(1),$(2),$(TARGET_GLOBAL_CLANG_FLAGS))
  HOST_GLOBAL_CLANG_FLAGS := $(subst $(1),$(2),$(HOST_GLOBAL_CLANG_FLAGS))
endef

define clang-flags-subst
  $(eval $(call do-clang-flags-subst,$(1),$(2)))
endef


CLANG_CONFIG_EXTRA_CFLAGS := \
  -D__compiler_offsetof=__builtin_offsetof \
  -Dnan=__builtin_nan \

CLANG_CONFIG_UNKNOWN_CFLAGS := \
  -funswitch-loops

ifeq ($(TARGET_ARCH),arm)
  CLANG_CONFIG_EXTRA_CFLAGS += \
    -target arm-linux-androideabi \
    -nostdlibinc \
    -B$(TARGET_TOOLCHAIN_ROOT)/arm-linux-androideabi/bin \
    -mllvm -arm-enable-ehabi
  CLANG_CONFIG_EXTRA_LDFLAGS += \
    -target arm-linux-androideabi \
    -B$(TARGET_TOOLCHAIN_ROOT)/arm-linux-androideabi/bin
  CLANG_CONFIG_UNKNOWN_CFLAGS += \
    -mthumb-interwork \
    -fgcse-after-reload \
    -frerun-cse-after-loop \
    -frename-registers \
    -fno-builtin-sin \
    -fno-strict-volatile-bitfields \
    -fno-align-jumps \
    -Wa,--noexecstack
endif
ifeq ($(TARGET_ARCH),x86)
  CLANG_CONFIG_EXTRA_CFLAGS += \
    -target i686-android-linux \
    -nostdlibinc \
    -B$(TARGET_TOOLCHAIN_ROOT)/i686-android-linux/bin
  CLANG_CONFIG_EXTRA_LDFLAGS += \
    -target i686-android-linux \
    -B$(TARGET_TOOLCHAIN_ROOT)/i686-android-linux/bin
  CLANG_CONFIG_UNKNOWN_CFLAGS += \
    -finline-limit=300 \
    -fno-inline-functions-called-once \
    -mfpmath=sse \
    -mbionic
endif

CLANG_CONFIG_EXTRA_TARGET_C_INCLUDES := external/clang/lib/include $(TARGET_OUT_HEADERS)/clang

# remove unknown flags to define CLANG_FLAGS
TARGET_GLOBAL_CLANG_FLAGS += $(filter-out $(CLANG_CONFIG_UNKNOWN_CFLAGS),$(TARGET_GLOBAL_CFLAGS))
HOST_GLOBAL_CLANG_FLAGS += $(filter-out $(CLANG_CONFIG_UNKNOWN_CFLAGS),$(HOST_GLOBAL_CFLAGS))

TARGET_arm_CLANG_CFLAGS += $(filter-out $(CLANG_CONFIG_UNKNOWN_CFLAGS),$(TARGET_arm_CFLAGS))
TARGET_thumb_CLANG_CFLAGS += $(filter-out $(CLANG_CONFIG_UNKNOWN_CFLAGS),$(TARGET_thumb_CFLAGS))

# llvm does not yet support -march=armv5e nor -march=armv5te, fall back to armv5 or armv5t
$(call clang-flags-subst,-march=armv5te,-march=armv5t)
$(call clang-flags-subst,-march=armv5e,-march=armv5)

ADDRESS_SANITIZER_CONFIG_EXTRA_CFLAGS := -faddress-sanitizer
ADDRESS_SANITIZER_CONFIG_EXTRA_LDFLAGS := -Wl,-u,__asan_preinit
ADDRESS_SANITIZER_CONFIG_EXTRA_SHARED_LIBRARIES := libdl libasan_preload
ADDRESS_SANITIZER_CONFIG_EXTRA_STATIC_LIBRARIES := libasan
