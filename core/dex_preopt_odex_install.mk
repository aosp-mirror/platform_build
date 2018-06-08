# dexpreopt_odex_install.mk is used to define odex creation rules for JARs and APKs
# This file depends on variables set in base_rules.mk
# Output variables: LOCAL_DEX_PREOPT, LOCAL_UNCOMPRESS_DEX, built_odex,
#                   dexpreopt_boot_jar_module

# We explicitly uncompress APKs of privileged apps, and used by
# privileged apps
LOCAL_UNCOMPRESS_DEX := false
ifneq (true,$(DONT_UNCOMPRESS_PRIV_APPS_DEXS))
ifeq (true,$(LOCAL_PRIVILEGED_MODULE))
  LOCAL_UNCOMPRESS_DEX := true
else
  ifneq (,$(filter $(PRODUCT_LOADED_BY_PRIVILEGED_MODULES), $(LOCAL_MODULE)))
    LOCAL_UNCOMPRESS_DEX := true
  endif  # PRODUCT_LOADED_BY_PRIVILEGED_MODULES
endif  # LOCAL_PRIVILEGED_MODULE
endif  # DONT_UNCOMPRESS_PRIV_APPS_DEXS

# Setting LOCAL_DEX_PREOPT based on WITH_DEXPREOPT, LOCAL_DEX_PREOPT, etc
LOCAL_DEX_PREOPT := $(strip $(LOCAL_DEX_PREOPT))
ifneq (true,$(WITH_DEXPREOPT))
  LOCAL_DEX_PREOPT :=
else # WITH_DEXPREOPT=true
  ifeq (,$(TARGET_BUILD_APPS)) # TARGET_BUILD_APPS empty
    ifndef LOCAL_DEX_PREOPT # LOCAL_DEX_PREOPT undefined
      ifneq ($(filter $(TARGET_OUT)/%,$(my_module_path)),) # Installed to system.img.
        ifeq (,$(LOCAL_APK_LIBRARIES)) # LOCAL_APK_LIBRARIES empty
          # If we have product-specific config for this module?
          ifeq (disable,$(DEXPREOPT.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG))
            LOCAL_DEX_PREOPT := false
          else
            LOCAL_DEX_PREOPT := $(DEX_PREOPT_DEFAULT)
          endif
        else # LOCAL_APK_LIBRARIES not empty
          LOCAL_DEX_PREOPT := nostripping
        endif # LOCAL_APK_LIBRARIES not empty
      endif # Installed to system.img.
    endif # LOCAL_DEX_PREOPT undefined
  endif # TARGET_BUILD_APPS empty
endif # WITH_DEXPREOPT=true
ifeq (false,$(LOCAL_DEX_PREOPT))
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

ifeq ($(LOCAL_DEX_PREOPT),true)

# Don't strip with dexes we explicitly uncompress (dexopt will not store the dex code).
ifeq ($(LOCAL_UNCOMPRESS_DEX),true)
LOCAL_DEX_PREOPT := nostripping
endif  # LOCAL_UNCOMPRESS_DEX

# system_other isn't there for an OTA, so don't strip
# if module is on system, and odex is on system_other.
ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
ifneq ($(call install-on-system-other, $(my_module_path)),)
LOCAL_DEX_PREOPT := nostripping
endif  # install-on-system-other
endif  # BOARD_USES_SYSTEM_OTHER_ODEX

# We also don't strip if all dexs are uncompressed (dexopt will not store the dex code),
# but that requires to inspect the source file, which is too early at this point (as we
# don't know if the source file will actually be used).
# See dexpreopt-remove-classes.dex.

endif  # LOCAL_DEX_PREOPT

built_odex :=
built_vdex :=
built_art :=
installed_odex :=
installed_vdex :=
installed_art :=
built_installed_odex :=
built_installed_vdex :=
built_installed_art :=
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
my_profile_is_text_listing := false
endif
else
my_process_profile := $(LOCAL_DEX_PREOPT_GENERATE_PROFILE)
my_profile_is_text_listing := true
LOCAL_DEX_PREOPT_PROFILE := $(LOCAL_DEX_PREOPT_PROFILE_CLASS_LISTING)
endif

ifeq (true,$(my_process_profile))

ifeq (,$(LOCAL_DEX_PREOPT_APP_IMAGE))
LOCAL_DEX_PREOPT_APP_IMAGE := true
endif

