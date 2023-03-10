# dexpreopt_odex_install.mk is used to define odex creation rules for JARs and APKs
# This file depends on variables set in base_rules.mk
# Input variables: my_manifest_or_apk
# Output variables: LOCAL_DEX_PREOPT, LOCAL_UNCOMPRESS_DEX

ifeq (true,$(LOCAL_USE_EMBEDDED_DEX))
  LOCAL_UNCOMPRESS_DEX := true
else
  LOCAL_UNCOMPRESS_DEX :=
endif

# We explicitly uncompress APKs of privileged apps, and used by
# privileged apps
ifneq (true,$(DONT_UNCOMPRESS_PRIV_APPS_DEXS))
  ifeq (true,$(LOCAL_PRIVILEGED_MODULE))
    LOCAL_UNCOMPRESS_DEX := true
  endif

  ifneq (,$(filter $(PRODUCT_LOADED_BY_PRIVILEGED_MODULES), $(LOCAL_MODULE)))
    LOCAL_UNCOMPRESS_DEX := true
  endif
endif  # DONT_UNCOMPRESS_PRIV_APPS_DEXS

# Setting LOCAL_DEX_PREOPT based on WITH_DEXPREOPT, LOCAL_DEX_PREOPT, etc
LOCAL_DEX_PREOPT := $(strip $(LOCAL_DEX_PREOPT))
ifndef LOCAL_DEX_PREOPT # LOCAL_DEX_PREOPT undefined
  LOCAL_DEX_PREOPT := $(DEX_PREOPT_DEFAULT)
endif

ifeq (false,$(LOCAL_DEX_PREOPT))
  LOCAL_DEX_PREOPT :=
endif

# Disable preopt for tests.
ifneq (,$(filter $(LOCAL_MODULE_TAGS),tests))
  LOCAL_DEX_PREOPT :=
endif

# If we have product-specific config for this module?
ifneq (,$(filter $(LOCAL_MODULE),$(DEXPREOPT_DISABLED_MODULES)))
  LOCAL_DEX_PREOPT :=
endif

# Disable preopt for DISABLE_PREOPT
ifeq (true,$(DISABLE_PREOPT))
  LOCAL_DEX_PREOPT :=
endif

# Disable preopt if not WITH_DEXPREOPT
ifneq (true,$(WITH_DEXPREOPT))
  LOCAL_DEX_PREOPT :=
endif

ifdef LOCAL_UNINSTALLABLE_MODULE
  LOCAL_DEX_PREOPT :=
endif

# Disable preopt if the app contains no java code.
ifeq (,$(strip $(built_dex)$(my_prebuilt_src_file)$(LOCAL_SOONG_DEX_JAR)))
  LOCAL_DEX_PREOPT :=
endif

# if WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY=true and module is not in boot class path skip
# Also preopt system server jars since selinux prevents system server from loading anything from
# /data. If we don't do this they will need to be extracted which is not favorable for RAM usage
# or performance. If my_preopt_for_extracted_apk is true, we ignore the only preopt boot image
# options.
system_server_jars := $(foreach m,$(PRODUCT_SYSTEM_SERVER_JARS),$(call word-colon,2,$(m)))
ifneq (true,$(my_preopt_for_extracted_apk))
  ifeq (true,$(WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY))
    ifeq ($(filter $(system_server_jars) $(DEXPREOPT_BOOT_JARS_MODULES),$(LOCAL_MODULE)),)
      LOCAL_DEX_PREOPT :=
    endif
  endif
endif

my_process_profile :=
my_profile_is_text_listing :=

ifeq (false,$(WITH_DEX_PREOPT_GENERATE_PROFILE))
  LOCAL_DEX_PREOPT_GENERATE_PROFILE := false
endif

ifndef LOCAL_DEX_PREOPT_GENERATE_PROFILE
  # If LOCAL_DEX_PREOPT_GENERATE_PROFILE is not defined, default it based on the existence of the
  # profile class listing. TODO: Use product specific directory here.
  my_classes_directory := $(PRODUCT_DEX_PREOPT_PROFILE_DIR)
  LOCAL_DEX_PREOPT_PROFILE := $(my_classes_directory)/$(LOCAL_MODULE).prof

  ifneq (,$(wildcard $(LOCAL_DEX_PREOPT_PROFILE)))
    my_process_profile := true
    my_profile_is_text_listing :=
  endif
