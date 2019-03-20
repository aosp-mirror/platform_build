###########################################################
## Standard rules for copying files that are prebuilt
##
## Additional inputs from base_rules.make:
## None.
##
###########################################################

include $(BUILD_SYSTEM)/use_lld_setup.mk

ifneq ($(LOCAL_PREBUILT_LIBS),)
$(call pretty-error,dont use LOCAL_PREBUILT_LIBS anymore)
endif
ifneq ($(LOCAL_PREBUILT_EXECUTABLES),)
$(call pretty-error,dont use LOCAL_PREBUILT_EXECUTABLES anymore)
endif
ifneq ($(LOCAL_PREBUILT_JAVA_LIBRARIES),)
$(call pretty-error,dont use LOCAL_PREBUILT_JAVA_LIBRARIES anymore)
endif

my_32_64_bit_suffix := $(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT),64,32)

ifdef LOCAL_PREBUILT_MODULE_FILE
  my_prebuilt_src_file := $(LOCAL_PREBUILT_MODULE_FILE)
else ifdef LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
  my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
  LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) :=
else ifdef LOCAL_SRC_FILES_$(my_32_64_bit_suffix)
  my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES_$(my_32_64_bit_suffix))
  LOCAL_SRC_FILES_$(my_32_64_bit_suffix) :=
else ifdef LOCAL_SRC_FILES
  my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES)
  LOCAL_SRC_FILES :=
else ifdef LOCAL_REPLACE_PREBUILT_APK_INSTALLED
  # This is handled specially below
else
  $(call pretty-error,No source files specified)
endif

LOCAL_CHECKED_MODULE := $(my_prebuilt_src_file)

ifeq (APPS,$(LOCAL_MODULE_CLASS))
include $(BUILD_SYSTEM)/app_prebuilt_internal.mk
else
#
# Non-APPS prebuilt modules handling almost to the end of the file
#

my_strip_module := $(firstword \
  $(LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) \
  $(LOCAL_STRIP_MODULE))

ifeq (SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS))
  ifeq ($(LOCAL_IS_HOST_MODULE)$(my_strip_module),)
    # Strip but not try to add debuglink
    my_strip_module := no_debuglink
  endif
endif

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  prebuilt_module_is_a_library := true
else
  prebuilt_module_is_a_library :=
endif

# Don't install static libraries by default.
ifndef LOCAL_UNINSTALLABLE_MODULE
ifeq (STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS))
  LOCAL_UNINSTALLABLE_MODULE := true
endif
endif

ifeq (JAVA_LIBRARIES,$(LOCAL_IS_HOST_MODULE)$(LOCAL_MODULE_CLASS)$(filter true,$(LOCAL_UNINSTALLABLE_MODULE)))
  prebuilt_module_is_dex_javalib := true
else
  prebuilt_module_is_dex_javalib :=
endif

ifdef LOCAL_COMPRESSED_MODULE
$(error $(LOCAL_MODULE) : LOCAL_COMPRESSED_MODULE can only be defined for module class APPS)
endif  # LOCAL_COMPRESSED_MODULE

my_check_elf_file_shared_lib_files :=