ifndef LOCAL_DEX_PREOPT_PROFILE
$(call pretty-error,Must have specified class listing (LOCAL_DEX_PREOPT_PROFILE))
endif
ifeq (,$(dex_preopt_profile_src_file))
$(call pretty-error, Internal error: dex_preopt_profile_src_file must be set)
endif
my_built_profile := $(dir $(LOCAL_BUILT_MODULE))/profile.prof
my_dex_location := $(patsubst $(PRODUCT_OUT)%,%,$(LOCAL_INSTALLED_MODULE))
# Remove compressed APK extension.
my_dex_location := $(patsubst %.gz,%,$(my_dex_location))
$(my_built_profile): PRIVATE_BUILT_MODULE := $(dex_preopt_profile_src_file)
$(my_built_profile): PRIVATE_DEX_LOCATION := $(my_dex_location)
$(my_built_profile): PRIVATE_SOURCE_CLASSES := $(LOCAL_DEX_PREOPT_PROFILE)
$(my_built_profile): $(LOCAL_DEX_PREOPT_PROFILE)
$(my_built_profile): $(PROFMAN)
$(my_built_profile): $(dex_preopt_profile_src_file)
ifeq (true,$(my_profile_is_text_listing))
# The profile is a test listing of classes (used for framework jars).
# We need to generate the actual binary profile before being able to compile.
	$(hide) mkdir -p $(dir $@)
	ANDROID_LOG_TAGS="*:e" $(PROFMAN) \
		--create-profile-from=$(PRIVATE_SOURCE_CLASSES) \
		--apk=$(PRIVATE_BUILT_MODULE) \
		--dex-location=$(PRIVATE_DEX_LOCATION) \
		--reference-profile-file=$@
else
# The profile is binary profile (used for apps). Run it through profman to
# ensure the profile keys match the apk.
$(my_built_profile):
	$(hide) mkdir -p $(dir $@)
	touch $@
	ANDROID_LOG_TAGS="*:i" $(PROFMAN) \
	  --copy-and-update-profile-key \
		--profile-file=$(PRIVATE_SOURCE_CLASSES) \
		--apk=$(PRIVATE_BUILT_MODULE) \
		--dex-location=$(PRIVATE_DEX_LOCATION) \
		--reference-profile-file=$@ \
	|| echo "Profile out of date for $(PRIVATE_BUILT_MODULE)"
endif

my_profile_is_text_listing :=
dex_preopt_profile_src_file :=

# Remove compressed APK extension.
my_installed_profile := $(patsubst %.gz,%,$(LOCAL_INSTALLED_MODULE)).prof

# my_installed_profile := $(LOCAL_INSTALLED_MODULE).prof
$(eval $(call copy-one-file,$(my_built_profile),$(my_installed_profile)))
build_installed_profile:=$(my_built_profile):$(my_installed_profile)
else
build_installed_profile:=
my_installed_profile :=
endif

ifdef LOCAL_DEX_PREOPT

dexpreopt_boot_jar_module := $(filter $(DEXPREOPT_BOOT_JARS_MODULES),$(LOCAL_MODULE))

# Filter org.apache.http.legacy.boot.
ifeq ($(dexpreopt_boot_jar_module),org.apache.http.legacy.boot)
dexpreopt_boot_jar_module :=
endif

