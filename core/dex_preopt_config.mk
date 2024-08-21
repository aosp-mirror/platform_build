DEX_PREOPT_CONFIG := $(SOONG_OUT_DIR)/dexpreopt.config

ENABLE_PREOPT := true
ENABLE_PREOPT_BOOT_IMAGES := true
ifneq (true,$(filter true,$(WITH_DEXPREOPT)))
  # Disable dexpreopt for libraries/apps and for boot images.
  ENABLE_PREOPT :=
  ENABLE_PREOPT_BOOT_IMAGES :=
else ifneq (true,$(filter true,$(PRODUCT_USES_DEFAULT_ART_CONFIG)))
  # Disable dexpreopt for libraries/apps and for boot images: not having default
  # ART config means that some important system properties are not set, which
  # would result in passing bad arguments to dex2oat and failing the build.
  ENABLE_PREOPT :=
  ENABLE_PREOPT_BOOT_IMAGES :=
else
  ifeq (true,$(DISABLE_PREOPT))
    # Disable dexpreopt for libraries/apps, but may compile boot images.
    ENABLE_PREOPT :=
  endif
  ifeq (true,$(DISABLE_PREOPT_BOOT_IMAGES))
    # Disable dexpreopt for boot images, but may compile libraries/apps.
    ENABLE_PREOPT_BOOT_IMAGES :=
  endif
endif

# The default value for LOCAL_DEX_PREOPT
DEX_PREOPT_DEFAULT ?= $(ENABLE_PREOPT)

# Whether to fail immediately if verify_uses_libraries check fails, or to keep
# going and restrict dexpreopt to not compile any code for the failed module.
#
# The intended use case for this flag is to have a smoother migration path for
# the Java modules that need to add <uses-library> information in their build
# files. The flag allows to quickly silence build errors. This flag should be
# used with caution and only as a temporary measure, as it masks real errors
# and affects performance.
ifndef RELAX_USES_LIBRARY_CHECK
  RELAX_USES_LIBRARY_CHECK := $(if \
    $(filter true,$(PRODUCT_BROKEN_VERIFY_USES_LIBRARIES)),true,false)
else
  # Let the environment variable override PRODUCT_BROKEN_VERIFY_USES_LIBRARIES.
endif
.KATI_READONLY := RELAX_USES_LIBRARY_CHECK

# The default filter for which files go into the system_other image (if it is
# being used). Note that each pattern p here matches both '/<p>' and /system/<p>'.
# To bundle everything one should set this to '%'.
SYSTEM_OTHER_ODEX_FILTER ?= \
    app/% \
    priv-app/% \
    system_ext/app/% \
    system_ext/priv-app/% \
    product/app/% \
    product/priv-app/% \

# Global switch to control if updatable boot jars are included in dexpreopt.
DEX_PREOPT_WITH_UPDATABLE_BCP := true

# Conditional to building on linux, as dex2oat currently does not work on darwin.
ifeq ($(HOST_OS),linux)
  # Add mini-debug-info to the boot classpath unless explicitly asked not to.
  ifneq (false,$(WITH_DEXPREOPT_DEBUG_INFO))
    PRODUCT_DEX_PREOPT_BOOT_FLAGS += --generate-mini-debug-info
  endif
endif

# Get value of a property. It is first searched from PRODUCT_VENDOR_PROPERTIES
# and then falls back to PRODUCT_SYSTEM_PROPERTIES
# $1: name of the property
define get-product-default-property
$(strip \
  $(eval _prop := $(patsubst $(1)=%,%,$(filter $(1)=%,$(PRODUCT_VENDOR_PROPERTIES))))\
  $(if $(_prop),$(_prop),$(patsubst $(1)=%,%,$(filter $(1)=%,$(PRODUCT_SYSTEM_PROPERTIES)))))
endef

