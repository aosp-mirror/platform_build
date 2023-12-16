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

ifeq (true,$(WITH_DEXPREOPT_ART_BOOT_IMG_ONLY))
  LOCAL_DEX_PREOPT :=
endif

my_process_profile :=
my_profile_is_text_listing :=

ifeq (false,$(WITH_DEX_PREOPT_GENERATE_PROFILE))
  LOCAL_DEX_PREOPT_GENERATE_PROFILE := false
endif

ifndef LOCAL_DEX_PREOPT_GENERATE_PROFILE
  # If LOCAL_DEX_PREOPT_GENERATE_PROFILE is not defined, default it based on the existence of the
  # profile class listing. TODO: Use product specific directory here.
  ifdef PRODUCT_DEX_PREOPT_PROFILE_DIR
    LOCAL_DEX_PREOPT_PROFILE := $(PRODUCT_DEX_PREOPT_PROFILE_DIR)/$(LOCAL_MODULE).prof

    ifneq (,$(wildcard $(LOCAL_DEX_PREOPT_PROFILE)))
      my_process_profile := true
      my_profile_is_text_listing :=
    endif
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

# TODO(b/132357300): This may filter out too much, as PRODUCT_PACKAGES doesn't
# include all packages (the full list is unknown until reading all Android.mk
# makefiles). As a consequence, a library may be present but not included in
# dexpreopt, which will result in class loader context mismatch and a failure
# to load dexpreopt code on device.
# However, we have to do filtering here. Otherwise, we may include extra
# libraries that Soong and Make don't generate build rules for (e.g., a library
# that exists in the source tree but not installable), and therefore get Ninja
# errors.
# We have deferred CLC computation to the Ninja phase, but the dependency
# computation still needs to be done early. For now, this is the best we can do.
my_filtered_optional_uses_libraries := $(filter $(PRODUCT_PACKAGES), \
  $(LOCAL_OPTIONAL_USES_LIBRARIES))

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

