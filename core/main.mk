ifndef KATI
$(warning Calling make directly is no longer supported.)
$(warning Either use 'envsetup.sh; m' or 'build/soong/soong_ui.bash --make-mode')
$(error done)
endif

$(info [1/1] initializing legacy Make module parser ...)

# Absolute path of the present working direcotry.
# This overrides the shell variable $PWD, which does not necessarily points to
# the top of the source tree, for example when "make -C" is used in m/mm/mmm.
PWD := $(shell pwd)

# This is the default target.  It must be the first declared target.
.PHONY: droid
DEFAULT_GOAL := droid
$(DEFAULT_GOAL): droid_targets

.PHONY: droid_targets
droid_targets:

# Set up various standard variables based on configuration
# and host information.
include build/make/core/config.mk

ifneq ($(filter $(dont_bother_goals), $(MAKECMDGOALS)),)
dont_bother := true
endif

.KATI_READONLY := SOONG_CONFIG_NAMESPACES
.KATI_READONLY := $(foreach n,$(SOONG_CONFIG_NAMESPACES),SOONG_CONFIG_$(n))
.KATI_READONLY := $(foreach n,$(SOONG_CONFIG_NAMESPACES),$(foreach k,$(SOONG_CONFIG_$(n)),SOONG_CONFIG_$(n)_$(k)))

include $(SOONG_MAKEVARS_MK)

YACC :=$= $(BISON) -d

include $(BUILD_SYSTEM)/clang/config.mk

