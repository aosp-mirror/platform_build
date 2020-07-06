SOONG := $(SOONG_OUT_DIR)/soong
SOONG_BOOTSTRAP := $(SOONG_OUT_DIR)/.soong.bootstrap
SOONG_BUILD_NINJA := $(SOONG_OUT_DIR)/build.ninja
SOONG_IN_MAKE := $(SOONG_OUT_DIR)/.soong.in_make
SOONG_MAKEVARS_MK := $(SOONG_OUT_DIR)/make_vars-$(TARGET_PRODUCT).mk
SOONG_VARIABLES := $(SOONG_OUT_DIR)/soong.variables
SOONG_ANDROID_MK := $(SOONG_OUT_DIR)/Android-$(TARGET_PRODUCT).mk

BINDER32BIT :=
ifneq ($(TARGET_USES_64_BIT_BINDER),true)
ifneq ($(TARGET_IS_64_BIT),true)
BINDER32BIT := true
endif
endif

include $(BUILD_SYSTEM)/dex_preopt_config.mk

ifeq ($(WRITE_SOONG_VARIABLES),true)

# Create soong.variables with copies of makefile settings.  Runs every build,
# but only updates soong.variables if it changes
$(shell mkdir -p $(dir $(SOONG_VARIABLES)))
$(call json_start)

$(call add_json_str,  Make_suffix, -$(TARGET_PRODUCT))

$(call add_json_str,  BuildId,                           $(BUILD_ID))
$(call add_json_str,  BuildNumberFile,                   build_number.txt)

$(call add_json_str,  Platform_version_name,             $(PLATFORM_VERSION))
$(call add_json_val,  Platform_sdk_version,              $(PLATFORM_SDK_VERSION))
$(call add_json_str,  Platform_sdk_codename,             $(PLATFORM_VERSION_CODENAME))
$(call add_json_bool, Platform_sdk_final,                $(filter REL,$(PLATFORM_VERSION_CODENAME)))
$(call add_json_csv,  Platform_version_active_codenames, $(PLATFORM_VERSION_ALL_CODENAMES))
$(call add_json_str,  Platform_security_patch,           $(PLATFORM_SECURITY_PATCH))
$(call add_json_str,  Platform_preview_sdk_version,      $(PLATFORM_PREVIEW_SDK_VERSION))
$(call add_json_str,  Platform_base_os,                  $(PLATFORM_BASE_OS))

$(call add_json_str,  Platform_min_supported_target_sdk_version, $(PLATFORM_MIN_SUPPORTED_TARGET_SDK_VERSION))

$(call add_json_bool, Allow_missing_dependencies,        $(ALLOW_MISSING_DEPENDENCIES))
$(call add_json_bool, Unbundled_build,                   $(TARGET_BUILD_APPS))
$(call add_json_bool, Unbundled_build_sdks_from_source,  $(UNBUNDLED_BUILD_SDKS_FROM_SOURCE))
$(call add_json_bool, Pdk,                               $(filter true,$(TARGET_BUILD_PDK)))

