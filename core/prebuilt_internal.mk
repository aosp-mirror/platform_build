###########################################################
## Standard rules for copying files that are prebuilt
##
## Additional inputs from base_rules.make:
## None.
##
###########################################################

ifneq ($(LOCAL_PREBUILT_LIBS),)
$(error dont use LOCAL_PREBUILT_LIBS anymore LOCAL_PATH=$(LOCAL_PATH))
endif
ifneq ($(LOCAL_PREBUILT_EXECUTABLES),)
$(error dont use LOCAL_PREBUILT_EXECUTABLES anymore LOCAL_PATH=$(LOCAL_PATH))
endif
ifneq ($(LOCAL_PREBUILT_JAVA_LIBRARIES),)
$(error dont use LOCAL_PREBUILT_JAVA_LIBRARIES anymore LOCAL_PATH=$(LOCAL_PATH))
endif

my_32_64_bit_suffix := $(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT),64,32)

ifdef LOCAL_PREBUILT_MODULE_FILE
  my_prebuilt_src_file := $(LOCAL_PREBUILT_MODULE_FILE)
else
  ifdef LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
    my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
    LOCAL_SRC_FILES_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) :=
  else
    ifdef LOCAL_SRC_FILES_$(my_32_64_bit_suffix)
      my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES_$(my_32_64_bit_suffix))
      LOCAL_SRC_FILES_$(my_32_64_bit_suffix) :=
    else
      my_prebuilt_src_file := $(LOCAL_PATH)/$(LOCAL_SRC_FILES)
      LOCAL_SRC_FILES :=
    endif
  endif
endif

LOCAL_CHECKED_MODULE := $(my_prebuilt_src_file)

my_strip_module := $(firstword \
  $(LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) \
  $(LOCAL_STRIP_MODULE))
my_pack_module_relocations := $(firstword \
  $(LOCAL_PACK_MODULE_RELOCATIONS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) \
  $(LOCAL_PACK_MODULE_RELOCATIONS))

ifeq (SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS))
  # LOCAL_COPY_TO_INTERMEDIATE_LIBRARIES indicates that this prebuilt should be
  # installed to the common directory of libraries. This is needed for the NDK
  # shared libraries built by soong, as we build many different versions of each
  # library (one for each API level). Since they all have the same basename,
  # they'd clobber each other (as well as any platform libraries by the same
  # name).
  ifneq ($(LOCAL_COPY_TO_INTERMEDIATE_LIBRARIES),false)
    # Put the built targets of all shared libraries in a common directory
    # to simplify the link line.
    OVERRIDE_BUILT_MODULE_PATH :=  \
        $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_INTERMEDIATE_LIBRARIES)
  endif
  ifeq ($(LOCAL_IS_HOST_MODULE)$(my_strip_module),)
    # Strip but not try to add debuglink
    my_strip_module := no_debuglink
  endif

  ifeq ($(LOCAL_IS_HOST_MODULE)$(my_pack_module_relocations),)
    # Do not pack relocations by default
    my_pack_module_relocations := false
  endif

  ifeq ($(DISABLE_RELOCATION_PACKER),true)
    my_pack_module_relocations := false
  endif
endif

