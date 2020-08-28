# Native prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_LINK_TYPE
# LOCAL_SOONG_TOC
# LOCAL_SOONG_UNSTRIPPED_BINARY

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_cc_prebuilt.mk may only be used from Soong)
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

skip_module :=
ifeq ($(TARGET_TRANSLATE_2ND_ARCH),true)
  ifndef LOCAL_IS_HOST_MODULE
    ifdef LOCAL_2ND_ARCH_VAR_PREFIX
      # Only support shared and static libraries and tests for translated arch
      ifeq ($(filter SHARED_LIBRARIES STATIC_LIBRARIES HEADER_LIBRARIES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
        skip_module := true
      endif
    endif
  endif
endif

ifndef skip_module

# Don't install static libraries by default.
ifndef LOCAL_UNINSTALLABLE_MODULE
  ifeq (STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS))
    LOCAL_UNINSTALLABLE_MODULE := true
  endif
endif

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES HEADER_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  # Soong module is a static or shared library
  export_includes := $(intermediates)/export_includes
  $(export_includes): PRIVATE_EXPORT_CFLAGS := $(LOCAL_EXPORT_CFLAGS)
  $(export_includes): $(LOCAL_EXPORT_C_INCLUDE_DEPS)
	@echo Export includes file: $< -- $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
  ifdef LOCAL_EXPORT_CFLAGS
	$(hide) echo "$(PRIVATE_EXPORT_CFLAGS)" >$@
  else
	$(hide) touch $@
  endif

  ifdef LOCAL_SOONG_TOC
    $(eval $(call copy-one-file,$(LOCAL_SOONG_TOC),$(LOCAL_BUILT_MODULE).toc))
    $(call add-dependency,$(LOCAL_BUILT_MODULE).toc,$(LOCAL_BUILT_MODULE))
    $(my_all_targets): $(LOCAL_BUILT_MODULE).toc
  endif

  SOONG_ALREADY_CONV := $(SOONG_ALREADY_CONV) $(LOCAL_MODULE)

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
    ifneq ($(name_without_suffix),$(LOCAL_MODULE)
      SPLIT_VENDOR.$(LOCAL_MODULE_CLASS).$(name_without_suffix) := 1
    endif
    name_without_suffix :=
  endif
endif

# Check prebuilt ELF binaries.
ifneq ($(LOCAL_CHECK_ELF_FILES),)
my_prebuilt_src_file := $(LOCAL_PREBUILT_MODULE_FILE)
include $(BUILD_SYSTEM)/check_elf_file.mk
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
endif

ifeq ($(LOCAL_VNDK_DEPEND_ON_CORE_VARIANT),true)
  # Add $(LOCAL_BUILT_MODULE) as a dependency to no_vendor_variant_vndk_check so
  # that the vendor variant will be built and checked against the core variant.
  no_vendor_variant_vndk_check: $(LOCAL_BUILT_MODULE)

  my_core_register_name := $(subst .vendor,,$(my_register_name))
  my_core_variant_files := $(call module-target-built-files,$(my_core_register_name))
  my_core_shared_lib := $(sort $(filter %.so,$(my_core_variant_files)))
  $(LOCAL_BUILT_MODULE): PRIVATE_CORE_VARIANT := $(my_core_shared_lib)

  # The built vendor variant library needs to depend on the built core variant
  # so that we can perform identity check against the core variant.
  $(LOCAL_BUILT_MODULE): $(my_core_shared_lib)
endif

ifeq ($(LOCAL_VNDK_DEPEND_ON_CORE_VARIANT),true)
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE) $(LIBRARY_IDENTITY_CHECK_SCRIPT)
	$(call verify-vndk-libs-identical,\
		$(PRIVATE_CORE_VARIANT),\
		$<,\
		$($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)TOOLS_PREFIX))
	$(copy-file-to-target)
else
$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)
	$(transform-prebuilt-to-target)
endif
ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
	$(hide) chmod +x $@
endif

ifndef LOCAL_IS_HOST_MODULE
  ifdef LOCAL_SOONG_UNSTRIPPED_BINARY
    ifneq ($(LOCAL_VNDK_DEPEND_ON_CORE_VARIANT),true)
      my_symbol_path := $(if $(LOCAL_SOONG_SYMBOL_PATH),$(LOCAL_SOONG_SYMBOL_PATH),$(my_module_path))
      # Store a copy with symbols for symbolic debugging
      my_unstripped_path := $(TARGET_OUT_UNSTRIPPED)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_symbol_path))
      # drop /root as /root is mounted as /
      my_unstripped_path := $(patsubst $(TARGET_OUT_UNSTRIPPED)/root/%,$(TARGET_OUT_UNSTRIPPED)/%, $(my_unstripped_path))
      symbolic_output := $(my_unstripped_path)/$(my_installed_module_stem)
      $(eval $(call copy-one-file,$(LOCAL_SOONG_UNSTRIPPED_BINARY),$(symbolic_output)))
      $(call add-dependency,$(LOCAL_BUILT_MODULE),$(symbolic_output))

      ifeq ($(BREAKPAD_GENERATE_SYMBOLS),true)
        my_breakpad_path := $(TARGET_OUT_BREAKPAD)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_symbol_path))
        breakpad_output := $(my_breakpad_path)/$(my_installed_module_stem).sym
        $(breakpad_output) : $(LOCAL_SOONG_UNSTRIPPED_BINARY) | $(BREAKPAD_DUMP_SYMS) $(PRIVATE_READELF)
	@echo "target breakpad: $(PRIVATE_MODULE) ($@)"
	@mkdir -p $(dir $@)
	$(hide) if $(PRIVATE_READELF) -S $< > /dev/null 2>&1 ; then \
	  $(BREAKPAD_DUMP_SYMS) -c $< > $@ ; \
	else \
	  echo "skipped for non-elf file."; \
	  touch $@; \
	fi
        $(call add-dependency,$(LOCAL_BUILT_MODULE),$(breakpad_output))
      endif
    endif
  endif
endif

ifeq ($(NATIVE_COVERAGE),true)
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
  else
    # Coverage information is needed when static lib is a dependency of another
    # coverage-enabled module.
    ifeq (STATIC_LIBRARIES, $(LOCAL_MODULE_CLASS))
      GCNO_ARCHIVE := $(LOCAL_MODULE).zip
      $(intermediates)/$(GCNO_ARCHIVE) : $(SOONG_ZIP) $(MERGE_ZIPS)
      $(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_OBJECTS :=
      $(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_WHOLE_STATIC_LIBRARIES :=
      $(intermediates)/$(GCNO_ARCHIVE) :
	$(package-coverage-files)
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

# We don't care about installed static libraries, since the libraries have
# already been linked into the module at that point. We do, however, care
# about the NOTICE files for any static libraries that we use.
# (see notice_files.mk)
#
# Filter out some NDK libraries that are not being exported.
my_static_libraries := \
    $(filter-out ndk_libc++_static ndk_libc++abi ndk_libandroid_support ndk_libunwind, \
      $(LOCAL_STATIC_LIBRARIES))
installed_static_library_notice_file_targets := \
    $(foreach lib,$(my_static_libraries) $(LOCAL_WHOLE_STATIC_LIBRARIES), \
      NOTICE-$(if $(LOCAL_IS_HOST_MODULE),HOST$(if $(my_host_cross),_CROSS,),TARGET)-STATIC_LIBRARIES-$(lib))

$(notice_target): | $(installed_static_library_notice_file_targets)
$(LOCAL_INSTALLED_MODULE): | $(notice_target)

endif # !skip_module

skip_module :=
