###########################################################
## Standard rules for building an executable file.
##
## Additional inputs from base_rules.make:
## None.
###########################################################

LOCAL_IS_HOST_MODULE := true
ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := EXECUTABLES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $(HOST_EXECUTABLE_SUFFIX)
endif

$(call host-executable-hook)

skip_build_from_source :=
ifdef LOCAL_PREBUILT_MODULE_FILE
ifeq (,$(call if-build-from-source,$(LOCAL_MODULE),$(LOCAL_PATH)))
include $(BUILD_SYSTEM)/prebuilt_internal.mk
skip_build_from_source := true
endif
endif

ifndef skip_build_from_source

include $(BUILD_SYSTEM)/binary.mk

my_host_libprofile_rt := $($(LOCAL_2ND_ARCH_VAR_PREFIX)HOST_LIBPROFILE_RT)
$(LOCAL_BUILT_MODULE): PRIVATE_HOST_LIBPROFILE_RT := $(my_host_libprofile_rt)

$(LOCAL_BUILT_MODULE): $(all_objects) $(all_libraries)
	$(transform-host-o-to-executable)

endif  # skip_build_from_source