ifneq ($(filter STATIC_LIBRARIES SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  prebuilt_module_is_a_library := true
else
  prebuilt_module_is_a_library :=
endif

ifeq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  ifeq ($(prebuilt_module_is_a_library),true)
    SOONG_ALREADY_CONV := $(SOONG_ALREADY_CONV) $(LOCAL_MODULE)
  endif

  ifdef LOCAL_USE_VNDK
    name_without_suffix := $(patsubst %.vendor,%,$(LOCAL_MODULE))
    ifneq ($(name_without_suffix),$(LOCAL_MODULE)
      SPLIT_VENDOR.$(LOCAL_MODULE_CLASS).$(name_without_suffix) := 1
    endif
    name_without_suffix :=
  endif
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
ifneq (true,$(LOCAL_COMPRESSED_MODULE))
$(call pretty-error, Unknown value for LOCAL_COMPRESSED_MODULE $(LOCAL_COMPRESSED_MODULE))
endif
endif

ifeq ($(LOCAL_MODULE_CLASS),APPS)
ifdef LOCAL_COMPRESSED_MODULE
LOCAL_BUILT_MODULE_STEM := package.apk.gz
else
LOCAL_BUILT_MODULE_STEM := package.apk
endif  # LOCAL_COMPRESSED_MODULE

ifndef LOCAL_INSTALLED_MODULE_STEM
ifdef LOCAL_COMPRESSED_MODULE
PACKAGES.$(LOCAL_MODULE).COMPRESSED := gz
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk.gz
else
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE).apk
endif  # LOCAL_COMPRESSED_MODULE
endif  # LOCAL_INSTALLED_MODULE_STEM

else  # $(LOCAL_MODULE_CLASS) != APPS)
ifdef LOCAL_COMPRESSED_MODULE
$(error $(LOCAL_MODULE) : LOCAL_COMPRESSED_MODULE can only be defined for module class APPS)
endif  # LOCAL_COMPRESSED_MODULE
endif

ifneq ($(filter true keep_symbols no_debuglink mini-debug-info,$(my_strip_module) $(my_pack_module_relocations)),)
  ifdef LOCAL_IS_HOST_MODULE
    $(error Cannot strip/pack host module LOCAL_PATH=$(LOCAL_PATH))
  endif
  ifeq ($(filter SHARED_LIBRARIES EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
    $(error Can strip/pack only shared libraries or executables LOCAL_PATH=$(LOCAL_PATH))
  endif
  ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
    $(error Cannot strip/pack scripts LOCAL_PATH=$(LOCAL_PATH))
  endif
  # Set the arch-specific variables to set up the strip/pack rules.
  LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) := $(my_strip_module)
  LOCAL_PACK_MODULE_RELOCATIONS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH) := $(my_pack_module_relocations)
  include $(BUILD_SYSTEM)/dynamic_binary.mk
  built_module := $(linked_module)

else  # my_strip_module and my_pack_module_relocations not true
  include $(BUILD_SYSTEM)/base_rules.mk
  built_module := $(LOCAL_BUILT_MODULE)

ifdef prebuilt_module_is_a_library
export_includes := $(intermediates)/export_includes
export_cflags := $(foreach d,$(LOCAL_EXPORT_C_INCLUDE_DIRS),-I $(d))
# Soong exports cflags instead of include dirs, so that -isystem can be included.
ifeq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
export_cflags += $(LOCAL_EXPORT_CFLAGS)
else ifdef LOCAL_EXPORT_CFLAGS
$(call pretty-error,LOCAL_EXPORT_CFLAGS can only be used by Soong, use LOCAL_EXPORT_C_INCLUDE_DIRS instead)
endif
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

ifdef LOCAL_SDK_VERSION
my_link_type := native:ndk
else ifdef LOCAL_USE_VNDK
my_link_type := native:vendor
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
ifdef LOCAL_SHARED_LIBRARIES
my_shared_libraries := $(LOCAL_SHARED_LIBRARIES)
# Extra shared libraries introduced by LOCAL_CXX_STL.
include $(BUILD_SYSTEM)/cxx_stl_setup.mk
ifdef LOCAL_USE_VNDK
  ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
    my_shared_libraries := $(foreach l,$(my_shared_libraries),\
      $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
  endif
endif
$(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)DEPENDENCIES_ON_SHARED_LIBRARIES += \
  $(my_register_name):$(LOCAL_INSTALLED_MODULE):$(subst $(space),$(comma),$(my_shared_libraries))

# We also need the LOCAL_BUILT_MODULE dependency,
# since we use -rpath-link which points to the built module's path.
my_built_shared_libraries := \
    $(addprefix $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_INTERMEDIATE_LIBRARIES)/, \
    $(addsuffix $($(my_prefix)SHLIB_SUFFIX), \
        $(my_shared_libraries)))
$(LOCAL_BUILT_MODULE) : $(my_built_shared_libraries)
endif
endif

# We need to enclose the above export_includes and my_built_shared_libraries in
# "my_strip_module not true" because otherwise the rules are defined in dynamic_binary.mk.
endif  # my_strip_module not true

ifeq ($(NATIVE_COVERAGE),true)
ifneq (,$(strip $(LOCAL_PREBUILT_COVERAGE_ARCHIVE)))
  $(eval $(call copy-one-file,$(LOCAL_PREBUILT_COVERAGE_ARCHIVE),$(intermediates)/$(LOCAL_MODULE).gcnodir))
  ifneq ($(LOCAL_UNINSTALLABLE_MODULE),true)
    ifdef LOCAL_IS_HOST_MODULE
      my_coverage_path := $($(my_prefix)OUT_COVERAGE)/$(patsubst $($(my_prefix)OUT)/%,%,$(my_module_path))
    else
      my_coverage_path := $(TARGET_OUT_COVERAGE)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
    endif
    my_coverage_path := $(my_coverage_path)/$(basename $(my_installed_module_stem)).gcnodir
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

ifeq ($(LOCAL_MODULE_CLASS),APPS)
PACKAGES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_PACKAGES))

