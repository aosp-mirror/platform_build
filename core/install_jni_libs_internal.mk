# Install jni libraries for one arch.
# Input variables:
#   my_2nd_arch_prefix: indicate if this is for TARGET_2ND_ARCH.
#   my_embed_jni: indicate if we want to embed the jni libs in the apk.
#   my_prebuilt_jni_libs
#   my_installed_module_stem (from configure_module_stem.mk)
#   partition_tag (from base_rules.mk)
#   partition_lib_pairs
#   my_prebuilt_src_file (from prebuilt_internal.mk)
#
# Output variables:
#   my_jni_shared_libraries, my_jni_shared_libraries_abi, if we are going to embed the libraries into the apk;
#   my_embedded_prebuilt_jni_libs, prebuilt jni libs embedded in prebuilt apk.
#

my_sdk_variant = $(1)
ifneq (,$(and $(my_embed_jni),$(LOCAL_SDK_VERSION)))
  # Soong produces $(lib).so in $(lib).sdk_intermediates so that the library
  # has the correct name for embedding in an APK.  Append .sdk to the name
  # of the intermediates directory, but not the .so name.
  my_sdk_variant = $(call use_soong_sdk_libraries,$(1))
endif

my_jni_shared_libraries := $(strip \
  $(foreach lib,$(LOCAL_JNI_SHARED_LIBRARIES), \
    $(call intermediates-dir-for,SHARED_LIBRARIES,$(call my_sdk_variant,$(lib)),,,$(my_2nd_arch_prefix))/$(lib).so))


# App-specific lib path.
my_app_lib_path := $(dir $(LOCAL_INSTALLED_MODULE))lib/$(TARGET_$(my_2nd_arch_prefix)ARCH)
my_embedded_prebuilt_jni_libs :=

ifdef my_embed_jni
  # App explicitly requires the prebuilt NDK stl shared libraies.
  # The NDK stl shared libraries should never go to the system image.
  ifeq ($(LOCAL_NDK_STL_VARIANT),c++_shared)
    ifndef LOCAL_SDK_VERSION
      $(error LOCAL_SDK_VERSION must be defined with LOCAL_NDK_STL_VARIANT, \
          LOCAL_PACKAGE_NAME=$(LOCAL_PACKAGE_NAME))
    endif
    my_libcxx_arch := $($(LOCAL_2ND_ARCH_VAR_PREFIX)PREBUILT_LIBCXX_ARCH_DIR)
    my_jni_shared_libraries += \
        $(LLVM_PREBUILTS_BASE)/$(BUILD_OS)-x86/$(LLVM_PREBUILTS_VERSION)/android_libc++/ndk/$(my_libcxx_arch)/lib/libc++_shared.so
  endif

  # Set the abi directory used by the local JNI shared libraries.
  # (Doesn't change how the local shared libraries are compiled, just
  # sets where they are stored in the apk.)
  ifeq ($(LOCAL_JNI_SHARED_LIBRARIES_ABI),)
    my_jni_shared_libraries_abi := $(TARGET_$(my_2nd_arch_prefix)CPU_ABI)
  else
    my_jni_shared_libraries_abi := $(LOCAL_JNI_SHARED_LIBRARIES_ABI)
  endif

else ifneq ($(my_jni_shared_libraries),) # not my_embed_jni

  # The jni libaries will be installed to the system.img.
  my_jni_filenames := $(notdir $(my_jni_shared_libraries))
  # Make sure the JNI libraries get installed
  my_shared_library_path := $(call get_non_asan_path,\
      $($(my_2nd_arch_prefix)TARGET_OUT$(partition_tag)_SHARED_LIBRARIES))

  bit_suffix := $(if $(filter %64,$(TARGET_$(my_2nd_arch_prefix)ARCH)),:64,:32)
  ALL_MODULES.$(my_register_name).REQUIRED_FROM_TARGET += $(addsuffix $(bit_suffix),$(LOCAL_JNI_SHARED_LIBRARIES))

  # Create symlink in the app specific lib path
  # Skip creating this symlink when running the second part of a target sanitization build.
  ifeq ($(filter address,$(SANITIZE_TARGET)),)
    my_symlink_target_dir := $(patsubst $(PRODUCT_OUT)%,%,\
      $(my_shared_library_path))

    ifdef partition_lib_pairs
      # Support cross-partition jni lib dependency for bp modules
      # API domain check is done in Soong
      $(foreach pl_pair,$(partition_lib_pairs),\
        $(eval lib_name := $(call word-colon, 1, $(pl_pair)))\
        $(eval lib_partition := $(call word-colon, 2, $(pl_pair)))\
        $(eval shared_library_path := $(call get_non_asan_path,\
        $($(my_2nd_arch_prefix)TARGET_OUT$(lib_partition)_SHARED_LIBRARIES)))\
        $(call symlink-file,\
          $(shared_library_path)/$(lib_name).so,\
          $(my_symlink_target_dir)/$(lib_name).so,\
          $(my_app_lib_path)/$(lib_name).so)\
        $(eval $$(LOCAL_INSTALLED_MODULE) : $$(my_app_lib_path)/$$(lib_name).so)\
        $(eval ALL_MODULES.$(my_register_name).INSTALLED += $$(my_app_lib_path)/$$(lib_name).so))

    else
      # Cross-partition jni lib dependency currently not supported for mk modules
      $(foreach lib,$(my_jni_filenames),\
        $(call symlink-file, \
          $(my_shared_library_path)/$(lib), \
          $(my_symlink_target_dir)/$(lib), \
          $(my_app_lib_path)/$(lib)) \
        $(eval $$(LOCAL_INSTALLED_MODULE) : $$(my_app_lib_path)/$$(lib)) \
        $(eval ALL_MODULES.$(my_register_name).INSTALLED += $$(my_app_lib_path)/$$(lib)))
    endif # partition_lib_pairs
  endif

  # Clear jni_shared_libraries to not embed it into the apk.
  my_jni_shared_libraries :=