else
  my_process_profile := $(LOCAL_DEX_PREOPT_GENERATE_PROFILE)
  my_profile_is_text_listing := true
  LOCAL_DEX_PREOPT_PROFILE := $(LOCAL_DEX_PREOPT_PROFILE_CLASS_LISTING)
endif

ifeq (true,$(my_process_profile))
  ifndef LOCAL_DEX_PREOPT_PROFILE
    $(call pretty-error,Must have specified class listing (LOCAL_DEX_PREOPT_PROFILE))
  endif
  ifeq (,$(dex_preopt_profile_src_file))
    $(call pretty-error, Internal error: dex_preopt_profile_src_file must be set)
  endif
endif

################################################################################
# Local module variables and functions used in dexpreopt and manifest_check.
################################################################################

my_filtered_optional_uses_libraries := $(filter-out $(INTERNAL_PLATFORM_MISSING_USES_LIBRARIES), \
  $(LOCAL_OPTIONAL_USES_LIBRARIES))

# TODO(b/132357300): This may filter out too much, as PRODUCT_PACKAGES doesn't
# include all packages (the full list is unknown until reading all Android.mk
# makefiles). As a consequence, a library may be present but not included in
# dexpreopt, which will result in class loader context mismatch and a failure
# to load dexpreopt code on device. We should fix this, either by deferring
# dependency computation until the full list of product packages is known, or
# by adding product-specific lists of missing libraries.
my_filtered_optional_uses_libraries := $(filter $(PRODUCT_PACKAGES), \
  $(my_filtered_optional_uses_libraries))

ifeq ($(LOCAL_MODULE_CLASS),APPS)
  # compatibility libraries are added to class loader context of an app only if
  # targetSdkVersion in the app's manifest is lower than the given SDK version

  my_dexpreopt_libs_compat_28 := \
    org.apache.http.legacy

  my_dexpreopt_libs_compat_29 := \
    android.hidl.manager-V1.0-java \
    android.hidl.base-V1.0-java

  my_dexpreopt_libs_compat_30 := \
    android.test.base \
    android.test.mock

  my_dexpreopt_libs_compat := \
    $(my_dexpreopt_libs_compat_28) \
    $(my_dexpreopt_libs_compat_29) \
    $(my_dexpreopt_libs_compat_30)
else
  my_dexpreopt_libs_compat :=
endif

my_dexpreopt_libs := \
  $(LOCAL_USES_LIBRARIES) \
  $(my_filtered_optional_uses_libraries)

# Module dexpreopt.config depends on dexpreopt.config files of each
# <uses-library> dependency, because these libraries may be processed after
# the current module by Make (there's no topological order), so the dependency
# information (paths, class loader context) may not be ready yet by the time
# this dexpreopt.config is generated. So it's necessary to add file-level
# dependencies between dexpreopt.config files.
my_dexpreopt_dep_configs := $(foreach lib, \
  $(filter-out $(my_dexpreopt_libs_compat),$(LOCAL_USES_LIBRARIES) $(my_filtered_optional_uses_libraries)), \
  $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,)/dexpreopt.config)

# 1: SDK version
# 2: list of libraries
#
# Make does not process modules in topological order wrt. <uses-library>
# dependencies, therefore we cannot rely on variables to get the information
# about dependencies (in particular, their on-device path and class loader
# context). This information is communicated via dexpreopt.config files: each
# config depends on configs for <uses-library> dependencies of this module,
# and the dex_preopt_config_merger.py script reads all configs and inserts the
# missing bits from dependency configs into the module config.
#
# By default on-device path is /system/framework/*.jar, and class loader
# subcontext is empty. These values are correct for compatibility libraries,
# which are special and not handled by dex_preopt_config_merger.py.
#
add_json_class_loader_context = \
  $(call add_json_array, $(1)) \
  $(foreach lib, $(2),\
    $(call add_json_map_anon) \
    $(call add_json_str, Name, $(lib)) \
    $(call add_json_str, Host, $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/javalib.jar) \
    $(call add_json_str, Device, /system/framework/$(lib).jar) \
    $(call add_json_val, Subcontexts, null) \
    $(call end_json_map)) \
  $(call end_json_array)

################################################################################
# Verify <uses-library> coherence between the build system and the manifest.
################################################################################

