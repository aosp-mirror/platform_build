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
ifneq ($(strip $(OVERRIDE_BUILT_MODULE_PATH)),)
$(error $(LOCAL_PATH): Illegal use of OVERRIDE_BUILT_MODULE_PATH)
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

# Put the built targets of all shared libraries in a common directory
# to simplify the link line.
OVERRIDE_BUILT_MODULE_PATH := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)

include $(BUILD_SYSTEM)/dynamic_binary.mk

# Define PRIVATE_ variables from global vars
ifeq ($(LOCAL_NO_LIBGCC),true)
my_target_libgcc :=
else
my_target_libgcc := $(call intermediates-dir-for,STATIC_LIBRARIES,libgcc,,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/libgcc.a
endif
my_target_libatomic := $(call intermediates-dir-for,STATIC_LIBRARIES,libatomic,,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/libatomic.a
ifeq ($(LOCAL_NO_CRT),true)
my_target_crtbegin_so_o :=
my_target_crtend_so_o :=
else ifdef LOCAL_USE_VNDK
my_target_crtbegin_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.vendor.o
my_target_crtend_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.vendor.o
else
my_target_crtbegin_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtbegin_so.o
my_target_crtend_so_o := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OUT_INTERMEDIATE_LIBRARIES)/crtend_so.o
endif
ifneq ($(LOCAL_SDK_VERSION),)
my_target_crtbegin_so_o := $(wildcard $(my_ndk_sysroot_lib)/crtbegin_so.o)
my_target_crtend_so_o := $(wildcard $(my_ndk_sysroot_lib)/crtend_so.o)
endif
$(linked_module): PRIVATE_TARGET_LIBGCC := $(my_target_libgcc)
$(linked_module): PRIVATE_TARGET_LIBATOMIC := $(my_target_libatomic)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_SO_O := $(my_target_crtbegin_so_o)
$(linked_module): PRIVATE_TARGET_CRTEND_SO_O := $(my_target_crtend_so_o)

$(linked_module): \
        $(all_objects) \
        $(all_libraries) \
        $(my_target_crtbegin_so_o) \
        $(my_target_crtend_so_o) \
        $(my_target_libgcc) \
        $(my_target_libatomic) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-o-to-shared-lib)

ifeq ($(my_native_coverage),true)
gcno_suffix := .gcnodir

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

$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_OBJECTS := $(strip $(LOCAL_GCNO_FILES))
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(strip $(built_whole_gcno_libraries)) $(strip $(built_static_gcno_libraries))
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_INTERMEDIATES_DIR := $(intermediates)
$(intermediates)/$(GCNO_ARCHIVE) : $(LOCAL_GCNO_FILES) $(built_whole_gcno_libraries) $(built_static_gcno_libraries)
	$(transform-o-to-static-lib)

$(my_coverage_path)/$(GCNO_ARCHIVE) : $(intermediates)/$(GCNO_ARCHIVE)
	$(copy-file-to-target)

$(LOCAL_BUILT_MODULE): $(my_coverage_path)/$(GCNO_ARCHIVE)
endif

endif  # skip_build_from_source