# Write the build number to a file so it can be read back in
# without changing the command line every time.  Avoids rebuilds
# when using ninja.
BUILD_NUMBER_FILE := $(SOONG_OUT_DIR)/build_number.txt
$(KATI_obsolete_var BUILD_NUMBER,See https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER)
BUILD_HOSTNAME_FILE := $(SOONG_OUT_DIR)/build_hostname.txt
$(KATI_obsolete_var BUILD_HOSTNAME,Use BUILD_HOSTNAME_FROM_FILE instead)
$(KATI_obsolete_var FILE_NAME_TAG,https://android.googlesource.com/platform/build/+/master/Changes.md#FILE_NAME_TAG)

$(BUILD_NUMBER_FILE):
	# empty rule to prevent dangling rule error for a file that is written by soong_ui
$(BUILD_HOSTNAME_FILE):
	# empty rule to prevent dangling rule error for a file that is written by soong_ui

.KATI_RESTAT: $(BUILD_NUMBER_FILE)
.KATI_RESTAT: $(BUILD_HOSTNAME_FILE)

DATE_FROM_FILE := date -d @$(BUILD_DATETIME_FROM_FILE)
.KATI_READONLY := DATE_FROM_FILE


# Make an empty directory, which can be used to make empty jars
EMPTY_DIRECTORY := $(OUT_DIR)/empty
$(shell mkdir -p $(EMPTY_DIRECTORY) && rm -rf $(EMPTY_DIRECTORY)/*)

# CTS-specific config.
-include cts/build/config.mk
# device-tests-specific-config.
-include tools/tradefederation/build/suites/device-tests/config.mk
# general-tests-specific-config.
-include tools/tradefederation/build/suites/general-tests/config.mk
# STS-specific config.
-include test/sts/tools/sts-tradefed/build/config.mk
# CTS-Instant-specific config
-include test/suite_harness/tools/cts-instant-tradefed/build/config.mk
# MTS-specific config.
-include test/mts/tools/build/config.mk
# VTS-Core-specific config.
-include test/vts/tools/vts-core-tradefed/build/config.mk
# CSUITE-specific config.
-include test/app_compat/csuite/tools/build/config.mk
# CATBox-specific config.
-include test/catbox/tools/build/config.mk
# CTS-Root-specific config.
-include test/cts-root/tools/build/config.mk
# WVTS-specific config.
-include test/wvts/tools/build/config.mk


# Clean rules
.PHONY: clean-dex-files
clean-dex-files:
	$(hide) find $(OUT_DIR) -name "*.dex" | xargs rm -f
	$(hide) for i in `find $(OUT_DIR) -name "*.jar" -o -name "*.apk"` ; do ((unzip -l $$i 2> /dev/null | \
				grep -q "\.dex$$" && rm -f $$i) || continue ) ; done
	@echo "All dex files and archives containing dex files have been removed."

# Include the google-specific config
-include vendor/google/build/config.mk

# These are the modifier targets that don't do anything themselves, but
# change the behavior of the build.
# (must be defined before including definitions.make)
INTERNAL_MODIFIER_TARGETS := all

# EMMA_INSTRUMENT_STATIC merges the static jacoco library to each
# jacoco-enabled module.
ifeq (true,$(EMMA_INSTRUMENT_STATIC))
EMMA_INSTRUMENT := true
endif

ifdef TARGET_ARCH_SUITE
  # TODO(b/175577370): Enable this error.
  # $(error TARGET_ARCH_SUITE is not supported in kati/make builds)
endif

# ADDITIONAL_<partition>_PROPERTIES are properties that are determined by the
# build system itself. Don't let it be defined from outside of the core build
# system like Android.mk or <product>.mk files.
_additional_prop_var_names := \
    ADDITIONAL_SYSTEM_PROPERTIES \
    ADDITIONAL_VENDOR_PROPERTIES \
    ADDITIONAL_ODM_PROPERTIES \
    ADDITIONAL_PRODUCT_PROPERTIES

$(foreach name, $(_additional_prop_var_names),\
  $(if $($(name)),\
    $(error $(name) must not set before here. $($(name)))\
  ,)\
  $(eval $(name) :=)\
)
_additional_prop_var_names :=

$(KATI_obsolete_var ADDITIONAL_BUILD_PROPERTIES, Please use ADDITIONAL_SYSTEM_PROPERTIES)

#
# -----------------------------------------------------------------
# Add the product-defined properties to the build properties.
ifneq ($(BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED), true)
  ADDITIONAL_SYSTEM_PROPERTIES += $(PRODUCT_PROPERTY_OVERRIDES)
else
  ifndef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
    ADDITIONAL_SYSTEM_PROPERTIES += $(PRODUCT_PROPERTY_OVERRIDES)
  endif
endif


# Bring in standard build system definitions.
include $(BUILD_SYSTEM)/definitions.mk

ifneq ($(filter user userdebug eng,$(MAKECMDGOALS)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Do not pass '$(filter user userdebug eng,$(MAKECMDGOALS))' on \
       the make command line.)
$(info Set TARGET_BUILD_VARIANT in buildspec.mk, or use lunch or)
$(info choosecombo.)
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

# These are the valid values of TARGET_BUILD_VARIANT.
INTERNAL_VALID_VARIANTS := user userdebug eng
ifneq ($(filter-out $(INTERNAL_VALID_VARIANTS),$(TARGET_BUILD_VARIANT)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Invalid variant: $(TARGET_BUILD_VARIANT))
$(info Valid values are: $(INTERNAL_VALID_VARIANTS))
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

# -----------------------------------------------------------------
# PDK builds are no longer supported, this is always platform
TARGET_BUILD_JAVA_SUPPORT_LEVEL :=$= platform

# -----------------------------------------------------------------

ADDITIONAL_SYSTEM_PROPERTIES += ro.treble.enabled=${PRODUCT_FULL_TREBLE}

$(KATI_obsolete_var PRODUCT_FULL_TREBLE,\
	Code should be written to work regardless of a device being Treble)

# Set ro.llndk.api_level to show the maximum vendor API level that the LLNDK in
# the system partition supports.
ifdef RELEASE_BOARD_API_LEVEL
ADDITIONAL_SYSTEM_PROPERTIES += ro.llndk.api_level=$(RELEASE_BOARD_API_LEVEL)
endif

# Sets ro.actionable_compatible_property.enabled to know on runtime whether the
# allowed list of actionable compatible properties is enabled or not.
ADDITIONAL_SYSTEM_PROPERTIES += ro.actionable_compatible_property.enabled=true

# Add the system server compiler filter if they are specified for the product.
ifneq (,$(PRODUCT_SYSTEM_SERVER_COMPILER_FILTER))
ADDITIONAL_PRODUCT_PROPERTIES += dalvik.vm.systemservercompilerfilter=$(PRODUCT_SYSTEM_SERVER_COMPILER_FILTER)
endif

# Add the 16K developer option if it is defined for the product.
ifeq ($(PRODUCT_16K_DEVELOPER_OPTION),true)
ADDITIONAL_PRODUCT_PROPERTIES += ro.product.build.16k_page.enabled=true
else
ADDITIONAL_PRODUCT_PROPERTIES += ro.product.build.16k_page.enabled=false
endif

# Enable core platform API violation warnings on userdebug and eng builds.
ifneq ($(TARGET_BUILD_VARIANT),user)
ADDITIONAL_SYSTEM_PROPERTIES += persist.debug.dalvik.vm.core_platform_api_policy=just-warn
endif

# Define ro.sanitize.<name> properties for all global sanitizers.
ADDITIONAL_SYSTEM_PROPERTIES += $(foreach s,$(SANITIZE_TARGET),ro.sanitize.$(s)=true)

# Sets the default value of ro.postinstall.fstab.prefix to /system.
# Device board config should override the value to /product when needed by:
#
#     PRODUCT_PRODUCT_PROPERTIES += ro.postinstall.fstab.prefix=/product
#
# It then uses ${ro.postinstall.fstab.prefix}/etc/fstab.postinstall to
# mount system_other partition.
ADDITIONAL_SYSTEM_PROPERTIES += ro.postinstall.fstab.prefix=/system

# -----------------------------------------------------------------
# ADDITIONAL_VENDOR_PROPERTIES will be installed in vendor/build.prop if
# property_overrides_split_enabled is true. Otherwise it will be installed in
# /system/build.prop
ifdef BOARD_VNDK_VERSION
  ifeq ($(KEEP_VNDK),true)
  ifeq ($(BOARD_VNDK_VERSION),current)
    ADDITIONAL_VENDOR_PROPERTIES := ro.vndk.version=$(PLATFORM_VNDK_VERSION)
  else
    ADDITIONAL_VENDOR_PROPERTIES := ro.vndk.version=$(BOARD_VNDK_VERSION)
  endif
  endif

  # TODO(b/290159430): ro.vndk.deprecate is a temporal variable for deprecating VNDK.
  # This variable will be removed once ro.vndk.version can be removed.
  ifneq ($(KEEP_VNDK),true)
    ADDITIONAL_SYSTEM_PROPERTIES += ro.vndk.deprecate=true
  endif
endif

# Add cpu properties for bionic and ART.
ADDITIONAL_VENDOR_PROPERTIES += ro.bionic.arch=$(TARGET_ARCH)
ADDITIONAL_VENDOR_PROPERTIES += ro.bionic.cpu_variant=$(TARGET_CPU_VARIANT_RUNTIME)
ADDITIONAL_VENDOR_PROPERTIES += ro.bionic.2nd_arch=$(TARGET_2ND_ARCH)
ADDITIONAL_VENDOR_PROPERTIES += ro.bionic.2nd_cpu_variant=$(TARGET_2ND_CPU_VARIANT_RUNTIME)

ADDITIONAL_VENDOR_PROPERTIES += persist.sys.dalvik.vm.lib.2=libart.so
ADDITIONAL_VENDOR_PROPERTIES += dalvik.vm.isa.$(TARGET_ARCH).variant=$(DEX2OAT_TARGET_CPU_VARIANT_RUNTIME)
ifneq ($(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES),)
  ADDITIONAL_VENDOR_PROPERTIES += dalvik.vm.isa.$(TARGET_ARCH).features=$(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
endif

ifdef TARGET_2ND_ARCH
  ADDITIONAL_VENDOR_PROPERTIES += dalvik.vm.isa.$(TARGET_2ND_ARCH).variant=$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT_RUNTIME)
  ifneq ($($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES),)
    ADDITIONAL_VENDOR_PROPERTIES += dalvik.vm.isa.$(TARGET_2ND_ARCH).features=$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
  endif
endif

# Although these variables are prefixed with TARGET_RECOVERY_, they are also needed under charger
# mode (via libminui).
ifdef TARGET_RECOVERY_DEFAULT_ROTATION
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.minui.default_rotation=$(TARGET_RECOVERY_DEFAULT_ROTATION)
endif
ifdef TARGET_RECOVERY_OVERSCAN_PERCENT
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.minui.overscan_percent=$(TARGET_RECOVERY_OVERSCAN_PERCENT)
endif
ifdef TARGET_RECOVERY_PIXEL_FORMAT
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.minui.pixel_format=$(TARGET_RECOVERY_PIXEL_FORMAT)
endif

ifdef PRODUCT_USE_DYNAMIC_PARTITIONS
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.boot.dynamic_partitions=$(PRODUCT_USE_DYNAMIC_PARTITIONS)
endif

ifdef PRODUCT_RETROFIT_DYNAMIC_PARTITIONS
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.boot.dynamic_partitions_retrofit=$(PRODUCT_RETROFIT_DYNAMIC_PARTITIONS)
endif

ifdef PRODUCT_SHIPPING_API_LEVEL
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.product.first_api_level=$(PRODUCT_SHIPPING_API_LEVEL)
endif

ifneq ($(TARGET_BUILD_VARIANT),user)
  ifdef PRODUCT_SET_DEBUGFS_RESTRICTIONS
    ADDITIONAL_VENDOR_PROPERTIES += \
      ro.product.debugfs_restrictions.enabled=$(PRODUCT_SET_DEBUGFS_RESTRICTIONS)
  endif
endif

# Vendors with GRF must define BOARD_SHIPPING_API_LEVEL for the vendor API level.
# This must not be defined for the non-GRF devices.
# The values of the GRF properties will be verified by post_process_props.py
ifdef BOARD_SHIPPING_API_LEVEL
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.board.first_api_level=$(BOARD_SHIPPING_API_LEVEL)
endif

# Build system set BOARD_API_LEVEL to show the api level of the vendor API surface.
# This must not be altered outside of build system.
ifdef BOARD_API_LEVEL
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.board.api_level=$(BOARD_API_LEVEL)
endif
# BOARD_API_LEVEL_FROZEN is true when the vendor API surface is frozen.
ifdef BOARD_API_LEVEL_FROZEN
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.board.api_frozen=$(BOARD_API_LEVEL_FROZEN)
endif

# Set build prop. This prop is read by ota_from_target_files when generating OTA,
# to decide if VABC should be disabled.
ifeq ($(BOARD_DONT_USE_VABC_OTA),true)
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.vendor.build.dont_use_vabc=true
endif

# Set the flag in vendor. So VTS would know if the new fingerprint format is in use when
# the system images are replaced by GSI.
ifeq ($(BOARD_USE_VBMETA_DIGTEST_IN_FINGERPRINT),true)
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.vendor.build.fingerprint_has_digest=1
endif

ADDITIONAL_VENDOR_PROPERTIES += \
    ro.vendor.build.security_patch=$(VENDOR_SECURITY_PATCH) \
    ro.product.board=$(TARGET_BOOTLOADER_BOARD_NAME) \
    ro.board.platform=$(TARGET_BOARD_PLATFORM) \
    ro.hwui.use_vulkan=$(TARGET_USES_VULKAN)

ifdef TARGET_SCREEN_DENSITY
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.sf.lcd_density=$(TARGET_SCREEN_DENSITY)
endif

ifdef AB_OTA_UPDATER
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.build.ab_update=$(AB_OTA_UPDATER)
endif

# Set ro.product.vndk.version to PLATFORM_VNDK_VERSION only if
# KEEP_VNDK is true, PRODUCT_PRODUCT_VNDK_VERSION is current and
# PLATFORM_VNDK_VERSION is less than or equal to 35.
# ro.product.vndk.version must be removed for the other future builds.
ifeq ($(KEEP_VNDK)|$(PRODUCT_PRODUCT_VNDK_VERSION),true|current)
ifeq ($(call math_is_number,$(PLATFORM_VNDK_VERSION)),true)
ifeq ($(call math_lt_or_eq,$(PLATFORM_VNDK_VERSION),35),true)
ADDITIONAL_PRODUCT_PROPERTIES += ro.product.vndk.version=$(PLATFORM_VNDK_VERSION)
endif
endif
endif

ADDITIONAL_PRODUCT_PROPERTIES += ro.build.characteristics=$(TARGET_AAPT_CHARACTERISTICS)

ifeq ($(AB_OTA_UPDATER),true)
ADDITIONAL_PRODUCT_PROPERTIES += ro.product.ab_ota_partitions=$(subst $(space),$(comma),$(sort $(AB_OTA_PARTITIONS)))
ADDITIONAL_VENDOR_PROPERTIES += ro.vendor.build.ab_ota_partitions=$(subst $(space),$(comma),$(sort $(AB_OTA_PARTITIONS)))
endif

# Set this property for VTS to skip large page size tests on unsupported devices.
ADDITIONAL_PRODUCT_PROPERTIES += \
    ro.product.cpu.pagesize.max=$(TARGET_MAX_PAGE_SIZE_SUPPORTED)

# -----------------------------------------------------------------
###
### In this section we set up the things that are different
### between the build variants
###

is_sdk_build :=

ifneq ($(filter sdk sdk_addon,$(MAKECMDGOALS)),)
is_sdk_build := true
endif

## user/userdebug ##

user_variant := $(filter user userdebug,$(TARGET_BUILD_VARIANT))
enable_target_debugging := true
tags_to_install :=
ifneq (,$(user_variant))
  # Target is secure in user builds.
  ADDITIONAL_SYSTEM_PROPERTIES += ro.secure=1
  ADDITIONAL_SYSTEM_PROPERTIES += security.perf_harden=1

  ifeq ($(user_variant),user)
    ADDITIONAL_SYSTEM_PROPERTIES += ro.adb.secure=1
  endif

  ifeq ($(user_variant),userdebug)
    # Pick up some extra useful tools
    tags_to_install += debug
  else
    # Disable debugging in plain user builds.
    enable_target_debugging :=
  endif

  # Disallow mock locations by default for user builds
  ADDITIONAL_SYSTEM_PROPERTIES += ro.allow.mock.location=0

else # !user_variant
  # Turn on checkjni for non-user builds.
  ADDITIONAL_SYSTEM_PROPERTIES += ro.kernel.android.checkjni=1
  # Set device insecure for non-user builds.
  ADDITIONAL_SYSTEM_PROPERTIES += ro.secure=0
  # Allow mock locations by default for non user builds
  ADDITIONAL_SYSTEM_PROPERTIES += ro.allow.mock.location=1
endif # !user_variant

ifeq (true,$(strip $(enable_target_debugging)))
  # Target is more debuggable and adbd is on by default
  ADDITIONAL_SYSTEM_PROPERTIES += ro.debuggable=1
  # Enable Dalvik lock contention logging.
  ADDITIONAL_SYSTEM_PROPERTIES += dalvik.vm.lockprof.threshold=500
else # !enable_target_debugging
  # Target is less debuggable and adbd is off by default
  ADDITIONAL_SYSTEM_PROPERTIES += ro.debuggable=0
endif # !enable_target_debugging

## eng ##

ifeq ($(TARGET_BUILD_VARIANT),eng)
tags_to_install := debug eng
ifneq ($(filter ro.setupwizard.mode=ENABLED, $(call collapse-pairs, $(ADDITIONAL_SYSTEM_PROPERTIES))),)
  # Don't require the setup wizard on eng builds
  ADDITIONAL_SYSTEM_PROPERTIES := $(filter-out ro.setupwizard.mode=%,\
          $(call collapse-pairs, $(ADDITIONAL_SYSTEM_PROPERTIES))) \
          ro.setupwizard.mode=OPTIONAL
endif
ifndef is_sdk_build
  # To speedup startup of non-preopted builds, don't verify or compile the boot image.
  ADDITIONAL_SYSTEM_PROPERTIES += dalvik.vm.image-dex2oat-filter=extract
endif
endif

## asan ##

# Install some additional tools on ASAN builds IFF we are also installing debug tools
ifneq ($(filter address,$(SANITIZE_TARGET)),)
ifneq (,$(filter debug,$(tags_to_install)))
  tags_to_install += asan
endif
endif

## java coverage ##
# Install additional tools on java coverage builds
ifeq (true,$(EMMA_INSTRUMENT))
ifneq (,$(filter debug,$(tags_to_install)))
  tags_to_install += java_coverage
endif
endif


## sdk ##

ifdef is_sdk_build

# Detect if we want to build a repository for the SDK
sdk_repo_goal := $(strip $(filter sdk_repo,$(MAKECMDGOALS)))
MAKECMDGOALS := $(strip $(filter-out sdk_repo,$(MAKECMDGOALS)))

ifneq ($(words $(sort $(filter-out $(INTERNAL_MODIFIER_TARGETS) checkbuild emulator_tests,$(MAKECMDGOALS)))),1)
$(error The 'sdk' target may not be specified with any other targets)
endif

# TODO: this should be eng I think.  Since the sdk is built from the eng
# variant.
tags_to_install := debug eng
ADDITIONAL_SYSTEM_PROPERTIES += xmpp.auto-presence=true
ADDITIONAL_SYSTEM_PROPERTIES += ro.config.nocheckin=yes
else # !sdk
endif

BUILD_WITHOUT_PV := true

ADDITIONAL_SYSTEM_PROPERTIES += net.bt.name=Android

# This property is set by flashing debug boot image, so default to false.
ADDITIONAL_SYSTEM_PROPERTIES += ro.force.debuggable=0

# ------------------------------------------------------------
# Define a function that, given a list of module tags, returns
# non-empty if that module should be installed in /system.

# For most goals, anything not tagged with the "tests" tag should
# be installed in /system.
define should-install-to-system
$(if $(filter tests,$(1)),,true)
endef

ifdef is_sdk_build
# For the sdk goal, anything with the "samples" tag should be
# installed in /data even if that module also has "eng"/"debug"/"user".
define should-install-to-system
$(if $(filter samples tests,$(1)),,true)
endef
endif


# If they only used the modifier goals (all, etc), we'll actually
# build the default target.
ifeq ($(filter-out $(INTERNAL_MODIFIER_TARGETS),$(MAKECMDGOALS)),)
.PHONY: $(INTERNAL_MODIFIER_TARGETS)
$(INTERNAL_MODIFIER_TARGETS): $(DEFAULT_GOAL)
endif

#
# Typical build; include any Android.mk files we can find.
#

include $(BUILD_SYSTEM)/art_config.mk

# Bring in dex_preopt.mk
# This creates some modules so it needs to be included after
# should-install-to-system is defined (in order for base_rules.mk to function
# properly), but before readonly-final-product-vars is called.
include $(BUILD_SYSTEM)/dex_preopt.mk

# Strip and readonly a few more variables so they won't be modified.
$(readonly-final-product-vars)
ADDITIONAL_SYSTEM_PROPERTIES := $(strip $(ADDITIONAL_SYSTEM_PROPERTIES))
.KATI_READONLY := ADDITIONAL_SYSTEM_PROPERTIES
ADDITIONAL_PRODUCT_PROPERTIES := $(strip $(ADDITIONAL_PRODUCT_PROPERTIES))
.KATI_READONLY := ADDITIONAL_PRODUCT_PROPERTIES

ifneq ($(PRODUCT_ENFORCE_RRO_TARGETS),)
ENFORCE_RRO_SOURCES :=
endif

# Color-coded warnings including current module info
# $(1): message to print
define pretty-warning
$(shell $(call echo-warning,$(LOCAL_MODULE_MAKEFILE),$(LOCAL_MODULE): $(1)))
endef

# Color-coded errors including current module info
# $(1): message to print
define pretty-error
$(shell $(call echo-error,$(LOCAL_MODULE_MAKEFILE),$(LOCAL_MODULE): $(1)))
$(error done)
endef

subdir_makefiles_inc := .
FULL_BUILD :=

ifneq ($(dont_bother),true)
FULL_BUILD := true
#
# Include all of the makefiles in the system
#

subdir_makefiles := $(SOONG_OUT_DIR)/installs-$(TARGET_PRODUCT).mk $(SOONG_ANDROID_MK)
# Android.mk files are only used on Linux builds, Mac only supports Android.bp
ifeq ($(HOST_OS),linux)
  subdir_makefiles += $(file <$(OUT_DIR)/.module_paths/Android.mk.list)
endif
subdir_makefiles += $(SOONG_OUT_DIR)/late-$(TARGET_PRODUCT).mk
subdir_makefiles_total := $(words int $(subdir_makefiles) post finish)
.KATI_READONLY := subdir_makefiles_total

$(foreach mk,$(subdir_makefiles),$(info [$(call inc_and_print,subdir_makefiles_inc)/$(subdir_makefiles_total)] including $(mk) ...)$(eval include $(mk)))

# For an unbundled image, we can skip blueprint_tools because unbundled image
# aims to remove a large number framework projects from the manifest, the
# sources or dependencies for these tools may be missing from the tree.
ifeq (,$(TARGET_BUILD_UNBUNDLED_IMAGE))
droid_targets : blueprint_tools
checkbuild: blueprint_tests
endif

endif # dont_bother

ifndef subdir_makefiles_total
subdir_makefiles_total := $(words init post finish)
endif

$(info [$(call inc_and_print,subdir_makefiles_inc)/$(subdir_makefiles_total)] finishing legacy Make module parsing ...)

# -------------------------------------------------------------------
# All module makefiles have been included at this point.
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Use basic warning/error messages now that LOCAL_MODULE_MAKEFILE
# and LOCAL_MODULE aren't useful anymore.
# -------------------------------------------------------------------
define pretty-warning
$(warning $(1))
endef

define pretty-error
$(error $(1))
endef

# -------------------------------------------------------------------
# Enforce to generate all RRO packages for modules having resource
# overlays.
# -------------------------------------------------------------------
ifneq ($(PRODUCT_ENFORCE_RRO_TARGETS),)
$(call generate_all_enforce_rro_packages)
endif

# -------------------------------------------------------------------
# Sort ALL_MODULES to remove duplicate entries.
# -------------------------------------------------------------------
ALL_MODULES := $(sort $(ALL_MODULES))
# Cannot set to readonly because Makefile extends ALL_MODULES
# .KATI_READONLY := ALL_MODULES

# -------------------------------------------------------------------
# Fix up CUSTOM_MODULES to refer to installed files rather than
# just bare module names.  Leave unknown modules alone in case
# they're actually full paths to a particular file.
known_custom_modules := $(filter $(ALL_MODULES),$(CUSTOM_MODULES))
unknown_custom_modules := $(filter-out $(ALL_MODULES),$(CUSTOM_MODULES))
CUSTOM_MODULES := \
	$(call module-installed-files,$(known_custom_modules)) \
	$(unknown_custom_modules)

# -------------------------------------------------------------------
# Define dependencies for modules that require other modules.
# This can only happen now, after we've read in all module makefiles.
#
# TODO: deal with the fact that a bare module name isn't
# unambiguous enough.  Maybe declare short targets like
# APPS:Quake or HOST:SHARED_LIBRARIES:libutils.
# BUG: the system image won't know to depend on modules that are
# brought in as requirements of other modules.
#
# Resolve the required module name to 32-bit or 64-bit variant.

# Get a list of corresponding module names for the second arch, if they exist.
# $(1): TARGET, HOST or HOST_CROSS
# $(2): A list of module names
define get-modules-for-2nd-arch
$(strip \
  $(foreach m,$(2), \
    $(if $(filter true,$(ALL_MODULES.$(m)$($(1)_2ND_ARCH_MODULE_SUFFIX).FOR_2ND_ARCH)), \
      $(m)$($(1)_2ND_ARCH_MODULE_SUFFIX) \
    ) \
  ) \
)
endef

# Resolves module bitness for PRODUCT_PACKAGES and PRODUCT_HOST_PACKAGES.
# The returned list of module names can be used to access
# ALL_MODULES.<module>.<*> variables.
# Name resolution for PRODUCT_PACKAGES / PRODUCT_HOST_PACKAGES:
#   foo:32 resolves to foo_32;
#   foo:64 resolves to foo;
#   foo resolves to both foo and foo_32 (if foo_32 is defined).
#
# Name resolution for HOST_CROSS modules:
#   foo:32 resolves to foo;
#   foo:64 resolves to foo_64;
#   foo resolves to both foo and foo_64 (if foo_64 is defined).
#
# $(1): TARGET, HOST or HOST_CROSS
# $(2): A list of simple module names with :32 and :64 suffix
define resolve-bitness-for-modules
$(strip \
  $(eval modules_32 := $(patsubst %:32,%,$(filter %:32,$(2)))) \
  $(eval modules_64 := $(patsubst %:64,%,$(filter %:64,$(2)))) \
  $(eval modules_both := $(filter-out %:32 %:64,$(2))) \
  $(eval ### if 2ND_HOST_CROSS_IS_64_BIT, then primary/secondary are reversed for HOST_CROSS modules) \
  $(if $(filter HOST_CROSS_true,$(1)_$(2ND_HOST_CROSS_IS_64_BIT)), \
    $(eval modules_1st_arch := $(modules_32)) \
    $(eval modules_2nd_arch := $(modules_64)), \
    $(eval modules_1st_arch := $(modules_64)) \
    $(eval modules_2nd_arch := $(modules_32))) \
  $(eval ### Note for 32-bit product, 32 and 64 will be added as their original module names.) \
  $(eval modules := $(modules_1st_arch)) \
  $(if $($(1)_2ND_ARCH), \
    $(eval modules += $(call get-modules-for-2nd-arch,$(1),$(modules_2nd_arch))), \
    $(eval modules += $(modules_2nd_arch))) \
  $(eval ### For the rest we add both) \
  $(eval modules += $(modules_both)) \
  $(if $($(1)_2ND_ARCH), \
    $(eval modules += $(call get-modules-for-2nd-arch,$(1),$(modules_both)))) \
  $(modules) \
)
endef

# Resolve the required module names to 32-bit or 64-bit variant for:
#   ALL_MODULES.<*>.REQUIRED_FROM_TARGET
#   ALL_MODULES.<*>.REQUIRED_FROM_HOST
#   ALL_MODULES.<*>.REQUIRED_FROM_HOST_CROSS
#
# If a module is for cross host OS, the required modules are also for that OS.
# Required modules explicitly suffixed with :32 or :64 resolve to that bitness.
# Otherwise if the requiring module is native and the required module is shared
# library or native test, then the required module resolves to the same bitness.
# Otherwise the required module resolves to both variants, if they exist.
# $(1): TARGET, HOST or HOST_CROSS
define select-bitness-of-required-modules
$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).REQUIRED_FROM_$(1))) \
  $(if $(r), \
    $(if $(filter HOST_CROSS,$(1)), \
      $(if $(ALL_MODULES.$(m).FOR_HOST_CROSS),,$(error Only expected REQUIRED_FROM_HOST_CROSS on FOR_HOST_CROSS modules - $(m))) \
      $(eval r := $(addprefix host_cross_,$(r)))) \
    $(eval module_is_native := \
      $(filter EXECUTABLES SHARED_LIBRARIES NATIVE_TESTS,$(ALL_MODULES.$(m).CLASS))) \
    $(eval r_r := \
      $(foreach r_i,$(r), \
        $(if $(filter %:32 %:64,$(r_i)), \
          $(eval r_m := $(call resolve-bitness-for-modules,$(1),$(r_i))), \
          $(eval r_m := \
            $(eval r_i_2nd := $(call get-modules-for-2nd-arch,$(1),$(r_i))) \
            $(eval required_is_shared_library_or_native_test := \
              $(filter SHARED_LIBRARIES NATIVE_TESTS, \
                $(ALL_MODULES.$(r_i).CLASS) $(ALL_MODULES.$(r_i_2nd).CLASS))) \
            $(if $(and $(module_is_native),$(required_is_shared_library_or_native_test)), \
              $(if $(ALL_MODULES.$(m).FOR_2ND_ARCH),$(r_i_2nd),$(r_i)), \
              $(r_i) $(r_i_2nd)))) \
        $(eval r_m := $(foreach r_j,$(r_m),$(if $(ALL_MODULES.$(r_j).PATH),$(r_j)))) \
        $(if $(r_m),,$(eval _nonexistent_required += $(1)$(comma)$(m)$(comma)$(1)$(comma)$(r_i))) \
        $(r_m))) \
    $(eval ALL_MODULES.$(m).REQUIRED_FROM_$(1) := $(sort $(r_r))) \
  ) \
)
endef

# Resolve the required module names to 32-bit or 64-bit variant for:
#   ALL_MODULES.<*>.TARGET_REQUIRED_FROM_HOST
#   ALL_MODULES.<*>.HOST_REQUIRED_FROM_TARGET
#
# This is like select-bitness-of-required-modules, but it doesn't have
# complicated logic for various module types.
# Calls resolve-bitness-for-modules to resolve module names.
# $(1): TARGET or HOST
# $(2): HOST or TARGET
define select-bitness-of-target-host-required-modules
$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).$(1)_REQUIRED_FROM_$(2))) \
  $(if $(r), \
    $(eval r_r := \
      $(foreach r_i,$(r), \
        $(eval r_m := $(call resolve-bitness-for-modules,$(1),$(r_i))) \
        $(eval r_m := $(foreach r_j,$(r_m),$(if $(ALL_MODULES.$(r_j).PATH),$(r_j)))) \
        $(if $(r_m),,$(eval _nonexistent_required += $(2)$(comma)$(m)$(comma)$(1)$(comma)$(r_i))) \
        $(r_m))) \
    $(eval ALL_MODULES.$(m).$(1)_REQUIRED_FROM_$(2) := $(sort $(r_r))) \
  ) \
)
endef

_nonexistent_required :=
$(call select-bitness-of-required-modules,TARGET)
$(call select-bitness-of-required-modules,HOST)
$(call select-bitness-of-required-modules,HOST_CROSS)
$(call select-bitness-of-target-host-required-modules,TARGET,HOST)
$(call select-bitness-of-target-host-required-modules,HOST,TARGET)
_nonexistent_required := $(sort $(_nonexistent_required))

check_missing_required_modules := true
ifneq (,$(filter true,$(ALLOW_MISSING_DEPENDENCIES) $(BUILD_BROKEN_MISSING_REQUIRED_MODULES)))
  check_missing_required_modules :=
endif # ALLOW_MISSING_DEPENDENCIES == true || BUILD_BROKEN_MISSING_REQUIRED_MODULES == true

# Some executables are skipped in ASAN SANITIZE_TARGET build, thus breaking their dependencies.
ifneq (,$(filter address,$(SANITIZE_TARGET)))
  check_missing_required_modules :=
endif # SANITIZE_TARGET has ASAN

# HOST OS darwin build is broken, disable this check for darwin for now.
# TODO(b/162102724): Remove this when darwin host has no broken dependency.
ifneq (,$(filter $(HOST_OS),darwin))
  check_missing_required_modules :=
endif # HOST_OS == darwin

ifeq (true,$(check_missing_required_modules))
ifneq (,$(_nonexistent_required))
  $(warning Missing required dependencies:)
  $(foreach r_i,$(_nonexistent_required), \
    $(eval r := $(subst $(comma),$(space),$(r_i))) \
    $(info $(word 1,$(r)) module $(word 2,$(r)) requires non-existent $(word 3,$(r)) module: $(word 4,$(r))) \
  )
  $(warning Set BUILD_BROKEN_MISSING_REQUIRED_MODULES := true to bypass this check if this is intentional)
  ifneq (,$(PRODUCT_SOURCE_ROOT_DIRS))
    $(warning PRODUCT_SOURCE_ROOT_DIRS is non-empty. Some necessary modules may have been skipped by Soong)
  endif
  $(error Build failed)
endif # _nonexistent_required != empty
endif # check_missing_required_modules == true

define add-required-deps
$(1): | $(2)
endef

# Use a normal dependency instead of an order-only dependency when installing
# host dynamic binaries so that the timestamp of the final binary always
# changes, even if the toc optimization has skipped relinking the binary
# and its dependant shared libraries.
define add-required-host-so-deps
$(1): $(2)
endef

# Sets up dependencies such that whenever a host module is installed,
# any other host modules listed in $(ALL_MODULES.$(m).REQUIRED_FROM_HOST) will also be installed
define add-all-host-to-host-required-modules-deps
$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).REQUIRED_FROM_HOST)) \
  $(if $(r), \
    $(eval r := $(call module-installed-files,$(r))) \
    $(eval h_m := $(filter $(HOST_OUT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval h_r := $(filter $(HOST_OUT)/%, $(r))) \
    $(eval h_r := $(filter-out $(h_m), $(h_r))) \
    $(if $(h_m), $(eval $(call add-required-deps, $(h_m),$(h_r)))) \
  ) \
)
endef
$(call add-all-host-to-host-required-modules-deps)

# Sets up dependencies such that whenever a host cross module is installed,
# any other host cross modules listed in $(ALL_MODULES.$(m).REQUIRED_FROM_HOST_CROSS) will also be installed
define add-all-host-cross-to-host-cross-required-modules-deps
$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).REQUIRED_FROM_HOST_CROSS)) \
  $(if $(r), \
    $(eval r := $(call module-installed-files,$(r))) \
    $(eval hc_m := $(filter $(HOST_CROSS_OUT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval hc_r := $(filter $(HOST_CROSS_OUT)/%, $(r))) \
    $(eval hc_r := $(filter-out $(hc_m), $(hc_r))) \
    $(if $(hc_m), $(eval $(call add-required-deps, $(hc_m),$(hc_r)))) \
  ) \
)
endef
$(call add-all-host-cross-to-host-cross-required-modules-deps)

# Sets up dependencies such that whenever a target module is installed,
# any other target modules listed in $(ALL_MODULES.$(m).REQUIRED_FROM_TARGET) will also be installed
# This doesn't apply to ORDERONLY_INSTALLED items.
define add-all-target-to-target-required-modules-deps
$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).REQUIRED_FROM_TARGET)) \
  $(if $(r), \
    $(eval r := $(call module-installed-files,$(r))) \
    $(eval t_m := $(filter $(TARGET_OUT_ROOT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval t_m := $(filter-out $(ALL_MODULES.$(m).ORDERONLY_INSTALLED), $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval t_r := $(filter $(TARGET_OUT_ROOT)/%, $(r))) \
    $(eval t_r := $(filter-out $(t_m), $(t_r))) \
    $(if $(t_m), $(eval $(call add-required-deps, $(t_m),$(t_r)))) \
  ) \
)
endef
$(call add-all-target-to-target-required-modules-deps)

# Sets up dependencies such that whenever a host module is installed,
# any target modules listed in $(ALL_MODULES.$(m).TARGET_REQUIRED_FROM_HOST) will also be installed
define add-all-host-to-target-required-modules-deps
$(foreach m,$(ALL_MODULES), \
  $(eval req_mods := $(ALL_MODULES.$(m).TARGET_REQUIRED_FROM_HOST))\
  $(if $(req_mods), \
    $(eval req_files := )\
    $(foreach req_mod,$(req_mods), \
      $(eval req_file := $(filter $(TARGET_OUT_ROOT)/%, $(call module-installed-files,$(req_mod)))) \
      $(if $(filter true,$(ALLOW_MISSING_DEPENDENCIES)), \
        , \
        $(if $(strip $(req_file)), \
          , \
          $(error $(m).LOCAL_TARGET_REQUIRED_MODULES : illegal value $(req_mod) : not a device module. If you want to specify host modules to be required to be installed along with your host module, add those module names to LOCAL_REQUIRED_MODULES instead) \
        ) \
      ) \
      $(eval req_files := $(req_files)$(space)$(req_file))\
    )\
    $(eval req_files := $(strip $(req_files)))\
    $(eval mod_files := $(filter $(HOST_OUT)/%, $(call module-installed-files,$(m)))) \
    $(if $(mod_files),\
      $(eval $(call add-required-deps, $(mod_files),$(req_files))) \
    )\
  )\
)
endef
$(call add-all-host-to-target-required-modules-deps)

# Sets up dependencies such that whenever a target module is installed,
# any host modules listed in $(ALL_MODULES.$(m).HOST_REQUIRED_FROM_TARGET) will also be installed
define add-all-target-to-host-required-modules-deps
$(foreach m,$(ALL_MODULES), \
  $(eval req_mods := $(ALL_MODULES.$(m).HOST_REQUIRED_FROM_TARGET))\
  $(if $(req_mods), \
    $(eval req_files := )\
    $(foreach req_mod,$(req_mods), \
      $(eval req_file := $(filter $(HOST_OUT)/%, $(call module-installed-files,$(req_mod)))) \
      $(if $(filter true,$(ALLOW_MISSING_DEPENDENCIES)), \
        , \
        $(if $(strip $(req_file)), \
          , \
          $(error $(m).LOCAL_HOST_REQUIRED_MODULES : illegal value $(req_mod) : not a host module. If you want to specify target modules to be required to be installed along with your target module, add those module names to LOCAL_REQUIRED_MODULES instead) \
        ) \
      ) \
      $(eval req_files := $(req_files)$(space)$(req_file))\
    )\
    $(eval req_files := $(strip $(req_files)))\
    $(eval mod_files := $(filter $(TARGET_OUT_ROOT)/%, $(call module-installed-files,$(m))))\
    $(if $(mod_files),\
      $(eval $(call add-required-deps, $(mod_files),$(req_files))) \
    )\
  )\
)
endef
$(call add-all-target-to-host-required-modules-deps)

t_m :=
h_m :=
hc_m :=
t_r :=
h_r :=
hc_r :=

# Establish the dependencies on the shared libraries.
# It also adds the shared library module names to ALL_MODULES.$(m).REQUIRED_FROM_(TARGET|HOST|HOST_CROSS),
# so they can be expanded to product_MODULES later.
# $(1): TARGET_ or HOST_ or HOST_CROSS_.
# $(2): non-empty for 2nd arch.
# $(3): non-empty for host cross compile.
define resolve-shared-libs-depes
$(foreach m,$($(if $(2),$($(1)2ND_ARCH_VAR_PREFIX))$(1)DEPENDENCIES_ON_SHARED_LIBRARIES),\
  $(eval p := $(subst :,$(space),$(m)))\
  $(eval mod := $(firstword $(p)))\
  $(eval deps := $(subst $(comma),$(space),$(lastword $(p))))\
  $(eval root := $(1)OUT$(if $(call streq,$(1),TARGET_),_ROOT))\
  $(if $(2),$(eval deps := $(addsuffix $($(1)2ND_ARCH_MODULE_SUFFIX),$(deps))))\
  $(if $(3),$(eval deps := $(addprefix host_cross_,$(deps))))\
  $(eval r := $(filter $($(root))/%,$(call module-installed-files,\
    $(deps))))\
  $(if $(filter $(1),HOST_),\
    $(eval ALL_MODULES.$(mod).HOST_SHARED_LIBRARY_FILES := $$(ALL_MODULES.$(mod).HOST_SHARED_LIBRARY_FILES) $(word 2,$(p)) $(r))\
    $(eval ALL_MODULES.$(mod).HOST_SHARED_LIBRARIES := $$(ALL_MODULES.$(mod).HOST_SHARED_LIBRARIES) $(deps))\
    $(eval $(call add-required-host-so-deps,$(word 2,$(p)),$(r))),\
    $(eval $(call add-required-deps,$(word 2,$(p)),$(r))))\
  $(eval ALL_MODULES.$(mod).REQUIRED_FROM_$(patsubst %_,%,$(1)) += $(deps)))
endef

# Recursively resolve host shared library dependency for a given module.
# $(1): module name
# Returns all dependencies of shared library.
define get-all-shared-libs-deps
$(if $(_all_deps_for_$(1)_set_),$(_all_deps_for_$(1)_),\
  $(eval _all_deps_for_$(1)_ :=) \
  $(foreach dep,$(ALL_MODULES.$(1).HOST_SHARED_LIBRARIES),\
    $(foreach m,$(call get-all-shared-libs-deps,$(dep)),\
      $(eval _all_deps_for_$(1)_ := $$(_all_deps_for_$(1)_) $(m))\
      $(eval _all_deps_for_$(1)_ := $(sort $(_all_deps_for_$(1)_))))\
    $(eval _all_deps_for_$(1)_ := $$(_all_deps_for_$(1)_) $(dep))\
    $(eval _all_deps_for_$(1)_ := $(sort $(_all_deps_for_$(1)_) $(dep)))\
    $(eval _all_deps_for_$(1)_set_ := true))\
$(_all_deps_for_$(1)_))
endef

# Scan all modules in general-tests, device-tests and other selected suites and
# flatten the shared library dependencies.
define update-host-shared-libs-deps-for-suites
$(foreach suite,general-tests device-tests vts tvts art-host-tests host-unit-tests,\
  $(foreach m,$(COMPATIBILITY.$(suite).MODULES),\
    $(eval my_deps := $(call get-all-shared-libs-deps,$(m)))\
    $(foreach dep,$(my_deps),\
      $(foreach f,$(ALL_MODULES.$(dep).HOST_SHARED_LIBRARY_FILES),\
        $(if $(filter $(suite),device-tests general-tests art-host-tests host-unit-tests),\
          $(eval my_testcases := $(HOST_OUT_TESTCASES)),\
          $(eval my_testcases := $$(COMPATIBILITY_TESTCASES_OUT_$(suite))))\
        $(eval target := $(my_testcases)/$(lastword $(subst /, ,$(dir $(f))))/$(notdir $(f)))\
        $(if $(strip $(ALL_TARGETS.$(target).META_LIC)),,$(call declare-copy-target-license-metadata,$(target),$(f)))\
        $(eval COMPATIBILITY.$(suite).HOST_SHARED_LIBRARY.FILES := \
          $$(COMPATIBILITY.$(suite).HOST_SHARED_LIBRARY.FILES) $(f):$(target))\
        $(eval COMPATIBILITY.$(suite).HOST_SHARED_LIBRARY.FILES := \
          $(sort $(COMPATIBILITY.$(suite).HOST_SHARED_LIBRARY.FILES)))))))
endef

$(call resolve-shared-libs-depes,TARGET_)
ifdef TARGET_2ND_ARCH
$(call resolve-shared-libs-depes,TARGET_,true)
endif
$(call resolve-shared-libs-depes,HOST_)
ifdef HOST_2ND_ARCH
$(call resolve-shared-libs-depes,HOST_,true)
endif
# Update host side shared library dependencies for tests in suite device-tests and general-tests.
# This should be called after calling resolve-shared-libs-depes for HOST_2ND_ARCH.
$(call update-host-shared-libs-deps-for-suites)
ifdef HOST_CROSS_OS
$(call resolve-shared-libs-depes,HOST_CROSS_,,true)
ifdef HOST_CROSS_2ND_ARCH
$(call resolve-shared-libs-depes,HOST_CROSS_,true,true)
endif
endif

# Pass the shared libraries dependencies to prebuilt ELF file check.
define add-elf-file-check-shared-lib
$(1): PRIVATE_SHARED_LIBRARY_FILES += $(2)
$(1): $(2)
endef

define resolve-shared-libs-for-elf-file-check
$(foreach m,$($(if $(2),$($(1)2ND_ARCH_VAR_PREFIX))$(1)DEPENDENCIES_ON_SHARED_LIBRARIES),\
  $(eval p := $(subst :,$(space),$(m)))\
  $(eval mod := $(firstword $(p)))\
  \
  $(eval deps := $(subst $(comma),$(space),$(lastword $(p))))\
  $(if $(2),$(eval deps := $(addsuffix $($(1)2ND_ARCH_MODULE_SUFFIX),$(deps))))\
  $(eval root := $(1)OUT$(if $(call streq,$(1),TARGET_),_ROOT))\
  $(eval deps := $(filter $($(root))/%$($(1)SHLIB_SUFFIX),$(call module-built-files,$(deps))))\
  \
  $(eval r := $(firstword $(filter \
    $($(if $(2),$($(1)2ND_ARCH_VAR_PREFIX))TARGET_OUT_INTERMEDIATES)/EXECUTABLES/%\
    $($(if $(2),$($(1)2ND_ARCH_VAR_PREFIX))TARGET_OUT_INTERMEDIATES)/NATIVE_TESTS/%\
    $($(if $(2),$($(1)2ND_ARCH_VAR_PREFIX))TARGET_OUT_INTERMEDIATES)/SHARED_LIBRARIES/%,\
    $(call module-built-files,$(mod)))))\
  \
  $(if $(and $(r),$(deps)),\
    $(eval stamp := $(dir $(r))check_elf_files.timestamp)\
    $(if $(CHECK_ELF_FILES.$(stamp)),\
      $(eval $(call add-elf-file-check-shared-lib,$(stamp),$(deps))))\
  ))
endef

$(call resolve-shared-libs-for-elf-file-check,TARGET_)
ifdef TARGET_2ND_ARCH
$(call resolve-shared-libs-for-elf-file-check,TARGET_,true)
endif

m :=
r :=
p :=
stamp :=
deps :=
add-required-deps :=

################################################################################
# Link type checking
#
# ALL_LINK_TYPES contains a list of all link type prefixes (generally one per
# module, but APKs can "link" to both java and native code). The link type
# prefix consists of all the information needed by intermediates-dir-for:
#
#  LINK_TYPE:TARGET:_:2ND:STATIC_LIBRARIES:libfoo
#
#   1: LINK_TYPE literal
#   2: prefix
#     - TARGET
#     - HOST
#     - HOST_CROSS
#   3: Whether to use the common intermediates directory or not
#     - _
#     - COMMON
#   4: Whether it's the second arch or not
#     - _
#     - 2ND_
#   5: Module Class
#     - STATIC_LIBRARIES
#     - SHARED_LIBRARIES
#     - ...
#   6: Module Name
#
# Then fields under that are separated by a period and the field name:
#   - TYPE: the link types for this module
#   - MAKEFILE: Where this module was defined
#   - BUILT: The built module location
#   - DEPS: the link type prefixes for the module's dependencies
#   - ALLOWED: the link types to allow in this module's dependencies
#   - WARN: the link types to warn about in this module's dependencies
#
# All of the dependency link types not listed in ALLOWED or WARN will become
# errors.
################################################################################

link_type_error :=

define link-type-prefix
$(word 2,$(subst :,$(space),$(1)))
endef
define link-type-common
$(patsubst _,,$(word 3,$(subst :,$(space),$(1))))
endef
define link-type-2ndarchprefix
$(patsubst _,,$(word 4,$(subst :,$(space),$(1))))
endef
define link-type-class
$(word 5,$(subst :,$(space),$(1)))
endef
define link-type-name
$(word 6,$(subst :,$(space),$(1)))
endef
define link-type-os
$(strip $(eval _p := $(link-type-prefix))\
  $(if $(filter HOST HOST_CROSS,$(_p)),\
    $($(_p)_OS),\
    android))
endef
define link-type-arch
$($(link-type-prefix)_$(link-type-2ndarchprefix)ARCH)
endef
define link-type-name-variant
$(link-type-name) ($(link-type-class) $(link-type-os)-$(link-type-arch))
endef

# $(1): the prefix of the module doing the linking
# $(2): the prefix of the linked module
define link-type-warning
$(shell $(call echo-warning,$($(1).MAKEFILE),"$(call link-type-name,$(1)) ($($(1).TYPE)) should not link against $(call link-type-name,$(2)) ($(3))"))
endef

# $(1): the prefix of the module doing the linking
# $(2): the prefix of the linked module
define link-type-error
$(shell $(call echo-error,$($(1).MAKEFILE),"$(call link-type-name,$(1)) ($($(1).TYPE)) can not link against $(call link-type-name,$(2)) ($(3))"))\
$(eval link_type_error := true)
endef

link-type-missing :=
ifneq ($(ALLOW_MISSING_DEPENDENCIES),true)
  # Print an error message if the linked-to module is missing
  # $(1): the prefix of the module doing the linking
  # $(2): the prefix of the missing module
  define link-type-missing
    $(shell $(call echo-error,$($(1).MAKEFILE),"$(call link-type-name-variant,$(1)) missing $(call link-type-name-variant,$(2))"))\
    $(eval available_variants := $(filter %:$(call link-type-name,$(2)),$(ALL_LINK_TYPES)))\
    $(if $(available_variants),\
      $(info Available variants:)\
      $(foreach v,$(available_variants),$(info $(space)$(space)$(call link-type-name-variant,$(v)))))\
    $(info You can set ALLOW_MISSING_DEPENDENCIES=true in your environment if this is intentional, but that may defer real problems until later in the build.)\
    $(eval link_type_error := true)
  endef
else
  define link-type-missing
    $(eval $$(1).MISSING := true)
  endef
endif

# Verify that $(1) can link against $(2)
# Both $(1) and $(2) are the link type prefix defined above
define verify-link-type
$(foreach t,$($(2).TYPE),\
  $(if $(filter-out $($(1).ALLOWED),$(t)),\
    $(if $(filter $(t),$($(1).WARN)),\
      $(call link-type-warning,$(1),$(2),$(t)),\
      $(call link-type-error,$(1),$(2),$(t)))))
endef

$(foreach lt,$(ALL_LINK_TYPES),\
  $(foreach d,$($(lt).DEPS),\
    $(if $($(d).TYPE),\
      $(call verify-link-type,$(lt),$(d)),\
      $(call link-type-missing,$(lt),$(d)))))

ifdef link_type_error
  $(error exiting from previous errors)
endif

# -------------------------------------------------------------------
# Handle exported/imported includes

# Recursively calculate flags
$(foreach export,$(EXPORTS_LIST), \
  $(eval EXPORTS.$$(export) = $$(EXPORTS.$(export).FLAGS) \
    $(foreach dep,$(EXPORTS.$(export).REEXPORT),$$(EXPORTS.$(dep)))))

# Recursively calculate dependencies
$(foreach export,$(EXPORTS_LIST), \
  $(eval EXPORT_DEPS.$$(export) = $$(EXPORTS.$(export).DEPS) \
    $(foreach dep,$(EXPORTS.$(export).REEXPORT),$$(EXPORT_DEPS.$(dep)))))

# Converts the recursive variables to simple variables so that we don't have to
# evaluate them for every .o rule
$(foreach export,$(EXPORTS_LIST),$(eval EXPORTS.$$(export) := $$(strip $$(EXPORTS.$$(export)))))
$(foreach export,$(EXPORTS_LIST),$(eval EXPORT_DEPS.$$(export) := $$(sort $$(EXPORT_DEPS.$$(export)))))

# Add dependencies
$(foreach export,$(EXPORTS_LIST),$(eval $(call add-dependency,$$(EXPORTS.$$(export).USERS),$$(EXPORT_DEPS.$$(export)))))

# -------------------------------------------------------------------
# Figure out our module sets.
#
# Of the modules defined by the component makefiles,
# determine what we actually want to build.


# Expand a list of modules to the modules that they override (if any)
# $(1): The list of modules.
define module-overrides
$(foreach m,$(1),\
  $(eval _mo_overrides := $(PACKAGES.$(m).OVERRIDES) $(EXECUTABLES.$(m).OVERRIDES) $(SHARED_LIBRARIES.$(m).OVERRIDES) $(ETC.$(m).OVERRIDES))\
  $(if $(filter $(m),$(_mo_overrides)),\
    $(error Module $(m) cannot override itself),\
    $(_mo_overrides)))
endef

###########################################################
## Expand a module name list with REQUIRED modules
###########################################################
# $(1): The variable name that holds the initial module name list.
#       the variable will be modified to hold the expanded results.
# $(2): The initial module name list.
# $(3): The list of overridden modules.
# Returns empty string (maybe with some whitespaces).
define expand-required-modules
$(eval _erm_req := $(foreach m,$(2),$(ALL_MODULES.$(m).REQUIRED_FROM_TARGET))) \
$(eval _erm_new_modules := $(sort $(filter-out $($(1)),$(_erm_req)))) \
$(eval _erm_new_overrides := $(call module-overrides,$(_erm_new_modules))) \
$(eval _erm_all_overrides := $(3) $(_erm_new_overrides)) \
$(eval _erm_new_modules := $(filter-out $(_erm_all_overrides), $(_erm_new_modules))) \
$(eval $(1) := $(filter-out $(_erm_new_overrides),$($(1)))) \
$(eval $(1) += $(_erm_new_modules)) \
$(if $(_erm_new_modules),\
  $(call expand-required-modules,$(1),$(_erm_new_modules),$(_erm_all_overrides)))
endef

# Same as expand-required-modules above, but does not handle module overrides, as
# we don't intend to support them on the host.
# $(1): The variable name that holds the initial module name list.
#       the variable will be modified to hold the expanded results.
# $(2): The initial module name list.
# $(3): HOST or HOST_CROSS depending on whether we're expanding host or host cross modules
# Returns empty string (maybe with some whitespaces).
define expand-required-host-modules
$(eval _erm_req := $(foreach m,$(2),$(ALL_MODULES.$(m).REQUIRED_FROM_$(3)))) \
$(eval _erm_new_modules := $(sort $(filter-out $($(1)),$(_erm_req)))) \
$(eval $(1) += $(_erm_new_modules)) \
$(if $(_erm_new_modules),\
  $(call expand-required-host-modules,$(1),$(_erm_new_modules),$(3)))
endef

# Transforms paths relative to PRODUCT_OUT to absolute paths.
# $(1): list of relative paths
# $(2): optional suffix to append to paths
define resolve-product-relative-paths
  $(subst $(_vendor_path_placeholder),$(TARGET_COPY_OUT_VENDOR),\
    $(subst $(_product_path_placeholder),$(TARGET_COPY_OUT_PRODUCT),\
      $(subst $(_system_ext_path_placeholder),$(TARGET_COPY_OUT_SYSTEM_EXT),\
        $(subst $(_odm_path_placeholder),$(TARGET_COPY_OUT_ODM),\
          $(subst $(_vendor_dlkm_path_placeholder),$(TARGET_COPY_OUT_VENDOR_DLKM),\
            $(subst $(_odm_dlkm_path_placeholder),$(TARGET_COPY_OUT_ODM_DLKM),\
              $(subst $(_system_dlkm_path_placeholder),$(TARGET_COPY_OUT_SYSTEM_DLKM),\
                $(foreach p,$(1),$(call append-path,$(PRODUCT_OUT),$(p)$(2))))))))))
endef

# Returns modules included automatically as a result of certain BoardConfig
# variables being set.
define auto-included-modules
  $(if $(and $(BOARD_VNDK_VERSION),$(filter true,$(KEEP_VNDK))),vndk_package) \
  $(if $(filter true,$(KEEP_VNDK)),,llndk_in_system) \
  $(if $(DEVICE_MANIFEST_FILE),vendor_manifest.xml) \
  $(if $(DEVICE_MANIFEST_SKUS),$(foreach sku, $(DEVICE_MANIFEST_SKUS),vendor_manifest_$(sku).xml)) \
  $(if $(ODM_MANIFEST_FILES),odm_manifest.xml) \
  $(if $(ODM_MANIFEST_SKUS),$(foreach sku, $(ODM_MANIFEST_SKUS),odm_manifest_$(sku).xml)) \

endef

# Lists the modules particular product installs.
# The base list of modules to build for this product is specified
# by the appropriate product definition file, which was included
# by product_config.mk.
# Name resolution for PRODUCT_PACKAGES:
#   foo:32 resolves to foo_32;
#   foo:64 resolves to foo;
#   foo resolves to both foo and foo_32 (if foo_32 is defined).
#
# Name resolution for LOCAL_REQUIRED_MODULES:
#   See the select-bitness-of-required-modules definition.
# $(1): product makefile
define product-installed-modules
  $(eval _pif_modules := \
    $(call get-product-var,$(1),PRODUCT_PACKAGES) \
    $(if $(filter eng,$(tags_to_install)),$(call get-product-var,$(1),PRODUCT_PACKAGES_ENG)) \
    $(if $(filter debug,$(tags_to_install)),$(call get-product-var,$(1),PRODUCT_PACKAGES_DEBUG)) \
    $(if $(filter tests,$(tags_to_install)),$(call get-product-var,$(1),PRODUCT_PACKAGES_TESTS)) \
    $(if $(filter asan,$(tags_to_install)),$(call get-product-var,$(1),PRODUCT_PACKAGES_DEBUG_ASAN)) \
    $(if $(filter java_coverage,$(tags_to_install)),$(call get-product-var,$(1),PRODUCT_PACKAGES_DEBUG_JAVA_COVERAGE)) \
    $(if $(filter arm64,$(TARGET_ARCH) $(TARGET_2ND_ARCH)),$(call get-product-var,$(1),PRODUCT_PACKAGES_ARM64)) \
    $(if $(PRODUCT_SHIPPING_API_LEVEL), \
      $(if $(call math_gt_or_eq,29,$(PRODUCT_SHIPPING_API_LEVEL)),$(call get-product-var,$(1),PRODUCT_PACKAGES_SHIPPING_API_LEVEL_29)) \
      $(if $(call math_gt_or_eq,33,$(PRODUCT_SHIPPING_API_LEVEL)),$(call get-product-var,$(1),PRODUCT_PACKAGES_SHIPPING_API_LEVEL_33)) \
      $(if $(call math_gt_or_eq,34,$(PRODUCT_SHIPPING_API_LEVEL)),$(call get-product-var,$(1),PRODUCT_PACKAGES_SHIPPING_API_LEVEL_34)) \
    ) \
    $(call auto-included-modules) \
  ) \
  $(eval ### Filter out the overridden packages and executables before doing expansion) \
  $(eval _pif_overrides := $(call module-overrides,$(_pif_modules))) \
  $(eval _pif_modules := $(filter-out $(_pif_overrides), $(_pif_modules))) \
  $(eval ### Resolve the :32 :64 module name) \
  $(eval _pif_modules := $(sort $(call resolve-bitness-for-modules,TARGET,$(_pif_modules)))) \
  $(call expand-required-modules,_pif_modules,$(_pif_modules),$(_pif_overrides)) \
  $(_pif_modules)
endef

# Lists most of the files a particular product installs.
# It gives all the installed files for all modules returned by product-installed-modules,
# and also includes PRODUCT_COPY_FILES.
define product-installed-files
  $(filter-out $(HOST_OUT_ROOT)/%,$(call module-installed-files, $(call product-installed-modules,$(1)))) \
  $(call resolve-product-relative-paths,\
    $(foreach cf,$(call get-product-var,$(1),PRODUCT_COPY_FILES),$(call word-colon,2,$(cf))))
endef

# Similar to product-installed-files above, but handles PRODUCT_HOST_PACKAGES instead
# This does support the :32 / :64 syntax, but does not support module overrides.
define host-installed-files
  $(eval _hif_modules := $(call get-product-var,$(1),PRODUCT_HOST_PACKAGES)) \
  $(eval ### Split host vs host cross modules) \
  $(eval _hcif_modules := $(filter host_cross_%,$(_hif_modules))) \
  $(eval _hif_modules := $(filter-out host_cross_%,$(_hif_modules))) \
  $(eval ### Resolve the :32 :64 module name) \
  $(eval _hif_modules := $(sort $(call resolve-bitness-for-modules,HOST,$(_hif_modules)))) \
  $(eval _hcif_modules := $(sort $(call resolve-bitness-for-modules,HOST_CROSS,$(_hcif_modules)))) \
  $(call expand-required-host-modules,_hif_modules,$(_hif_modules),HOST) \
  $(call expand-required-host-modules,_hcif_modules,$(_hcif_modules),HOST_CROSS) \
  $(filter $(HOST_OUT)/%,$(call module-installed-files, $(_hif_modules))) \
  $(filter $(HOST_CROSS_OUT)/%,$(call module-installed-files, $(_hcif_modules)))
endef

# Fails the build if the given list is non-empty, and prints it entries (stripping PRODUCT_OUT).
# $(1): list of files to print
# $(2): heading to print on failure
define maybe-print-list-and-error
$(if $(strip $(1)), \
  $(warning $(2)) \
  $(info Offending entries:) \
  $(foreach e,$(sort $(1)),$(info    $(patsubst $(PRODUCT_OUT)/%,%,$(e)))) \
  $(error Build failed) \
)
endef

ifeq ($(HOST_OS),darwin)
  # Target builds are not supported on Mac
  product_target_FILES :=
  product_host_FILES := $(call host-installed-files,$(INTERNAL_PRODUCT))
else ifdef FULL_BUILD
  ifneq (true,$(ALLOW_MISSING_DEPENDENCIES))
    # Check to ensure that all modules in PRODUCT_PACKAGES exist (opt in per product)
    ifeq (true,$(PRODUCT_ENFORCE_PACKAGES_EXIST))
      _allow_list := $(PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST)
      _modules := $(PRODUCT_PACKAGES)
      # Strip :32 and :64 suffixes
      _modules := $(patsubst %:32,%,$(_modules))
      _modules := $(patsubst %:64,%,$(_modules))
      # Quickly check all modules in PRODUCT_PACKAGES exist. We check for the
      # existence if either <module> or the <module>_32 variant.
      _nonexistent_modules := $(foreach m,$(_modules), \
        $(if $(or $(ALL_MODULES.$(m).PATH),$(call get-modules-for-2nd-arch,TARGET,$(m))),,$(m)))
      $(call maybe-print-list-and-error,$(filter-out $(_allow_list),$(_nonexistent_modules)),\
        $(INTERNAL_PRODUCT) includes non-existent modules in PRODUCT_PACKAGES)
      # TODO(b/182105280): Consider re-enabling this check when the ART modules
      # have been cleaned up from the allowed_list in target/product/generic.mk.
      #$(call maybe-print-list-and-error,$(filter-out $(_nonexistent_modules),$(_allow_list)),\
      #  $(INTERNAL_PRODUCT) includes redundant allow list entries for non-existent PRODUCT_PACKAGES)
    endif

    # Check to ensure that all modules in PRODUCT_HOST_PACKAGES exist
    #
    # Many host modules are Linux-only, so skip this check on Mac. If we ever have Mac-only modules,
    # maybe it would make sense to have PRODUCT_HOST_PACKAGES_LINUX/_DARWIN?
    ifneq ($(HOST_OS),darwin)
      _modules := $(PRODUCT_HOST_PACKAGES)
      # Strip :32 and :64 suffixes
      _modules := $(patsubst %:32,%,$(_modules))
      _modules := $(patsubst %:64,%,$(_modules))
      _nonexistent_modules := $(foreach m,$(_modules),\
        $(if $(ALL_MODULES.$(m).REQUIRED_FROM_HOST)$(filter $(HOST_OUT_ROOT)/%,$(ALL_MODULES.$(m).INSTALLED)),,$(m)))
      $(call maybe-print-list-and-error,$(_nonexistent_modules),\
        $(INTERNAL_PRODUCT) includes non-existent modules in PRODUCT_HOST_PACKAGES)
    endif
  endif

  # Modules may produce only host installed files in unbundled builds.
  ifeq (,$(TARGET_BUILD_UNBUNDLED))
    _modules := $(call resolve-bitness-for-modules,TARGET, \
      $(PRODUCT_PACKAGES) \
      $(PRODUCT_PACKAGES_DEBUG) \
      $(PRODUCT_PACKAGES_DEBUG_ASAN) \
      $(PRODUCT_PACKAGES_ENG) \
      $(PRODUCT_PACKAGES_TESTS))
    _host_modules := $(foreach m,$(_modules), \
                  $(if $(ALL_MODULES.$(m).INSTALLED),\
                    $(if $(filter-out $(HOST_OUT_ROOT)/%,$(ALL_MODULES.$(m).INSTALLED)),,\
                      $(m))))
    ifeq ($(TARGET_ARCH),riscv64)
      # HACK: riscv64 can't build the device version of bcc and ld.mc due to a
      # dependency on an old version of LLVM, but they are listed in
      # base_system.mk which can't add them conditionally based on the target
      # architecture.
      _host_modules := $(filter-out bcc ld.mc,$(_host_modules))
    endif
    $(call maybe-print-list-and-error,$(sort $(_host_modules)),\
      Host modules should be in PRODUCT_HOST_PACKAGES$(comma) not PRODUCT_PACKAGES)
  endif

  product_host_FILES := $(call host-installed-files,$(INTERNAL_PRODUCT))
  product_target_FILES := $(call product-installed-files, $(INTERNAL_PRODUCT))
  # WARNING: The product_MODULES variable is depended on by external files.
  # It contains the list of register names that will be installed on the device
  product_MODULES := $(_pif_modules)

  # Verify the artifact path requirements made by included products.
  is_asan := $(if $(filter address,$(SANITIZE_TARGET)),true)
  ifeq (,$(or $(is_asan),$(DISABLE_ARTIFACT_PATH_REQUIREMENTS)))
    include $(BUILD_SYSTEM)/artifact_path_requirements.mk
  endif
else
  # We're not doing a full build, and are probably only including
  # a subset of the module makefiles.  Don't try to build any modules
  # requested by the product, because we probably won't have rules
  # to build them.
  product_target_FILES :=
  product_host_FILES :=
endif

# TODO: Remove the 3 places in the tree that use ALL_DEFAULT_INSTALLED_MODULES
# and get rid of it from this list.
modules_to_install := $(sort \
    $(ALL_DEFAULT_INSTALLED_MODULES) \
    $(product_target_FILES) \
    $(product_host_FILES) \
    $(CUSTOM_MODULES) \
  )

# Deduplicate compatibility suite dist files across modules and packages before
# copying them to their requested locations. Assign the eval result to an unused
# var to prevent Make from trying to make a sense of it.
_unused := $(call copy-many-files, $(sort $(ALL_COMPATIBILITY_DIST_FILES)))

ifdef is_sdk_build
  # Ensure every module listed in PRODUCT_PACKAGES* gets something installed
  # TODO: Should we do this for all builds and not just the sdk?
  dangling_modules :=
  $(foreach m, $(PRODUCT_PACKAGES), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED) $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).INSTALLED)),,\
      $(eval dangling_modules += $(m))))
  ifneq ($(dangling_modules),)
    $(warning: Modules '$(dangling_modules)' in PRODUCT_PACKAGES have nothing to install!)
  endif
  $(foreach m, $(PRODUCT_PACKAGES_DEBUG), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED)),,\
      $(warning $(ALL_MODULES.$(m).MAKEFILE): Module '$(m)' in PRODUCT_PACKAGES_DEBUG has nothing to install!)))
  $(foreach m, $(PRODUCT_PACKAGES_ENG), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED)),,\
      $(warning $(ALL_MODULES.$(m).MAKEFILE): Module '$(m)' in PRODUCT_PACKAGES_ENG has nothing to install!)))
  $(foreach m, $(PRODUCT_PACKAGES_TESTS), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED)),,\
      $(warning $(ALL_MODULES.$(m).MAKEFILE): Module '$(m)' in PRODUCT_PACKAGES_TESTS has nothing to install!)))
endif

ifneq ($(TARGET_BUILD_APPS),)
  # If this build is just for apps, only build apps and not the full system by default.
  ifneq ($(filter all,$(TARGET_BUILD_APPS)),)
    # If they used the magic goal "all" then build all apps in the source tree.
    unbundled_build_modules := $(foreach m,$(sort $(ALL_MODULES)),$(if $(filter APPS,$(ALL_MODULES.$(m).CLASS)),$(m)))
  else
    unbundled_build_modules := $(sort $(TARGET_BUILD_APPS))
  endif
endif

# build/make/core/Makefile contains extra stuff that we don't want to pollute this
# top-level makefile with.  It expects that ALL_DEFAULT_INSTALLED_MODULES
# contains everything that's built during the current make, but it also further
# extends ALL_DEFAULT_INSTALLED_MODULES.
ALL_DEFAULT_INSTALLED_MODULES := $(modules_to_install)
ifeq ($(HOST_OS),linux)
  include $(BUILD_SYSTEM)/Makefile
endif
modules_to_install := $(sort $(ALL_DEFAULT_INSTALLED_MODULES))
ALL_DEFAULT_INSTALLED_MODULES :=

ifdef FULL_BUILD
#
# Used by the cleanup logic in soong_ui to remove files that should no longer
# be installed.
#

# Include all tests, so that we remove them from the test suites / testcase
# folders when they are removed.
test_files := $(foreach ts,$(ALL_COMPATIBILITY_SUITES),$(COMPATIBILITY.$(ts).FILES))

$(shell mkdir -p $(PRODUCT_OUT) $(HOST_OUT))

$(file >$(PRODUCT_OUT)/.installable_files$(if $(filter address,$(SANITIZE_TARGET)),_asan), \
  $(sort $(patsubst $(PRODUCT_OUT)/%,%,$(filter $(PRODUCT_OUT)/%, \
    $(modules_to_install) $(test_files)))))

$(file >$(HOST_OUT)/.installable_test_files,$(sort \
  $(patsubst $(HOST_OUT)/%,%,$(filter $(HOST_OUT)/%, \
    $(test_files)))))

test_files :=
endif

# Some notice deps refer to module names without prefix or arch suffix where
# only the variants with them get built.
# fix-notice-deps replaces those unadorned module names with every built variant.
$(call fix-notice-deps)

# These are additional goals that we build, in order to make sure that there
# is as little code as possible in the tree that doesn't build.
modules_to_check := $(foreach m,$(ALL_MODULES),$(ALL_MODULES.$(m).CHECKED))

# If you would like to build all goals, and not skip any intermediate
# steps, you can pass the "all" modifier goal on the commandline.
ifneq ($(filter all,$(MAKECMDGOALS)),)
modules_to_check += $(foreach m,$(ALL_MODULES),$(ALL_MODULES.$(m).BUILT))
endif

# Build docs as part of checkbuild to catch more breakages.
modules_to_check += $(ALL_DOCS)

# for easier debugging
modules_to_check := $(sort $(modules_to_check))
#$(error modules_to_check $(modules_to_check))

# -------------------------------------------------------------------
# This is used to to get the ordering right, you can also use these,
# but they're considered undocumented, so don't complain if their
# behavior changes.
# An internal target that depends on all copied headers
# (see copy_headers.make).  Other targets that need the
# headers to be copied first can depend on this target.
.PHONY: all_copied_headers
all_copied_headers: ;

$(ALL_C_CPP_ETC_OBJECTS): | all_copied_headers

# All the droid stuff, in directories
.PHONY: files
files: $(modules_to_install) \
       $(INSTALLED_ANDROID_INFO_TXT_TARGET)

# -------------------------------------------------------------------

.PHONY: checkbuild
checkbuild: $(modules_to_check) droid_targets check-elf-files

ifeq (true,$(ANDROID_BUILD_EVERYTHING_BY_DEFAULT))
droid: checkbuild
endif

.PHONY: ramdisk
ramdisk: $(INSTALLED_RAMDISK_TARGET)

.PHONY: ramdisk_debug
ramdisk_debug: $(INSTALLED_DEBUG_RAMDISK_TARGET)

.PHONY: ramdisk_test_harness
ramdisk_test_harness: $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET)

.PHONY: userdataimage
userdataimage: $(INSTALLED_USERDATAIMAGE_TARGET)

ifneq (,$(filter userdataimage, $(MAKECMDGOALS)))
$(call dist-for-goals, userdataimage, $(BUILT_USERDATAIMAGE_TARGET))
endif

.PHONY: cacheimage
cacheimage: $(INSTALLED_CACHEIMAGE_TARGET)

.PHONY: bptimage
bptimage: $(INSTALLED_BPTIMAGE_TARGET)

.PHONY: vendorimage
vendorimage: $(INSTALLED_VENDORIMAGE_TARGET)

.PHONY: vendorbootimage
vendorbootimage: $(INSTALLED_VENDOR_BOOTIMAGE_TARGET)

.PHONY: vendorkernelbootimage
vendorkernelbootimage: $(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET)

.PHONY: vendorbootimage_debug
vendorbootimage_debug: $(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET)

.PHONY: vendorbootimage_test_harness
vendorbootimage_test_harness: $(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET)

.PHONY: vendorramdisk
vendorramdisk: $(INSTALLED_VENDOR_RAMDISK_TARGET)

.PHONY: vendorkernelramdisk
vendorkernelramdisk: $(INSTALLED_VENDOR_KERNEL_RAMDISK_TARGET)

.PHONY: vendorramdisk_debug
vendorramdisk_debug: $(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET)

.PHONY: vendorramdisk_test_harness
vendorramdisk_test_harness: $(INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET)

.PHONY: productimage
productimage: $(INSTALLED_PRODUCTIMAGE_TARGET)

.PHONY: systemextimage
systemextimage: $(INSTALLED_SYSTEM_EXTIMAGE_TARGET)

.PHONY: odmimage
odmimage: $(INSTALLED_ODMIMAGE_TARGET)

.PHONY: vendor_dlkmimage
vendor_dlkmimage: $(INSTALLED_VENDOR_DLKMIMAGE_TARGET)

.PHONY: odm_dlkmimage
odm_dlkmimage: $(INSTALLED_ODM_DLKMIMAGE_TARGET)

.PHONY: system_dlkmimage
system_dlkmimage: $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET)

.PHONY: systemotherimage
systemotherimage: $(INSTALLED_SYSTEMOTHERIMAGE_TARGET)

.PHONY: superimage_empty
superimage_empty: $(INSTALLED_SUPERIMAGE_EMPTY_TARGET)

.PHONY: bootimage
bootimage: $(INSTALLED_BOOTIMAGE_TARGET)

.PHONY: initbootimage
initbootimage: $(INSTALLED_INIT_BOOT_IMAGE_TARGET)

ifeq (true,$(PRODUCT_EXPORT_BOOT_IMAGE_TO_DIST))
$(call dist-for-goals, bootimage, $(INSTALLED_BOOTIMAGE_TARGET))
endif

.PHONY: bootimage_debug
bootimage_debug: $(INSTALLED_DEBUG_BOOTIMAGE_TARGET)

.PHONY: bootimage_test_harness
bootimage_test_harness: $(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET)

.PHONY: vbmetaimage
vbmetaimage: $(INSTALLED_VBMETAIMAGE_TARGET)

.PHONY: vbmetasystemimage
vbmetasystemimage: $(INSTALLED_VBMETA_SYSTEMIMAGE_TARGET)

.PHONY: vbmetavendorimage
vbmetavendorimage: $(INSTALLED_VBMETA_VENDORIMAGE_TARGET)

.PHONY: vbmetacustomimages
vbmetacustomimages: $(foreach partition,$(call to-upper,$(BOARD_AVB_VBMETA_CUSTOM_PARTITIONS)),$(INSTALLED_VBMETA_$(partition)IMAGE_TARGET))

# The droidcore-unbundled target depends on the subset of targets necessary to
# perform a full system build (either unbundled or not).
.PHONY: droidcore-unbundled
droidcore-unbundled: $(filter $(HOST_OUT_ROOT)/%,$(modules_to_install)) \
    $(INSTALLED_FILES_OUTSIDE_IMAGES) \
    $(INSTALLED_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_RAMDISK_TARGET) \
    $(INSTALLED_BOOTIMAGE_TARGET) \
    $(INSTALLED_INIT_BOOT_IMAGE_TARGET) \
    $(INSTALLED_RADIOIMAGE_TARGET) \
    $(INSTALLED_DEBUG_RAMDISK_TARGET) \
    $(INSTALLED_DEBUG_BOOTIMAGE_TARGET) \
    $(INSTALLED_RECOVERYIMAGE_TARGET) \
    $(INSTALLED_VBMETAIMAGE_TARGET) \
    $(INSTALLED_VBMETA_SYSTEMIMAGE_TARGET) \
    $(INSTALLED_VBMETA_VENDORIMAGE_TARGET) \
    $(INSTALLED_USERDATAIMAGE_TARGET) \
    $(INSTALLED_CACHEIMAGE_TARGET) \
    $(INSTALLED_BPTIMAGE_TARGET) \
    $(INSTALLED_VENDORIMAGE_TARGET) \
    $(INSTALLED_VENDOR_BOOTIMAGE_TARGET) \
    $(INSTALLED_VENDOR_KERNEL_BOOTIMAGE_TARGET) \
    $(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET) \
    $(INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET) \
    $(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET) \
    $(INSTALLED_VENDOR_RAMDISK_TARGET) \
    $(INSTALLED_VENDOR_KERNEL_RAMDISK_TARGET) \
    $(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET) \
    $(INSTALLED_ODMIMAGE_TARGET) \
    $(INSTALLED_VENDOR_DLKMIMAGE_TARGET) \
    $(INSTALLED_ODM_DLKMIMAGE_TARGET) \
    $(INSTALLED_SYSTEM_DLKMIMAGE_TARGET) \
    $(INSTALLED_SUPERIMAGE_EMPTY_TARGET) \
    $(INSTALLED_PRODUCTIMAGE_TARGET) \
    $(INSTALLED_SYSTEMOTHERIMAGE_TARGET) \
    $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET) \
    $(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET) \
    $(INSTALLED_FILES_FILE) \
    $(INSTALLED_FILES_JSON) \
    $(INSTALLED_FILES_FILE_VENDOR) \
    $(INSTALLED_FILES_JSON_VENDOR) \
    $(INSTALLED_FILES_FILE_ODM) \
    $(INSTALLED_FILES_JSON_ODM) \
    $(INSTALLED_FILES_FILE_VENDOR_DLKM) \
    $(INSTALLED_FILES_JSON_VENDOR_DLKM) \
    $(INSTALLED_FILES_FILE_ODM_DLKM) \
    $(INSTALLED_FILES_JSON_ODM_DLKM) \
    $(INSTALLED_FILES_FILE_SYSTEM_DLKM) \
    $(INSTALLED_FILES_JSON_SYSTEM_DLKM) \
    $(INSTALLED_FILES_FILE_PRODUCT) \
    $(INSTALLED_FILES_JSON_PRODUCT) \
    $(INSTALLED_FILES_FILE_SYSTEM_EXT) \
    $(INSTALLED_FILES_JSON_SYSTEM_EXT) \
    $(INSTALLED_FILES_FILE_SYSTEMOTHER) \
    $(INSTALLED_FILES_JSON_SYSTEMOTHER) \
    $(INSTALLED_FILES_FILE_RAMDISK) \
    $(INSTALLED_FILES_JSON_RAMDISK) \
    $(INSTALLED_FILES_FILE_DEBUG_RAMDISK) \
    $(INSTALLED_FILES_JSON_DEBUG_RAMDISK) \
    $(INSTALLED_FILES_FILE_VENDOR_RAMDISK) \
    $(INSTALLED_FILES_JSON_VENDOR_RAMDISK) \
    $(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK) \
    $(INSTALLED_FILES_JSON_VENDOR_DEBUG_RAMDISK) \
    $(INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK) \
    $(INSTALLED_FILES_JSON_VENDOR_KERNEL_RAMDISK) \
    $(INSTALLED_FILES_FILE_ROOT) \
    $(INSTALLED_FILES_JSON_ROOT) \
    $(INSTALLED_FILES_FILE_RECOVERY) \
    $(INSTALLED_FILES_JSON_RECOVERY) \
    $(INSTALLED_ANDROID_INFO_TXT_TARGET)

# The droidcore target depends on the droidcore-unbundled subset and any other
# targets for a non-unbundled (full source) full system build.
.PHONY: droidcore
droidcore: droidcore-unbundled

# dist_files only for putting your library into the dist directory with a full build.
.PHONY: dist_files

ifeq ($(SOONG_COLLECT_JAVA_DEPS), true)
  $(call dist-for-goals, dist_files, $(SOONG_OUT_DIR)/module_bp_java_deps.json)
  $(call dist-for-goals, dist_files, $(PRODUCT_OUT)/module-info.json)
endif

.PHONY: apps_only
ifeq ($(HOST_OS),darwin)
  # Mac only supports building host modules
  droid_targets: $(filter $(HOST_OUT_ROOT)/%,$(modules_to_install)) dist_files

else ifneq ($(TARGET_BUILD_APPS),)
  # If this build is just for apps, only build apps and not the full system by default.

  # Dist the installed files if they exist, except the installed symlinks. dist-for-goals emits
  # `cp src dest` commands, which will fail to copy dangling symlinks.
  apps_only_installed_files := $(foreach m,$(unbundled_build_modules),\
    $(filter-out $(ALL_MODULES.$(m).INSTALLED_SYMLINKS),$(ALL_MODULES.$(m).INSTALLED)))
  $(call dist-for-goals,apps_only, $(apps_only_installed_files))

  # Dist the bundle files if they exist.
  apps_only_bundle_files := $(foreach m,$(unbundled_build_modules),\
    $(if $(ALL_MODULES.$(m).BUNDLE),$(ALL_MODULES.$(m).BUNDLE):$(m)-base.zip))
  $(call dist-for-goals,apps_only, $(apps_only_bundle_files))

  # Dist the lint reports if they exist.
  apps_only_lint_report_files := $(foreach m,$(unbundled_build_modules),\
    $(foreach report,$(ALL_MODULES.$(m).LINT_REPORTS),\
      $(report):$(m)-$(notdir $(report))))
  .PHONY: lint-check
  lint-check: $(foreach f, $(apps_only_lint_report_files), $(call word-colon,1,$(f)))
  $(call dist-for-goals,lint-check, $(apps_only_lint_report_files))

  # For uninstallable modules such as static Java library, we have to dist the built file,
  # as <module_name>.<suffix>
  apps_only_dist_built_files := $(foreach m,$(unbundled_build_modules),$(if $(ALL_MODULES.$(m).INSTALLED),,\
      $(if $(ALL_MODULES.$(m).BUILT),$(ALL_MODULES.$(m).BUILT):$(m)$(suffix $(ALL_MODULES.$(m).BUILT)))\
      $(if $(ALL_MODULES.$(m).AAR),$(ALL_MODULES.$(m).AAR):$(m).aar)\
      ))
  $(call dist-for-goals,apps_only, $(apps_only_dist_built_files))

  ifeq ($(EMMA_INSTRUMENT),true)
    $(JACOCO_REPORT_CLASSES_ALL) : $(apps_only_installed_files)
    $(call dist-for-goals,apps_only, $(JACOCO_REPORT_CLASSES_ALL))
  endif

  $(PROGUARD_DICT_ZIP) : $(apps_only_installed_files)
  $(call dist-for-goals-with-filenametag,apps_only, $(PROGUARD_DICT_ZIP) $(PROGUARD_DICT_ZIP) $(PROGUARD_DICT_MAPPING))
  $(call declare-container-license-deps,$(PROGUARD_DICT_ZIP),$(apps_only_installed_files),$(PRODUCT_OUT)/:/)

  $(PROGUARD_USAGE_ZIP) : $(apps_only_installed_files)
  $(call dist-for-goals-with-filenametag,apps_only, $(PROGUARD_USAGE_ZIP))
  $(call declare-container-license-deps,$(PROGUARD_USAGE_ZIP),$(apps_only_installed_files),$(PRODUCT_OUT)/:/)

  $(SYMBOLS_ZIP) : $(apps_only_installed_files)
  $(call dist-for-goals-with-filenametag,apps_only, $(SYMBOLS_ZIP) $(SYMBOLS_MAPPING))
  $(call declare-container-license-deps,$(SYMBOLS_ZIP),$(apps_only_installed_files),$(PRODUCT_OUT)/:/)

  $(COVERAGE_ZIP) : $(apps_only_installed_files)
  $(call dist-for-goals,apps_only, $(COVERAGE_ZIP))
  $(call declare-container-license-deps,$(COVERAGE_ZIP),$(apps_only_installed_files),$(PRODUCT_OUT)/:/)

apps_only: $(unbundled_build_modules)

droid_targets: apps_only

# NOTICE files for a apps_only build
$(eval $(call html-notice-rule,$(target_notice_file_html_or_xml),"Apps","Notices for files for apps:",$(unbundled_build_modules),$(PRODUCT_OUT)/ $(HOST_OUT)/))

$(eval $(call text-notice-rule,$(target_notice_file_txt),"Apps","Notices for files for apps:",$(unbundled_build_modules),$(PRODUCT_OUT)/ $(HOST_OUT)/))

$(call declare-0p-target,$(target_notice_file_txt))
$(call declare-0p-target,$(target_notice_html_or_xml))


else ifeq ($(TARGET_BUILD_UNBUNDLED),$(TARGET_BUILD_UNBUNDLED_IMAGE))

  # Truth table for entering this block of code:
  # TARGET_BUILD_UNBUNDLED | TARGET_BUILD_UNBUNDLED_IMAGE | Action
  # -----------------------|------------------------------|-------------------------
  # not set                | not set                      | droidcore path
  # not set                | true                         | invalid
  # true                   | not set                      | skip
  # true                   | true                         | droidcore-unbundled path

  # We dist the following targets only for droidcore full build. These items
  # can include java-related targets that would cause building framework java
  # sources in a droidcore full build.

  $(call dist-for-goals, droidcore, \
    $(BUILT_OTATOOLS_PACKAGE) \
    $(APPCOMPAT_ZIP) \
    $(DEXPREOPT_TOOLS_ZIP) \
  )

  # We dist the following targets for droidcore-unbundled (and droidcore since
  # droidcore depends on droidcore-unbundled). The droidcore-unbundled target
  # is a subset of droidcore. It can be used used for an unbundled build to
  # avoid disting targets that would cause building framework java sources,
  # which we want to avoid in an unbundled build.

  $(call dist-for-goals-with-filenametag, droidcore-unbundled, \
    $(INTERNAL_UPDATE_PACKAGE_TARGET) \
    $(INTERNAL_OTA_PACKAGE_TARGET) \
    $(INTERNAL_OTA_PARTIAL_PACKAGE_TARGET) \
    $(BUILT_RAMDISK_16K_TARGET) \
    $(BUILT_KERNEL_16K_TARGET) \
    $(INTERNAL_OTA_RETROFIT_DYNAMIC_PARTITIONS_PACKAGE_TARGET) \
    $(SYMBOLS_ZIP) \
    $(SYMBOLS_MAPPING) \
    $(PROGUARD_DICT_ZIP) \
    $(PROGUARD_DICT_MAPPING) \
    $(PROGUARD_USAGE_ZIP) \
    $(BUILT_TARGET_FILES_PACKAGE) \
  )

  $(call dist-for-goals, droidcore-unbundled, \
    $(INTERNAL_OTA_METADATA) \
    $(COVERAGE_ZIP) \
    $(INSTALLED_FILES_FILE) \
    $(INSTALLED_FILES_JSON) \
    $(INSTALLED_FILES_FILE_VENDOR) \
    $(INSTALLED_FILES_JSON_VENDOR) \
    $(INSTALLED_FILES_FILE_ODM) \
    $(INSTALLED_FILES_JSON_ODM) \
    $(INSTALLED_FILES_FILE_VENDOR_DLKM) \
    $(INSTALLED_FILES_JSON_VENDOR_DLKM) \
    $(INSTALLED_FILES_FILE_ODM_DLKM) \
    $(INSTALLED_FILES_JSON_ODM_DLKM) \
    $(INSTALLED_FILES_FILE_SYSTEM_DLKM) \
    $(INSTALLED_FILES_JSON_SYSTEM_DLKM) \
    $(INSTALLED_FILES_FILE_PRODUCT) \
    $(INSTALLED_FILES_JSON_PRODUCT) \
    $(INSTALLED_FILES_FILE_SYSTEM_EXT) \
    $(INSTALLED_FILES_JSON_SYSTEM_EXT) \
    $(INSTALLED_FILES_FILE_SYSTEMOTHER) \
    $(INSTALLED_FILES_JSON_SYSTEMOTHER) \
    $(INSTALLED_FILES_FILE_RECOVERY) \
    $(INSTALLED_FILES_JSON_RECOVERY) \
    $(INSTALLED_BUILD_PROP_TARGET):build.prop \
    $(INSTALLED_VENDOR_BUILD_PROP_TARGET):build.prop-vendor \
    $(INSTALLED_PRODUCT_BUILD_PROP_TARGET):build.prop-product \
    $(INSTALLED_ODM_BUILD_PROP_TARGET):build.prop-odm \
    $(INSTALLED_SYSTEM_EXT_BUILD_PROP_TARGET):build.prop-system_ext \
    $(INSTALLED_RAMDISK_BUILD_PROP_TARGET):build.prop-ramdisk \
    $(INSTALLED_ANDROID_INFO_TXT_TARGET) \
    $(INSTALLED_MISC_INFO_TARGET) \
    $(INSTALLED_RAMDISK_TARGET) \
    $(DEXPREOPT_CONFIG_ZIP) \
  )

  # Put a copy of the radio/bootloader files in the dist dir.
  $(foreach f,$(INSTALLED_RADIOIMAGE_TARGET), \
    $(call dist-for-goals, droidcore-unbundled, $(f)))

  ifneq ($(ANDROID_BUILD_EMBEDDED),true)
    $(call dist-for-goals-with-filenametag, droidcore, \
      $(APPS_ZIP) \
      $(INTERNAL_EMULATOR_PACKAGE_TARGET) \
    )
  endif

  $(call dist-for-goals, droidcore-unbundled, \
    $(INSTALLED_FILES_FILE_ROOT) \
    $(INSTALLED_FILES_JSON_ROOT) \
  )

  $(call dist-for-goals, droidcore-unbundled, \
    $(INSTALLED_FILES_FILE_RAMDISK) \
    $(INSTALLED_FILES_JSON_RAMDISK) \
    $(INSTALLED_FILES_FILE_DEBUG_RAMDISK) \
    $(INSTALLED_FILES_JSON_DEBUG_RAMDISK) \
    $(INSTALLED_FILES_FILE_VENDOR_RAMDISK) \
    $(INSTALLED_FILES_JSON_VENDOR_RAMDISK) \
    $(INSTALLED_FILES_FILE_VENDOR_KERNEL_RAMDISK) \
    $(INSTALLED_FILES_JSON_VENDOR_KERNEL_RAMDISK) \
    $(INSTALLED_FILES_FILE_VENDOR_DEBUG_RAMDISK) \
    $(INSTALLED_FILES_JSON_VENDOR_DEBUG_RAMDISK) \
    $(INSTALLED_DEBUG_RAMDISK_TARGET) \
    $(INSTALLED_DEBUG_BOOTIMAGE_TARGET) \
    $(INSTALLED_TEST_HARNESS_RAMDISK_TARGET) \
    $(INSTALLED_TEST_HARNESS_BOOTIMAGE_TARGET) \
    $(INSTALLED_VENDOR_DEBUG_BOOTIMAGE_TARGET) \
    $(INSTALLED_VENDOR_TEST_HARNESS_RAMDISK_TARGET) \
    $(INSTALLED_VENDOR_TEST_HARNESS_BOOTIMAGE_TARGET) \
    $(INSTALLED_VENDOR_RAMDISK_TARGET) \
    $(INSTALLED_VENDOR_DEBUG_RAMDISK_TARGET) \
    $(INSTALLED_VENDOR_KERNEL_RAMDISK_TARGET) \
  )

  ifeq ($(PRODUCT_EXPORT_BOOT_IMAGE_TO_DIST),true)
    $(call dist-for-goals, droidcore-unbundled, $(INSTALLED_BOOTIMAGE_TARGET))
  endif

  ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
    $(call dist-for-goals, droidcore-unbundled, \
      $(recovery_ramdisk) \
    )
  endif

  ifeq ($(EMMA_INSTRUMENT),true)
    $(call dist-for-goals, dist_files, $(JACOCO_REPORT_CLASSES_ALL))
  endif

  # Put XML formatted API files in the dist dir.
  $(TARGET_OUT_COMMON_INTERMEDIATES)/api.xml: $(call java-lib-files,$(ANDROID_PUBLIC_STUBS)) $(APICHECK)
  $(TARGET_OUT_COMMON_INTERMEDIATES)/system-api.xml: $(call java-lib-files,$(ANDROID_SYSTEM_STUBS)) $(APICHECK)
  $(TARGET_OUT_COMMON_INTERMEDIATES)/module-lib-api.xml: $(call java-lib-files,$(ANDROID_MODULE_LIB_STUBS)) $(APICHECK)
  $(TARGET_OUT_COMMON_INTERMEDIATES)/system-server-api.xml: $(call java-lib-files,$(ANDROID_SYSTEM_SERVER_STUBS)) $(APICHECK)
  $(TARGET_OUT_COMMON_INTERMEDIATES)/test-api.xml: $(call java-lib-files,$(ANDROID_TEST_STUBS)) $(APICHECK)

  api_xmls := $(addprefix $(TARGET_OUT_COMMON_INTERMEDIATES)/,api.xml system-api.xml module-lib-api.xml system-server-api.xml test-api.xml)
  $(api_xmls):
	$(hide) echo "Converting API file to XML: $@"
	$(hide) mkdir -p $(dir $@)
	$(hide) $(APICHECK_COMMAND) --input-api-jar $< --api-xml $@

  $(foreach xml,$(sort $(api_xmls)),$(call declare-1p-target,$(xml),))

  $(call dist-for-goals, dist_files, $(api_xmls))
  api_xmls :=

  ifdef CLANG_COVERAGE
    $(foreach f,$(SOONG_NDK_API_XML), \
        $(call dist-for-goals,droidcore,$(f):ndk_apis/$(notdir $(f))))
    $(foreach f,$(SOONG_CC_API_XML), \
        $(call dist-for-goals,droidcore,$(f):cc_apis/$(notdir $(f))))
  endif

  # For full system build (whether unbundled or not), we configure
  # droid_targets to depend on droidcore-unbundled, which will set up the full
  # system dependencies and also dist the subset of targets that correspond to
  # an unbundled build (exclude building some framework sources).

  droid_targets: droidcore-unbundled

  ifeq (,$(TARGET_BUILD_UNBUNDLED_IMAGE))

    # If we're building a full system (including the framework sources excluded
    # by droidcore-unbundled), we configure droid_targets also to depend on
    # droidcore, which includes all dist for droidcore, and will build the
    # necessary framework sources.

    droid_targets: droidcore dist_files

  endif

endif # TARGET_BUILD_UNBUNDLED == TARGET_BUILD_UNBUNDLED_IMAGE

.PHONY: docs
docs: $(ALL_DOCS)

.PHONY: sdk sdk_addon
ifeq ($(HOST_OS),linux)
ALL_SDK_TARGETS := $(INTERNAL_SDK_TARGET)
sdk: $(ALL_SDK_TARGETS)
$(call dist-for-goals-with-filenametag,sdk,$(ALL_SDK_TARGETS))
$(call dist-for-goals,sdk,$(INSTALLED_BUILD_PROP_TARGET))
endif

# umbrella targets to assit engineers in verifying builds
.PHONY: java native target host java-host java-target native-host native-target \
        java-host-tests java-target-tests native-host-tests native-target-tests \
        java-tests native-tests host-tests target-tests tests java-dex \
        native-host-cross
# some synonyms
.PHONY: host-java target-java host-native target-native \
        target-java-tests target-native-tests
host-java : java-host
target-java : java-target
host-native : native-host
target-native : native-target
target-java-tests : java-target-tests
target-native-tests : native-target-tests
tests : host-tests target-tests

# Phony target to run all java compilations that use javac
.PHONY: javac-check

.PHONY: findbugs
findbugs: $(INTERNAL_FINDBUGS_HTML_TARGET) $(INTERNAL_FINDBUGS_XML_TARGET)

LSDUMP_PATHS_FILE := $(PRODUCT_OUT)/lsdump_paths.txt

.PHONY: findlsdumps
# LSDUMP_PATHS is a list of tag:path.
findlsdumps: $(LSDUMP_PATHS_FILE) $(foreach p,$(LSDUMP_PATHS),$(call word-colon,2,$(p)))

$(LSDUMP_PATHS_FILE): PRIVATE_LSDUMP_PATHS := $(LSDUMP_PATHS)
$(LSDUMP_PATHS_FILE):
	@echo "Generate $@"
	@rm -rf $@ && echo -e "$(subst :,:$(space),$(subst $(space),\n,$(PRIVATE_LSDUMP_PATHS)))" > $@

.PHONY: check-elf-files
check-elf-files:

.PHONY: dump-files
dump-files:
	@echo "Target files for $(TARGET_PRODUCT)-$(TARGET_BUILD_VARIANT) ($(INTERNAL_PRODUCT)):"
	@echo $(sort $(patsubst $(PRODUCT_OUT)/%,%,$(filter $(PRODUCT_OUT)/%,$(modules_to_install)))) | tr -s ' ' '\n'
	@echo Successfully dumped product target file list.

.PHONY: nothing
nothing:
	@echo Successfully read the makefiles.

.PHONY: tidy_only
tidy_only:
	@echo Successfully make tidy_only.

ndk: $(SOONG_OUT_DIR)/ndk.timestamp
.PHONY: ndk

# Checks that allowed_deps.txt remains up to date
ifneq ($(UNSAFE_DISABLE_APEX_ALLOWED_DEPS_CHECK),true)
  droidcore: ${APEX_ALLOWED_DEPS_CHECK}
endif

# Create a license metadata rule per module. Could happen in base_rules.mk or
# notice_files.mk; except, it has to happen after fix-notice-deps to avoid
# missing dependency errors.
$(call build-license-metadata)

# Generate SBOM in SPDX format
product_copy_files_without_owner := $(foreach pcf,$(PRODUCT_COPY_FILES),$(call word-colon,1,$(pcf)):$(call word-colon,2,$(pcf)))
ifeq ($(TARGET_BUILD_APPS),)
dest_files_without_source := $(sort $(foreach pcf,$(product_copy_files_without_owner),$(if $(wildcard $(call word-colon,1,$(pcf))),,$(call word-colon,2,$(pcf)))))
dest_files_without_source := $(addprefix $(PRODUCT_OUT)/,$(dest_files_without_source))
filter_out_files := \
  $(PRODUCT_OUT)/apex/% \
  $(PRODUCT_OUT)/fake_packages/% \
  $(PRODUCT_OUT)/testcases/% \
  $(dest_files_without_source)
# Check if each partition image is built, if not filter out all its installed files
# Also check if a partition uses prebuilt image file, save the info if prebuilt image is used.
PREBUILT_PARTITION_COPY_FILES :=
# product.img
ifndef BUILDING_PRODUCT_IMAGE
filter_out_files += $(PRODUCT_OUT)/product/%
ifdef BOARD_PREBUILT_PRODUCTIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_PRODUCTIMAGE):$(INSTALLED_PRODUCTIMAGE_TARGET)
endif
endif

# system.img
ifndef BUILDING_SYSTEM_IMAGE
filter_out_files += $(PRODUCT_OUT)/system/%
endif
# system_dlkm.img
ifndef BUILDING_SYSTEM_DLKM_IMAGE
filter_out_files += $(PRODUCT_OUT)/system_dlkm/%
ifdef BOARD_PREBUILT_SYSTEM_DLKMIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_SYSTEM_DLKMIMAGE):$(INSTALLED_SYSTEM_DLKMIMAGE_TARGET)
endif
endif
# system_ext.img
ifndef BUILDING_SYSTEM_EXT_IMAGE
filter_out_files += $(PRODUCT_OUT)/system_ext/%
ifdef BOARD_PREBUILT_SYSTEM_EXTIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_SYSTEM_EXTIMAGE):$(INSTALLED_SYSTEM_EXTIMAGE_TARGET)
endif
endif
# system_other.img
ifndef BUILDING_SYSTEM_OTHER_IMAGE
filter_out_files += $(PRODUCT_OUT)/system_other/%
endif

# odm.img
ifndef BUILDING_ODM_IMAGE
filter_out_files += $(PRODUCT_OUT)/odm/%
ifdef BOARD_PREBUILT_ODMIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_ODMIMAGE):$(INSTALLED_ODMIMAGE_TARGET)
endif
endif
# odm_dlkm.img
ifndef BUILDING_ODM_DLKM_IMAGE
filter_out_files += $(PRODUCT_OUT)/odm_dlkm/%
ifdef BOARD_PREBUILT_ODM_DLKMIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_ODM_DLKMIMAGE):$(INSTALLED_ODM_DLKMIMAGE_TARGET)
endif
endif

# vendor.img
ifndef BUILDING_VENDOR_IMAGE
filter_out_files += $(PRODUCT_OUT)/vendor/%
ifdef BOARD_PREBUILT_VENDORIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_VENDORIMAGE):$(INSTALLED_VENDORIMAGE_TARGET)
endif
endif
# vendor_dlkm.img
ifndef BUILDING_VENDOR_DLKM_IMAGE
filter_out_files += $(PRODUCT_OUT)/vendor_dlkm/%
ifdef BOARD_PREBUILT_VENDOR_DLKMIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_VENDOR_DLKMIMAGE):$(INSTALLED_VENDOR_DLKMIMAGE_TARGET)
endif
endif

# cache.img
ifndef BUILDING_CACHE_IMAGE
filter_out_files += $(PRODUCT_OUT)/cache/%
endif

# boot.img
ifndef BUILDING_BOOT_IMAGE
ifdef BOARD_PREBUILT_BOOTIMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_BOOTIMAGE):$(INSTALLED_BOOTIMAGE_TARGET)
endif
endif
# init_boot.img
ifndef BUILDING_INIT_BOOT_IMAGE
ifdef BOARD_PREBUILT_INIT_BOOT_IMAGE
PREBUILT_PARTITION_COPY_FILES += $(BOARD_PREBUILT_INIT_BOOT_IMAGE):$(INSTALLED_INIT_BOOT_IMAGE_TARGET)
endif
endif

# ramdisk.img
ifndef BUILDING_RAMDISK_IMAGE
filter_out_files += $(PRODUCT_OUT)/ramdisk/%
endif

# recovery.img
ifndef INSTALLED_RECOVERYIMAGE_TARGET
filter_out_files += $(PRODUCT_OUT)/recovery/%
endif

installed_files := $(sort $(filter-out $(filter_out_files),$(filter $(PRODUCT_OUT)/%,$(modules_to_install))))
else
installed_files := $(apps_only_installed_files)
endif  # TARGET_BUILD_APPS

# sbom-metadata.csv contains all raw data collected in Make for generating SBOM in generate-sbom.py.
# There are multiple columns and each identifies the source of an installed file for a specific case.
# The columns and their uses are described as below:
#   installed_file: the file path on device, e.g. /product/app/Browser2/Browser2.apk
#   module_path: the path of the module that generates the installed file, e.g. packages/apps/Browser2
#   soong_module_type: Soong module type, e.g. android_app, cc_binary
#   is_prebuilt_make_module: Y, if the installed file is from a prebuilt Make module, see prebuilt_internal.mk
#   product_copy_files: the installed file is from variable PRODUCT_COPY_FILES, e.g. device/google/cuttlefish/shared/config/init.product.rc:product/etc/init/init.rc
#   kernel_module_copy_files: the installed file is from variable KERNEL_MODULE_COPY_FILES, similar to product_copy_files
#   is_platform_generated: this is an aggregated value including some small cases instead of adding more columns. It is set to Y if any case is Y
#       is_build_prop: build.prop in each partition, see sysprop.mk.
#       is_notice_file: NOTICE.xml.gz in each partition, see Makefile.
#       is_dexpreopt_image_profile: see the usage of DEXPREOPT_IMAGE_PROFILE_BUILT_INSTALLED in Soong and Make
#       is_product_system_other_avbkey: see INSTALLED_PRODUCT_SYSTEM_OTHER_AVBKEY_TARGET
#       is_system_other_odex_marker: see INSTALLED_SYSTEM_OTHER_ODEX_MARKER
#       is_event_log_tags_file: see variable event_log_tags_file in Makefile
#       is_kernel_modules_blocklist: modules.blocklist created for _dlkm partitions, see macro build-image-kernel-modules-dir in Makefile.
#       is_fsverity_build_manifest_apk: BuildManifest<part>.apk files for system and system_ext partition, see ALL_FSVERITY_BUILD_MANIFEST_APK in Makefile.
#       is_linker_config: see SYSTEM_LINKER_CONFIG and vendor_linker_config_file in Makefile.
#   build_output_path: the path of the built file, used to calculate checksum
#   static_libraries/whole_static_libraries: list of module name of the static libraries the file links against, e.g. libclang_rt.builtins or libclang_rt.builtins_32
#       Info of all static libraries of all installed files are collected in variable _all_static_libs that is used to list all the static library files in sbom-metadata.csv.
#       See the second foreach loop in the rule of sbom-metadata.csv for the detailed info of static libraries collected in _all_static_libs.
#   is_static_lib: whether the file is a static library

metadata_list := $(OUT_DIR)/.module_paths/METADATA.list
metadata_files := $(subst $(newline),$(space),$(file <$(metadata_list)))
$(PRODUCT_OUT)/sbom-metadata.csv:
	rm -f $@
	echo 'installed_file,module_path,soong_module_type,is_prebuilt_make_module,product_copy_files,kernel_module_copy_files,is_platform_generated,build_output_path,static_libraries,whole_static_libraries,is_static_lib' >> $@
	$(eval _all_static_libs :=)
	$(foreach f,$(installed_files),\
	  $(eval _module_name := $(ALL_INSTALLED_FILES.$f)) \
	  $(eval _path_on_device := $(patsubst $(PRODUCT_OUT)/%,%,$f)) \
	  $(eval _build_output_path := $(PRODUCT_OUT)/$(_path_on_device)) \
	  $(eval _module_path := $(strip $(sort $(ALL_MODULES.$(_module_name).PATH)))) \
	  $(eval _soong_module_type := $(strip $(sort $(ALL_MODULES.$(_module_name).SOONG_MODULE_TYPE)))) \
	  $(eval _is_prebuilt_make_module := $(ALL_MODULES.$(_module_name).IS_PREBUILT_MAKE_MODULE)) \
	  $(eval _product_copy_files := $(sort $(filter %:$(_path_on_device),$(product_copy_files_without_owner)))) \
	  $(eval _kernel_module_copy_files := $(sort $(filter %$(_path_on_device),$(KERNEL_MODULE_COPY_FILES)))) \
	  $(eval _is_build_prop := $(call is-build-prop,$f)) \
	  $(eval _is_notice_file := $(call is-notice-file,$f)) \
	  $(eval _is_dexpreopt_image_profile := $(if $(filter %:/$(_path_on_device),$(DEXPREOPT_IMAGE_PROFILE_BUILT_INSTALLED)),Y)) \
	  $(eval _is_product_system_other_avbkey := $(if $(findstring $f,$(INSTALLED_PRODUCT_SYSTEM_OTHER_AVBKEY_TARGET)),Y)) \
	  $(eval _is_event_log_tags_file := $(if $(findstring $f,$(event_log_tags_file)),Y)) \
	  $(eval _is_system_other_odex_marker := $(if $(findstring $f,$(INSTALLED_SYSTEM_OTHER_ODEX_MARKER)),Y)) \
	  $(eval _is_kernel_modules_blocklist := $(if $(findstring $f,$(ALL_KERNEL_MODULES_BLOCKLIST)),Y)) \
	  $(eval _is_fsverity_build_manifest_apk := $(if $(findstring $f,$(ALL_FSVERITY_BUILD_MANIFEST_APK)),Y)) \
	  $(eval _is_linker_config := $(if $(findstring $f,$(SYSTEM_LINKER_CONFIG) $(vendor_linker_config_file)),Y)) \
	  $(eval _is_partition_compat_symlink := $(if $(findstring $f,$(PARTITION_COMPAT_SYMLINKS)),Y)) \
	  $(eval _is_flags_file := $(if $(findstring $f, $(ALL_FLAGS_FILES)),Y)) \
	  $(eval _is_rootdir_symlink := $(if $(findstring $f, $(ALL_ROOTDIR_SYMLINKS)),Y)) \
	  $(eval _is_platform_generated := $(_is_build_prop)$(_is_notice_file)$(_is_dexpreopt_image_profile)$(_is_product_system_other_avbkey)$(_is_event_log_tags_file)$(_is_system_other_odex_marker)$(_is_kernel_modules_blocklist)$(_is_fsverity_build_manifest_apk)$(_is_linker_config)$(_is_partition_compat_symlink)$(_is_flags_file)$(_is_rootdir_symlink)) \
	  $(eval _static_libs := $(ALL_INSTALLED_FILES.$f.STATIC_LIBRARIES)) \
	  $(eval _whole_static_libs := $(ALL_INSTALLED_FILES.$f.WHOLE_STATIC_LIBRARIES)) \
	  $(foreach l,$(_static_libs),$(eval _all_static_libs += $l:$(strip $(sort $(ALL_MODULES.$l.PATH))):$(strip $(sort $(ALL_MODULES.$l.SOONG_MODULE_TYPE))):$(ALL_STATIC_LIBRARIES.$l.BUILT_FILE))) \
	  $(foreach l,$(_whole_static_libs),$(eval _all_static_libs += $l:$(strip $(sort $(ALL_MODULES.$l.PATH))):$(strip $(sort $(ALL_MODULES.$l.SOONG_MODULE_TYPE))):$(ALL_STATIC_LIBRARIES.$l.BUILT_FILE))) \
	  echo '/$(_path_on_device),$(_module_path),$(_soong_module_type),$(_is_prebuilt_make_module),$(_product_copy_files),$(_kernel_module_copy_files),$(_is_platform_generated),$(_build_output_path),$(_static_libs),$(_whole_static_libs),' >> $@; \
	)
	$(foreach l,$(sort $(_all_static_libs)), \
	  $(eval _lib_stem := $(call word-colon,1,$l)) \
	  $(eval _module_path := $(call word-colon,2,$l)) \
	  $(eval _soong_module_type := $(call word-colon,3,$l)) \
	  $(eval _built_file := $(call word-colon,4,$l)) \
	  $(eval _static_libs := $(ALL_STATIC_LIBRARIES.$l.STATIC_LIBRARIES)) \
	  $(eval _whole_static_libs := $(ALL_STATIC_LIBRARIES.$l.WHOLE_STATIC_LIBRARIES)) \
	  $(eval _is_static_lib := Y) \
	  echo '$(_lib_stem).a,$(_module_path),$(_soong_module_type),,,,,$(_built_file),$(_static_libs),$(_whole_static_libs),$(_is_static_lib)' >> $@; \
	)

# (TODO: b/272358583 find another way of always rebuilding sbom.spdx)
# Remove the always_dirty_file.txt whenever the makefile is evaluated
$(shell rm -f $(PRODUCT_OUT)/always_dirty_file.txt)
$(PRODUCT_OUT)/always_dirty_file.txt:
	touch $@

.PHONY: sbom
ifeq ($(TARGET_BUILD_APPS),)
sbom: $(PRODUCT_OUT)/sbom.spdx.json
$(PRODUCT_OUT)/sbom.spdx.json: $(PRODUCT_OUT)/sbom.spdx
$(PRODUCT_OUT)/sbom.spdx: $(PRODUCT_OUT)/sbom-metadata.csv $(GEN_SBOM) $(installed_files) $(metadata_list) $(metadata_files) $(PRODUCT_OUT)/always_dirty_file.txt
	rm -rf $@
	$(GEN_SBOM) --output_file $@ --metadata $(PRODUCT_OUT)/sbom-metadata.csv --build_version $(BUILD_FINGERPRINT_FROM_FILE) --product_mfr "$(PRODUCT_MANUFACTURER)" --json

$(call dist-for-goals,droid,$(PRODUCT_OUT)/sbom.spdx.json:sbom/sbom.spdx.json)
else
# Create build rules for generating SBOMs of unbundled APKs and APEXs
# $1: sbom file
# $2: sbom fragment file
# $3: installed file
# $4: sbom-metadata.csv file
define generate-app-sbom
$(eval _path_on_device := $(patsubst $(PRODUCT_OUT)/%,%,$(3)))
$(eval _module_name := $(ALL_INSTALLED_FILES.$(3)))
$(eval _module_path := $(strip $(sort $(ALL_MODULES.$(_module_name).PATH))))
$(eval _soong_module_type := $(strip $(sort $(ALL_MODULES.$(_module_name).SOONG_MODULE_TYPE))))
$(eval _dep_modules := $(filter %.$(_module_name),$(ALL_MODULES)) $(filter %.$(_module_name)$(TARGET_2ND_ARCH_MODULE_SUFFIX),$(ALL_MODULES)))
$(eval _is_apex := $(filter %.apex,$(3)))

$(4):
	rm -rf $$@
	echo installed_file,module_path,soong_module_type,is_prebuilt_make_module,product_copy_files,kernel_module_copy_files,is_platform_generated,build_output_path,static_libraries,whole_static_libraries,is_static_lib >> $$@
	echo /$(_path_on_device),$(_module_path),$(_soong_module_type),,,,,$(3),,, >> $$@
	$(if $(filter %.apex,$(3)),\
	  $(foreach m,$(_dep_modules),\
	    echo $(patsubst $(PRODUCT_OUT)/apex/$(_module_name)/%,%,$(ALL_MODULES.$m.INSTALLED)),$(sort $(ALL_MODULES.$m.PATH)),$(sort $(ALL_MODULES.$m.SOONG_MODULE_TYPE)),,,,,$(strip $(ALL_MODULES.$m.BUILT)),,, >> $$@;))

$(2): $(1)
$(1): $(4) $(3) $(GEN_SBOM) $(installed_files) $(metadata_list) $(metadata_files)
	rm -rf $$@
	$(GEN_SBOM) --output_file $$@ --metadata $(4) --build_version $$(BUILD_FINGERPRINT_FROM_FILE) --product_mfr "$(PRODUCT_MANUFACTURER)" --json $(if $(filter %.apk,$(3)),--unbundled_apk,--unbundled_apex)
endef

apps_only_sbom_files :=
apps_only_fragment_files :=
$(foreach f,$(filter %.apk %.apex,$(installed_files)), \
  $(eval _metadata_csv_file := $(patsubst %,%-sbom-metadata.csv,$f)) \
  $(eval _sbom_file := $(patsubst %,%.spdx.json,$f)) \
  $(eval _fragment_file := $(patsubst %,%-fragment.spdx,$f)) \
  $(eval apps_only_sbom_files += $(_sbom_file)) \
  $(eval apps_only_fragment_files += $(_fragment_file)) \
  $(eval $(call generate-app-sbom,$(_sbom_file),$(_fragment_file),$f,$(_metadata_csv_file))) \
)

sbom: $(apps_only_sbom_files)

$(foreach f,$(apps_only_fragment_files),$(eval apps_only_fragment_dist_files += :sbom/$(notdir $f)))
$(foreach f,$(apps_only_sbom_files),$(eval apps_only_sbom_dist_files += :sbom/$(notdir $f)))
$(call dist-for-goals,apps_only,$(join $(apps_only_sbom_files),$(apps_only_sbom_dist_files)) $(join $(apps_only_fragment_files),$(apps_only_fragment_dist_files)))
endif

$(call dist-write-file,$(KATI_PACKAGE_MK_DIR)/dist.mk)

$(info [$(call inc_and_print,subdir_makefiles_inc)/$(subdir_makefiles_total)] writing legacy Make module rules ...)