DEX2OAT_IMAGE_XMS := $(call get-product-default-property,dalvik.vm.image-dex2oat-Xms)
DEX2OAT_IMAGE_XMX := $(call get-product-default-property,dalvik.vm.image-dex2oat-Xmx)
DEX2OAT_XMS := $(call get-product-default-property,dalvik.vm.dex2oat-Xms)
DEX2OAT_XMX := $(call get-product-default-property,dalvik.vm.dex2oat-Xmx)

ifeq ($(WRITE_SOONG_VARIABLES),true)

  $(call json_start)

  $(call add_json_bool, DisablePreopt,                           $(call invert_bool,$(ENABLE_PREOPT)))
  $(call add_json_bool, DisablePreoptBootImages,                 $(call invert_bool,$(ENABLE_PREOPT_BOOT_IMAGES)))
  $(call add_json_list, DisablePreoptModules,                    $(DEXPREOPT_DISABLED_MODULES))
  $(call add_json_bool, OnlyPreoptArtBootImage            ,      $(filter true,$(WITH_DEXPREOPT_ART_BOOT_IMG_ONLY)))
  $(call add_json_bool, PreoptWithUpdatableBcp,                  $(filter true,$(DEX_PREOPT_WITH_UPDATABLE_BCP)))
  $(call add_json_bool, DontUncompressPrivAppsDex,               $(filter true,$(DONT_UNCOMPRESS_PRIV_APPS_DEXS)))
  $(call add_json_list, ModulesLoadedByPrivilegedModules,        $(PRODUCT_LOADED_BY_PRIVILEGED_MODULES))
  $(call add_json_bool, HasSystemOther,                          $(BOARD_USES_SYSTEM_OTHER_ODEX))
  $(call add_json_list, PatternsOnSystemOther,                   $(SYSTEM_OTHER_ODEX_FILTER))
  $(call add_json_bool, DisableGenerateProfile,                  $(filter false,$(WITH_DEX_PREOPT_GENERATE_PROFILE)))
  $(call add_json_str,  ProfileDir,                              $(PRODUCT_DEX_PREOPT_PROFILE_DIR))
  $(call add_json_list, BootJars,                                $(PRODUCT_BOOT_JARS))
  $(call add_json_list, ApexBootJars,                            $(filter-out $(APEX_BOOT_JARS_EXCLUDED), $(PRODUCT_APEX_BOOT_JARS)))
  $(call add_json_list, ArtApexJars,                             $(filter $(PRODUCT_BOOT_JARS),$(ART_APEX_JARS)))
  $(call add_json_list, TestOnlyArtBootImageJars,                $(PRODUCT_TEST_ONLY_ART_BOOT_IMAGE_JARS))
  $(call add_json_list, SystemServerJars,                        $(PRODUCT_SYSTEM_SERVER_JARS))
  $(call add_json_list, SystemServerApps,                        $(PRODUCT_SYSTEM_SERVER_APPS))
  $(call add_json_list, ApexSystemServerJars,                    $(PRODUCT_APEX_SYSTEM_SERVER_JARS))
  $(call add_json_list, StandaloneSystemServerJars,              $(PRODUCT_STANDALONE_SYSTEM_SERVER_JARS))
  $(call add_json_list, ApexStandaloneSystemServerJars,          $(PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS))
  $(call add_json_bool, BrokenSuboptimalOrderOfSystemServerJars, $(PRODUCT_BROKEN_SUBOPTIMAL_ORDER_OF_SYSTEM_SERVER_JARS))
  $(call add_json_list, SpeedApps,                               $(PRODUCT_DEXPREOPT_SPEED_APPS))
  $(call add_json_list, PreoptFlags,                             $(PRODUCT_DEX_PREOPT_DEFAULT_FLAGS))
  $(call add_json_str,  DefaultCompilerFilter,                   $(PRODUCT_DEX_PREOPT_DEFAULT_COMPILER_FILTER))
  $(call add_json_str,  SystemServerCompilerFilter,              $(PRODUCT_SYSTEM_SERVER_COMPILER_FILTER))
  $(call add_json_bool, GenerateDmFiles,                         $(PRODUCT_DEX_PREOPT_GENERATE_DM_FILES))
  $(call add_json_bool, NeverAllowStripping,                     $(PRODUCT_DEX_PREOPT_NEVER_ALLOW_STRIPPING))
  $(call add_json_bool, NoDebugInfo,                             $(filter false,$(WITH_DEXPREOPT_DEBUG_INFO)))
  $(call add_json_bool, DontResolveStartupStrings,               $(filter false,$(PRODUCT_DEX_PREOPT_RESOLVE_STARTUP_STRINGS)))
  $(call add_json_bool, AlwaysSystemServerDebugInfo,             $(filter true,$(PRODUCT_SYSTEM_SERVER_DEBUG_INFO)))
  $(call add_json_bool, NeverSystemServerDebugInfo,              $(filter false,$(PRODUCT_SYSTEM_SERVER_DEBUG_INFO)))
  $(call add_json_bool, AlwaysOtherDebugInfo,                    $(filter true,$(PRODUCT_OTHER_JAVA_DEBUG_INFO)))
  $(call add_json_bool, NeverOtherDebugInfo,                     $(filter false,$(PRODUCT_OTHER_JAVA_DEBUG_INFO)))
  $(call add_json_bool, IsEng,                                   $(filter eng,$(TARGET_BUILD_VARIANT)))
  $(call add_json_bool, SanitizeLite,                            $(SANITIZE_LITE))
  $(call add_json_bool, DefaultAppImages,                        $(WITH_DEX_PREOPT_APP_IMAGE))
  $(call add_json_bool, RelaxUsesLibraryCheck,                   $(filter true,$(RELAX_USES_LIBRARY_CHECK)))
  $(call add_json_str,  Dex2oatXmx,                              $(DEX2OAT_XMX))
  $(call add_json_str,  Dex2oatXms,                              $(DEX2OAT_XMS))
  $(call add_json_str,  EmptyDirectory,                          $(OUT_DIR)/empty)
  $(call add_json_str,  EnableUffdGc,                            $(ENABLE_UFFD_GC))