# Some libraries do not have a manifest, so there is nothing to check against.
# Handle it as if the manifest had zero <uses-library> tags: it is ok unless the
# module has non-empty LOCAL_USES_LIBRARIES or LOCAL_OPTIONAL_USES_LIBRARIES.
ifndef my_manifest_or_apk
  ifneq (,$(strip $(LOCAL_USES_LIBRARIES)$(LOCAL_OPTIONAL_USES_LIBRARIES)))
    $(error $(LOCAL_MODULE) has non-empty <uses-library> list but no manifest)
  else
    LOCAL_ENFORCE_USES_LIBRARIES := false
  endif
endif

# Disable the check for tests.
ifneq (,$(filter $(LOCAL_MODULE_TAGS),tests))
  LOCAL_ENFORCE_USES_LIBRARIES := false
endif
ifneq (,$(LOCAL_COMPATIBILITY_SUITE))
  LOCAL_ENFORCE_USES_LIBRARIES := false
endif

# Disable the check if the app contains no java code.
ifeq (,$(strip $(built_dex)$(my_prebuilt_src_file)$(LOCAL_SOONG_DEX_JAR)))
  LOCAL_ENFORCE_USES_LIBRARIES := false
endif

# Disable <uses-library> checks if dexpreopt is globally disabled.
# Without dexpreopt the check is not necessary, and although it is good to have,
# it is difficult to maintain on non-linux build platforms where dexpreopt is
# generally disabled (the check may fail due to various unrelated reasons, such
# as a failure to get manifest from an APK).
ifneq (true,$(WITH_DEXPREOPT))
  LOCAL_ENFORCE_USES_LIBRARIES := false
else ifeq (true,$(WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY))
  LOCAL_ENFORCE_USES_LIBRARIES := false
endif

# Verify LOCAL_USES_LIBRARIES/LOCAL_OPTIONAL_USES_LIBRARIES against the manifest.
ifndef LOCAL_ENFORCE_USES_LIBRARIES
  LOCAL_ENFORCE_USES_LIBRARIES := true
endif

my_enforced_uses_libraries :=
ifeq (true,$(LOCAL_ENFORCE_USES_LIBRARIES))
  my_verify_script := build/soong/scripts/manifest_check.py
  my_uses_libs_args := $(patsubst %,--uses-library %,$(LOCAL_USES_LIBRARIES))
  my_optional_uses_libs_args := $(patsubst %,--optional-uses-library %, \
    $(LOCAL_OPTIONAL_USES_LIBRARIES))
  my_relax_check_arg := $(if $(filter true,$(RELAX_USES_LIBRARY_CHECK)), \
    --enforce-uses-libraries-relax,)
  my_dexpreopt_config_args := $(patsubst %,--dexpreopt-config %,$(my_dexpreopt_dep_configs))

  my_enforced_uses_libraries := $(intermediates.COMMON)/enforce_uses_libraries.status
  $(my_enforced_uses_libraries): PRIVATE_USES_LIBRARIES := $(my_uses_libs_args)
  $(my_enforced_uses_libraries): PRIVATE_OPTIONAL_USES_LIBRARIES := $(my_optional_uses_libs_args)
  $(my_enforced_uses_libraries): PRIVATE_DEXPREOPT_CONFIGS := $(my_dexpreopt_config_args)
  $(my_enforced_uses_libraries): PRIVATE_RELAX_CHECK := $(my_relax_check_arg)
  $(my_enforced_uses_libraries): $(AAPT2)
  $(my_enforced_uses_libraries): $(my_verify_script)
  $(my_enforced_uses_libraries): $(my_dexpreopt_dep_configs)
  $(my_enforced_uses_libraries): $(my_manifest_or_apk)
	@echo Verifying uses-libraries: $<
	rm -f $@
	$(my_verify_script) \
	  --enforce-uses-libraries \
	  --enforce-uses-libraries-status $@ \
	  --aapt $(AAPT2) \
	  $(PRIVATE_USES_LIBRARIES) \
	  $(PRIVATE_OPTIONAL_USES_LIBRARIES) \
	  $(PRIVATE_DEXPREOPT_CONFIGS) \
	  $(PRIVATE_RELAX_CHECK) \
	  $<
  $(LOCAL_BUILT_MODULE) : $(my_enforced_uses_libraries)
endif

