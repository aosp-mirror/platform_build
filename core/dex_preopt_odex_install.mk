# dexpreopt_odex_install.mk is used to define odex creation rules for JARs and APKs
# This file depends on variables set in base_rules.mk
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

# Only enable preopt for non tests.
ifneq (,$(filter $(LOCAL_MODULE_TAGS),tests))
  LOCAL_DEX_PREOPT :=
endif

# If we have product-specific config for this module?
ifneq (,$(filter $(LOCAL_MODULE),$(DEXPREOPT_DISABLED_MODULES)))
  LOCAL_DEX_PREOPT :=
endif

# Disable preopt for TARGET_BUILD_APPS
ifneq (,$(TARGET_BUILD_APPS))
  LOCAL_DEX_PREOPT :=
endif

# Disable preopt if not WITH_DEXPREOPT
ifneq (true,$(WITH_DEXPREOPT))
  LOCAL_DEX_PREOPT :=
endif

ifdef LOCAL_UNINSTALLABLE_MODULE
  LOCAL_DEX_PREOPT :=
endif

ifeq (,$(strip $(built_dex)$(my_prebuilt_src_file)$(LOCAL_SOONG_DEX_JAR))) # contains no java code
  LOCAL_DEX_PREOPT :=
endif

# if WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY=true and module is not in boot class path skip
# Also preopt system server jars since selinux prevents system server from loading anything from
# /data. If we don't do this they will need to be extracted which is not favorable for RAM usage
# or performance. If my_preopt_for_extracted_apk is true, we ignore the only preopt boot image
# options.
ifneq (true,$(my_preopt_for_extracted_apk))
  ifeq (true,$(WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY))
    ifeq ($(filter $(PRODUCT_SYSTEM_SERVER_JARS) $(DEXPREOPT_BOOT_JARS_MODULES),$(LOCAL_MODULE)),)
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

# If LOCAL_ENFORCE_USES_LIBRARIES is not set, default to true if either of LOCAL_USES_LIBRARIES or
# LOCAL_OPTIONAL_USES_LIBRARIES are specified.
ifeq (,$(LOCAL_ENFORCE_USES_LIBRARIES))
  # Will change the default to true unconditionally in the future.
  ifneq (,$(LOCAL_OPTIONAL_USES_LIBRARIES))
    LOCAL_ENFORCE_USES_LIBRARIES := true
  endif
  ifneq (,$(LOCAL_USES_LIBRARIES))
    LOCAL_ENFORCE_USES_LIBRARIES := true
  endif
endif

my_dexpreopt_archs :=
my_dexpreopt_images :=
my_dexpreopt_infix := boot
ifeq (true, $(DEXPREOPT_USE_APEX_IMAGE))
  my_dexpreopt_infix := apex
