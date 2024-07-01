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
LOCAL_MODULE_SUFFIX := $(TARGET_SHLIB_SUFFIX)
endif
ifneq ($(strip $(LOCAL_MODULE_STEM)$(LOCAL_BUILT_MODULE_STEM)$(LOCAL_MODULE_STEM_32)$(LOCAL_MODULE_STEM_64)),)
$(error $(LOCAL_PATH): Cannot set module stem for a library)
endif

ifdef target-shared-library-hook
$(call target-shared-library-hook)
endif

skip_build_from_source :=
ifdef LOCAL_PREBUILT_MODULE_FILE
ifeq (,$(call if-build-from-source,$(LOCAL_MODULE),$(LOCAL_PATH)))
include $(BUILD_SYSTEM)/prebuilt_internal.mk
skip_build_from_source := true
endif
endif

ifndef skip_build_from_source

include $(BUILD_SYSTEM)/dynamic_binary.mk

# Define PRIVATE_ variables from global vars
ifeq ($(LOCAL_NO_LIBCRT_BUILTINS),true)
my_target_libcrt_builtins :=
else
my_target_libcrt_builtins := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LIBCRT_BUILTINS)
endif
ifeq ($(LOCAL_NO_CRT),true)
my_target_crtbegin_so_o :=
my_target_crtend_so_o :=
else ifeq ($(call module-in-vendor-or-product),true)
my_target_crtbegin_so_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtbegin_so.vendor)
my_target_crtend_so_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtend_so.vendor)
else
my_target_crtbegin_so_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtbegin_so)
my_target_crtend_so_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtend_so)
endif
ifneq ($(LOCAL_SDK_VERSION),)
my_target_crtbegin_so_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtbegin_so.sdk.$(my_ndk_crt_version))
my_target_crtend_so_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtend_so.sdk.$(my_ndk_crt_version))
endif
$(linked_module): PRIVATE_TARGET_LIBCRT_BUILTINS := $(my_target_libcrt_builtins)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_SO_O := $(my_target_crtbegin_so_o)
$(linked_module): PRIVATE_TARGET_CRTEND_SO_O := $(my_target_crtend_so_o)

$(linked_module): \
        $(all_objects) \
        $(all_libraries) \
        $(my_target_crtbegin_so_o) \
        $(my_target_crtend_so_o) \
        $(my_target_libcrt_builtins) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES) $(CLANG_CXX)
	$(transform-o-to-shared-lib)

ifeq ($(my_native_coverage),true)
gcno_suffix := .zip

built_whole_gcno_libraries := \
    $(foreach lib,$(my_whole_static_libraries), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX), \
        $(my_host_cross))/$(lib)$(gcno_suffix))

built_static_gcno_libraries := \
    $(foreach lib,$(my_static_libraries), \
      $(call intermediates-dir-for, \
        STATIC_LIBRARIES,$(lib),$(my_kind),,$(LOCAL_2ND_ARCH_VAR_PREFIX), \
        $(my_host_cross))/$(lib)$(gcno_suffix))

ifdef LOCAL_IS_HOST_MODULE
my_coverage_path := $($(my_prefix)OUT_COVERAGE)/$(patsubst $($(my_prefix)OUT)/%,%,$(my_module_path))
else
my_coverage_path := $(TARGET_OUT_COVERAGE)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
endif

GCNO_ARCHIVE := $(basename $(my_installed_module_stem))$(gcno_suffix)

$(intermediates)/$(GCNO_ARCHIVE) : $(SOONG_ZIP) $(MERGE_ZIPS)
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_OBJECTS := $(strip $(LOCAL_GCNO_FILES))
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(strip $(built_whole_gcno_libraries)) $(strip $(built_static_gcno_libraries))
$(intermediates)/$(GCNO_ARCHIVE) : $(LOCAL_GCNO_FILES) $(built_whole_gcno_libraries) $(built_static_gcno_libraries)
	$(package-coverage-files)

$(my_coverage_path)/$(GCNO_ARCHIVE) : $(intermediates)/$(GCNO_ARCHIVE)
	$(copy-file-to-target)

$(LOCAL_BUILT_MODULE): $(my_coverage_path)/$(GCNO_ARCHIVE)
endif

$(if $(my_register_name),$(eval ALL_MODULES.$(my_register_name).MAKE_MODULE_TYPE:=SHARED_LIBRARY))

endif  # skip_build_from_source