my_extract_apk := $(strip $(LOCAL_EXTRACT_APK))

# Select dpi-specific source
ifdef LOCAL_DPI_VARIANTS
my_dpi := $(firstword $(filter $(LOCAL_DPI_VARIANTS),$(PRODUCT_AAPT_PREF_CONFIG) $(PRODUCT_AAPT_PREBUILT_DPI)))
ifdef my_dpi
ifdef LOCAL_DPI_FILE_STEM
my_prebuilt_dpi_file_stem := $(LOCAL_DPI_FILE_STEM)
else
my_prebuilt_dpi_file_stem := $(LOCAL_MODULE)_%.apk
endif
my_prebuilt_src_file := $(dir $(my_prebuilt_src_file))$(subst %,$(my_dpi),$(my_prebuilt_dpi_file_stem))

ifneq ($(strip $(LOCAL_EXTRACT_DPI_APK)),)
my_extract_apk := $(subst %,$(my_dpi),$(LOCAL_EXTRACT_DPI_APK))
endif  # LOCAL_EXTRACT_DPI_APK
endif  # my_dpi
endif  # LOCAL_DPI_VARIANTS

ifdef my_extract_apk
my_extracted_apk := $(intermediates)/extracted.apk

$(my_extracted_apk): PRIVATE_EXTRACT := $(my_extract_apk)
$(my_extracted_apk): $(my_prebuilt_src_file)
	@echo Extract APK: $@
	$(hide) mkdir -p $(dir $@) && rm -f $@
	$(hide) unzip -p $< $(PRIVATE_EXTRACT) >$@

my_prebuilt_src_file := $(my_extracted_apk)
my_extracted_apk :=
my_extract_apk :=
ifeq ($(PRODUCT_ALWAYS_PREOPT_EXTRACTED_APK),true)
# If the product property is set, always preopt for extracted modules to prevent executing out of
# the APK.
my_preopt_for_extracted_apk := true
endif
endif

dex_preopt_profile_src_file := $(my_prebuilt_src_file)

rs_compatibility_jni_libs :=
include $(BUILD_SYSTEM)/install_jni_libs.mk

