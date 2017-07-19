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

# Converts a list to a JSON list.
# $1: List separator.
# $2: List.
_json_list = [$(if $(2),"$(subst $(1),"$(comma)",$(2))")]

# Converts a space-separated list to a JSON list.
json_list = $(call _json_list,$(space),$(1))

# Converts a comma-separated list to a JSON list.
csv_to_json_list = $(call _json_list,$(comma),$(1))

# Create soong.variables with copies of makefile settings.  Runs every build,
# but only updates soong.variables if it changes
SOONG_VARIABLES_TMP := $(SOONG_VARIABLES).$$$$
$(SOONG_VARIABLES): FORCE
	$(hide) mkdir -p $(dir $@)
	$(hide) (\
	echo '{'; \
	echo '    "Make_suffix": "-$(TARGET_PRODUCT)",'; \
	echo ''; \
	echo '    "Platform_sdk_version": $(PLATFORM_SDK_VERSION),'; \
	echo '    "Platform_version_all_codenames": $(call csv_to_json_list,$(PLATFORM_VERSION_ALL_CODENAMES)),'; \
	echo '    "Unbundled_build": $(if $(TARGET_BUILD_APPS),true,false),'; \
	echo '    "Brillo": $(if $(BRILLO),true,false),'; \
	echo '    "Malloc_not_svelte": $(if $(filter true,$(MALLOC_SVELTE)),false,true),'; \
	echo '    "Allow_missing_dependencies": $(if $(ALLOW_MISSING_DEPENDENCIES),true,false),'; \
	echo '    "SanitizeHost": $(call json_list,$(SANITIZE_HOST)),'; \
	echo '    "SanitizeDevice": $(call json_list,$(SANITIZE_TARGET)),'; \
	echo '    "SanitizeDeviceDiag": $(call json_list,$(SANITIZE_TARGET_DIAG)),'; \
	echo '    "SanitizeDeviceArch": $(call json_list,$(SANITIZE_TARGET_ARCH)),'; \
	echo '    "HostStaticBinaries": $(if $(strip $(BUILD_HOST_static)),true,false),'; \
	echo '    "Binder32bit": $(if $(BINDER32BIT),true,false),'; \
	echo '    "DevicePrefer32BitExecutables": $(if $(filter true,$(TARGET_PREFER_32_BIT_EXECUTABLES)),true,false),'; \
	echo '    "UseGoma": $(if $(filter-out false,$(USE_GOMA)),true,false),'; \
	echo '    "Debuggable": $(if $(filter userdebug eng,$(TARGET_BUILD_VARIANT)),true,false),'; \
	echo '    "Eng": $(if $(filter eng,$(TARGET_BUILD_VARIANT)),true,false),'; \
	echo '    "VendorPath": "$(TARGET_COPY_OUT_VENDOR)",'; \
	echo ''; \
	echo '    "ClangTidy": $(if $(filter 1 true,$(WITH_TIDY)),true,false),'; \
	echo '    "TidyChecks": "$(WITH_TIDY_CHECKS)",'; \
	echo ''; \
	echo '    "NativeCoverage": $(if $(filter true,$(NATIVE_COVERAGE)),true,false),'; \
	echo '    "CoveragePaths": $(call csv_to_json_list,$(COVERAGE_PATHS)),'; \
	echo '    "CoverageExcludePaths": $(call csv_to_json_list,$(COVERAGE_EXCLUDE_PATHS)),'; \
	echo ''; \
	echo '    "DeviceName": "$(TARGET_DEVICE)",'; \
	echo '    "DeviceArch": "$(TARGET_ARCH)",'; \
	echo '    "DeviceArchVariant": "$(TARGET_ARCH_VARIANT)",'; \
	echo '    "DeviceCpuVariant": "$(TARGET_CPU_VARIANT)",'; \
	echo '    "DeviceAbi": ["$(TARGET_CPU_ABI)", "$(TARGET_CPU_ABI2)"],'; \
	echo '    "DeviceUsesClang": $(if $(USE_CLANG_PLATFORM_BUILD),$(USE_CLANG_PLATFORM_BUILD),false),'; \
	echo '    "DeviceVndkVersion": "$(BOARD_VNDK_VERSION)",'; \
	echo ''; \
	echo '    "DeviceSecondaryArch": "$(TARGET_2ND_ARCH)",'; \
	echo '    "DeviceSecondaryArchVariant": "$(TARGET_2ND_ARCH_VARIANT)",'; \
	echo '    "DeviceSecondaryCpuVariant": "$(TARGET_2ND_CPU_VARIANT)",'; \
	echo '    "DeviceSecondaryAbi": ["$(TARGET_2ND_CPU_ABI)", "$(TARGET_2ND_CPU_ABI2)"],'; \
	echo ''; \
	echo '    "HostArch": "$(HOST_ARCH)",'; \
	echo '    "HostSecondaryArch": "$(HOST_2ND_ARCH)",'; \
	echo ''; \
	echo '    "CrossHost": "$(HOST_CROSS_OS)",'; \
	echo '    "CrossHostArch": "$(HOST_CROSS_ARCH)",'; \
	echo '    "CrossHostSecondaryArch": "$(HOST_CROSS_2ND_ARCH)",'; \
	echo '    "Safestack": $(if $(filter true,$(USE_SAFESTACK)),true,false),'; \
	echo '    "EnableCFI": $(if $(filter false,$(ENABLE_CFI)),false,true),'; \
	echo '    "IntegerOverflowExcludePaths": $(call json_list,$(INTEGER_OVERFLOW_EXCLUDE_PATHS) $(PRODUCT_INTEGER_OVERFLOW_EXCLUDE_PATHS)),'; \
	echo '    "Device_uses_hwc2": $(if $(filter true,$(TARGET_USES_HWC2)),true,false),'; \
	echo '    "Override_rs_driver": "$(OVERRIDE_RS_DRIVER)",'; \
	echo '    "Treble": $(if $(filter true,$(PRODUCT_FULL_TREBLE)),true,false),'; \
	echo '    "Pdk": $(if $(filter true,$(TARGET_BUILD_PDK)),true,false),'; \
	echo ''; \
	echo '    "ArtUseReadBarrier": $(if $(filter false,$(PRODUCT_ART_USE_READ_BARRIER)),false,true),'; \
	echo ''; \
	echo '    "BtConfigIncludeDir": "$(BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR)",'; \
	echo ''; \
	echo '    "DeviceKernelHeaders": $(call json_list,$(strip $(TARGET_PROJECT_SYSTEM_INCLUDES)))'; \
	echo '}') > $(SOONG_VARIABLES_TMP); \
	if ! cmp -s $(SOONG_VARIABLES_TMP) $(SOONG_VARIABLES); then \
	  mv $(SOONG_VARIABLES_TMP) $(SOONG_VARIABLES); \
	else \
	  rm $(SOONG_VARIABLES_TMP); \
	fi
