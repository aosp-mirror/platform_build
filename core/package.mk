# We don't automatically set up rules to build packages for both
# TARGET_ARCH and TARGET_2ND_ARCH.
# To build it for TARGET_2ND_ARCH in a 64bit product, use "LOCAL_MULTILIB := 32".

my_prefix := TARGET_
include $(BUILD_SYSTEM)/multilib.mk

ifeq ($(TARGET_SUPPORTS_32_BIT_APPS)|$(TARGET_SUPPORTS_64_BIT_APPS),true|true)
  # packages default to building for either architecture,
  # the preferred if its supported, otherwise the non-preferred.
else ifeq ($(TARGET_SUPPORTS_64_BIT_APPS),true)
  # only 64-bit apps supported
  ifeq ($(filter $(my_module_multilib),64 both first),$(my_module_multilib))
    # if my_module_multilib was 64, both, first, or unset, build for 64-bit
    my_module_multilib := 64
  else
    # otherwise don't build this app
    my_module_multilib := none
  endif
else
  # only 32-bit apps supported
  ifeq ($(filter $(my_module_multilib),32 both),$(my_module_multilib))
    # if my_module_multilib was 32, both, or unset, build for 32-bit
    my_module_multilib := 32
  else ifeq ($(my_module_multilib),first)
    ifndef TARGET_IS_64_BIT
      # if my_module_multilib was first and this is a 32-bit build, build for
      # 32-bit
      my_module_multilib := 32
    else
      # if my_module_multilib was first and this is a 64-bit build, don't build
      # this app
      my_module_multilib := none
    endif
  else
    # my_module_mulitlib was 64 or none, don't build this app
    my_module_multilib := none
  endif
endif

LOCAL_NO_2ND_ARCH_MODULE_SUFFIX := true

# if TARGET_PREFER_32_BIT_APPS is set, try to build 32-bit first
ifdef TARGET_2ND_ARCH
ifeq ($(TARGET_PREFER_32_BIT_APPS),true)
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
else
LOCAL_2ND_ARCH_VAR_PREFIX :=
endif
endif

# check if preferred arch is supported
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# first arch is supported
include $(BUILD_SYSTEM)/package_internal.mk
else ifneq (,$(TARGET_2ND_ARCH))
# check if the non-preferred arch is the primary or secondary
ifeq ($(TARGET_PREFER_32_BIT_APPS),true)
LOCAL_2ND_ARCH_VAR_PREFIX :=
else
LOCAL_2ND_ARCH_VAR_PREFIX := $(TARGET_2ND_ARCH_VAR_PREFIX)
endif

# check if non-preferred arch is supported
include $(BUILD_SYSTEM)/module_arch_supported.mk
ifeq ($(my_module_arch_supported),true)
# secondary arch is supported
include $(BUILD_SYSTEM)/package_internal.mk
endif
endif # TARGET_2ND_ARCH

LOCAL_2ND_ARCH_VAR_PREFIX :=
LOCAL_NO_2ND_ARCH_MODULE_SUFFIX :=

my_module_arch_supported :=