endif  # my_embed_jni

ifdef my_prebuilt_jni_libs
  # Files like @lib/<abi>/libfoo.so (path inside the apk) are JNI libs embedded prebuilt apk;
  # Files like path/to/libfoo.so (path relative to LOCAL_PATH) are prebuilts in the source tree.
  my_embedded_prebuilt_jni_libs := $(patsubst @%,%, \
      $(filter @%, $(my_prebuilt_jni_libs)))

  # prebuilt JNI exsiting as separate source files.
  my_prebuilt_jni_libs := $(addprefix $(LOCAL_PATH)/, \
      $(filter-out @%, $(my_prebuilt_jni_libs)))
  ifdef my_prebuilt_jni_libs
    ifdef my_embed_jni
      # Embed my_prebuilt_jni_libs to the apk
      my_jni_shared_libraries += $(my_prebuilt_jni_libs)
    else # not my_embed_jni
      # Install my_prebuilt_jni_libs as separate files.
      $(foreach lib, $(my_prebuilt_jni_libs), \
          $(eval $(call copy-one-file, $(lib), $(my_app_lib_path)/$(notdir $(lib)))))

      my_installed_library := $(addprefix $(my_app_lib_path)/, $(notdir $(my_prebuilt_jni_libs)))
      $(LOCAL_INSTALLED_MODULE) : $(my_installed_library)

      ALL_MODULES.$(my_register_name).INSTALLED += $(my_installed_library)
    endif  # my_embed_jni
  endif  # inner my_prebuilt_jni_libs
endif  # outer my_prebuilt_jni_libs

# Verify that all included libraries are built against the NDK
include $(BUILD_SYSTEM)/allowed_ndk_types.mk

ifneq ($(strip $(LOCAL_JNI_SHARED_LIBRARIES)),)
  ifneq ($(LOCAL_SDK_VERSION),)
    my_link_type := app:sdk
    my_warn_types := native:platform $(my_warn_ndk_types)
    my_allowed_types := $(my_allowed_ndk_types)
    ifneq (,$(filter true,$(LOCAL_VENDOR_MODULE) $(LOCAL_ODM_MODULE) $(LOCAL_PROPRIETARY_MODULE)))
      my_allowed_types += native:vendor native:vndk native:platform_vndk
    else ifeq ($(LOCAL_PRODUCT_MODULE),true)
      my_allowed_types += native:product native:vndk native:platform_vndk
    endif
  else
    my_link_type := app:platform
    my_warn_types := $(my_warn_ndk_types)
    my_allowed_types := $(my_allowed_ndk_types) native:platform native:product native:vendor native:vndk native:vndk_private native:platform_vndk
  endif

  ifeq ($(SOONG_ANDROID_MK),$(LOCAL_MODULE_MAKEFILE))
    # SOONG_SDK_VARIANT_MODULES isn't complete yet while parsing Soong modules, and Soong has
    # already ensured that apps link against the correct SDK variants, don't check them.
  else
    ifneq (,$(LOCAL_SDK_VERSION))
      my_link_deps := $(addprefix SHARED_LIBRARIES:,$(call use_soong_sdk_libraries,$(LOCAL_JNI_SHARED_LIBRARIES)))
    else
      my_link_deps := $(addprefix SHARED_LIBRARIES:,$(LOCAL_JNI_SHARED_LIBRARIES))
    endif
  endif

  my_common :=
  include $(BUILD_SYSTEM)/link_type.mk
endif