endif

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
    # Odex for the 2nd arch
    ifdef TARGET_2ND_ARCH
      ifneq ($(TARGET_TRANSLATE_2ND_ARCH),true)
        ifneq (first,$(my_module_multilib))
          my_dexpreopt_archs += $(TARGET_2ND_ARCH)
          my_dexpreopt_images += $(DEXPREOPT_IMAGE_$(my_dexpreopt_infix)_$(TARGET_2ND_ARCH))
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
    ifdef TARGET_2ND_ARCH
      ifeq ($(my_module_multilib),both)
        # The non-preferred arch
        my_2nd_arch_prefix := $(if $(LOCAL_2ND_ARCH_VAR_PREFIX),,$(TARGET_2ND_ARCH_VAR_PREFIX))
        my_dexpreopt_archs += $(TARGET_$(my_2nd_arch_prefix)ARCH)
        my_dexpreopt_images += \
            $(DEXPREOPT_IMAGE_$(my_dexpreopt_infix)_$(TARGET_$(my_2nd_arch_prefix)ARCH))
      endif  # LOCAL_MULTILIB is both
    endif  # TARGET_2ND_ARCH
  endif  # LOCAL_MODULE_CLASS

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

  # DexPath, StripInputPath, and StripOutputPath are not set, they will
  # be filled in by dexpreopt_gen.

  $(call add_json_str,  Name,                           $(LOCAL_MODULE))
  $(call add_json_str,  DexLocation,                    $(patsubst $(PRODUCT_OUT)%,%,$(LOCAL_INSTALLED_MODULE)))
  $(call add_json_str,  BuildPath,                      $(LOCAL_BUILT_MODULE))
  $(call add_json_str,  ExtrasOutputPath,               $$2)
  $(call add_json_bool, Privileged,                     $(filter true,$(LOCAL_PRIVILEGED_MODULE)))
  $(call add_json_bool, UncompressedDex,                $(filter true,$(LOCAL_UNCOMPRESS_DEX)))
  $(call add_json_bool, HasApkLibraries,                $(LOCAL_APK_LIBRARIES))
  $(call add_json_list, PreoptFlags,                    $(LOCAL_DEX_PREOPT_FLAGS))
  $(call add_json_str,  ProfileClassListing,            $(if $(my_process_profile),$(LOCAL_DEX_PREOPT_PROFILE)))
  $(call add_json_bool, ProfileIsTextListing,           $(my_profile_is_text_listing))
  $(call add_json_bool, EnforceUsesLibraries,           $(LOCAL_ENFORCE_USES_LIBRARIES))
  $(call add_json_list, OptionalUsesLibraries,          $(LOCAL_OPTIONAL_USES_LIBRARIES))
  $(call add_json_list, UsesLibraries,                  $(LOCAL_USES_LIBRARIES))
  $(call add_json_map,  LibraryPaths)
  $(foreach lib,$(sort $(LOCAL_USES_LIBRARIES) $(LOCAL_OPTIONAL_USES_LIBRARIES) org.apache.http.legacy android.hidl.base-V1.0-java android.hidl.manager-V1.0-java),\
    $(call add_json_str, $(lib), $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/javalib.jar))
  $(call end_json_map)
  $(call add_json_list, Archs,                          $(my_dexpreopt_archs))
  $(call add_json_list, DexPreoptImages,                $(my_dexpreopt_images))
  $(call add_json_list, PreoptBootClassPathDexFiles,    $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES))
  $(call add_json_list, PreoptBootClassPathDexLocations,$(DEXPREOPT_BOOTCLASSPATH_DEX_LOCATIONS))
  $(call add_json_bool, PreoptExtractedApk,             $(my_preopt_for_extracted_apk))
  $(call add_json_bool, NoCreateAppImage,               $(filter false,$(LOCAL_DEX_PREOPT_APP_IMAGE)))
  $(call add_json_bool, ForceCreateAppImage,            $(filter true,$(LOCAL_DEX_PREOPT_APP_IMAGE)))
  $(call add_json_bool, PresignedPrebuilt,              $(filter PRESIGNED,$(LOCAL_CERTIFICATE)))

  $(call add_json_bool, NoStripping,                    $(filter nostripping,$(LOCAL_DEX_PREOPT)))

  $(call json_end)

  my_dexpreopt_config := $(intermediates)/dexpreopt.config
  my_dexpreopt_script := $(intermediates)/dexpreopt.sh
  my_strip_script := $(intermediates)/strip.sh
  my_dexpreopt_zip := $(intermediates)/dexpreopt.zip

  $(my_dexpreopt_config): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_config): PRIVATE_CONTENTS := $(json_contents)
  $(my_dexpreopt_config):
	@echo "$(PRIVATE_MODULE) dexpreopt.config"
	echo -e -n '$(subst $(newline),\n,$(subst ','\'',$(subst \,\\,$(PRIVATE_CONTENTS))))' > $@

  .KATI_RESTAT: $(my_dexpreopt_script) $(my_strip_script)
  $(my_dexpreopt_script): PRIVATE_MODULE := $(LOCAL_MODULE)
  $(my_dexpreopt_script): PRIVATE_GLOBAL_CONFIG := $(PRODUCT_OUT)/dexpreopt.config
  $(my_dexpreopt_script): PRIVATE_MODULE_CONFIG := $(my_dexpreopt_config)
  $(my_dexpreopt_script): PRIVATE_STRIP_SCRIPT := $(my_strip_script)
  $(my_dexpreopt_script): .KATI_IMPLICIT_OUTPUTS := $(my_strip_script)
  $(my_dexpreopt_script): $(DEXPREOPT_GEN)
  $(my_dexpreopt_script): $(my_dexpreopt_config) $(PRODUCT_OUT)/dexpreopt.config
	@echo "$(PRIVATE_MODULE) dexpreopt gen"
	$(DEXPREOPT_GEN) -global $(PRIVATE_GLOBAL_CONFIG) -module $(PRIVATE_MODULE_CONFIG) \
	-dexpreopt_script $@ -strip_script $(PRIVATE_STRIP_SCRIPT) \
	-out_dir $(OUT_DIR)

  my_dexpreopt_deps := $(my_dex_jar)
  my_dexpreopt_deps += $(if $(my_process_profile),$(LOCAL_DEX_PREOPT_PROFILE))
  my_dexpreopt_deps += \
    $(foreach lib,$(sort $(LOCAL_USES_LIBRARIES) $(LOCAL_OPTIONAL_USES_LIBRARIES) org.apache.http.legacy android.hidl.base-V1.0-java android.hidl.manager-V1.0-java),\
      $(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/javalib.jar)
  my_dexpreopt_deps += $(my_dexpreopt_images)
  my_dexpreopt_deps += $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES)

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
    ( unzip -qo -d $(PRODUCT_OUT) $(my_dexpreopt_zip) 2>&1 | grep -v "zipfile is empty"; exit $${PIPESTATUS[0]} ) || \
      ( code=$$?; if [ $$code -ne 0 -a $$code -ne 1 ]; then exit $$code; fi )

  $(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := $(LOCAL_POST_INSTALL_CMD)
  $(LOCAL_INSTALLED_MODULE): $(my_dexpreopt_zip)

  $(my_all_targets): $(my_dexpreopt_zip)

  my_dexpreopt_config :=
  my_dexpreopt_script :=
  my_strip_script :=
  my_dexpreopt_zip :=
endif # LOCAL_DEX_PREOPT
