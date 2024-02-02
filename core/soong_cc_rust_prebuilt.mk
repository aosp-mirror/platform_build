# Native prebuilt coming from Soong.
# Extra inputs:
# LOCAL_SOONG_LINK_TYPE
# LOCAL_SOONG_TOC
# LOCAL_SOONG_UNSTRIPPED_BINARY
# LOCAL_SOONG_VNDK_VERSION : means the version of VNDK where this module belongs

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  $(call pretty-error,soong_cc_rust_prebuilt.mk may only be used from Soong)
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

# Don't install modules of current VNDK when it is told so
ifeq ($(TARGET_SKIP_CURRENT_VNDK),true)
  ifeq ($(LOCAL_SOONG_VNDK_VERSION),$(PLATFORM_VNDK_VERSION))
    LOCAL_UNINSTALLABLE_MODULE := true
  endif
endif


# Use the Soong output as the checkbuild target instead of LOCAL_BUILT_MODULE
# to avoid checkbuilds making an extra copy of every module.
LOCAL_CHECKED_MODULE := $(LOCAL_PREBUILT_MODULE_FILE)

my_check_same_vndk_variants :=
same_vndk_variants_stamp :=
ifeq ($(LOCAL_CHECK_SAME_VNDK_VARIANTS),true)
  ifeq ($(filter hwaddress address, $(SANITIZE_TARGET)),)
    ifneq ($(CLANG_COVERAGE),true)
      # Do not compare VNDK variant for special cases e.g. coverage builds.
      ifneq ($(SKIP_VNDK_VARIANTS_CHECK),true)
        my_check_same_vndk_variants := true
        same_vndk_variants_stamp := $(call local-intermediates-dir,,$(LOCAL_2ND_ARCH_VAR_PREFIX))/same_vndk_variants.timestamp
      endif
    endif
  endif
endif

ifeq ($(my_check_same_vndk_variants),true)
  # Add the timestamp to the CHECKED list so that `checkbuild` can run it.
  # Note that because `checkbuild` doesn't check LOCAL_BUILT_MODULE for soong-built modules adding
  # the timestamp to LOCAL_BUILT_MODULE isn't enough. It is skipped when the vendor variant
  # isn't used at all and it may break in the downstream trees.
  LOCAL_ADDITIONAL_CHECKED_MODULE := $(same_vndk_variants_stamp)
endif

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES RLIB_LIBRARIES DYLIB_LIBRARIES HEADER_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  # Soong module is a static or shared library
  EXPORTS_LIST += $(intermediates)
  EXPORTS.$(intermediates).FLAGS := $(LOCAL_EXPORT_CFLAGS)
  EXPORTS.$(intermediates).DEPS := $(LOCAL_EXPORT_C_INCLUDE_DEPS)

  ifdef LOCAL_SOONG_TOC
    $(eval $(call copy-one-file,$(LOCAL_SOONG_TOC),$(LOCAL_BUILT_MODULE).toc))
    $(call add-dependency,$(LOCAL_BUILT_MODULE).toc,$(LOCAL_BUILT_MODULE))
    $(my_all_targets): $(LOCAL_BUILT_MODULE).toc
  endif

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

# Check prebuilt ELF binaries.
ifdef LOCAL_INSTALLED_MODULE
  ifneq ($(LOCAL_CHECK_ELF_FILES),)
    my_prebuilt_src_file := $(LOCAL_PREBUILT_MODULE_FILE)
    my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
    include $(BUILD_SYSTEM)/check_elf_file.mk
  endif
endif

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
  ifdef LOCAL_SHARED_LIBRARIES
    my_shared_libraries := $(LOCAL_SHARED_LIBRARIES)
    ifdef LOCAL_USE_VNDK
      ifdef LOCAL_USE_VNDK_PRODUCT
        my_shared_libraries := $(foreach l,$(my_shared_libraries),\
          $(if $(SPLIT_PRODUCT.SHARED_LIBRARIES.$(l)),$(l).product,$(l)))
      else
        my_shared_libraries := $(foreach l,$(my_shared_libraries),\
          $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
      endif
    endif
    $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
      $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_shared_libraries))
  endif
  ifdef LOCAL_DYLIB_LIBRARIES
    my_dylibs := $(LOCAL_DYLIB_LIBRARIES)
    # Treat these as shared library dependencies for installation purposes.
    ifdef LOCAL_USE_VNDK
      ifdef LOCAL_USE_VNDK_PRODUCT
        my_dylibs := $(foreach l,$(my_dylibs),\
          $(if $(SPLIT_PRODUCT.SHARED_LIBRARIES.$(l)),$(l).product,$(l)))
      else
        my_dylibs := $(foreach l,$(my_dylibs),\
          $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
      endif
    endif
    $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
      $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_dylibs))
  endif
endif

ifeq ($(my_check_same_vndk_variants),true)
  my_core_register_name := $(subst .vendor,,$(subst .product,,$(my_register_name)))
  my_core_variant_files := $(call module-target-built-files,$(my_core_register_name))
  my_core_shared_lib := $(sort $(filter %.so,$(my_core_variant_files)))

  $(same_vndk_variants_stamp): PRIVATE_CORE_VARIANT := $(my_core_shared_lib)
  $(same_vndk_variants_stamp): PRIVATE_VENDOR_VARIANT := $(LOCAL_PREBUILT_MODULE_FILE)
  $(same_vndk_variants_stamp): PRIVATE_TOOLS_PREFIX := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)TOOLS_PREFIX)

  $(same_vndk_variants_stamp): $(my_core_shared_lib) $(LOCAL_PREBUILT_MODULE_FILE)
	$(call verify-vndk-libs-identical,\
	    $(PRIVATE_CORE_VARIANT),\
	    $(PRIVATE_VENDOR_VARIANT),\
	    $(PRIVATE_TOOLS_PREFIX))
	touch $@

  $(LOCAL_BUILT_MODULE): $(same_vndk_variants_stamp)
endif

# Use copy-or-link-prebuilt-to-target for host executables and shared libraries,
# to preserve symlinks to the source trees. They can then run directly from the
# prebuilt directories where the linker can load their dependencies using
# relative RUNPATHs.
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
    ifneq ($(LOCAL_UNINSTALLABLE_MODULE),true)
      my_symbol_path := $(if $(LOCAL_SOONG_SYMBOL_PATH),$(LOCAL_SOONG_SYMBOL_PATH),$(my_module_path))
      # Store a copy with symbols for symbolic debugging
      my_unstripped_path := $(TARGET_OUT_UNSTRIPPED)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_symbol_path))
      # drop /root as /root is mounted as /
      my_unstripped_path := $(patsubst $(TARGET_OUT_UNSTRIPPED)/root/%,$(TARGET_OUT_UNSTRIPPED)/%, $(my_unstripped_path))
      symbolic_output := $(my_unstripped_path)/$(my_installed_module_stem)
      $(eval $(call copy-unstripped-elf-file-with-mapping,$(LOCAL_SOONG_UNSTRIPPED_BINARY),$(symbolic_output)))
      $(LOCAL_BUILT_MODULE): | $(symbolic_output)

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

# Reinstall shared library dependencies of fuzz targets to /data/fuzz/ (for
# target) or /data/ (for host).
ifdef LOCAL_IS_FUZZ_TARGET
$(LOCAL_INSTALLED_MODULE): $(LOCAL_FUZZ_INSTALLED_SHARED_DEPS)
endif