$(call add_json_bool, Debuggable,                        $(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
$(call add_json_bool, Eng,                               $(filter eng,$(TARGET_BUILD_VARIANT)))

$(call add_json_str,  DeviceName,                        $(TARGET_DEVICE))
$(call add_json_str,  DeviceArch,                        $(TARGET_ARCH))
$(call add_json_str,  DeviceArchVariant,                 $(TARGET_ARCH_VARIANT))
$(call add_json_str,  DeviceCpuVariant,                  $(TARGET_CPU_VARIANT))
$(call add_json_list, DeviceAbi,                         $(TARGET_CPU_ABI) $(TARGET_CPU_ABI2))

$(call add_json_str,  DeviceSecondaryArch,               $(TARGET_2ND_ARCH))
$(call add_json_str,  DeviceSecondaryArchVariant,        $(TARGET_2ND_ARCH_VARIANT))
$(call add_json_str,  DeviceSecondaryCpuVariant,         $(TARGET_2ND_CPU_VARIANT))
$(call add_json_list, DeviceSecondaryAbi,                $(TARGET_2ND_CPU_ABI) $(TARGET_2ND_CPU_ABI2))

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

$(call add_json_str,  CrossHost,                         $(HOST_CROSS_OS))
$(call add_json_str,  CrossHostArch,                     $(HOST_CROSS_ARCH))
$(call add_json_str,  CrossHostSecondaryArch,            $(HOST_CROSS_2ND_ARCH))

$(call add_json_list, DeviceResourceOverlays,            $(DEVICE_PACKAGE_OVERLAYS))
$(call add_json_list, ProductResourceOverlays,           $(PRODUCT_PACKAGE_OVERLAYS))
$(call add_json_list, EnforceRROTargets,                 $(PRODUCT_ENFORCE_RRO_TARGETS))
$(call add_json_list, EnforceRROExemptedTargets,         $(PRODUCT_ENFORCE_RRO_EXEMPTED_TARGETS))
$(call add_json_list, EnforceRROExcludedOverlays,        $(PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS))

$(call add_json_str,  AAPTCharacteristics,               $(TARGET_AAPT_CHARACTERISTICS))
$(call add_json_list, AAPTConfig,                        $(PRODUCT_AAPT_CONFIG))
$(call add_json_str,  AAPTPreferredConfig,               $(PRODUCT_AAPT_PREF_CONFIG))
$(call add_json_list, AAPTPrebuiltDPI,                   $(PRODUCT_AAPT_PREBUILT_DPI))

$(call add_json_str,  DefaultAppCertificate,             $(PRODUCT_DEFAULT_DEV_CERTIFICATE))

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

$(call add_json_bool, Experimental_mte,                  $(filter true,$(TARGET_EXPERIMENTAL_MTE)))

$(call add_json_bool, DisableScudo,                      $(filter true,$(PRODUCT_DISABLE_SCUDO)))

$(call add_json_bool, ClangTidy,                         $(filter 1 true,$(WITH_TIDY)))
$(call add_json_str,  TidyChecks,                        $(WITH_TIDY_CHECKS))

$(call add_json_list, JavaCoveragePaths,                 $(JAVA_COVERAGE_PATHS))
$(call add_json_list, JavaCoverageExcludePaths,          $(JAVA_COVERAGE_EXCLUDE_PATHS))

$(call add_json_bool, GcovCoverage,                      $(filter true,$(NATIVE_COVERAGE)))
$(call add_json_bool, ClangCoverage,                     $(filter true,$(CLANG_COVERAGE)))
# TODO(b/158212027): Remove `$(COVERAGE_PATHS)` from this list when all users have been moved to
# `NATIVE_COVERAGE_PATHS`.
$(call add_json_list, NativeCoveragePaths,               $(COVERAGE_PATHS) $(NATIVE_COVERAGE_PATHS))
# TODO(b/158212027): Remove `$(COVERAGE_EXCLUDE_PATHS)` from this list when all users have been
# moved to `NATIVE_COVERAGE_EXCLUDE_PATHS`.
$(call add_json_list, NativeCoverageExcludePaths,        $(COVERAGE_EXCLUDE_PATHS) $(NATIVE_COVERAGE_EXCLUDE_PATHS))

$(call add_json_bool, SamplingPGO,                       $(filter true,$(SAMPLING_PGO)))

$(call add_json_bool, ArtUseReadBarrier,                 $(call invert_bool,$(filter false,$(PRODUCT_ART_USE_READ_BARRIER))))
$(call add_json_bool, Binder32bit,                       $(BINDER32BIT))
$(call add_json_str,  BtConfigIncludeDir,                $(BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR))
$(call add_json_list, DeviceKernelHeaders,               $(TARGET_PROJECT_SYSTEM_INCLUDES))
$(call add_json_bool, DevicePrefer32BitApps,             $(filter true,$(TARGET_PREFER_32_BIT_APPS)))
$(call add_json_bool, DevicePrefer32BitExecutables,      $(filter true,$(TARGET_PREFER_32_BIT_EXECUTABLES)))
$(call add_json_str,  DeviceVndkVersion,                 $(BOARD_VNDK_VERSION))
$(call add_json_str,  Platform_vndk_version,             $(PLATFORM_VNDK_VERSION))
$(call add_json_str,  ProductVndkVersion,                $(PRODUCT_PRODUCT_VNDK_VERSION))
$(call add_json_list, ExtraVndkVersions,                 $(PRODUCT_EXTRA_VNDK_VERSIONS))
$(call add_json_bool, BoardVndkRuntimeDisable,           $(BOARD_VNDK_RUNTIME_DISABLE))
$(call add_json_list, DeviceSystemSdkVersions,           $(BOARD_SYSTEMSDK_VERSIONS))
$(call add_json_list, Platform_systemsdk_versions,       $(PLATFORM_SYSTEMSDK_VERSIONS))
$(call add_json_bool, Malloc_not_svelte,                 $(call invert_bool,$(filter true,$(MALLOC_SVELTE))))
$(call add_json_str,  Override_rs_driver,                $(OVERRIDE_RS_DRIVER))

$(call add_json_bool, UncompressPrivAppDex,              $(call invert_bool,$(filter true,$(DONT_UNCOMPRESS_PRIV_APPS_DEXS))))
$(call add_json_list, ModulesLoadedByPrivilegedModules,  $(PRODUCT_LOADED_BY_PRIVILEGED_MODULES))

$(call add_json_list, BootJars,                          $(PRODUCT_BOOT_JARS))
$(call add_json_list, UpdatableBootJars,                 $(PRODUCT_UPDATABLE_BOOT_JARS))

$(call add_json_bool, VndkUseCoreVariant,                $(TARGET_VNDK_USE_CORE_VARIANT))
$(call add_json_bool, VndkSnapshotBuildArtifacts,        $(VNDK_SNAPSHOT_BUILD_ARTIFACTS))

$(call add_json_bool, Treble_linker_namespaces,          $(filter true,$(PRODUCT_TREBLE_LINKER_NAMESPACES)))
$(call add_json_bool, Enforce_vintf_manifest,            $(filter true,$(PRODUCT_ENFORCE_VINTF_MANIFEST)))

$(call add_json_bool, Check_elf_files,                   $(filter true,$(PRODUCT_CHECK_ELF_FILES)))

$(call add_json_bool, Uml,                               $(filter true,$(TARGET_USER_MODE_LINUX)))
$(call add_json_bool, Use_lmkd_stats_log,                $(filter true,$(TARGET_LMKD_STATS_LOG)))
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
$(call add_json_list, BoardPlatPublicSepolicyDirs,       $(BOARD_PLAT_PUBLIC_SEPOLICY_DIR))
$(call add_json_list, BoardPlatPrivateSepolicyDirs,      $(BOARD_PLAT_PRIVATE_SEPOLICY_DIR))
$(call add_json_list, BoardSepolicyM4Defs,               $(BOARD_SEPOLICY_M4DEFS))

$(call add_json_bool, Flatten_apex,                      $(filter true,$(TARGET_FLATTEN_APEX)))

$(call add_json_str,  DexpreoptGlobalConfig,             $(DEX_PREOPT_CONFIG))

$(call add_json_list, ManifestPackageNameOverrides,      $(PRODUCT_MANIFEST_PACKAGE_NAME_OVERRIDES))
$(call add_json_list, PackageNameOverrides,              $(PRODUCT_PACKAGE_NAME_OVERRIDES))
$(call add_json_list, CertificateOverrides,              $(PRODUCT_CERTIFICATE_OVERRIDES))

$(call add_json_bool, EnforceSystemCertificate,          $(ENFORCE_SYSTEM_CERTIFICATE))
$(call add_json_list, EnforceSystemCertificateAllowList, $(ENFORCE_SYSTEM_CERTIFICATE_ALLOW_LIST))

$(call add_json_list, ProductHiddenAPIStubs,             $(PRODUCT_HIDDENAPI_STUBS))
$(call add_json_list, ProductHiddenAPIStubsSystem,       $(PRODUCT_HIDDENAPI_STUBS_SYSTEM))
$(call add_json_list, ProductHiddenAPIStubsTest,         $(PRODUCT_HIDDENAPI_STUBS_TEST))

$(call add_json_list, ProductPublicSepolicyDirs,         $(PRODUCT_PUBLIC_SEPOLICY_DIRS))
$(call add_json_list, ProductPrivateSepolicyDirs,        $(PRODUCT_PRIVATE_SEPOLICY_DIRS))
$(call add_json_bool, ProductCompatibleProperty,         $(PRODUCT_COMPATIBLE_PROPERTY))

$(call add_json_list, TargetFSConfigGen,                 $(TARGET_FS_CONFIG_GEN))

$(call add_json_list, MissingUsesLibraries,              $(INTERNAL_PLATFORM_MISSING_USES_LIBRARIES))

$(call add_json_map, VendorVars)
$(foreach namespace,$(SOONG_CONFIG_NAMESPACES),\
  $(call add_json_map, $(namespace))\
  $(foreach key,$(SOONG_CONFIG_$(namespace)),\
    $(call add_json_str,$(key),$(SOONG_CONFIG_$(namespace)_$(key))))\
  $(call end_json_map))
$(call end_json_map)

$(call add_json_bool, EnforceProductPartitionInterface,  $(PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE))

$(call add_json_bool, InstallExtraFlattenedApexes, $(PRODUCT_INSTALL_EXTRA_FLATTENED_APEXES))

$(call add_json_bool, BoardUsesRecoveryAsBoot, $(BOARD_USES_RECOVERY_AS_BOOT))

$(call json_end)

$(file >$(SOONG_VARIABLES).tmp,$(json_contents))

$(shell if ! cmp -s $(SOONG_VARIABLES).tmp $(SOONG_VARIABLES); then \
	  mv $(SOONG_VARIABLES).tmp $(SOONG_VARIABLES); \
	else \
	  rm $(SOONG_VARIABLES).tmp; \
	fi)

endif # CONFIGURE_SOONG
