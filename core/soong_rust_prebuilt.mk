# Native prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_UNSTRIPPED_BINARY

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_rust_prebuilt.mk may only be used from Soong)
endif

ifdef LOCAL_IS_HOST_MODULE
  ifneq ($(HOST_OS),$(LOCAL_MODULE_HOST_OS))
    my_prefix := HOST_CROSS_
    LOCAL_HOST_PREFIX := $(my_prefix)
  else
    my_prefix := HOST_
    LOCAL_HOST_PREFIX :=
  endif
else
  my_prefix := TARGET_
endif

ifeq ($($(my_prefix)ARCH),$(LOCAL_MODULE_$(my_prefix)ARCH))
  # primary arch
  LOCAL_2ND_ARCH_VAR_PREFIX :=
else ifeq ($($(my_prefix)2ND_ARCH),$(LOCAL_MODULE_$(my_prefix)ARCH))
  # secondary arch
  LOCAL_2ND_ARCH_VAR_PREFIX := $($(my_prefix)2ND_ARCH_VAR_PREFIX)
else
  $(call pretty-error,Unsupported LOCAL_MODULE_$(my_prefix)ARCH=$(LOCAL_MODULE_$(my_prefix)ARCH))
endif

# Don't install static/rlib/proc_macro libraries.
ifndef LOCAL_UNINSTALLABLE_MODULE
  ifneq ($(filter STATIC_LIBRARIES RLIB_LIBRARIES PROC_MACRO_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
    LOCAL_UNINSTALLABLE_MODULE := true
  endif
endif


#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES RLIB_LIBRARIES DYLIB_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  # Soong module is a static or shared library
  EXPORTS_LIST += $(intermediates)
  EXPORTS.$(intermediates).FLAGS := $(LOCAL_EXPORT_CFLAGS)
  EXPORTS.$(intermediates).DEPS := $(LOCAL_EXPORT_C_INCLUDE_DEPS)

  SOONG_ALREADY_CONV += $(LOCAL_MODULE)

  my_link_type := $(LOCAL_SOONG_LINK_TYPE)
  my_warn_types :=
  my_allowed_types :=
  my_link_deps :=
  my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
  my_common :=
  include $(BUILD_SYSTEM)/link_type.mk
endif


ifdef LOCAL_USE_VNDK
  ifneq ($(LOCAL_VNDK_DEPEND_ON_CORE_VARIANT),true)
    name_without_suffix := $(patsubst %.vendor,%,$(LOCAL_MODULE))
    ifneq ($(name_without_suffix),$(LOCAL_MODULE))
      SPLIT_VENDOR.$(LOCAL_MODULE_CLASS).$(name_without_suffix) := 1
    else
      name_without_suffix := $(patsubst %.product,%,$(LOCAL_MODULE))
      ifneq ($(name_without_suffix),$(LOCAL_MODULE))
        SPLIT_PRODUCT.$(LOCAL_MODULE_CLASS).$(name_without_suffix) := 1
      endif
    endif
    name_without_suffix :=
  endif
endif

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
  ifdef LOCAL_SHARED_LIBRARIES
    my_shared_libraries := $(LOCAL_SHARED_LIBRARIES)
    ifdef LOCAL_USE_VNDK
      my_shared_libraries := $(foreach l,$(my_shared_libraries),\
        $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
    endif
    $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
      $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_shared_libraries))
  endif
  ifdef LOCAL_DYLIB_LIBRARIES
    my_dylibs := $(LOCAL_DYLIB_LIBRARIES)
    # Treat these as shared library dependencies for installation purposes.
    ifdef LOCAL_USE_VNDK
      my_dylibs := $(foreach l,$(my_dylibs),\
        $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
    endif
    $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
      $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_dylibs))
  endif
endif

$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)
ifeq ($(LOCAL_IS_HOST_MODULE) $(if $(filter EXECUTABLES SHARED_LIBRARIES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),true,),true true)
	$(copy-or-link-prebuilt-to-target)
  ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
	[ -x $@ ] || ( $(call echo-error,$@,Target of symlink is not executable); false )
  endif
else
	$(transform-prebuilt-to-target)
  ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
	$(hide) chmod +x $@
  endif
endif

