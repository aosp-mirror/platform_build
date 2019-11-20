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

# Don't install rlib/proc_macro libraries.
ifndef LOCAL_UNINSTALLABLE_MODULE
  ifneq ($(filter RLIB_LIBRARIES PROC_MACRO_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
    LOCAL_UNINSTALLABLE_MODULE := true
  endif
endif


#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
  ifdef LOCAL_SHARED_LIBRARIES
    my_shared_libraries := $(LOCAL_SHARED_LIBRARIES)
    $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
      $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_shared_libraries))
  endif
  ifdef LOCAL_DYLIB_LIBRARIES
    my_dylibs := $(LOCAL_DYLIB_LIBRARIES)
    # Treat these as shared library dependencies for installation purposes.
    $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
      $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_dylibs))
  endif
endif

$(LOCAL_BUILT_MODULE): $(LOCAL_PREBUILT_MODULE_FILE)
	$(transform-prebuilt-to-target)
ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
	$(hide) chmod +x $@
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
    $(call add-dependency,$(LOCAL_BUILT_MODULE),$(symbolic_output))
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
