###########################################################
## Standard rules for building a normal shared library.
##
## Additional inputs from base_rules.make:
## None.
##
## LOCAL_MODULE_SUFFIX will be set for you.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $($(my_prefix)SHLIB_SUFFIX)
endif
ifneq ($(strip $(OVERRIDE_BUILT_MODULE_PATH)),)
$(error $(LOCAL_PATH): Illegal use of OVERRIDE_BUILT_MODULE_PATH)
endif
ifneq ($(strip $(LOCAL_MODULE_STEM)$(LOCAL_BUILT_MODULE_STEM)),)
$(error $(LOCAL_PATH): Cannot set module stem for a library)
endif

$(call host-shared-library-hook)

skip_build_from_source :=
ifdef LOCAL_PREBUILT_MODULE_FILE
ifeq (,$(call if-build-from-source,$(LOCAL_MODULE),$(LOCAL_PATH)))
include $(BUILD_SYSTEM)/prebuilt_internal.mk
skip_build_from_source := true
endif
endif

ifndef skip_build_from_source

# Put the built modules of all shared libraries in a common directory
# to simplify the link line.
OVERRIDE_BUILT_MODULE_PATH := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_INTERMEDIATE_LIBRARIES)

include $(BUILD_SYSTEM)/binary.mk

my_host_libprofile_rt := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LIBPROFILE_RT)
$(LOCAL_BUILD_MODULE): PRIVATE_HOST_LIBPROFILE_RT := $(my_host_libprofile_rt)

$(LOCAL_BUILT_MODULE): \
        $(all_objects) \
        $(all_libraries) \
        $(LOCAL_MODULE_MAKEFILE_DEP) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-host-o-to-shared-lib)

endif  # skip_build_from_source
