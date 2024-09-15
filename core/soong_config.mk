SOONG_MAKEVARS_MK := $(SOONG_OUT_DIR)/make_vars-$(TARGET_PRODUCT)$(COVERAGE_SUFFIX).mk
SOONG_ANDROID_MK := $(SOONG_OUT_DIR)/Android-$(TARGET_PRODUCT)$(COVERAGE_SUFFIX).mk

include $(BUILD_SYSTEM)/art_config.mk
include $(BUILD_SYSTEM)/dex_preopt_config.mk

ifndef AFDO_PROFILES
# Set AFDO_PROFILES
-include vendor/google_data/pgo_profile/sampling/afdo_profiles.mk
include toolchain/pgo-profiles/sampling/afdo_profiles.mk
else
$(error AFDO_PROFILES can only be set from soong_config.mk. For product-specific fdo_profiles, please use PRODUCT_AFDO_PROFILES)
endif

# PRODUCT_AFDO_PROFILES takes precedence over product-agnostic profiles in AFDO_PROFILES
ALL_AFDO_PROFILES := $(PRODUCT_AFDO_PROFILES) $(AFDO_PROFILES)

ifneq (,$(filter-out environment undefined,$(origin GENRULE_SANDBOXING)))
  $(error GENRULE_SANDBOXING can only be provided via an environment variable, use BUILD_BROKEN_GENRULE_SANDBOXING to disable genrule sandboxing in board config)
endif

ifeq ($(WRITE_SOONG_VARIABLES),true)

# Create soong.variables with copies of makefile settings.  Runs every build,
# but only updates soong.variables if it changes
$(shell mkdir -p $(dir $(SOONG_VARIABLES)))
$(call json_start)

$(call add_json_str,  Make_suffix, -$(TARGET_PRODUCT)$(COVERAGE_SUFFIX))

$(call add_json_str,  BuildId,                           $(BUILD_ID))
$(call add_json_str,  BuildFingerprintFile,              build_fingerprint.txt)
$(call add_json_str,  BuildNumberFile,                   build_number.txt)
$(call add_json_str,  BuildHostnameFile,                 build_hostname.txt)
$(call add_json_str,  BuildThumbprintFile,               build_thumbprint.txt)
$(call add_json_bool, DisplayBuildNumber,                $(filter true,$(DISPLAY_BUILD_NUMBER)))

$(call add_json_str,  Platform_display_version_name,     $(PLATFORM_DISPLAY_VERSION))
$(call add_json_str,  Platform_version_name,             $(PLATFORM_VERSION))
$(call add_json_val,  Platform_sdk_version,              $(PLATFORM_SDK_VERSION))
$(call add_json_str,  Platform_sdk_codename,             $(PLATFORM_VERSION_CODENAME))
$(call add_json_bool, Platform_sdk_final,                $(filter REL,$(PLATFORM_VERSION_CODENAME)))
$(call add_json_val,  Platform_sdk_extension_version,    $(PLATFORM_SDK_EXTENSION_VERSION))
$(call add_json_val,  Platform_base_sdk_extension_version, $(PLATFORM_BASE_SDK_EXTENSION_VERSION))
$(call add_json_csv,  Platform_version_active_codenames, $(PLATFORM_VERSION_ALL_CODENAMES))
$(call add_json_csv,  Platform_version_all_preview_codenames, $(PLATFORM_VERSION_ALL_PREVIEW_CODENAMES))
$(call add_json_str,  Platform_security_patch,           $(PLATFORM_SECURITY_PATCH))
$(call add_json_str,  Platform_preview_sdk_version,      $(PLATFORM_PREVIEW_SDK_VERSION))
$(call add_json_str,  Platform_base_os,                  $(PLATFORM_BASE_OS))
$(call add_json_str,  Platform_version_last_stable,      $(PLATFORM_VERSION_LAST_STABLE))
$(call add_json_str,  Platform_version_known_codenames,  $(PLATFORM_VERSION_KNOWN_CODENAMES))

$(call add_json_bool, Release_aidl_use_unfrozen,         $(RELEASE_AIDL_USE_UNFROZEN))

