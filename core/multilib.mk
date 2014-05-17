# Translate LOCAL_32_BIT_ONLY to LOCAL_MULTILIB,
# and check LOCAL_MULTILIB is a valid value.  Returns module's multilib
# setting in my_module_multilib, or empty if not set.

my_module_multilib := $(strip $(LOCAL_MULTILIB))

ifndef my_module_multilib
ifeq ($(LOCAL_32_BIT_ONLY),true)
my_module_multilib := 32
endif
else # my_module_multilib defined
ifeq (,$(filter 32 64 first both none,$(my_module_multilib)))
$(error $(LOCAL_PATH): Invalid LOCAL_MULTILIB specified for module $(LOCAL_MODULE))
endif
endif # my_module_multilib defined