################################################################################
# Dexpreopt command.
################################################################################

my_dexpreopt_archs :=
my_dexpreopt_images :=
my_dexpreopt_images_deps :=
my_dexpreopt_image_locations_on_host :=
my_dexpreopt_image_locations_on_device :=
# Infix can be 'boot' or 'art'. Soong creates a set of variables for Make, one
# for each boot image (primary and the framework extension). The only reason why
# the primary image is exposed to Make is testing (art gtests) and benchmarking
# (art golem benchmarks). Install rules that use those variables are in
# dex_preopt_libart.mk. Here for dexpreopt purposes the infix is always 'boot'.
my_dexpreopt_infix := boot
my_create_dexpreopt_config :=

ifdef LOCAL_DEX_PREOPT
  ifeq (,$(filter PRESIGNED,$(LOCAL_CERTIFICATE)))
    # Store uncompressed dex files preopted in /system
    ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
      ifeq ($(call install-on-system-other, $(my_module_path)),)
        LOCAL_UNCOMPRESS_DEX := true
      endif  # install-on-system-other
    else  # BOARD_USES_SYSTEM_OTHER_ODEX
      LOCAL_UNCOMPRESS_DEX := true
    endif
  endif
  my_create_dexpreopt_config := true
endif

# dexpreopt is disabled when TARGET_BUILD_UNBUNDLED_IMAGE is true,
# but dexpreopt config files are required to dexpreopt in post-processing.
ifeq ($(TARGET_BUILD_UNBUNDLED_IMAGE),true)
  my_create_dexpreopt_config := true
endif