ifdef TARGET_ARCH
  $(call add_json_map,  CpuVariant)
  $(call add_json_str,  $(TARGET_ARCH), $(DEX2OAT_TARGET_CPU_VARIANT))
  ifdef TARGET_2ND_ARCH
    $(call add_json_str, $(TARGET_2ND_ARCH), $($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT))
  endif
  $(call end_json_map)

  $(call add_json_map,  InstructionSetFeatures)
  $(call add_json_str,  $(TARGET_ARCH), $(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES))
  ifdef TARGET_2ND_ARCH
    $(call add_json_str, $(TARGET_2ND_ARCH), $($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES))
  endif
  $(call end_json_map)
endif

  $(call add_json_list, BootImageProfiles,                  $(PRODUCT_DEX_PREOPT_BOOT_IMAGE_PROFILE_LOCATION))
  $(call add_json_str,  BootFlags,                          $(PRODUCT_DEX_PREOPT_BOOT_FLAGS))
  $(call add_json_str,  Dex2oatImageXmx,                    $(DEX2OAT_IMAGE_XMX))
  $(call add_json_str,  Dex2oatImageXms,                    $(DEX2OAT_IMAGE_XMS))

  $(call json_end)

  $(shell mkdir -p $(dir $(DEX_PREOPT_CONFIG)))
  $(file >$(DEX_PREOPT_CONFIG).tmp,$(json_contents))

  $(shell \
    if ! cmp -s $(DEX_PREOPT_CONFIG).tmp $(DEX_PREOPT_CONFIG); then \
      mv $(DEX_PREOPT_CONFIG).tmp $(DEX_PREOPT_CONFIG); \
    else \
      rm $(DEX_PREOPT_CONFIG).tmp; \
    fi)
endif