ifndef LOCAL_IS_HOST_MODULE
  ifdef LOCAL_SOONG_UNSTRIPPED_BINARY
    my_symbol_path := $(if $(LOCAL_SOONG_SYMBOL_PATH),$(LOCAL_SOONG_SYMBOL_PATH),$(my_module_path))
    # Store a copy with symbols for symbolic debugging
    my_unstripped_path := $(TARGET_OUT_UNSTRIPPED)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_symbol_path))
    # drop /root as /root is mounted as /
    my_unstripped_path := $(patsubst $(TARGET_OUT_UNSTRIPPED)/root/%,$(TARGET_OUT_UNSTRIPPED)/%, $(my_unstripped_path))
    symbolic_output := $(my_unstripped_path)/$(my_installed_module_stem)
    $(eval $(call copy-one-file,$(LOCAL_SOONG_UNSTRIPPED_BINARY),$(symbolic_output)))
    $(LOCAL_BUILT_MODULE): | $(symbolic_output)
  endif
endif

create_coverage_zip :=

ifeq ($(NATIVE_COVERAGE),true)
   create_coverage_zip := true
endif

# Until Rust supports LLVM coverage, Soong assumes GCOV coverage in both cases.
# Therefore we should create the coverage zip with the gcno files in this case as well.
ifeq ($(CLANG_COVERAGE),true)
   create_coverage_zip := true
endif

ifdef create_coverage_zip
  ifneq (,$(strip $(LOCAL_PREBUILT_COVERAGE_ARCHIVE)))
    $(eval $(call copy-one-file,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(intermediates)/$(LOCAL_MODULE).zip))
    ifneq ($(LOCAL_UNINSTALLABLE_MODULE),true)
      ifdef LOCAL_IS_HOST_MODULE
        my_coverage_path := $($(my_prefix)OUT_COVERAGE)/$(patsubst $($(my_prefix)OUT)/%,%,$(my_module_path))
      else
        my_coverage_path := $(TARGET_OUT_COVERAGE)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
      endif
      my_coverage_path := $(my_coverage_path)/$(patsubst %.so,%,$(my_installed_module_stem)).zip
      $(eval $(call copy-one-file,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(my_coverage_path)))
      $(LOCAL_BUILT_MODULE): $(my_coverage_path)
    endif
  endif
endif

# A product may be configured to strip everything in some build variants.
# We do the stripping as a post-install command so that LOCAL_BUILT_MODULE
# is still with the symbols and we don't need to clean it (and relink) when
# you switch build variant.
ifneq ($(filter $(STRIP_EVERYTHING_BUILD_VARIANTS),$(TARGET_BUILD_VARIANT)),)
$(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := \
  $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP) --strip-all $(LOCAL_INSTALLED_MODULE)
endif

$(LOCAL_BUILT_MODULE): $(LOCAL_ADDITIONAL_DEPENDENCIES)

# We don't care about installed rlib/static libraries, since the libraries have
# already been linked into the module at that point. We do, however, care
# about the NOTICE files for any rlib/static libraries that we use.
# (see notice_files.mk)
#
# Filter out some NDK libraries that are not being exported.
my_static_libraries := \
    $(filter-out ndk_libc++_static ndk_libc++abi ndk_libandroid_support ndk_libunwind \
      ndk_libc++_static.native_bridge ndk_libc++abi.native_bridge \
      ndk_libandroid_support.native_bridge ndk_libunwind.native_bridge, \
      $(LOCAL_STATIC_LIBRARIES))
installed_static_library_notice_file_targets := \
    $(foreach lib,$(my_static_libraries), \
      NOTICE-$(if $(LOCAL_IS_HOST_MODULE),HOST$(if $(my_host_cross),_CROSS,),TARGET)-STATIC_LIBRARIES-$(lib))
installed_static_library_notice_file_targets += \
    $(foreach lib,$(LOCAL_RLIB_LIBRARIES), \
      NOTICE-$(if $(LOCAL_IS_HOST_MODULE),HOST$(if $(my_host_cross),_CROSS,),TARGET)-RLIB_LIBRARIES-$(lib))

$(notice_target): | $(installed_static_library_notice_file_targets)
$(LOCAL_INSTALLED_MODULE): | $(notice_target)