ifeq ($(my_create_dexpreopt_config), true)
  ifeq ($(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
    my_module_multilib := $(LOCAL_MULTILIB)
    # If the module is not an SDK library and it's a system server jar, only preopt the primary arch.
    ifeq (,$(filter $(JAVA_SDK_LIBRARIES),$(LOCAL_MODULE)))
      # For a Java library, by default we build odex for both 1st arch and 2nd arch.
      # But it can be overridden with "LOCAL_MULTILIB := first".
      ifneq (,$(filter $(PRODUCT_SYSTEM_SERVER_JARS),$(LOCAL_MODULE)))
        # For system server jars, we build for only "first".
        my_module_multilib := first
      endif
    endif

    # Only preopt primary arch for translated arch since there is only an image there.
    ifeq ($(TARGET_TRANSLATE_2ND_ARCH),true)
      my_module_multilib := first
    endif

    # #################################################
    # Odex for the 1st arch
    my_dexpreopt_archs += $(TARGET_ARCH)
    my_dexpreopt_images += $(DEXPREOPT_IMAGE_$(my_dexpreopt_infix)_$(TARGET_ARCH))
    my_dexpreopt_images_deps += $(DEXPREOPT_IMAGE_DEPS_$(my_dexpreopt_infix)_$(TARGET_ARCH))
    # Odex for the 2nd arch
    ifdef TARGET_2ND_ARCH
      ifneq ($(TARGET_TRANSLATE_2ND_ARCH),true)
        ifneq (first,$(my_module_multilib))
          my_dexpreopt_archs += $(TARGET_2ND_ARCH)
          my_dexpreopt_images += $(DEXPREOPT_IMAGE_$(my_dexpreopt_infix)_$(TARGET_2ND_ARCH))
          my_dexpreopt_images_deps += $(DEXPREOPT_IMAGE_DEPS_$(my_dexpreopt_infix)_$(TARGET_2ND_ARCH))
        endif  # my_module_multilib is not first.
      endif  # TARGET_TRANSLATE_2ND_ARCH not true
    endif  # TARGET_2ND_ARCH
    # #################################################
  else  # must be APPS
    # The preferred arch
    # Save the module multilib since setup_one_odex modifies it.
    my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
    my_dexpreopt_archs += $(TARGET_$(my_2nd_arch_prefix)ARCH)
    my_dexpreopt_images += \
        $(DEXPREOPT_IMAGE_$(my_dexpreopt_infix)_$(TARGET_$(my_2nd_arch_prefix)ARCH))
    my_dexpreopt_images_deps += \
        $(DEXPREOPT_IMAGE_DEPS_$(my_dexpreopt_infix)_$(TARGET_$(my_2nd_arch_prefix)ARCH))
    ifdef TARGET_2ND_ARCH
      ifeq ($(my_module_multilib),both)
        # The non-preferred arch
        my_2nd_arch_prefix := $(if $(LOCAL_2ND_ARCH_VAR_PREFIX),,$(TARGET_2ND_ARCH_VAR_PREFIX))
        my_dexpreopt_archs += $(TARGET_$(my_2nd_arch_prefix)ARCH)
        my_dexpreopt_images += \
            $(DEXPREOPT_IMAGE_$(my_dexpreopt_infix)_$(TARGET_$(my_2nd_arch_prefix)ARCH))
        my_dexpreopt_images_deps += \
            $(DEXPREOPT_IMAGE_DEPS_$(my_dexpreopt_infix)_$(TARGET_$(my_2nd_arch_prefix)ARCH))
      endif  # LOCAL_MULTILIB is both
    endif  # TARGET_2ND_ARCH
  endif  # LOCAL_MODULE_CLASS

  my_dexpreopt_image_locations_on_host += $(DEXPREOPT_IMAGE_LOCATIONS_ON_HOST$(my_dexpreopt_infix))
  my_dexpreopt_image_locations_on_device += $(DEXPREOPT_IMAGE_LOCATIONS_ON_DEVICE$(my_dexpreopt_infix))

  # Record dex-preopt config.
  DEXPREOPT.$(LOCAL_MODULE).DEX_PREOPT := $(LOCAL_DEX_PREOPT)
  DEXPREOPT.$(LOCAL_MODULE).MULTILIB := $(LOCAL_MULTILIB)
  DEXPREOPT.$(LOCAL_MODULE).DEX_PREOPT_FLAGS := $(LOCAL_DEX_PREOPT_FLAGS)
  DEXPREOPT.$(LOCAL_MODULE).PRIVILEGED_MODULE := $(LOCAL_PRIVILEGED_MODULE)
  DEXPREOPT.$(LOCAL_MODULE).VENDOR_MODULE := $(LOCAL_VENDOR_MODULE)
  DEXPREOPT.$(LOCAL_MODULE).TARGET_ARCH := $(LOCAL_MODULE_TARGET_ARCH)
  DEXPREOPT.$(LOCAL_MODULE).INSTALLED_STRIPPED := $(LOCAL_INSTALLED_MODULE)
  DEXPREOPT.MODULES.$(LOCAL_MODULE_CLASS) := $(sort \
    $(DEXPREOPT.MODULES.$(LOCAL_MODULE_CLASS)) $(LOCAL_MODULE))

  $(call json_start)

  # DexPath is not set: it will be filled in by dexpreopt_gen.

  $(call add_json_str,  Name,                           $(LOCAL_MODULE))
  $(call add_json_str,  DexLocation,                    $(patsubst $(PRODUCT_OUT)%,%,$(LOCAL_INSTALLED_MODULE)))
  $(call add_json_str,  BuildPath,                      $(LOCAL_BUILT_MODULE))
  $(call add_json_str,  ManifestPath,                   $(full_android_manifest))
  $(call add_json_str,  ExtrasOutputPath,               $$2)
  $(call add_json_bool, Privileged,                     $(filter true,$(LOCAL_PRIVILEGED_MODULE)))
  $(call add_json_bool, UncompressedDex,                $(filter true,$(LOCAL_UNCOMPRESS_DEX)))
  $(call add_json_bool, HasApkLibraries,                $(LOCAL_APK_LIBRARIES))
  $(call add_json_list, PreoptFlags,                    $(LOCAL_DEX_PREOPT_FLAGS))
  $(call add_json_str,  ProfileClassListing,            $(if $(my_process_profile),$(LOCAL_DEX_PREOPT_PROFILE)))
  $(call add_json_bool, ProfileIsTextListing,           $(my_profile_is_text_listing))
  $(call add_json_str,  EnforceUsesLibrariesStatusFile, $(my_enforced_uses_libraries))
  $(call add_json_bool, EnforceUsesLibraries,           $(filter true,$(LOCAL_ENFORCE_USES_LIBRARIES)))
  $(call add_json_str,  ProvidesUsesLibrary,            $(firstword $(LOCAL_PROVIDES_USES_LIBRARY) $(LOCAL_MODULE)))
  $(call add_json_map,  ClassLoaderContexts)
  $(call add_json_class_loader_context, any, $(my_dexpreopt_libs))
  $(call add_json_class_loader_context,  28, $(my_dexpreopt_libs_compat_28))
  $(call add_json_class_loader_context,  29, $(my_dexpreopt_libs_compat_29))
  $(call add_json_class_loader_context,  30, $(my_dexpreopt_libs_compat_30))
  $(call end_json_map)
  $(call add_json_list, Archs,                          $(my_dexpreopt_archs))
  $(call add_json_list, DexPreoptImages,                $(my_dexpreopt_images))
  $(call add_json_list, DexPreoptImageLocationsOnHost,  $(my_dexpreopt_image_locations_on_host))
  $(call add_json_list, DexPreoptImageLocationsOnDevice,$(my_dexpreopt_image_locations_on_device))
  $(call add_json_list, PreoptBootClassPathDexFiles,    $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES))
  $(call add_json_list, PreoptBootClassPathDexLocations,$(DEXPREOPT_BOOTCLASSPATH_DEX_LOCATIONS))
  $(call add_json_bool, PreoptExtractedApk,             $(my_preopt_for_extracted_apk))
  $(call add_json_bool, NoCreateAppImage,               $(filter false,$(LOCAL_DEX_PREOPT_APP_IMAGE)))
  $(call add_json_bool, ForceCreateAppImage,            $(filter true,$(LOCAL_DEX_PREOPT_APP_IMAGE)))
  $(call add_json_bool, PresignedPrebuilt,              $(filter PRESIGNED,$(LOCAL_CERTIFICATE)))

  $(call json_end)

  my_dexpreopt_config := $(intermediates)/dexpreopt.config
  my_dexpreopt_config_for_postprocessing := $(PRODUCT_OUT)/dexpreopt_config/$(LOCAL_MODULE)_dexpreopt.config
  my_dexpreopt_config_merger := $(BUILD_SYSTEM)/dex_preopt_config_merger.py

  $(my_dexpreopt_config): $(my_dexpreopt_dep_configs) $(my_dexpreopt_config_merger)
  $(my_dexpreopt_config): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_config): PRIVATE_CONTENTS := $(json_contents)
  $(my_dexpreopt_config): PRIVATE_DEP_CONFIGS := $(my_dexpreopt_dep_configs)
  $(my_dexpreopt_config): PRIVATE_CONFIG_MERGER := $(my_dexpreopt_config_merger)
  $(my_dexpreopt_config):
	@echo "$(PRIVATE_MODULE) dexpreopt.config"
	echo -e -n '$(subst $(newline),\n,$(subst ','\'',$(subst \,\\,$(PRIVATE_CONTENTS))))' > $@
	$(PRIVATE_CONFIG_MERGER) $@ $(PRIVATE_DEP_CONFIGS)