ifneq ($(filter true keep_symbols no_debuglink mini-debug-info,$(my_strip_module)),)
  ifdef LOCAL_IS_HOST_MODULE
    $(call pretty-error,Cannot strip/pack host module)
  endif
  ifeq ($(filter SHARED_LIBRARIES EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
    $(call pretty-error,Can strip/pack only shared libraries or executables)
  endif
  ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
    $(call pretty-error,Cannot strip/pack scripts)
  endif
  # Set the arch-specific variables to set up the strip rules
  LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) := $(my_strip_module)
  include $(BUILD_SYSTEM)/dynamic_binary.mk
  built_module := $(linked_module)

  ifneq ($(LOCAL_SDK_VERSION),)
    # binary.mk filters out NDK_MIGRATED_LIBS from my_shared_libs, thus those NDK libs are not added
    # to DEPENDENCIES_ON_SHARED_LIBRARIES. Assign $(my_ndk_shared_libraries_fullpath) to
    # my_check_elf_file_shared_lib_files so that check_elf_file.py can see those NDK stub libs.
    my_check_elf_file_shared_lib_files := $(my_ndk_shared_libraries_fullpath)
  endif
else  # my_strip_module not true
  include $(BUILD_SYSTEM)/base_rules.mk
  built_module := $(LOCAL_BUILT_MODULE)

ifdef prebuilt_module_is_a_library
export_includes := $(intermediates)/export_includes
export_cflags := $(foreach d,$(LOCAL_EXPORT_C_INCLUDE_DIRS),-I $(d))
$(export_includes): PRIVATE_EXPORT_CFLAGS := $(export_cflags)
$(export_includes): $(LOCAL_EXPORT_C_INCLUDE_DEPS)
	@echo Export includes file: $< -- $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
ifdef export_cflags
	$(hide) echo "$(PRIVATE_EXPORT_CFLAGS)" >$@
else
	$(hide) touch $@
endif
export_cflags :=

include $(BUILD_SYSTEM)/allowed_ndk_types.mk

ifdef LOCAL_SDK_VERSION
my_link_type := native:ndk:$(my_ndk_stl_family):$(my_ndk_stl_link_type)
else ifdef LOCAL_USE_VNDK
    _name := $(patsubst %.vendor,%,$(LOCAL_MODULE))
    ifneq ($(filter $(_name),$(VNDK_CORE_LIBRARIES) $(VNDK_SAMEPROCESS_LIBRARIES) $(LLNDK_LIBRARIES)),)
        ifeq ($(filter $(_name),$(VNDK_PRIVATE_LIBRARIES)),)
            my_link_type := native:vndk
        else
            my_link_type := native:vndk_private
        endif
    else
        my_link_type := native:vendor
    endif
else ifneq ($(filter $(TARGET_RECOVERY_OUT)/%,$(LOCAL_MODULE_PATH)),)
my_link_type := native:recovery
else
my_link_type := native:platform
endif

# TODO: check dependencies of prebuilt files
my_link_deps :=

my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common :=
include $(BUILD_SYSTEM)/link_type.mk
endif  # prebuilt_module_is_a_library

# The real dependency will be added after all Android.mks are loaded and the install paths
# of the shared libraries are determined.
ifdef LOCAL_INSTALLED_MODULE
ifdef LOCAL_IS_HOST_MODULE
    ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
        my_system_shared_libraries :=
    else
        my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
    endif
else
    ifeq ($(LOCAL_SYSTEM_SHARED_LIBRARIES),none)
        my_system_shared_libraries := libc libm libdl
    else
        my_system_shared_libraries := $(LOCAL_SYSTEM_SHARED_LIBRARIES)
        my_system_shared_libraries := $(patsubst libc,libc libdl,$(my_system_shared_libraries))
    endif
endif

my_shared_libraries := \
    $(filter-out $(my_system_shared_libraries),$(LOCAL_SHARED_LIBRARIES)) \
    $(my_system_shared_libraries)

ifdef my_shared_libraries
# Extra shared libraries introduced by LOCAL_CXX_STL.
include $(BUILD_SYSTEM)/cxx_stl_setup.mk
ifdef LOCAL_USE_VNDK
  my_shared_libraries := $(foreach l,$(my_shared_libraries),\
    $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
endif
$(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
  $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_shared_libraries))
endif
endif  # my_shared_libraries

# We need to enclose the above export_includes and my_built_shared_libraries in
# "my_strip_module not true" because otherwise the rules are defined in dynamic_binary.mk.
endif  # my_strip_module not true

# Check prebuilt ELF binaries.
include $(BUILD_SYSTEM)/check_elf_file.mk

ifeq ($(NATIVE_COVERAGE),true)
ifneq (,$(strip $(LOCAL_PREBUILT_COVERAGE_ARCHIVE)))
  $(eval $(call copy-one-file,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(intermediates)/$(LOCAL_MODULE).gcnodir))
  ifneq ($(LOCAL_UNINSTALLABLE_MODULE),true)
    ifdef LOCAL_IS_HOST_MODULE
      my_coverage_path := $($(my_prefix)OUT_COVERAGE)/$(patsubst $($(my_prefix)OUT)/%,%,$(my_module_path))
    else
      my_coverage_path := $(TARGET_OUT_COVERAGE)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
    endif
    my_coverage_path := $(my_coverage_path)/$(patsubst %.so,%,$(my_installed_module_stem)).gcnodir
    $(eval $(call copy-one-file,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(my_coverage_path)))
    $(LOCAL_BUILT_MODULE): $(my_coverage_path)
  endif
else
# Coverage information is needed when static lib is a dependency of another
# coverage-enabled module.
ifeq (STATIC_LIBRARIES, $(LOCAL_MODULE_CLASS))
GCNO_ARCHIVE := $(LOCAL_MODULE).gcnodir
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_OBJECTS :=
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_ALL_WHOLE_STATIC_LIBRARIES :=
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_PREFIX := $(my_prefix)
$(intermediates)/$(GCNO_ARCHIVE) : PRIVATE_2ND_ARCH_VAR_PREFIX := $(LOCAL_2ND_ARCH_VAR_PREFIX)
$(intermediates)/$(GCNO_ARCHIVE) :
	$(transform-o-to-static-lib)
endif
endif
endif

ifeq ($(prebuilt_module_is_dex_javalib),true)
my_dex_jar := $(my_prebuilt_src_file)
# This is a target shared library, i.e. a jar with classes.dex.

ifneq ($(filter $(LOCAL_MODULE),$(PRODUCT_BOOT_JARS)),)
  $(call pretty-error,Modules in PRODUCT_BOOT_JARS must be defined in Android.bp files)
endif

#######################################
# defines built_odex along with rule to install odex
include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk
#######################################
ifdef LOCAL_DEX_PREOPT

$(built_module): PRIVATE_STRIP_SCRIPT := $(intermediates)/strip.sh
$(built_module): $(intermediates)/strip.sh
$(built_module): | $(DEXPREOPT_STRIP_DEPS)
$(built_module): .KATI_DEPFILE := $(built_module).d
$(built_module): $(my_prebuilt_src_file)
	$(PRIVATE_STRIP_SCRIPT) $< $@

else # ! LOCAL_DEX_PREOPT
$(built_module) : $(my_prebuilt_src_file)
	$(call copy-file-to-target)
endif # LOCAL_DEX_PREOPT

else  # ! prebuilt_module_is_dex_javalib
ifneq ($(filter init%rc,$(notdir $(LOCAL_INSTALLED_MODULE)))$(filter %/etc/init,$(dir $(LOCAL_INSTALLED_MODULE))),)
  $(eval $(call copy-init-script-file-checked,$(my_prebuilt_src_file),$(built_module)))
else ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
$(built_module) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target-strip-comments)
else
$(built_module) : $(my_prebuilt_src_file)
	$(transform-prebuilt-to-target)