ifeq ($(LOCAL_CERTIFICATE),EXTERNAL)
  # The magic string "EXTERNAL" means this package will be signed with
  # the default dev key throughout the build process, but we expect
  # the final package to be signed with a different key.
  #
  # This can be used for packages where we don't have access to the
  # keys, but want the package to be predexopt'ed.
  LOCAL_CERTIFICATE := $(DEFAULT_SYSTEM_DEV_CERTIFICATE)
  PACKAGES.$(LOCAL_MODULE).EXTERNAL_KEY := 1

  $(built_module) : $(LOCAL_CERTIFICATE).pk8 $(LOCAL_CERTIFICATE).x509.pem
  $(built_module) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  $(built_module) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
endif
ifeq ($(LOCAL_CERTIFICATE),)
  # It is now a build error to add a prebuilt .apk without
  # specifying a key for it.
  $(error No LOCAL_CERTIFICATE specified for prebuilt "$(my_prebuilt_src_file)")
else ifeq ($(LOCAL_CERTIFICATE),PRESIGNED)
  # The magic string "PRESIGNED" means this package is already checked
  # signed with its release key.
  #
  # By setting .CERTIFICATE but not .PRIVATE_KEY, this package will be
  # mentioned in apkcerts.txt (with certificate set to "PRESIGNED")
  # but the dexpreopt process will not try to re-sign the app.
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := PRESIGNED
  PACKAGES := $(PACKAGES) $(LOCAL_MODULE)
else
  # If this is not an absolute certificate, assign it to a generic one.
  ifeq ($(dir $(strip $(LOCAL_CERTIFICATE))),./)
      LOCAL_CERTIFICATE := $(dir $(DEFAULT_SYSTEM_DEV_CERTIFICATE))$(LOCAL_CERTIFICATE)
  endif

  PACKAGES.$(LOCAL_MODULE).PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  PACKAGES.$(LOCAL_MODULE).CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
  PACKAGES := $(PACKAGES) $(LOCAL_MODULE)

  $(built_module) : $(LOCAL_CERTIFICATE).pk8 $(LOCAL_CERTIFICATE).x509.pem
  $(built_module) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
  $(built_module) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
endif

# Disable dex-preopt of prebuilts to save space, if requested.
ifndef LOCAL_DEX_PREOPT
ifeq ($(DONT_DEXPREOPT_PREBUILTS),true)
LOCAL_DEX_PREOPT := false
endif
endif

# If the module is a compressed module, we don't pre-opt it because its final
# installation location will be the data partition.
ifdef LOCAL_COMPRESSED_MODULE
LOCAL_DEX_PREOPT := false
endif

#######################################
# defines built_odex along with rule to install odex
include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk
#######################################
ifneq ($(LOCAL_REPLACE_PREBUILT_APK_INSTALLED),)
# There is a replacement for the prebuilt .apk we can install without any processing.
$(built_module) : $(LOCAL_REPLACE_PREBUILT_APK_INSTALLED)
	$(transform-prebuilt-to-target)

else  # ! LOCAL_REPLACE_PREBUILT_APK_INSTALLED
# Sign and align non-presigned .apks.
# The embedded prebuilt jni to uncompress.
ifeq ($(LOCAL_CERTIFICATE),PRESIGNED)
# For PRESIGNED apks we must uncompress every .so file:
# even if the .so file isn't for the current TARGET_ARCH,
# we can't strip the file.
embedded_prebuilt_jni_libs := 'lib/*.so'
endif
ifndef embedded_prebuilt_jni_libs
# No LOCAL_PREBUILT_JNI_LIBS, uncompress all.
embedded_prebuilt_jni_libs := 'lib/*.so'
endif
$(built_module): PRIVATE_EMBEDDED_JNI_LIBS := $(embedded_prebuilt_jni_libs)

ifdef LOCAL_COMPRESSED_MODULE
$(built_module) : $(MINIGZIP)
endif

$(built_module) : $(my_prebuilt_src_file) | $(ZIPALIGN) $(SIGNAPK_JAR)
	$(transform-prebuilt-to-target)
	$(uncompress-shared-libs)