# The order needs to be deterministic.
my_dexpreopt_libs_all := $(sort $(my_dexpreopt_libs) $(my_dexpreopt_libs_compat))

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
else ifeq (true,$(WITH_DEXPREOPT_ART_BOOT_IMG_ONLY))
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

  my_enforced_uses_libraries := $(intermediates)/enforce_uses_libraries.status
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
my_dexpreopt_infix := $(DEXPREOPT_INFIX)
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

  # The root "product_packages.txt" is generated by `build/make/core/Makefile`. It contains a list
  # of all packages that are installed on the device. We use `grep` to filter the list by the app's
  # dependencies to create a per-app list, and use `rsync --checksum` to prevent the file's mtime
  # from being changed if the contents don't change. This avoids unnecessary dexpreopt reruns.
  my_dexpreopt_product_packages := $(intermediates)/product_packages.txt
  .KATI_RESTAT: $(my_dexpreopt_product_packages)
  $(my_dexpreopt_product_packages): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_product_packages): PRIVATE_LIBS := $(my_dexpreopt_libs_all)
  $(my_dexpreopt_product_packages): PRIVATE_STAGING := $(my_dexpreopt_product_packages).tmp
  $(my_dexpreopt_product_packages): $(PRODUCT_OUT)/product_packages.txt
	@echo "$(PRIVATE_MODULE) dexpreopt product_packages"
  ifneq (,$(my_dexpreopt_libs_all))
		grep -F -x \
			$(addprefix -e ,$(PRIVATE_LIBS)) \
			$(PRODUCT_OUT)/product_packages.txt \
			> $(PRIVATE_STAGING) \
			|| true
  else
		rm -f $(PRIVATE_STAGING) && touch $(PRIVATE_STAGING)
  endif
	rsync --checksum $(PRIVATE_STAGING) $@

  my_dexpreopt_script := $(intermediates)/dexpreopt.sh
  .KATI_RESTAT: $(my_dexpreopt_script)
  $(my_dexpreopt_script): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_script): PRIVATE_GLOBAL_SOONG_CONFIG := $(DEX_PREOPT_SOONG_CONFIG_FOR_MAKE)
  $(my_dexpreopt_script): PRIVATE_GLOBAL_CONFIG := $(DEX_PREOPT_CONFIG_FOR_MAKE)
  $(my_dexpreopt_script): PRIVATE_MODULE_CONFIG := $(my_dexpreopt_config)
  $(my_dexpreopt_script): PRIVATE_PRODUCT_PACKAGES := $(my_dexpreopt_product_packages)
  $(my_dexpreopt_script): $(DEXPREOPT_GEN)
  $(my_dexpreopt_script): $(my_dexpreopt_jar_copy)
  $(my_dexpreopt_script): $(my_dexpreopt_config) $(DEX_PREOPT_SOONG_CONFIG_FOR_MAKE) $(DEX_PREOPT_CONFIG_FOR_MAKE) $(my_dexpreopt_product_packages)
	@echo "$(PRIVATE_MODULE) dexpreopt gen"
	$(DEXPREOPT_GEN) \
	-global_soong $(PRIVATE_GLOBAL_SOONG_CONFIG) \
	-global $(PRIVATE_GLOBAL_CONFIG) \
	-module $(PRIVATE_MODULE_CONFIG) \
	-dexpreopt_script $@ \
	-out_dir $(OUT_DIR) \
	-product_packages $(PRIVATE_PRODUCT_PACKAGES)

  my_dexpreopt_deps := $(my_dex_jar)
  my_dexpreopt_deps += $(if $(my_process_profile),$(LOCAL_DEX_PREOPT_PROFILE))
  my_dexpreopt_deps += \
    $(foreach lib, $(my_dexpreopt_libs_all), \
      $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/javalib.jar)
  my_dexpreopt_deps += $(my_dexpreopt_images_deps)
  my_dexpreopt_deps += $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES)
  ifeq ($(LOCAL_ENFORCE_USES_LIBRARIES),true)
    my_dexpreopt_deps += $(intermediates)/enforce_uses_libraries.status
  endif

  # We need to add all the installed files to ALL_MODULES.$(my_register_name).INSTALLED in order
  # for the build system to properly track installed files. (for sbom, installclean, etc)
  # We install all the files in a zip file generated at execution time, which means we have to guess
  # what's going to be in that zip file before it's created. We then check at executation time that
  # our guess is correct.
  # _system_other corresponds to OdexOnSystemOtherByName() in soong.
  # The other paths correspond to dexpreoptCommand()
  _dexlocation := $(patsubst $(PRODUCT_OUT)/%,%,$(LOCAL_INSTALLED_MODULE))
  _dexname := $(basename $(notdir $(_dexlocation)))
  _system_other := $(strip $(if $(strip $(BOARD_USES_SYSTEM_OTHER_ODEX)), \
    $(if $(strip $(SANITIZE_LITE)),, \
      $(if $(filter $(_dexname),$(PRODUCT_DEXPREOPT_SPEED_APPS))$(filter $(_dexname),$(PRODUCT_SYSTEM_SERVER_APPS)),, \
        $(if $(strip $(foreach myfilter,$(SYSTEM_OTHER_ODEX_FILTER),$(filter system/$(myfilter),$(_dexlocation)))), \
          system_other/)))))
  # _dexdir has a trailing /
  _dexdir := $(_system_other)$(dir $(_dexlocation))
  my_dexpreopt_zip_contents := $(sort \
    $(foreach arch,$(my_dexpreopt_archs), \
      $(_dexdir)oat/$(arch)/$(_dexname).odex \
      $(_dexdir)oat/$(arch)/$(_dexname).vdex \
      $(if $(filter false,$(LOCAL_DEX_PREOPT_APP_IMAGE)),, \
        $(if $(my_process_profile)$(filter true,$(LOCAL_DEX_PREOPT_APP_IMAGE)), \
          $(_dexdir)oat/$(arch)/$(_dexname).art))) \
    $(if $(my_process_profile),$(_dexlocation).prof))
  _dexlocation :=
  _dexdir :=
  _dexname :=
  _system_other :=

  my_dexpreopt_zip := $(intermediates)/dexpreopt.zip
  $(my_dexpreopt_zip): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_zip): $(my_dexpreopt_deps)
  $(my_dexpreopt_zip): | $(DEXPREOPT_GEN_DEPS)
  $(my_dexpreopt_zip): .KATI_DEPFILE := $(my_dexpreopt_zip).d
  $(my_dexpreopt_zip): PRIVATE_DEX := $(my_dex_jar)
  $(my_dexpreopt_zip): PRIVATE_SCRIPT := $(my_dexpreopt_script)
  $(my_dexpreopt_zip): PRIVATE_ZIP_CONTENTS := $(my_dexpreopt_zip_contents)
  $(my_dexpreopt_zip): $(my_dexpreopt_script)
	@echo "$(PRIVATE_MODULE) dexpreopt"
	rm -f $@
	echo -n > $@.contents
	$(foreach f,$(PRIVATE_ZIP_CONTENTS),echo "$(f)" >> $@.contents$(newline))
	bash $(PRIVATE_SCRIPT) $(PRIVATE_DEX) $@
	if ! diff <(zipinfo -1 $@ | sort) $@.contents >&2; then \
	  echo "Contents of $@ did not match what make was expecting." >&2 && exit 1; \
	fi

  $(foreach installed_dex_file,$(my_dexpreopt_zip_contents),\
    $(eval $(PRODUCT_OUT)/$(installed_dex_file): $(my_dexpreopt_zip) \
$(newline)	unzip -qoDD -d $(PRODUCT_OUT) $(my_dexpreopt_zip) $(installed_dex_file)))

  ALL_MODULES.$(my_register_name).INSTALLED += $(addprefix $(PRODUCT_OUT)/,$(my_dexpreopt_zip_contents))

  # Normally this happens in sbom.mk, which is included from base_rules.mk. But since
  # dex_preopt_odex_install.mk is included after base_rules.mk, it misses these odex files.
  $(foreach installed_file,$(addprefix $(PRODUCT_OUT)/,$(my_dexpreopt_zip_contents)), \
    $(eval ALL_INSTALLED_FILES.$(installed_file) := $(my_register_name)))

  my_dexpreopt_config :=
  my_dexpreopt_config_for_postprocessing :=
  my_dexpreopt_jar_copy :=
  my_dexpreopt_product_packages :=
  my_dexpreopt_script :=
  my_dexpreopt_zip :=
  my_dexpreopt_zip_contents :=
endif # LOCAL_DEX_PREOPT
endif # my_create_dexpreopt_config

my_dexpreopt_libs_all :=