$(call add_json_bool, Allow_missing_dependencies,        $(filter true,$(ALLOW_MISSING_DEPENDENCIES)))
$(call add_json_bool, Unbundled_build,                   $(TARGET_BUILD_UNBUNDLED))
$(call add_json_list, Unbundled_build_apps,              $(TARGET_BUILD_APPS))
$(call add_json_bool, Unbundled_build_image,             $(TARGET_BUILD_UNBUNDLED_IMAGE))
$(call add_json_bool, Always_use_prebuilt_sdks,          $(TARGET_BUILD_USE_PREBUILT_SDKS))

$(call add_json_bool, Debuggable,                        $(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
$(call add_json_bool, Eng,                               $(filter eng,$(TARGET_BUILD_VARIANT)))
$(call add_json_str,  BuildType,                         $(TARGET_BUILD_TYPE))

$(call add_json_str,  DeviceName,                        $(TARGET_DEVICE))
$(call add_json_str,  DeviceProduct,                     $(TARGET_PRODUCT))
$(call add_json_str,  DeviceArch,                        $(TARGET_ARCH))
$(call add_json_str,  DeviceArchVariant,                 $(TARGET_ARCH_VARIANT))
$(call add_json_str,  DeviceCpuVariant,                  $(TARGET_CPU_VARIANT))
$(call add_json_list, DeviceAbi,                         $(TARGET_CPU_ABI) $(TARGET_CPU_ABI2))

$(call add_json_str,  DeviceSecondaryArch,               $(TARGET_2ND_ARCH))
$(call add_json_str,  DeviceSecondaryArchVariant,        $(TARGET_2ND_ARCH_VARIANT))
$(call add_json_str,  DeviceSecondaryCpuVariant,         $(TARGET_2ND_CPU_VARIANT))
$(call add_json_list, DeviceSecondaryAbi,                $(TARGET_2ND_CPU_ABI) $(TARGET_2ND_CPU_ABI2))

$(call add_json_bool, Aml_abis,                          $(if $(filter mainline_sdk,$(TARGET_ARCH_SUITE)),true))
$(call add_json_bool, Ndk_abis,                          $(if $(filter ndk,         $(TARGET_ARCH_SUITE)),true))

$(call add_json_str,  NativeBridgeArch,                  $(TARGET_NATIVE_BRIDGE_ARCH))
$(call add_json_str,  NativeBridgeArchVariant,           $(TARGET_NATIVE_BRIDGE_ARCH_VARIANT))
$(call add_json_str,  NativeBridgeCpuVariant,            $(TARGET_NATIVE_BRIDGE_CPU_VARIANT))
$(call add_json_list, NativeBridgeAbi,                   $(TARGET_NATIVE_BRIDGE_ABI))
$(call add_json_str,  NativeBridgeRelativePath,          $(TARGET_NATIVE_BRIDGE_RELATIVE_PATH))

$(call add_json_str,  NativeBridgeSecondaryArch,         $(TARGET_NATIVE_BRIDGE_2ND_ARCH))
$(call add_json_str,  NativeBridgeSecondaryArchVariant,  $(TARGET_NATIVE_BRIDGE_2ND_ARCH_VARIANT))
$(call add_json_str,  NativeBridgeSecondaryCpuVariant,   $(TARGET_NATIVE_BRIDGE_2ND_CPU_VARIANT))
$(call add_json_list, NativeBridgeSecondaryAbi,          $(TARGET_NATIVE_BRIDGE_2ND_ABI))
$(call add_json_str,  NativeBridgeSecondaryRelativePath, $(TARGET_NATIVE_BRIDGE_2ND_RELATIVE_PATH))

$(call add_json_str,  HostArch,                          $(HOST_ARCH))
$(call add_json_str,  HostSecondaryArch,                 $(HOST_2ND_ARCH))
$(call add_json_bool, HostStaticBinaries,                $(BUILD_HOST_static))
$(call add_json_bool, HostMusl,                          $(USE_HOST_MUSL))

$(call add_json_str,  CrossHost,                         $(HOST_CROSS_OS))
$(call add_json_str,  CrossHostArch,                     $(HOST_CROSS_ARCH))
$(call add_json_str,  CrossHostSecondaryArch,            $(HOST_CROSS_2ND_ARCH))

$(call add_json_list, DeviceResourceOverlays,            $(DEVICE_PACKAGE_OVERLAYS))
$(call add_json_list, ProductResourceOverlays,           $(PRODUCT_PACKAGE_OVERLAYS))
$(call add_json_list, EnforceRROTargets,                 $(PRODUCT_ENFORCE_RRO_TARGETS))
$(call add_json_list, EnforceRROExcludedOverlays,        $(PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS))

$(call add_json_str,  AAPTCharacteristics,               $(TARGET_AAPT_CHARACTERISTICS))
$(call add_json_list, AAPTConfig,                        $(PRODUCT_AAPT_CONFIG))
$(call add_json_str,  AAPTPreferredConfig,               $(PRODUCT_AAPT_PREF_CONFIG))
$(call add_json_list, AAPTPrebuiltDPI,                   $(PRODUCT_AAPT_PREBUILT_DPI))

$(call add_json_str,  DefaultAppCertificate,             $(PRODUCT_DEFAULT_DEV_CERTIFICATE))
$(call add_json_list, ExtraOtaKeys,                      $(PRODUCT_EXTRA_OTA_KEYS))
$(call add_json_list, ExtraOtaRecoveryKeys,              $(PRODUCT_EXTRA_RECOVERY_KEYS))
$(call add_json_str,  MainlineSepolicyDevCertificates,   $(MAINLINE_SEPOLICY_DEV_CERTIFICATES))

$(call add_json_str,  AppsDefaultVersionName,            $(APPS_DEFAULT_VERSION_NAME))

$(call add_json_list, SanitizeHost,                      $(SANITIZE_HOST))
$(call add_json_list, SanitizeDevice,                    $(SANITIZE_TARGET))
$(call add_json_list, SanitizeDeviceDiag,                $(SANITIZE_TARGET_DIAG))
$(call add_json_list, SanitizeDeviceArch,                $(SANITIZE_TARGET_ARCH))

$(call add_json_bool, Safestack,                         $(filter true,$(USE_SAFESTACK)))
$(call add_json_bool, EnableCFI,                         $(call invert_bool,$(filter false,$(ENABLE_CFI))))
$(call add_json_list, CFIExcludePaths,                   $(CFI_EXCLUDE_PATHS) $(PRODUCT_CFI_EXCLUDE_PATHS))
$(call add_json_list, CFIIncludePaths,                   $(CFI_INCLUDE_PATHS) $(PRODUCT_CFI_INCLUDE_PATHS))
$(call add_json_list, IntegerOverflowExcludePaths,       $(INTEGER_OVERFLOW_EXCLUDE_PATHS) $(PRODUCT_INTEGER_OVERFLOW_EXCLUDE_PATHS))
$(call add_json_list, HWASanIncludePaths,                $(HWASAN_INCLUDE_PATHS) $(PRODUCT_HWASAN_INCLUDE_PATHS))
$(call add_json_list, HWASanExcludePaths,                $(HWASAN_EXCLUDE_PATHS) $(PRODUCT_HWASAN_EXCLUDE_PATHS))

$(call add_json_list, MemtagHeapExcludePaths,            $(MEMTAG_HEAP_EXCLUDE_PATHS) $(PRODUCT_MEMTAG_HEAP_EXCLUDE_PATHS))
$(call add_json_list, MemtagHeapAsyncIncludePaths,       $(MEMTAG_HEAP_ASYNC_INCLUDE_PATHS) $(PRODUCT_MEMTAG_HEAP_ASYNC_INCLUDE_PATHS) $(if $(filter true,$(PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS)),,$(PRODUCT_MEMTAG_HEAP_ASYNC_DEFAULT_INCLUDE_PATHS)))
$(call add_json_list, MemtagHeapSyncIncludePaths,       $(MEMTAG_HEAP_SYNC_INCLUDE_PATHS) $(PRODUCT_MEMTAG_HEAP_SYNC_INCLUDE_PATHS) $(if $(filter true,$(PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS)),,$(PRODUCT_MEMTAG_HEAP_SYNC_DEFAULT_INCLUDE_PATHS)))

$(call add_json_bool, DisableScudo,                      $(filter true,$(PRODUCT_DISABLE_SCUDO)))

$(call add_json_bool, ClangTidy,                         $(filter 1 true,$(WITH_TIDY)))
$(call add_json_str,  TidyChecks,                        $(WITH_TIDY_CHECKS))

$(call add_json_list, JavaCoveragePaths,                 $(JAVA_COVERAGE_PATHS))
$(call add_json_list, JavaCoverageExcludePaths,          $(JAVA_COVERAGE_EXCLUDE_PATHS))

$(call add_json_bool, GcovCoverage,                      $(filter true,$(NATIVE_COVERAGE)))
$(call add_json_bool, ClangCoverage,                     $(filter true,$(CLANG_COVERAGE)))
$(call add_json_bool, ClangCoverageContinuousMode,       $(filter true,$(CLANG_COVERAGE_CONTINUOUS_MODE)))
$(call add_json_list, NativeCoveragePaths,               $(NATIVE_COVERAGE_PATHS))
$(call add_json_list, NativeCoverageExcludePaths,        $(NATIVE_COVERAGE_EXCLUDE_PATHS))

$(call add_json_bool, ArtUseReadBarrier,                 $(call invert_bool,$(filter false,$(PRODUCT_ART_USE_READ_BARRIER))))
$(call add_json_str,  BtConfigIncludeDir,                $(BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR))
$(call add_json_list, DeviceKernelHeaders,               $(TARGET_DEVICE_KERNEL_HEADERS) $(TARGET_BOARD_KERNEL_HEADERS) $(TARGET_PRODUCT_KERNEL_HEADERS))
$(call add_json_str,  VendorApiLevel,                    $(BOARD_API_LEVEL))
$(call add_json_list, ExtraVndkVersions,                 $(PRODUCT_EXTRA_VNDK_VERSIONS))
$(call add_json_list, DeviceSystemSdkVersions,           $(BOARD_SYSTEMSDK_VERSIONS))
$(call add_json_list, Platform_systemsdk_versions,       $(PLATFORM_SYSTEMSDK_VERSIONS))
$(call add_json_bool, Malloc_low_memory,                 $(findstring true,$(MALLOC_SVELTE) $(MALLOC_LOW_MEMORY)))
$(call add_json_bool, Malloc_zero_contents,              $(call invert_bool,$(filter false,$(MALLOC_ZERO_CONTENTS))))
$(call add_json_bool, Malloc_pattern_fill_contents,      $(MALLOC_PATTERN_FILL_CONTENTS))
$(call add_json_str,  Override_rs_driver,                $(OVERRIDE_RS_DRIVER))
$(call add_json_str,  DeviceMaxPageSizeSupported,        $(TARGET_MAX_PAGE_SIZE_SUPPORTED))
$(call add_json_bool, DeviceNoBionicPageSizeMacro,       $(filter true,$(TARGET_NO_BIONIC_PAGE_SIZE_MACRO)))

$(call add_json_bool, UncompressPrivAppDex,              $(call invert_bool,$(filter true,$(DONT_UNCOMPRESS_PRIV_APPS_DEXS))))
$(call add_json_list, ModulesLoadedByPrivilegedModules,  $(PRODUCT_LOADED_BY_PRIVILEGED_MODULES))

$(call add_json_list, BootJars,                          $(PRODUCT_BOOT_JARS))
$(call add_json_list, ApexBootJars,                      $(filter-out $(APEX_BOOT_JARS_EXCLUDED), $(PRODUCT_APEX_BOOT_JARS)))

$(call add_json_map,  BuildFlags)
$(foreach flag,$(_ALL_RELEASE_FLAGS),\
  $(call add_json_str,$(flag),$(_ALL_RELEASE_FLAGS.$(flag).VALUE)))
$(call end_json_map)
$(call add_json_map,  BuildFlagTypes)
$(foreach flag,$(_ALL_RELEASE_FLAGS),\
  $(call add_json_str,$(flag),$(_ALL_RELEASE_FLAGS.$(flag).TYPE)))
$(call end_json_map)

$(call add_json_bool, MultitreeUpdateMeta,               $(filter true,$(TARGET_MULTITREE_UPDATE_META)))

$(call add_json_bool, Treble_linker_namespaces,          $(filter true,$(PRODUCT_TREBLE_LINKER_NAMESPACES)))
$(call add_json_bool, Enforce_vintf_manifest,            $(filter true,$(PRODUCT_ENFORCE_VINTF_MANIFEST)))

$(call add_json_bool, Uml,                               $(filter true,$(TARGET_USER_MODE_LINUX)))
$(call add_json_str,  VendorPath,                        $(TARGET_COPY_OUT_VENDOR))
$(call add_json_str,  OdmPath,                           $(TARGET_COPY_OUT_ODM))
$(call add_json_str,  ProductPath,                       $(TARGET_COPY_OUT_PRODUCT))
$(call add_json_str,  SystemExtPath,                     $(TARGET_COPY_OUT_SYSTEM_EXT))
$(call add_json_bool, MinimizeJavaDebugInfo,             $(filter true,$(PRODUCT_MINIMIZE_JAVA_DEBUG_INFO)))

$(call add_json_bool, UseGoma,                           $(filter-out false,$(USE_GOMA)))
$(call add_json_bool, UseRBE,                            $(filter-out false,$(USE_RBE)))
$(call add_json_bool, UseRBEJAVAC,                       $(filter-out false,$(RBE_JAVAC)))
$(call add_json_bool, UseRBER8,                          $(filter-out false,$(RBE_R8)))
$(call add_json_bool, UseRBED8,                          $(filter-out false,$(RBE_D8)))
$(call add_json_bool, Arc,                               $(filter true,$(TARGET_ARC)))

$(call add_json_list, NamespacesToExport,                $(PRODUCT_SOONG_NAMESPACES))

$(call add_json_list, PgoAdditionalProfileDirs,          $(PGO_ADDITIONAL_PROFILE_DIRS))

$(call add_json_list, BoardVendorSepolicyDirs,           $(BOARD_VENDOR_SEPOLICY_DIRS) $(BOARD_SEPOLICY_DIRS))
$(call add_json_list, BoardOdmSepolicyDirs,              $(BOARD_ODM_SEPOLICY_DIRS))
$(call add_json_list, SystemExtPublicSepolicyDirs,       $(SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS))
$(call add_json_list, SystemExtPrivateSepolicyDirs,      $(SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS))
$(call add_json_list, BoardSepolicyM4Defs,               $(BOARD_SEPOLICY_M4DEFS))
$(call add_json_str,  BoardSepolicyVers,                 $(BOARD_SEPOLICY_VERS))
$(call add_json_str,  SystemExtSepolicyPrebuiltApiDir,   $(BOARD_SYSTEM_EXT_PREBUILT_DIR))
$(call add_json_str,  ProductSepolicyPrebuiltApiDir,     $(BOARD_PRODUCT_PREBUILT_DIR))
$(call add_json_str,  BoardPlatform,                     $(TARGET_BOARD_PLATFORM))

$(call add_json_str,  PlatformSepolicyVersion,           $(PLATFORM_SEPOLICY_VERSION))
$(call add_json_list, PlatformSepolicyCompatVersions,    $(PLATFORM_SEPOLICY_COMPAT_VERSIONS))

$(call add_json_bool, ForceApexSymlinkOptimization,      $(filter true,$(TARGET_FORCE_APEX_SYMLINK_OPTIMIZATION)))

$(call add_json_str,  DexpreoptGlobalConfig,             $(DEX_PREOPT_CONFIG))

$(call add_json_bool, WithDexpreopt,                     $(filter true,$(WITH_DEXPREOPT)))

$(call add_json_list, ManifestPackageNameOverrides,      $(PRODUCT_MANIFEST_PACKAGE_NAME_OVERRIDES))
$(call add_json_list, PackageNameOverrides,              $(PRODUCT_PACKAGE_NAME_OVERRIDES))
$(call add_json_list, CertificateOverrides,              $(PRODUCT_CERTIFICATE_OVERRIDES))
$(call add_json_list, ConfiguredJarLocationOverrides,    $(PRODUCT_CONFIGURED_JAR_LOCATION_OVERRIDES))

$(call add_json_str, ApexGlobalMinSdkVersionOverride,    $(APEX_GLOBAL_MIN_SDK_VERSION_OVERRIDE))

$(call add_json_bool, EnforceSystemCertificate,          $(filter true,$(ENFORCE_SYSTEM_CERTIFICATE)))
$(call add_json_list, EnforceSystemCertificateAllowList, $(ENFORCE_SYSTEM_CERTIFICATE_ALLOW_LIST))

$(call add_json_list, ProductHiddenAPIStubs,             $(PRODUCT_HIDDENAPI_STUBS))
$(call add_json_list, ProductHiddenAPIStubsSystem,       $(PRODUCT_HIDDENAPI_STUBS_SYSTEM))
$(call add_json_list, ProductHiddenAPIStubsTest,         $(PRODUCT_HIDDENAPI_STUBS_TEST))

$(call add_json_list, ProductPublicSepolicyDirs,         $(PRODUCT_PUBLIC_SEPOLICY_DIRS))
$(call add_json_list, ProductPrivateSepolicyDirs,        $(PRODUCT_PRIVATE_SEPOLICY_DIRS))

$(call add_json_list, TargetFSConfigGen,                 $(TARGET_FS_CONFIG_GEN))

# Although USE_SOONG_DEFINED_SYSTEM_IMAGE determines whether to use the system image specified by
# PRODUCT_SOONG_DEFINED_SYSTEM_IMAGE, PRODUCT_SOONG_DEFINED_SYSTEM_IMAGE is still used to compare
# installed files between make and soong, regardless of the USE_SOONG_DEFINED_SYSTEM_IMAGE setting.
$(call add_json_bool, UseSoongSystemImage,               $(filter true,$(USE_SOONG_DEFINED_SYSTEM_IMAGE)))
$(call add_json_str,  ProductSoongDefinedSystemImage,    $(PRODUCT_SOONG_DEFINED_SYSTEM_IMAGE))

$(call add_json_map, VendorVars)
$(foreach namespace,$(sort $(SOONG_CONFIG_NAMESPACES)),\
  $(call add_json_map, $(namespace))\
  $(foreach key,$(sort $(SOONG_CONFIG_$(namespace))),\
    $(call add_json_str,$(key),$(subst ",\",$(SOONG_CONFIG_$(namespace)_$(key)))))\
  $(call end_json_map))
$(call end_json_map)

# Add the types of the variables in VendorVars. Since this is much newer
# than VendorVars, which has a history of just using string values for everything,
# variables are assumed to be strings by default. For strings, SOONG_CONFIG_TYPE_*
# will not be set, and they will not have an entry in the VendorVarTypes map.
$(call add_json_map, VendorVarTypes)
$(foreach namespace,$(sort $(SOONG_CONFIG_NAMESPACES)),\
  $(call add_json_map, $(namespace))\
  $(foreach key,$(sort $(SOONG_CONFIG_$(namespace))),\
    $(if $(SOONG_CONFIG_TYPE_$(namespace)_$(key)),$(call add_json_str,$(key),$(subst ",\",$(SOONG_CONFIG_TYPE_$(namespace)_$(key))))))\
  $(call end_json_map))
$(call end_json_map)

$(call add_json_bool, EnforceProductPartitionInterface,  $(filter true,$(PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE)))
$(call add_json_str,  DeviceCurrentApiLevelForVendorModules,  $(BOARD_CURRENT_API_LEVEL_FOR_VENDOR_MODULES))

$(call add_json_bool, EnforceInterPartitionJavaSdkLibrary, $(filter true,$(PRODUCT_ENFORCE_INTER_PARTITION_JAVA_SDK_LIBRARY)))
$(call add_json_list, InterPartitionJavaLibraryAllowList, $(PRODUCT_INTER_PARTITION_JAVA_LIBRARY_ALLOWLIST))

$(call add_json_bool, CompressedApex, $(filter true,$(PRODUCT_COMPRESSED_APEX)))

ifndef APEX_BUILD_FOR_PRE_S_DEVICES
$(call add_json_bool, TrimmedApex, $(filter true,$(PRODUCT_TRIMMED_APEX)))
endif

$(call add_json_bool, BoardUsesRecoveryAsBoot, $(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))

$(call add_json_list, BoardKernelBinaries, $(BOARD_KERNEL_BINARIES))
$(call add_json_list, BoardKernelModuleInterfaceVersions, $(BOARD_KERNEL_MODULE_INTERFACE_VERSIONS))

$(call add_json_bool, BoardMoveRecoveryResourcesToVendorBoot, $(filter true,$(BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT)))
$(call add_json_str,  PrebuiltHiddenApiDir, $(BOARD_PREBUILT_HIDDENAPI_DIR))

$(call add_json_str,  Shipping_api_level, $(PRODUCT_SHIPPING_API_LEVEL))

$(call add_json_list, BuildBrokenPluginValidation,         $(BUILD_BROKEN_PLUGIN_VALIDATION))
$(call add_json_bool, BuildBrokenClangProperty,            $(filter true,$(BUILD_BROKEN_CLANG_PROPERTY)))
$(call add_json_bool, BuildBrokenClangAsFlags,             $(filter true,$(BUILD_BROKEN_CLANG_ASFLAGS)))
$(call add_json_bool, BuildBrokenClangCFlags,              $(filter true,$(BUILD_BROKEN_CLANG_CFLAGS)))
# Use the value of GENRULE_SANDBOXING if set, otherwise use the inverse of BUILD_BROKEN_GENRULE_SANDBOXING
$(call add_json_bool, GenruleSandboxing,                   $(if $(GENRULE_SANDBOXING),$(filter true,$(GENRULE_SANDBOXING)),$(if $(filter true,$(BUILD_BROKEN_GENRULE_SANDBOXING)),,true)))
$(call add_json_bool, BuildBrokenEnforceSyspropOwner,      $(filter true,$(BUILD_BROKEN_ENFORCE_SYSPROP_OWNER)))
$(call add_json_bool, BuildBrokenTrebleSyspropNeverallow,  $(filter true,$(BUILD_BROKEN_TREBLE_SYSPROP_NEVERALLOW)))
$(call add_json_bool, BuildBrokenVendorPropertyNamespace,  $(filter true,$(BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE)))
$(call add_json_bool, BuildBrokenIncorrectPartitionImages, $(filter true,$(BUILD_BROKEN_INCORRECT_PARTITION_IMAGES)))
$(call add_json_list, BuildBrokenInputDirModules,          $(BUILD_BROKEN_INPUT_DIR_MODULES))
$(call add_json_bool, BuildBrokenDontCheckSystemSdk,       $(filter true,$(BUILD_BROKEN_DONT_CHECK_SYSTEMSDK)))
$(call add_json_bool, BuildBrokenDupSysprop,               $(filter true,$(BUILD_BROKEN_DUP_SYSPROP)))

$(call add_json_list, BuildWarningBadOptionalUsesLibsAllowlist,    $(BUILD_WARNING_BAD_OPTIONAL_USES_LIBS_ALLOWLIST))

$(call add_json_bool, BuildDebugfsRestrictionsEnabled, $(filter true,$(PRODUCT_SET_DEBUGFS_RESTRICTIONS)))

$(call add_json_bool, RequiresInsecureExecmemForSwiftshader, $(filter true,$(PRODUCT_REQUIRES_INSECURE_EXECMEM_FOR_SWIFTSHADER)))

$(call add_json_bool, SelinuxIgnoreNeverallows, $(filter true,$(SELINUX_IGNORE_NEVERALLOWS)))

$(call add_json_list, SepolicyFreezeTestExtraDirs,         $(SEPOLICY_FREEZE_TEST_EXTRA_DIRS))
$(call add_json_list, SepolicyFreezeTestExtraPrebuiltDirs, $(SEPOLICY_FREEZE_TEST_EXTRA_PREBUILT_DIRS))

$(call add_json_bool, GenerateAidlNdkPlatformBackend, $(filter true,$(NEED_AIDL_NDK_PLATFORM_BACKEND)))

$(call add_json_bool, IgnorePrefer32OnDevice, $(filter true,$(IGNORE_PREFER32_ON_DEVICE)))

$(call add_json_list, SourceRootDirs,             $(PRODUCT_SOURCE_ROOT_DIRS))

$(call add_json_list, AfdoProfiles,                $(ALL_AFDO_PROFILES))

$(call add_json_str,  ProductManufacturer, $(PRODUCT_MANUFACTURER))
$(call add_json_str,  ProductBrand,        $(PRODUCT_BRAND))

$(call add_json_str, ReleaseVersion,    $(_RELEASE_VERSION))
$(call add_json_list, ReleaseAconfigValueSets,    $(RELEASE_ACONFIG_VALUE_SETS))
$(call add_json_str, ReleaseAconfigFlagDefaultPermission,    $(RELEASE_ACONFIG_FLAG_DEFAULT_PERMISSION))

$(call add_json_bool, ReleaseDefaultModuleBuildFromSource,   $(RELEASE_DEFAULT_MODULE_BUILD_FROM_SOURCE))

$(call add_json_bool, CheckVendorSeappViolations, $(filter true,$(CHECK_VENDOR_SEAPP_VIOLATIONS)))

$(call add_json_bool, BuildIgnoreApexContributionContents, $(PRODUCT_BUILD_IGNORE_APEX_CONTRIBUTION_CONTENTS))

$(call add_json_bool, BuildFromSourceStub, $(findstring true,$(PRODUCT_BUILD_FROM_SOURCE_STUB) $(BUILD_FROM_SOURCE_STUB)))

$(call add_json_bool, HiddenapiExportableStubs, $(filter true,$(PRODUCT_HIDDEN_API_EXPORTABLE_STUBS)))

$(call add_json_bool, ExportRuntimeApis, $(filter true,$(PRODUCT_EXPORT_RUNTIME_APIS)))

$(call add_json_str, AconfigContainerValidation, $(ACONFIG_CONTAINER_VALIDATION))

$(call add_json_list, ProductLocales, $(subst _,-,$(PRODUCT_LOCALES)))

$(call add_json_list, ProductDefaultWifiChannels, $(PRODUCT_DEFAULT_WIFI_CHANNELS))

$(call add_json_bool, BoardUseVbmetaDigestInFingerprint, $(filter true,$(BOARD_USE_VBMETA_DIGTEST_IN_FINGERPRINT)))

$(call add_json_list, OemProperties, $(PRODUCT_OEM_PROPERTIES))

$(call add_json_list, SystemPropFiles, $(TARGET_SYSTEM_PROP))
$(call add_json_list, SystemExtPropFiles, $(TARGET_SYSTEM_EXT_PROP))
$(call add_json_list, ProductPropFiles, $(TARGET_PRODUCT_PROP))
$(call add_json_list, OdmPropFiles, $(TARGET_ODM_PROP))

# Do not set ArtTargetIncludeDebugBuild into any value if PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD is not set,
# to have the same behavior from runtime_libart.mk.
ifneq ($(PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD),)
$(call add_json_bool, ArtTargetIncludeDebugBuild, $(PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD))
endif

_config_enable_uffd_gc := \
  $(firstword $(OVERRIDE_ENABLE_UFFD_GC) $(PRODUCT_ENABLE_UFFD_GC) default)
$(call add_json_str, EnableUffdGc, $(_config_enable_uffd_gc))
_config_enable_uffd_gc :=

$(call add_json_list, DeviceFrameworkCompatibilityMatrixFile, $(DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE))
$(call add_json_list, DeviceProductCompatibilityMatrixFile, $(DEVICE_PRODUCT_COMPATIBILITY_MATRIX_FILE))
$(call add_json_list, BoardAvbSystemAddHashtreeFooterArgs, $(BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS))
$(call add_json_bool, BoardAvbEnable, $(filter true,$(BOARD_AVB_ENABLE)))

$(call json_end)

$(file >$(SOONG_VARIABLES).tmp,$(json_contents))

$(shell if ! cmp -s $(SOONG_VARIABLES).tmp $(SOONG_VARIABLES); then \
	  mv $(SOONG_VARIABLES).tmp $(SOONG_VARIABLES); \
	else \
	  rm $(SOONG_VARIABLES).tmp; \
	fi)

include $(BUILD_SYSTEM)/soong_extra_config.mk

endif # CONFIGURE_SOONG