$(eval $(call copy-one-file,$(my_dexpreopt_config),$(my_dexpreopt_config_for_postprocessing)))

$(LOCAL_INSTALLED_MODULE): $(my_dexpreopt_config_for_postprocessing)

# System server jars defined in Android.mk are deprecated.
ifneq (true, $(PRODUCT_BROKEN_DEPRECATED_MK_SYSTEM_SERVER_JARS))
  ifneq (,$(filter %:$(LOCAL_MODULE), $(PRODUCT_SYSTEM_SERVER_JARS) $(PRODUCT_APEX_SYSTEM_SERVER_JARS)))
    $(error System server jars defined in Android.mk are deprecated. \
      Convert $(LOCAL_MODULE) to Android.bp or temporarily disable the error \
      with 'PRODUCT_BROKEN_DEPRECATED_MK_SYSTEM_SERVER_JARS := true')
  endif
endif

ifdef LOCAL_DEX_PREOPT
  # System server jars must be copied into predefined locations expected by
  # dexpreopt. Copy rule must be exposed to Ninja (as it uses these files as
  # inputs), so it cannot go in dexpreopt.sh.
  ifneq (,$(filter %:$(LOCAL_MODULE), $(PRODUCT_SYSTEM_SERVER_JARS)))
    my_dexpreopt_jar_copy := $(OUT_DIR)/soong/system_server_dexjars/$(LOCAL_MODULE).jar
    $(my_dexpreopt_jar_copy): PRIVATE_BUILT_MODULE := $(LOCAL_BUILT_MODULE)
    $(my_dexpreopt_jar_copy): $(LOCAL_BUILT_MODULE)
	  @cp $(PRIVATE_BUILT_MODULE) $@
  endif

  my_dexpreopt_script := $(intermediates)/dexpreopt.sh
  my_dexpreopt_zip := $(intermediates)/dexpreopt.zip
  DEXPREOPT.$(LOCAL_MODULE).POST_INSTALLED_DEXPREOPT_ZIP := $(my_dexpreopt_zip)
  .KATI_RESTAT: $(my_dexpreopt_script)
  $(my_dexpreopt_script): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_script): PRIVATE_GLOBAL_SOONG_CONFIG := $(DEX_PREOPT_SOONG_CONFIG_FOR_MAKE)
  $(my_dexpreopt_script): PRIVATE_GLOBAL_CONFIG := $(DEX_PREOPT_CONFIG_FOR_MAKE)
  $(my_dexpreopt_script): PRIVATE_MODULE_CONFIG := $(my_dexpreopt_config)
  $(my_dexpreopt_script): $(DEXPREOPT_GEN)
  $(my_dexpreopt_script): $(my_dexpreopt_jar_copy)
  $(my_dexpreopt_script): $(my_dexpreopt_config) $(DEX_PREOPT_SOONG_CONFIG_FOR_MAKE) $(DEX_PREOPT_CONFIG_FOR_MAKE)
	@echo "$(PRIVATE_MODULE) dexpreopt gen"
	$(DEXPREOPT_GEN) \
	-global_soong $(PRIVATE_GLOBAL_SOONG_CONFIG) \
	-global $(PRIVATE_GLOBAL_CONFIG) \
	-module $(PRIVATE_MODULE_CONFIG) \
	-dexpreopt_script $@ \
	-out_dir $(OUT_DIR)

  my_dexpreopt_deps := $(my_dex_jar)
  my_dexpreopt_deps += $(if $(my_process_profile),$(LOCAL_DEX_PREOPT_PROFILE))
  my_dexpreopt_deps += \
    $(foreach lib, $(my_dexpreopt_libs) $(my_dexpreopt_libs_compat), \
      $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/javalib.jar)
  my_dexpreopt_deps += $(my_dexpreopt_images_deps)
  my_dexpreopt_deps += $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES)
  ifeq ($(LOCAL_ENFORCE_USES_LIBRARIES),true)
    my_dexpreopt_deps += $(intermediates.COMMON)/enforce_uses_libraries.status
  endif

  $(my_dexpreopt_zip): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_zip): $(my_dexpreopt_deps)
  $(my_dexpreopt_zip): | $(DEXPREOPT_GEN_DEPS)
  $(my_dexpreopt_zip): .KATI_DEPFILE := $(my_dexpreopt_zip).d
  $(my_dexpreopt_zip): PRIVATE_DEX := $(my_dex_jar)
  $(my_dexpreopt_zip): PRIVATE_SCRIPT := $(my_dexpreopt_script)
  $(my_dexpreopt_zip): $(my_dexpreopt_script)
	@echo "$(PRIVATE_MODULE) dexpreopt"
	bash $(PRIVATE_SCRIPT) $(PRIVATE_DEX) $@

  ifdef LOCAL_POST_INSTALL_CMD
    # Add a shell command separator
    LOCAL_POST_INSTALL_CMD += &&
  endif

  LOCAL_POST_INSTALL_CMD += \
    for i in $$(zipinfo -1 $(my_dexpreopt_zip)); \
      do mkdir -p $(PRODUCT_OUT)/$$(dirname $$i); \
    done && \
    ( unzip -qoDD -d $(PRODUCT_OUT) $(my_dexpreopt_zip) 2>&1 | grep -v "zipfile is empty"; exit $${PIPESTATUS[0]} ) || \
      ( code=$$?; if [ $$code -ne 0 -a $$code -ne 1 ]; then exit $$code; fi )

  $(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := $(LOCAL_POST_INSTALL_CMD)
  $(LOCAL_INSTALLED_MODULE): $(my_dexpreopt_zip)

  $(my_all_targets): $(my_dexpreopt_zip)

  my_dexpreopt_config :=
  my_dexpreopt_script :=
  my_dexpreopt_zip :=
  my_dexpreopt_config_for_postprocessing :=
endif # LOCAL_DEX_PREOPT
endif # my_create_dexpreopt_config