ifdef LOCAL_DEX_PREOPT
ifneq ($(BUILD_PLATFORM_ZIP),)
	@# Keep a copy of apk with classes.dex unstripped
	$(hide) cp -f $@ $(dir $@)package.dex.apk
endif  # BUILD_PLATFORM_ZIP
endif  # LOCAL_DEX_PREOPT
ifneq ($(LOCAL_CERTIFICATE),PRESIGNED)
	@# Only strip out files if we can re-sign the package.
ifdef LOCAL_DEX_PREOPT
ifneq (nostripping,$(LOCAL_DEX_PREOPT))
	$(call dexpreopt-remove-classes.dex,$@)
endif  # LOCAL_DEX_PREOPT != nostripping
endif  # LOCAL_DEX_PREOPT
	$(sign-package)
	# No need for align-package because sign-package takes care of alignment
else  # LOCAL_CERTIFICATE == PRESIGNED
	$(align-package)
endif  # LOCAL_CERTIFICATE
ifdef LOCAL_COMPRESSED_MODULE
	$(compress-package)
endif  # LOCAL_COMPRESSED_MODULE
endif  # ! LOCAL_REPLACE_PREBUILT_APK_INSTALLED

###############################
## Rule to build the odex file
ifdef LOCAL_DEX_PREOPT
$(built_odex) : $(my_prebuilt_src_file)
	$(call dexpreopt-one-file,$<,$@)
endif

###############################
## Install split apks.
ifdef LOCAL_PACKAGE_SPLITS
ifdef LOCAL_COMPRESSED_MODULE
$(error $(LOCAL_MODULE): LOCAL_COMPRESSED_MODULE is not currently supported for split installs)
endif  # LOCAL_COMPRESSED_MODULE

# LOCAL_PACKAGE_SPLITS is a list of apks to be installed.
built_apk_splits := $(addprefix $(intermediates)/,$(notdir $(LOCAL_PACKAGE_SPLITS)))
installed_apk_splits := $(addprefix $(my_module_path)/,$(notdir $(LOCAL_PACKAGE_SPLITS)))

# Rules to sign the split apks.
my_src_dir := $(sort $(dir $(LOCAL_PACKAGE_SPLITS)))
ifneq (1,$(words $(my_src_dir)))
$(error You must put all the split source apks in the same folder: $(LOCAL_PACKAGE_SPLITS))
endif
my_src_dir := $(LOCAL_PATH)/$(my_src_dir)

$(built_apk_splits) : $(LOCAL_CERTIFICATE).pk8 $(LOCAL_CERTIFICATE).x509.pem
$(built_apk_splits) : PRIVATE_PRIVATE_KEY := $(LOCAL_CERTIFICATE).pk8
$(built_apk_splits) : PRIVATE_CERTIFICATE := $(LOCAL_CERTIFICATE).x509.pem
$(built_apk_splits) : $(intermediates)/%.apk : $(my_src_dir)/%.apk
	$(copy-file-to-new-target)
	$(sign-package)

# Rules to install the split apks.
$(installed_apk_splits) : $(my_module_path)/%.apk : $(intermediates)/%.apk
	@echo "Install: $@"
	$(copy-file-to-new-target)

# Register the additional built and installed files.
ALL_MODULES.$(my_register_name).INSTALLED += $(installed_apk_splits)
ALL_MODULES.$(my_register_name).BUILT_INSTALLED += \
  $(foreach s,$(LOCAL_PACKAGE_SPLITS),$(intermediates)/$(notdir $(s)):$(my_module_path)/$(notdir $(s)))

# Make sure to install the splits when you run "make <module_name>".
$(my_all_targets): $(installed_apk_splits)

endif # LOCAL_PACKAGE_SPLITS

