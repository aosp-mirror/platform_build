DEX_PREOPT_CONFIG := $(SOONG_OUT_DIR)/dexpreopt.config

# The default value for LOCAL_DEX_PREOPT
DEX_PREOPT_DEFAULT ?= true

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

# Conditional to building on linux, as dex2oat currently does not work on darwin.
ifeq ($(HOST_OS),linux)
  ifeq (eng,$(TARGET_BUILD_VARIANT))
    # For an eng build only pre-opt the boot image and system server. This gives reasonable performance
    # and still allows a simple workflow: building in frameworks/base and syncing.
    WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY ?= true
  endif
  # Add mini-debug-info to the boot classpath unless explicitly asked not to.
  ifneq (false,$(WITH_DEXPREOPT_DEBUG_INFO))
    PRODUCT_DEX_PREOPT_BOOT_FLAGS += --generate-mini-debug-info
  endif

  # Non eng linux builds must have preopt enabled so that system server doesn't run as interpreter
  # only. b/74209329
  ifeq (,$(filter eng, $(TARGET_BUILD_VARIANT)))
    ifneq (true,$(WITH_DEXPREOPT))
      ifneq (true,$(WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY))
        $(call pretty-error, DEXPREOPT must be enabled for user and userdebug builds)
      endif
    endif
  endif
endif

# Use the first preloaded-classes file in PRODUCT_COPY_FILES.
PRELOADED_CLASSES := $(call word-colon,1,$(firstword \
    $(filter %system/etc/preloaded-classes,$(PRODUCT_COPY_FILES))))

# Use the first dirty-image-objects file in PRODUCT_COPY_FILES.
DIRTY_IMAGE_OBJECTS := $(call word-colon,1,$(firstword \
    $(filter %system/etc/dirty-image-objects,$(PRODUCT_COPY_FILES))))

define get-product-default-property
$(strip \
  $(eval _prop := $(patsubst $(1)=%,%,$(filter $(1)=%,$(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))))\
  $(if $(_prop),$(_prop),$(patsubst $(1)=%,%,$(filter $(1)=%,$(PRODUCT_SYSTEM_DEFAULT_PROPERTIES)))))
endef

DEX2OAT_IMAGE_XMS := $(call get-product-default-property,dalvik.vm.image-dex2oat-Xms)
DEX2OAT_IMAGE_XMX := $(call get-product-default-property,dalvik.vm.image-dex2oat-Xmx)
DEX2OAT_XMS := $(call get-product-default-property,dalvik.vm.dex2oat-Xms)
DEX2OAT_XMX := $(call get-product-default-property,dalvik.vm.dex2oat-Xmx)

ifeq ($(WRITE_SOONG_VARIABLES),true)

  $(call json_start)

  $(call add_json_bool, DisablePreopt,                      $(call invert_bool,$(and $(filter true,$(PRODUCT_USES_DEFAULT_ART_CONFIG)),$(filter true,$(WITH_DEXPREOPT)))))
  $(call add_json_list, DisablePreoptModules,               $(DEXPREOPT_DISABLED_MODULES))
  $(call add_json_bool, OnlyPreoptBootImageAndSystemServer, $(filter true,$(WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY)))
  $(call add_json_bool, UseArtImage,                        $(filter true,$(DEXPREOPT_USE_ART_IMAGE)))
  $(call add_json_bool, DontUncompressPrivAppsDex,          $(filter true,$(DONT_UNCOMPRESS_PRIV_APPS_DEXS)))
  $(call add_json_list, ModulesLoadedByPrivilegedModules,   $(PRODUCT_LOADED_BY_PRIVILEGED_MODULES))
  $(call add_json_bool, HasSystemOther,                     $(BOARD_USES_SYSTEM_OTHER_ODEX))
  $(call add_json_list, PatternsOnSystemOther,              $(SYSTEM_OTHER_ODEX_FILTER))
  $(call add_json_bool, DisableGenerateProfile,             $(filter false,$(WITH_DEX_PREOPT_GENERATE_PROFILE)))
  $(call add_json_str,  ProfileDir,                         $(PRODUCT_DEX_PREOPT_PROFILE_DIR))
  $(call add_json_list, BootJars,                           $(PRODUCT_BOOT_JARS))
  $(call add_json_list, UpdatableBootJars,                  $(PRODUCT_UPDATABLE_BOOT_JARS))
  $(call add_json_list, ArtApexJars,                        $(ART_APEX_JARS))
  $(call add_json_list, SystemServerJars,                   $(PRODUCT_SYSTEM_SERVER_JARS))
  $(call add_json_list, SystemServerApps,                   $(PRODUCT_SYSTEM_SERVER_APPS))
  $(call add_json_list, UpdatableSystemServerJars,          $(PRODUCT_UPDATABLE_SYSTEM_SERVER_JARS))
  $(call add_json_list, SpeedApps,                          $(PRODUCT_DEXPREOPT_SPEED_APPS))
  $(call add_json_list, PreoptFlags,                        $(PRODUCT_DEX_PREOPT_DEFAULT_FLAGS))
  $(call add_json_str,  DefaultCompilerFilter,              $(PRODUCT_DEX_PREOPT_DEFAULT_COMPILER_FILTER))
  $(call add_json_str,  SystemServerCompilerFilter,         $(PRODUCT_SYSTEM_SERVER_COMPILER_FILTER))
  $(call add_json_bool, GenerateDmFiles,                    $(PRODUCT_DEX_PREOPT_GENERATE_DM_FILES))
  $(call add_json_bool, NeverAllowStripping,                $(PRODUCT_DEX_PREOPT_NEVER_ALLOW_STRIPPING))
  $(call add_json_bool, NoDebugInfo,                        $(filter false,$(WITH_DEXPREOPT_DEBUG_INFO)))
  $(call add_json_bool, DontResolveStartupStrings,          $(filter false,$(PRODUCT_DEX_PREOPT_RESOLVE_STARTUP_STRINGS)))
  $(call add_json_bool, AlwaysSystemServerDebugInfo,        $(filter true,$(PRODUCT_SYSTEM_SERVER_DEBUG_INFO)))
  $(call add_json_bool, NeverSystemServerDebugInfo,         $(filter false,$(PRODUCT_SYSTEM_SERVER_DEBUG_INFO)))
  $(call add_json_bool, AlwaysOtherDebugInfo,               $(filter true,$(PRODUCT_OTHER_JAVA_DEBUG_INFO)))
  $(call add_json_bool, NeverOtherDebugInfo,                $(filter false,$(PRODUCT_OTHER_JAVA_DEBUG_INFO)))
  $(call add_json_bool, IsEng,                              $(filter eng,$(TARGET_BUILD_VARIANT)))
  $(call add_json_bool, SanitizeLite,                       $(SANITIZE_LITE))
  $(call add_json_bool, DefaultAppImages,                   $(WITH_DEX_PREOPT_APP_IMAGE))
  $(call add_json_str,  Dex2oatXmx,                         $(DEX2OAT_XMX))
  $(call add_json_str,  Dex2oatXms,                         $(DEX2OAT_XMS))
  $(call add_json_str,  EmptyDirectory,                     $(OUT_DIR)/empty)

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

  $(call add_json_str,  DirtyImageObjects,                  $(DIRTY_IMAGE_OBJECTS))
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
