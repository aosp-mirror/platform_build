# Translate LOCAL_32_BIT_ONLY and LOCAL_NO_2ND_ARCH to LOCAL_MULTILIB,
# and check LOCAL_MULTILIB is a valid value.  Returns module's multilib
# setting in my_module_multilib, or empty if not set.

my_module_multilib := $(strip $(LOCAL_MULTILIB))
ifndef my_module_multilib
ifeq ($(LOCAL_32_BIT_ONLY)|$(LOCAL_NO_2ND_ARCH),true|true)
ifdef TARGET_2ND_ARCH
# Both LOCAL_32_BIT_ONLY and LOCAL_NO_2ND_ARCH specified on 64-bit target
# skip the module completely
my_module_multilib := none
else
# Both LOCAL_32_BIT_ONLY and LOCAL_NO_2ND_ARCH specified on 32-bit target
# build for 32-bit
my_module_multilib := 32
endif
else ifeq ($(LOCAL_32_BIT_ONLY),true)
my_module_multilib := 32
else ifeq ($(LOCAL_NO_2ND_ARCH),true)
my_module_multilib := first
endif
else # my_module_multilib defined
ifeq (,$(filter 32 64 first both none,$(my_module_multilib)))
$(error $(LOCAL_PATH): Invalid LOCAL_MULTILIB specified for module $(LOCAL_MODULE))
endif
endif # my_module_multilib defined