else ifeq ($(prebuilt_module_is_dex_javalib),true)  # ! LOCAL_MODULE_CLASS != APPS
# This is a target shared library, i.e. a jar with classes.dex.
#######################################
# defines built_odex along with rule to install odex
include $(BUILD_SYSTEM)/dex_preopt_odex_install.mk
#######################################
ifdef LOCAL_DEX_PREOPT
ifneq ($(dexpreopt_boot_jar_module),) # boot jar
# boot jar's rules are defined in dex_preopt.mk
dexpreopted_boot_jar := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/$(dexpreopt_boot_jar_module)_nodex.jar
$(built_module) : $(dexpreopted_boot_jar)
	$(call copy-file-to-target)

# For libart boot jars, we don't have .odex files.
else # ! boot jar
$(built_odex): PRIVATE_MODULE := $(LOCAL_MODULE)
# Use pattern rule - we may have multiple built odex files.
$(built_odex) : $(dir $(LOCAL_BUILT_MODULE))% : $(my_prebuilt_src_file)
	@echo "Dexpreopt Jar: $(PRIVATE_MODULE) ($@)"
	$(call dexpreopt-one-file,$<,$@)

$(built_module) : $(my_prebuilt_src_file)
	$(call copy-file-to-target)
ifneq (nostripping,$(LOCAL_DEX_PREOPT))
	$(call dexpreopt-remove-classes.dex,$@)
endif
endif # boot jar
else # ! LOCAL_DEX_PREOPT
$(built_module) : $(my_prebuilt_src_file)
	$(call copy-file-to-target)
endif # LOCAL_DEX_PREOPT

else  # ! prebuilt_module_is_dex_javalib
$(built_module) : $(my_prebuilt_src_file)
ifneq ($(LOCAL_PREBUILT_STRIP_COMMENTS),)
	$(transform-prebuilt-to-target-strip-comments)
else
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

$(common_classes_jar): PRIVATE_MODULE := $(LOCAL_MODULE)
$(common_classes_jar): PRIVATE_PREFIX := $(my_prefix)