endif
ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
	$(hide) chmod +x $@
endif
endif # ! prebuilt_module_is_dex_javalib

ifeq ($(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
my_src_jar := $(my_prebuilt_src_file)

ifdef LOCAL_IS_HOST_MODULE
# for host java libraries deps should be in the common dir, so we make a copy in
# the common dir.
common_classes_jar := $(intermediates.COMMON)/classes.jar
common_header_jar := $(intermediates.COMMON)/classes-header.jar

$(common_classes_jar): PRIVATE_MODULE := $(LOCAL_MODULE)
$(common_classes_jar): PRIVATE_PREFIX := $(my_prefix)

$(common_classes_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

ifneq ($(TURBINE_ENABLED),false)
$(common_header_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)
endif

else # !LOCAL_IS_HOST_MODULE
# for target java libraries, the LOCAL_BUILT_MODULE is in a product-specific dir,
# while the deps should be in the common dir, so we make a copy in the common dir.
common_classes_jar := $(intermediates.COMMON)/classes.jar
common_header_jar := $(intermediates.COMMON)/classes-header.jar
common_classes_pre_proguard_jar := $(intermediates.COMMON)/classes-pre-proguard.jar
common_javalib_jar := $(intermediates.COMMON)/javalib.jar

$(common_classes_jar) $(common_classes_pre_proguard_jar) $(common_javalib_jar): PRIVATE_MODULE := $(LOCAL_MODULE)
$(common_classes_jar) $(common_classes_pre_proguard_jar) $(common_javalib_jar): PRIVATE_PREFIX := $(my_prefix)

ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
else ifneq (,$(call has-system-sdk-version,$(LOCAL_SDK_VERSION)))
my_link_type := java:system
else ifeq ($(LOCAL_SDK_VERSION),core_current)
my_link_type := java:core
else ifneq ($(LOCAL_SDK_VERSION),)
my_link_type := java:sdk
else
my_link_type := java:platform
endif

# TODO: check dependencies of prebuilt files
my_link_deps :=

my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
my_common := COMMON
include $(BUILD_SYSTEM)/link_type.mk

ifeq ($(prebuilt_module_is_dex_javalib),true)
# For prebuilt shared Java library we don't have classes.jar.
$(common_javalib_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

else  # ! prebuilt_module_is_dex_javalib

my_src_aar := $(filter %.aar, $(my_prebuilt_src_file))
ifneq ($(my_src_aar),)
# This is .aar file, archive of classes.jar and Android resources.

# run Jetifier if needed
LOCAL_JETIFIER_INPUT_FILE := $(my_src_aar)
include $(BUILD_SYSTEM)/jetifier.mk
my_src_aar := $(LOCAL_JETIFIER_OUTPUT_FILE)

my_src_jar := $(intermediates.COMMON)/aar/classes.jar
my_src_proguard_options := $(intermediates.COMMON)/aar/proguard.txt
my_src_android_manifest := $(intermediates.COMMON)/aar/AndroidManifest.xml

$(my_src_jar) : .KATI_IMPLICIT_OUTPUTS := $(my_src_proguard_options)
$(my_src_jar) : .KATI_IMPLICIT_OUTPUTS += $(my_src_android_manifest)
$(my_src_jar) : $(my_src_aar)
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@) $(dir $@)/res
	$(hide) unzip -qo -d $(dir $@) $<
	# Make sure the extracted classes.jar has a new timestamp.
	$(hide) touch $@
	# Make sure the proguard and AndroidManifest.xml files exist
	# and have a new timestamp.
	$(hide) touch $(dir $@)/proguard.txt
	$(hide) touch $(dir $@)/AndroidManifest.xml

my_prebuilt_android_manifest := $(intermediates.COMMON)/manifest/AndroidManifest.xml
$(eval $(call copy-one-file,$(my_src_android_manifest),$(my_prebuilt_android_manifest)))
$(call add-dependency,$(LOCAL_BUILT_MODULE),$(my_prebuilt_android_manifest))

else

# run Jetifier if needed
LOCAL_JETIFIER_INPUT_FILE := $(my_src_jar)
include $(BUILD_SYSTEM)/jetifier.mk
my_src_jar := $(LOCAL_JETIFIER_OUTPUT_FILE)

endif

$(common_classes_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

ifneq ($(TURBINE_ENABLED),false)
$(common_header_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)
endif

$(common_classes_pre_proguard_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

$(common_javalib_jar) : $(common_classes_jar)
	$(transform-prebuilt-to-target)

include $(BUILD_SYSTEM)/force_aapt2.mk

ifdef LOCAL_AAPT2_ONLY
LOCAL_USE_AAPT2 := true
endif

ifeq ($(LOCAL_USE_AAPT2),true)
ifneq ($(my_src_aar),)

$(intermediates.COMMON)/export_proguard_flags : $(my_src_proguard_options)
	$(transform-prebuilt-to-target)

LOCAL_SDK_RES_VERSION:=$(strip $(LOCAL_SDK_RES_VERSION))
ifeq ($(LOCAL_SDK_RES_VERSION),)
  LOCAL_SDK_RES_VERSION:=$(LOCAL_SDK_VERSION)
endif

framework_res_package_export :=
# Please refer to package.mk
ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
ifneq ($(filter-out current system_current test_current,$(LOCAL_SDK_RES_VERSION))$(if $(TARGET_BUILD_APPS),$(filter current system_current test_current,$(LOCAL_SDK_RES_VERSION))),)
framework_res_package_export := \
    $(call resolve-prebuilt-sdk-jar-path,$(LOCAL_SDK_RES_VERSION))
else
framework_res_package_export := \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
endif
endif

my_res_package := $(intermediates.COMMON)/package-res.apk

# We needed only very few PRIVATE variables and aapt2.mk input variables. Reset the unnecessary ones.
$(my_res_package): PRIVATE_AAPT2_CFLAGS :=
$(my_res_package): PRIVATE_AAPT_FLAGS := --static-lib --no-static-lib-packages --auto-add-overlay
$(my_res_package): PRIVATE_ANDROID_MANIFEST := $(my_src_android_manifest)
$(my_res_package): PRIVATE_AAPT_INCLUDES := $(framework_res_package_export)
$(my_res_package): PRIVATE_SOURCE_INTERMEDIATES_DIR :=
$(my_res_package): PRIVATE_PROGUARD_OPTIONS_FILE :=
$(my_res_package): PRIVATE_DEFAULT_APP_TARGET_SDK :=
$(my_res_package): PRIVATE_DEFAULT_APP_TARGET_SDK :=
$(my_res_package): PRIVATE_PRODUCT_AAPT_CONFIG :=
$(my_res_package): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
$(my_res_package): PRIVATE_TARGET_AAPT_CHARACTERISTICS :=
$(my_res_package) : $(framework_res_package_export)
$(my_res_package) : $(my_src_android_manifest)

full_android_manifest :=
my_res_resources :=
my_overlay_resources :=
my_compiled_res_base_dir := $(intermediates.COMMON)/flat-res
R_file_stamp :=
proguard_options_file :=
my_generated_res_dirs := $(intermediates.COMMON)/aar/res
my_generated_res_dirs_deps := $(my_src_jar)
include $(BUILD_SYSTEM)/aapt2.mk

# Make sure my_res_package is created when you run mm/mmm.
$(built_module) : $(my_res_package)
endif  # $(my_src_aar)
endif  # LOCAL_USE_AAPT2
# make sure the classes.jar and javalib.jar are built before $(LOCAL_BUILT_MODULE)
$(built_module) : $(common_javalib_jar)

my_exported_sdk_libs_file := $(intermediates.COMMON)/exported-sdk-libs
$(my_exported_sdk_libs_file): PRIVATE_EXPORTED_SDK_LIBS := $(LOCAL_EXPORT_SDK_LIBRARIES)
$(my_exported_sdk_libs_file):
	@echo "Export SDK libs $@"
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(if $(PRIVATE_EXPORTED_SDK_LIBS),\
		$(hide) echo $(PRIVATE_EXPORTED_SDK_LIBS) | tr ' ' '\n' > $@,\
		$(hide) touch $@)

endif # ! prebuilt_module_is_dex_javalib
endif # LOCAL_IS_HOST_MODULE is not set

endif # JAVA_LIBRARIES

endif # APPS

$(built_module) : $(LOCAL_ADDITIONAL_DEPENDENCIES)

my_prebuilt_src_file :=
my_preopt_for_extracted_apk :=
