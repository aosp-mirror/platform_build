###########################################################
## Standard rules for building an executable file.
##
## Additional inputs from base_rules.make:
## None.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := EXECUTABLES
endif
ifeq ($(strip $(LOCAL_MODULE_SUFFIX)),)
LOCAL_MODULE_SUFFIX := $(TARGET_EXECUTABLE_SUFFIX)
endif

ifdef target-executable-hook
$(call target-executable-hook)
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

# Check for statically linked libc
ifneq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
ifneq ($(filter $(my_static_libraries),libc),)
$(error $(LOCAL_PATH): $(LOCAL_MODULE) is statically linking libc to dynamic executable, please remove libc from static libs or set LOCAL_FORCE_STATIC_EXECUTABLE := true)
endif
endif

# Define PRIVATE_ variables from global vars
ifeq ($(LOCAL_NO_LIBCRT_BUILTINS),true)
my_target_libcrt_builtins :=
else
my_target_libcrt_builtins := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)LIBCRT_BUILTINS)
endif
ifeq ($(LOCAL_NO_LIBGCC),true)
my_target_libgcc :=
else
my_target_libgcc := $(call intermediates-dir-for,STATIC_LIBRARIES,libgcc,,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/libgcc.a
endif
my_target_libatomic := $(call intermediates-dir-for,STATIC_LIBRARIES,libatomic,,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/libatomic.a
ifeq ($(LOCAL_NO_CRT),true)
my_target_crtbegin_dynamic_o :=
my_target_crtbegin_static_o :=
my_target_crtend_o :=
else ifdef LOCAL_USE_VNDK
my_target_crtbegin_dynamic_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtbegin_dynamic.vendor)
my_target_crtbegin_static_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtbegin_static.vendor)
my_target_crtend_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtend_android.vendor)
else
my_target_crtbegin_dynamic_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtbegin_dynamic)
my_target_crtbegin_static_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtbegin_static)
my_target_crtend_o := $(SOONG_$(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJECT_crtend_android)
endif
ifneq ($(LOCAL_SDK_VERSION),)
my_target_crtbegin_dynamic_o := $(wildcard $(my_ndk_sysroot_lib)/crtbegin_dynamic.o)
my_target_crtbegin_static_o := $(wildcard $(my_ndk_sysroot_lib)/crtbegin_static.o)
my_target_crtend_o := $(wildcard $(my_ndk_sysroot_lib)/crtend_android.o)
endif
$(linked_module): PRIVATE_TARGET_LIBCRT_BUILTINS := $(my_target_libcrt_builtins)
$(linked_module): PRIVATE_TARGET_LIBGCC := $(my_target_libgcc)
$(linked_module): PRIVATE_TARGET_LIBATOMIC := $(my_target_libatomic)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_DYNAMIC_O := $(my_target_crtbegin_dynamic_o)
$(linked_module): PRIVATE_TARGET_CRTBEGIN_STATIC_O := $(my_target_crtbegin_static_o)
$(linked_module): PRIVATE_TARGET_CRTEND_O := $(my_target_crtend_o)
$(linked_module): PRIVATE_POST_LINK_CMD := $(LOCAL_POST_LINK_CMD)

ifeq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
$(linked_module): $(my_target_crtbegin_static_o) $(all_objects) $(all_libraries) $(my_target_crtend_o) $(my_target_libcrt_builtins) $(my_target_libgcc) $(my_target_libatomic) $(CLANG_CXX)
	$(transform-o-to-static-executable)
	$(PRIVATE_POST_LINK_CMD)
else
$(linked_module): $(my_target_crtbegin_dynamic_o) $(all_objects) $(all_libraries) $(my_target_crtend_o) $(my_target_libcrt_builtins) $(my_target_libgcc) $(my_target_libatomic) $(CLANG_CXX)
	$(transform-o-to-executable)
	$(PRIVATE_POST_LINK_CMD)
endif

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

GCNO_ARCHIVE := $(my_installed_module_stem)$(gcno_suffix)

$(intermediates)/$(GCNO_ARCHIVE) : $(SOONG_ZIP) $(MERGE_ZIPS)
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_OBJECTS := $(strip $(LOCAL_GCNO_FILES))
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(strip $(built_whole_gcno_libraries)) $(strip $(built_static_gcno_libraries))
$(intermediates)/$(GCNO_ARCHIVE) : $(LOCAL_GCNO_FILES) $(built_whole_gcno_libraries) $(built_static_gcno_libraries)
	$(package-coverage-files)

$(my_coverage_path)/$(GCNO_ARCHIVE) : $(intermediates)/$(GCNO_ARCHIVE)
	$(copy-file-to-target)

$(LOCAL_BUILT_MODULE): $(my_coverage_path)/$(GCNO_ARCHIVE)
endif

endif  # skip_build_from_source
