$(call json_start)

$(call add_json_str, DeviceCpuVariantRuntime,           $(TARGET_CPU_VARIANT_RUNTIME))
$(call add_json_str, DeviceAbiList,                     $(TARGET_CPU_ABI_LIST))
$(call add_json_str, DeviceAbiList32,                   $(TARGET_CPU_ABI_LIST_32_BIT))
$(call add_json_str, DeviceAbiList64,                   $(TARGET_CPU_ABI_LIST_64_BIT))
$(call add_json_str, DeviceSecondaryCpuVariantRuntime,  $(TARGET_2ND_CPU_VARIANT_RUNTIME))

$(call add_json_str, Dex2oatTargetCpuVariantRuntime,         $(DEX2OAT_TARGET_CPU_VARIANT_RUNTIME))
$(call add_json_str, Dex2oatTargetInstructionSetFeatures,    $(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES))
$(call add_json_str, SecondaryDex2oatCpuVariantRuntime,      $($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT_RUNTIME))
$(call add_json_str, SecondaryDex2oatInstructionSetFeatures, $($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES))

$(call add_json_str, BoardPlatform,          $(TARGET_BOARD_PLATFORM))
$(call add_json_str, BoardShippingApiLevel,  $(BOARD_SHIPPING_API_LEVEL))
$(call add_json_str, ShippingApiLevel,       $(PRODUCT_SHIPPING_API_LEVEL))
$(call add_json_str, ShippingVendorApiLevel, $(PRODUCT_SHIPPING_VENDOR_API_LEVEL))

$(call add_json_str, ProductModel,                      $(PRODUCT_MODEL))
$(call add_json_str, ProductModelForAttestation,        $(PRODUCT_MODEL_FOR_ATTESTATION))
$(call add_json_str, ProductBrandForAttestation,        $(PRODUCT_BRAND_FOR_ATTESTATION))
$(call add_json_str, ProductNameForAttestation,         $(PRODUCT_NAME_FOR_ATTESTATION))
$(call add_json_str, ProductDeviceForAttestation,       $(PRODUCT_DEVICE_FOR_ATTESTATION))
$(call add_json_str, ProductManufacturerForAttestation, $(PRODUCT_MANUFACTURER_FOR_ATTESTATION))

$(call add_json_str, SystemBrand, $(PRODUCT_SYSTEM_BRAND))
$(call add_json_str, SystemDevice, $(PRODUCT_SYSTEM_DEVICE))
$(call add_json_str, SystemManufacturer, $(PRODUCT_SYSTEM_MANUFACTURER))
$(call add_json_str, SystemModel, $(PRODUCT_SYSTEM_MODEL))
$(call add_json_str, SystemName, $(PRODUCT_SYSTEM_NAME))

# Collapses ?= and = operators for system property variables. Also removes double quotes to prevent
# malformed JSON. This change aligns with the existing behavior of sysprop.mk, which passes property
# variables to the echo command, effectively discarding surrounding double quotes.
define collapse-prop-pairs
$(subst ",,$(call collapse-pairs,$(call collapse-pairs,$$($(1)),?=),=))
endef

$(call add_json_list, PRODUCT_SYSTEM_PROPERTIES,         $(call collapse-prop-pairs,PRODUCT_SYSTEM_PROPERTIES))
$(call add_json_list, PRODUCT_SYSTEM_DEFAULT_PROPERTIES, $(call collapse-prop-pairs,PRODUCT_SYSTEM_DEFAULT_PROPERTIES))
$(call add_json_list, PRODUCT_SYSTEM_EXT_PROPERTIES,     $(call collapse-prop-pairs,PRODUCT_SYSTEM_EXT_PROPERTIES))
$(call add_json_list, PRODUCT_VENDOR_PROPERTIES,         $(call collapse-prop-pairs,PRODUCT_VENDOR_PROPERTIES))
$(call add_json_list, PRODUCT_PRODUCT_PROPERTIES,        $(call collapse-prop-pairs,PRODUCT_PRODUCT_PROPERTIES))
$(call add_json_list, PRODUCT_ODM_PROPERTIES,            $(call collapse-prop-pairs,PRODUCT_ODM_PROPERTIES))
$(call add_json_list, PRODUCT_PROPERTY_OVERRIDES,        $(call collapse-prop-pairs,PRODUCT_PROPERTY_OVERRIDES))

$(call add_json_str, BootloaderBoardName, $(TARGET_BOOTLOADER_BOARD_NAME))

$(call add_json_bool, SdkBuild, $(filter sdk sdk_addon,$(MAKECMDGOALS)))

$(call add_json_str, SystemServerCompilerFilter, $(PRODUCT_SYSTEM_SERVER_COMPILER_FILTER))

$(call add_json_bool, Product16KDeveloperOption, $(filter true,$(PRODUCT_16K_DEVELOPER_OPTION)))

$(call add_json_str, RecoveryDefaultRotation, $(TARGET_RECOVERY_DEFAULT_ROTATION))
$(call add_json_str, RecoveryOverscanPercent, $(TARGET_RECOVERY_OVERSCAN_PERCENT))
$(call add_json_str, RecoveryPixelFormat, $(TARGET_RECOVERY_PIXEL_FORMAT))

ifdef AB_OTA_UPDATER
$(call add_json_bool, AbOtaUpdater, $(filter true,$(AB_OTA_UPDATER)))
$(call add_json_str, AbOtaPartitions, $(subst $(space),$(comma),$(sort $(AB_OTA_PARTITIONS))))
endif

ifdef PRODUCT_USE_DYNAMIC_PARTITIONS
$(call add_json_bool, UseDynamicPartitions, $(filter true,$(PRODUCT_USE_DYNAMIC_PARTITIONS)))
endif

ifdef PRODUCT_RETROFIT_DYNAMIC_PARTITIONS
$(call add_json_bool, RetrofitDynamicPartitions, $(filter true,$(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS)))
endif

$(call add_json_bool, DontUseVabcOta, $(filter true,$(BOARD_DONT_USE_VABC_OTA)))

$(call add_json_bool, FullTreble, $(filter true,$(PRODUCT_FULL_TREBLE)))

$(call add_json_bool, NoBionicPageSizeMacro, $(filter true,$(PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO)))

$(call add_json_bool, PropertySplitEnabled, $(filter true,$(BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED)))

$(call add_json_str, ScreenDensity, $(TARGET_SCREEN_DENSITY))

$(call add_json_bool, UsesVulkan, $(filter true,$(TARGET_USES_VULKAN)))

$(call add_json_bool, ZygoteForce64, $(filter true,$(ZYGOTE_FORCE_64)))

$(call add_json_str, VendorSecurityPatch,       $(VENDOR_SECURITY_PATCH))
$(call add_json_str, VendorImageFileSystemType, $(BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE))

$(call add_json_list, BuildVersionTags, $(BUILD_VERSION_TAGS))

$(call add_json_bool, ProductNotDebuggableInUserdebug, $(PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG))

$(call json_end)

$(shell mkdir -p $(dir $(SOONG_EXTRA_VARIABLES)))
$(file >$(SOONG_EXTRA_VARIABLES).tmp,$(json_contents))

$(shell if ! cmp -s $(SOONG_EXTRA_VARIABLES).tmp $(SOONG_EXTRA_VARIABLES); then \
	  mv $(SOONG_EXTRA_VARIABLES).tmp $(SOONG_EXTRA_VARIABLES); \
	else \
	  rm $(SOONG_EXTRA_VARIABLES).tmp; \
	fi)