ifdef dexpreopt_boot_jar_module
# For libart, the boot jars' odex files are replaced by $(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE).
# We use this installed_odex trick to get boot.art installed.
installed_odex := $(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE)
# Append the odex for the 2nd arch if we have one.
installed_odex += $($(TARGET_2ND_ARCH_VAR_PREFIX)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE)
else  # boot jar
ifeq ($(LOCAL_MODULE_CLASS),JAVA_LIBRARIES)
# For a Java library, by default we build odex for both 1st arch and 2nd arch.
# But it can be overridden with "LOCAL_MULTILIB := first".
ifneq (,$(filter $(PRODUCT_SYSTEM_SERVER_JARS),$(LOCAL_MODULE)))
# For system server jars, we build for only "first".
my_module_multilib := first
else
my_module_multilib := $(LOCAL_MULTILIB)
endif
# #################################################
# Odex for the 1st arch
my_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/setup_one_odex.mk
# #################################################
# Odex for the 2nd arch
ifdef TARGET_2ND_ARCH
ifneq ($(TARGET_TRANSLATE_2ND_ARCH),true)
ifneq (first,$(my_module_multilib))
my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/setup_one_odex.mk
endif  # my_module_multilib is not first.
endif  # TARGET_TRANSLATE_2ND_ARCH not true
endif  # TARGET_2ND_ARCH
# #################################################
else  # must be APPS
# The preferred arch
my_2nd_arch_prefix := $(LOCAL_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/setup_one_odex.mk
ifdef TARGET_2ND_ARCH
ifeq ($(LOCAL_MULTILIB),both)
# The non-preferred arch
my_2nd_arch_prefix := $(if $(LOCAL_2ND_ARCH_VAR_PREFIX),,$(TARGET_2ND_ARCH_VAR_PREFIX))
include $(BUILD_SYSTEM)/setup_one_odex.mk
endif  # LOCAL_MULTILIB is both
endif  # TARGET_2ND_ARCH
endif  # LOCAL_MODULE_CLASS
endif  # boot jar

built_odex := $(strip $(built_odex))
built_vdex := $(strip $(built_vdex))
built_art := $(strip $(built_art))
installed_odex := $(strip $(installed_odex))
installed_vdex := $(strip $(installed_vdex))
installed_art := $(strip $(installed_art))

ifdef built_odex
ifeq (true,$(my_process_profile))
$(built_odex): $(my_built_profile)
$(built_odex): PRIVATE_PROFILE_PREOPT_FLAGS := --profile-file=$(my_built_profile)
else
$(built_odex): PRIVATE_PROFILE_PREOPT_FLAGS :=
endif

ifndef LOCAL_DEX_PREOPT_FLAGS
LOCAL_DEX_PREOPT_FLAGS := $(DEXPREOPT.$(TARGET_PRODUCT).$(LOCAL_MODULE).CONFIG)
ifndef LOCAL_DEX_PREOPT_FLAGS
LOCAL_DEX_PREOPT_FLAGS := $(PRODUCT_DEX_PREOPT_DEFAULT_FLAGS)
endif
endif

my_system_server_compiler_filter := $(PRODUCT_SYSTEM_SERVER_COMPILER_FILTER)
ifeq (,$(my_system_server_compiler_filter))
my_system_server_compiler_filter := speed
endif

my_default_compiler_filter := $(PRODUCT_DEX_PREOPT_DEFAULT_COMPILER_FILTER)
ifeq (,$(my_default_compiler_filter))
# If no default compiler filter is specified, default to 'quicken' to save on storage.
my_default_compiler_filter := quicken
endif

ifeq (,$(filter --compiler-filter=%, $(LOCAL_DEX_PREOPT_FLAGS)))
  ifneq (,$(filter $(PRODUCT_SYSTEM_SERVER_JARS),$(LOCAL_MODULE)))
    # Jars of system server, use the product option if it is set, speed otherwise.
    LOCAL_DEX_PREOPT_FLAGS += --compiler-filter=$(my_system_server_compiler_filter)
  else
    ifneq (,$(filter $(PRODUCT_DEXPREOPT_SPEED_APPS) $(PRODUCT_SYSTEM_SERVER_APPS),$(LOCAL_MODULE)))
      # Apps loaded into system server, and apps the product default to being compiled with the
      # 'speed' compiler filter.
      LOCAL_DEX_PREOPT_FLAGS += --compiler-filter=speed
    else
      ifeq (true,$(my_process_profile))
        # For non system server jars, use speed-profile when we have a profile.
        LOCAL_DEX_PREOPT_FLAGS += --compiler-filter=speed-profile
      else
        LOCAL_DEX_PREOPT_FLAGS += --compiler-filter=$(my_default_compiler_filter)
      endif
    endif
  endif
endif

my_generate_dm := $(PRODUCT_DEX_PREOPT_GENERATE_DM_FILES)
ifeq (,$(filter $(LOCAL_DEX_PREOPT_FLAGS),--compiler-filter=verify))
# Generating DM files only makes sense for verify, avoid doing for non verify compiler filter APKs.
my_generate_dm := false
endif

# No reason to use a dm file if the dex is already uncompressed.
ifeq ($(LOCAL_UNCOMPRESS_DEX),true)
my_generate_dm := false
endif

ifeq (true,$(my_generate_dm))
LOCAL_DEX_PREOPT_FLAGS += --copy-dex-files=false
LOCAL_DEX_PREOPT := nostripping
my_built_dm := $(dir $(LOCAL_BUILT_MODULE))generated.dm
my_installed_dm := $(patsubst %.apk,%,$(LOCAL_INSTALLED_MODULE)).dm
my_copied_vdex := $(dir $(LOCAL_BUILT_MODULE))primary.vdex
$(eval $(call copy-one-file,$(built_vdex),$(my_copied_vdex)))
$(my_built_dm): PRIVATE_INPUT_VDEX := $(my_copied_vdex)
$(my_built_dm): $(my_copied_vdex) $(ZIPTIME)
	$(hide) mkdir -p $(dir $@)
	$(hide) rm -f $@
	$(hide) zip -qD -j -X -9 $@ $(PRIVATE_INPUT_VDEX)
	$(ZIPTIME) $@
$(eval $(call copy-one-file,$(my_built_dm),$(my_installed_dm)))
endif

# By default, emit debug info.
my_dexpreopt_debug_info := true
# If the global setting suppresses mini-debug-info, disable it.
ifeq (false,$(WITH_DEXPREOPT_DEBUG_INFO))
  my_dexpreopt_debug_info := false
endif

# PRODUCT_SYSTEM_SERVER_DEBUG_INFO overrides WITH_DEXPREOPT_DEBUG_INFO.
# PRODUCT_OTHER_JAVA_DEBUG_INFO overrides WITH_DEXPREOPT_DEBUG_INFO.
ifneq (,$(filter $(PRODUCT_SYSTEM_SERVER_JARS),$(LOCAL_MODULE)))
  ifeq (true,$(PRODUCT_SYSTEM_SERVER_DEBUG_INFO))
    my_dexpreopt_debug_info := true
  else ifeq (false,$(PRODUCT_SYSTEM_SERVER_DEBUG_INFO))
    my_dexpreopt_debug_info := false
  endif
else
  ifeq (true,$(PRODUCT_OTHER_JAVA_DEBUG_INFO))
    my_dexpreopt_debug_info := true
  else ifeq (false,$(PRODUCT_OTHER_JAVA_DEBUG_INFO))
    my_dexpreopt_debug_info := false
  endif
endif

# Never enable on eng.
ifeq (eng,$(filter eng, $(TARGET_BUILD_VARIANT)))
my_dexpreopt_debug_info := false
endif

# Add dex2oat flag for debug-info/no-debug-info.
ifeq (true,$(my_dexpreopt_debug_info))
  LOCAL_DEX_PREOPT_FLAGS += --generate-mini-debug-info
else ifeq (false,$(my_dexpreopt_debug_info))
  LOCAL_DEX_PREOPT_FLAGS += --no-generate-mini-debug-info
endif

# Set the compiler reason to 'prebuilt' to identify the oat files produced
# during the build, as opposed to compiled on the device.
LOCAL_DEX_PREOPT_FLAGS += --compilation-reason=prebuilt

$(built_odex): PRIVATE_DEX_PREOPT_FLAGS := $(LOCAL_DEX_PREOPT_FLAGS)
$(built_vdex): $(built_odex)
$(built_art): $(built_odex)
endif

ifneq (true,$(my_generate_dm))
  # Add the installed_odex to the list of installed files for this module if we aren't generating a
  # dm file.
  ALL_MODULES.$(my_register_name).INSTALLED += $(installed_odex)
  ALL_MODULES.$(my_register_name).INSTALLED += $(installed_vdex)
  ALL_MODULES.$(my_register_name).INSTALLED += $(installed_art)

  ALL_MODULES.$(my_register_name).BUILT_INSTALLED += $(built_installed_odex)
  ALL_MODULES.$(my_register_name).BUILT_INSTALLED += $(built_installed_vdex)
  ALL_MODULES.$(my_register_name).BUILT_INSTALLED += $(built_installed_art)

  # Make sure to install the .odex and .vdex when you run "make <module_name>"
  $(my_all_targets): $(installed_odex) $(installed_vdex) $(installed_art)
else
  ALL_MODULES.$(my_register_name).INSTALLED += $(my_installed_dm)
  ALL_MODULES.$(my_register_name).BUILT_INSTALLED += $(my_built_dm) $(my_installed_dm)

  # Make sure to install the .dm when you run "make <module_name>"
  $(my_all_targets): $(installed_dm)
endif

# Record dex-preopt config.
DEXPREOPT.$(LOCAL_MODULE).DEX_PREOPT := $(LOCAL_DEX_PREOPT)
DEXPREOPT.$(LOCAL_MODULE).MULTILIB := $(LOCAL_MULTILIB)
DEXPREOPT.$(LOCAL_MODULE).DEX_PREOPT_FLAGS := $(LOCAL_DEX_PREOPT_FLAGS)
DEXPREOPT.$(LOCAL_MODULE).PRIVILEGED_MODULE := $(LOCAL_PRIVILEGED_MODULE)
DEXPREOPT.$(LOCAL_MODULE).VENDOR_MODULE := $(LOCAL_VENDOR_MODULE)
DEXPREOPT.$(LOCAL_MODULE).TARGET_ARCH := $(LOCAL_MODULE_TARGET_ARCH)
DEXPREOPT.$(LOCAL_MODULE).INSTALLED := $(installed_odex)
DEXPREOPT.$(LOCAL_MODULE).INSTALLED_STRIPPED := $(LOCAL_INSTALLED_MODULE)
DEXPREOPT.MODULES.$(LOCAL_MODULE_CLASS) := $(sort \
  $(DEXPREOPT.MODULES.$(LOCAL_MODULE_CLASS)) $(LOCAL_MODULE))

endif # LOCAL_DEX_PREOPT

# Profile doesn't depend on LOCAL_DEX_PREOPT.
ALL_MODULES.$(my_register_name).INSTALLED += $(my_installed_profile)
ALL_MODULES.$(my_register_name).BUILT_INSTALLED += $(build_installed_profile)

my_process_profile :=

$(my_all_targets): $(my_installed_profile)