$(common_classes_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

else # !LOCAL_IS_HOST_MODULE
# for target java libraries, the LOCAL_BUILT_MODULE is in a product-specific dir,
# while the deps should be in the common dir, so we make a copy in the common dir.
common_classes_jar := $(intermediates.COMMON)/classes.jar
common_classes_pre_proguard_jar := $(intermediates.COMMON)/classes-pre-proguard.jar
common_javalib_jar := $(intermediates.COMMON)/javalib.jar

$(common_classes_jar) $(common_classes_pre_proguard_jar) $(common_javalib_jar): PRIVATE_MODULE := $(LOCAL_MODULE)
$(common_classes_jar) $(common_classes_pre_proguard_jar) $(common_javalib_jar): PRIVATE_PREFIX := $(my_prefix)

ifeq ($(LOCAL_SDK_VERSION),system_current)
my_link_type := java:system
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
my_src_jar := $(intermediates.COMMON)/aar/classes.jar

$(my_src_jar) : $(my_src_aar)
	$(hide) rm -rf $(dir $@) && mkdir -p $(dir $@) $(dir $@)/res
	$(hide) unzip -qo -d $(dir $@) $<
	# Make sure the extracted classes.jar has a new timestamp.
	$(hide) touch $@

endif

$(common_classes_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

$(common_classes_pre_proguard_jar) : $(my_src_jar)
	$(transform-prebuilt-to-target)

$(common_javalib_jar) : $(common_classes_jar)
	$(transform-prebuilt-to-target)

$(call define-jar-to-toc-rule, $(common_classes_jar))

ifdef LOCAL_USE_AAPT2
ifneq ($(my_src_aar),)
LOCAL_SDK_RES_VERSION:=$(strip $(LOCAL_SDK_RES_VERSION))
ifeq ($(LOCAL_SDK_RES_VERSION),)
  LOCAL_SDK_RES_VERSION:=$(LOCAL_SDK_VERSION)
endif

framework_res_package_export :=
framework_res_package_export_deps :=
# Please refer to package.mk
ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
ifneq ($(filter-out current system_current test_current,$(LOCAL_SDK_RES_VERSION))$(if $(TARGET_BUILD_APPS),$(filter current system_current test_current,$(LOCAL_SDK_RES_VERSION))),)
framework_res_package_export := \
    $(HISTORICAL_SDK_VERSIONS_ROOT)/$(LOCAL_SDK_RES_VERSION)/android.jar
framework_res_package_export_deps := $(framework_res_package_export)
else
framework_res_package_export := \
    $(call intermediates-dir-for,APPS,framework-res,,COMMON)/package-export.apk
framework_res_package_export_deps := \
    $(dir $(framework_res_package_export))src/R.stamp
endif
endif

my_res_package := $(intermediates.COMMON)/package-res.apk

# We needed only very few PRIVATE variables and aapt2.mk input variables. Reset the unnecessary ones.
$(my_res_package): PRIVATE_AAPT2_CFLAGS :=
$(my_res_package): PRIVATE_AAPT_FLAGS := --static-lib --no-static-lib-packages
$(my_res_package): PRIVATE_ANDROID_MANIFEST := $(intermediates.COMMON)/aar/AndroidManifest.xml
$(my_res_package): PRIVATE_AAPT_INCLUDES := $(framework_res_package_export)
$(my_res_package): PRIVATE_SOURCE_INTERMEDIATES_DIR :=
$(my_res_package): PRIVATE_PROGUARD_OPTIONS_FILE :=
$(my_res_package): PRIVATE_DEFAULT_APP_TARGET_SDK :=
$(my_res_package): PRIVATE_DEFAULT_APP_TARGET_SDK :=
$(my_res_package): PRIVATE_PRODUCT_AAPT_CONFIG :=
$(my_res_package): PRIVATE_PRODUCT_AAPT_PREF_CONFIG :=
$(my_res_package): PRIVATE_TARGET_AAPT_CHARACTERISTICS :=
$(my_res_package) : $(framework_res_package_export_deps)

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

endif # ! prebuilt_module_is_dex_javalib
endif # LOCAL_IS_HOST_MODULE is not set

ifneq ($(prebuilt_module_is_dex_javalib),true)

ifdef LOCAL_JACK_ENABLED
# We may be building classes.jack from a host jar for host dalvik Java library.
$(intermediates.COMMON)/classes.jack : PRIVATE_JACK_FLAGS:=$(LOCAL_JACK_FLAGS)
$(intermediates.COMMON)/classes.jack : PRIVATE_JACK_MIN_SDK_VERSION := $(if $(strip $(LOCAL_MIN_SDK_VERSION)),$(LOCAL_MIN_SDK_VERSION),1)
$(intermediates.COMMON)/classes.jack : PRIVATE_JACK_PLUGIN_PATH := $(LOCAL_JACK_PLUGIN_PATH)
$(intermediates.COMMON)/classes.jack : PRIVATE_JACK_PLUGIN := $(LOCAL_JACK_PLUGIN)
$(intermediates.COMMON)/classes.jack : $(LOCAL_JACK_PLUGIN_PATH) $(my_src_jar) \
        $(LOCAL_ADDITIONAL_DEPENDENCIES) $(JACK_DEFAULT_ARGS) $(JACK) \
        | setup-jack-server
	$(transform-jar-to-jack)

# Update timestamps of .toc files for prebuilts so dependents will be
# always rebuilt.
$(intermediates.COMMON)/classes.dex.toc: $(intermediates.COMMON)/classes.jack
	touch $@
endif # LOCAL_JACK_ENABLED
endif # ! prebuilt_module_is_dex_javalib
endif # JAVA_LIBRARIES

$(built_module) : $(LOCAL_ADDITIONAL_DEPENDENCIES)

my_prebuilt_src_file :=
my_preopt_for_extracted_apk :=
