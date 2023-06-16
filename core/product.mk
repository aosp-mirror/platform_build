#
# Copyright (C) 2007 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Variables that are meant to hold only a single value.
# - The value set in the current makefile takes precedence over inherited values
# - If multiple inherited makefiles set the var, the first-inherited value wins
_product_single_value_vars :=

# Variables that are lists of values.
_product_list_vars :=

_product_single_value_vars += PRODUCT_NAME
_product_single_value_vars += PRODUCT_MODEL
_product_single_value_vars += PRODUCT_NAME_FOR_ATTESTATION
_product_single_value_vars += PRODUCT_MODEL_FOR_ATTESTATION

# Defines the ELF segment alignment for binaries (executables and shared libraries).
# The ELF segment alignment has to be a PAGE_SIZE multiple. For example, if
# PRODUCT_MAX_PAGE_SIZE_SUPPORTED=65536, the possible values for PAGE_SIZE could be
# 4096, 16384 and 65536.
_product_single_value_vars += PRODUCT_MAX_PAGE_SIZE_SUPPORTED

# The resource configuration options to use for this product.
_product_list_vars += PRODUCT_LOCALES
_product_list_vars += PRODUCT_AAPT_CONFIG
_product_single_value_vars += PRODUCT_AAPT_PREF_CONFIG
_product_list_vars += PRODUCT_AAPT_PREBUILT_DPI
_product_list_vars += PRODUCT_HOST_PACKAGES
_product_list_vars += PRODUCT_PACKAGES
_product_list_vars += PRODUCT_PACKAGES_DEBUG
_product_list_vars += PRODUCT_PACKAGES_DEBUG_ASAN
_product_list_vars += PRODUCT_PACKAGES_ARM64
# Packages included only for eng/userdebug builds, when building with EMMA_INSTRUMENT=true
_product_list_vars += PRODUCT_PACKAGES_DEBUG_JAVA_COVERAGE
_product_list_vars += PRODUCT_PACKAGES_ENG
_product_list_vars += PRODUCT_PACKAGES_TESTS

# The device that this product maps to.
_product_single_value_vars += PRODUCT_DEVICE
_product_single_value_vars += PRODUCT_MANUFACTURER
_product_single_value_vars += PRODUCT_BRAND
_product_single_value_vars += PRODUCT_BRAND_FOR_ATTESTATION

# These PRODUCT_SYSTEM_* flags, if defined, are used in place of the
# corresponding PRODUCT_* flags for the sysprops on /system.
_product_single_value_vars += \
    PRODUCT_SYSTEM_NAME \
    PRODUCT_SYSTEM_MODEL \
    PRODUCT_SYSTEM_DEVICE \
    PRODUCT_SYSTEM_BRAND \
    PRODUCT_SYSTEM_MANUFACTURER \

# PRODUCT_<PARTITION>_PROPERTIES are lists of property assignments
# that go to <partition>/build.prop. Each property assignment is
# "key = value" with zero or more whitespace characters on either
# side of the '='.
_product_list_vars += \
    PRODUCT_SYSTEM_PROPERTIES \
    PRODUCT_SYSTEM_EXT_PROPERTIES \
    PRODUCT_VENDOR_PROPERTIES \
    PRODUCT_ODM_PROPERTIES \
    PRODUCT_PRODUCT_PROPERTIES

# TODO(b/117892318) deprecate these:
# ... in favor or PRODUCT_SYSTEM_PROPERTIES
_product_list_vars += PRODUCT_SYSTEM_DEFAULT_PROPERTIES
# ... in favor of PRODUCT_VENDOR_PROPERTIES
_product_list_vars += PRODUCT_PROPERTY_OVERRIDES
_product_list_vars += PRODUCT_DEFAULT_PROPERTY_OVERRIDES

# TODO(b/117892318) consider deprecating these too
_product_list_vars += PRODUCT_SYSTEM_PROPERTY_BLACKLIST
_product_list_vars += PRODUCT_VENDOR_PROPERTY_BLACKLIST

# The characteristics of the product, which among other things is passed to aapt
_product_single_value_vars += PRODUCT_CHARACTERISTICS

# A list of words like <source path>:<destination path>[:<owner>].
# The file at the source path should be copied to the destination path
# when building  this product.  <destination path> is relative to
# $(PRODUCT_OUT), so it should look like, e.g., "system/etc/file.xml".
# The rules for these copy steps are defined in build/make/core/Makefile.
# The optional :<owner> is used to indicate the owner of a vendor file.
_product_list_vars += PRODUCT_COPY_FILES

# The OTA key(s) specified by the product config, if any.  The names
# of these keys are stored in the target-files zip so that post-build
# signing tools can substitute them for the test key embedded by
# default.
_product_list_vars += PRODUCT_OTA_PUBLIC_KEYS
_product_list_vars += PRODUCT_EXTRA_OTA_KEYS
_product_list_vars += PRODUCT_EXTRA_RECOVERY_KEYS

# Should we use the default resources or add any product specific overlays
_product_list_vars += PRODUCT_PACKAGE_OVERLAYS
_product_list_vars += DEVICE_PACKAGE_OVERLAYS

# Resource overlay list which must be excluded from enforcing RRO.
_product_list_vars += PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS

# Package list to apply enforcing RRO.
_product_list_vars += PRODUCT_ENFORCE_RRO_TARGETS

_product_list_vars += PRODUCT_SDK_ATREE_FILES
_product_list_vars += PRODUCT_SDK_ADDON_NAME
_product_list_vars += PRODUCT_SDK_ADDON_COPY_FILES
_product_list_vars += PRODUCT_SDK_ADDON_COPY_MODULES
_product_list_vars += PRODUCT_SDK_ADDON_DOC_MODULES
_product_list_vars += PRODUCT_SDK_ADDON_SYS_IMG_SOURCE_PROP

# which Soong namespaces to export to Make
_product_list_vars += PRODUCT_SOONG_NAMESPACES

_product_list_vars += PRODUCT_DEFAULT_WIFI_CHANNELS
_product_single_value_vars += PRODUCT_DEFAULT_DEV_CERTIFICATE
_product_list_vars += PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES
_product_list_vars += PRODUCT_RESTRICT_VENDOR_FILES

# The list of product-specific kernel header dirs
_product_list_vars += PRODUCT_VENDOR_KERNEL_HEADERS

# A list of module names in BOOTCLASSPATH (jar files). Each module may be
# prefixed with "<apex>:", which identifies the APEX that provides it. APEXes
# are identified by their "variant" names, i.e. their `apex_name` values in
# Soong, which default to the `name` values. The prefix can also be "platform:"
# or "system_ext:", and defaults to "platform:" if left out. See the long
# comment in build/soong/java/dexprepopt_bootjars.go for details.
_product_list_vars += PRODUCT_BOOT_JARS

# A list of extra BOOTCLASSPATH jars (to be appended after common jars),
# following the same format as PRODUCT_BOOT_JARS. Products that include
# device-specific makefiles before AOSP makefiles should use this instead of
# PRODUCT_BOOT_JARS, so that device-specific jars go after common jars.
_product_list_vars += PRODUCT_BOOT_JARS_EXTRA

_product_single_value_vars += PRODUCT_SUPPORTS_VBOOT
_product_list_vars += PRODUCT_SYSTEM_SERVER_APPS
# List of system_server classpath jars on the platform.
_product_list_vars += PRODUCT_SYSTEM_SERVER_JARS
# List of system_server classpath jars delivered via apex. Format = <apex name>:<jar name>.
_product_list_vars += PRODUCT_APEX_SYSTEM_SERVER_JARS
# List of jars on the platform that system_server loads dynamically using separate classloaders.
_product_list_vars += PRODUCT_STANDALONE_SYSTEM_SERVER_JARS
# List of jars delivered via apex that system_server loads dynamically using separate classloaders.
# Format = <apex name>:<jar name>
_product_list_vars += PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS
# If true, then suboptimal order of system server jars does not cause an error.
_product_single_value_vars += PRODUCT_BROKEN_SUBOPTIMAL_ORDER_OF_SYSTEM_SERVER_JARS
# If true, then system server jars defined in Android.mk are supported.
_product_single_value_vars += PRODUCT_BROKEN_DEPRECATED_MK_SYSTEM_SERVER_JARS

# Additional system server jars to be appended at the end of the common list.
# This is necessary to avoid jars reordering due to makefile inheritance order.
_product_list_vars += PRODUCT_SYSTEM_SERVER_JARS_EXTRA

# Set to true to disable <uses-library> checks for a product.
_product_list_vars += PRODUCT_BROKEN_VERIFY_USES_LIBRARIES

# All of the apps that we force preopt, this overrides WITH_DEXPREOPT.
_product_list_vars += PRODUCT_ALWAYS_PREOPT_EXTRACTED_APK
_product_list_vars += PRODUCT_DEXPREOPT_SPEED_APPS
_product_list_vars += PRODUCT_LOADED_BY_PRIVILEGED_MODULES
_product_single_value_vars += PRODUCT_VBOOT_SIGNING_KEY
_product_single_value_vars += PRODUCT_VBOOT_SIGNING_SUBKEY
_product_single_value_vars += PRODUCT_SYSTEM_VERITY_PARTITION
_product_single_value_vars += PRODUCT_VENDOR_VERITY_PARTITION
_product_single_value_vars += PRODUCT_PRODUCT_VERITY_PARTITION
_product_single_value_vars += PRODUCT_SYSTEM_EXT_VERITY_PARTITION
_product_single_value_vars += PRODUCT_ODM_VERITY_PARTITION
_product_single_value_vars += PRODUCT_VENDOR_DLKM_VERITY_PARTITION
_product_single_value_vars += PRODUCT_ODM_DLKM_VERITY_PARTITION
_product_single_value_vars += PRODUCT_SYSTEM_DLKM_VERITY_PARTITION
_product_single_value_vars += PRODUCT_SYSTEM_SERVER_DEBUG_INFO
_product_single_value_vars += PRODUCT_OTHER_JAVA_DEBUG_INFO

# Per-module dex-preopt configs.
_product_list_vars += PRODUCT_DEX_PREOPT_MODULE_CONFIGS
_product_single_value_vars += PRODUCT_DEX_PREOPT_DEFAULT_COMPILER_FILTER
_product_list_vars += PRODUCT_DEX_PREOPT_DEFAULT_FLAGS
_product_single_value_vars += PRODUCT_DEX_PREOPT_BOOT_FLAGS
_product_single_value_vars += PRODUCT_DEX_PREOPT_PROFILE_DIR
_product_single_value_vars += PRODUCT_DEX_PREOPT_GENERATE_DM_FILES
_product_single_value_vars += PRODUCT_DEX_PREOPT_NEVER_ALLOW_STRIPPING
_product_single_value_vars += PRODUCT_DEX_PREOPT_RESOLVE_STARTUP_STRINGS

# Boot image options.
_product_list_vars += PRODUCT_DEX_PREOPT_BOOT_IMAGE_PROFILE_LOCATION
_product_single_value_vars += \
    PRODUCT_EXPORT_BOOT_IMAGE_TO_DIST \
    PRODUCT_USE_PROFILE_FOR_BOOT_IMAGE \
    PRODUCT_USES_DEFAULT_ART_CONFIG \

_product_single_value_vars += PRODUCT_SYSTEM_SERVER_COMPILER_FILTER
# Per-module sanitizer configs
_product_list_vars += PRODUCT_SANITIZER_MODULE_CONFIGS
_product_single_value_vars += PRODUCT_SYSTEM_BASE_FS_PATH
_product_single_value_vars += PRODUCT_VENDOR_BASE_FS_PATH
_product_single_value_vars += PRODUCT_PRODUCT_BASE_FS_PATH
_product_single_value_vars += PRODUCT_SYSTEM_EXT_BASE_FS_PATH
_product_single_value_vars += PRODUCT_ODM_BASE_FS_PATH
_product_single_value_vars += PRODUCT_VENDOR_DLKM_BASE_FS_PATH
_product_single_value_vars += PRODUCT_ODM_DLKM_BASE_FS_PATH
_product_single_value_vars += PRODUCT_SYSTEM_DLKM_BASE_FS_PATH

# The first API level this product shipped with
_product_single_value_vars += PRODUCT_SHIPPING_API_LEVEL

_product_list_vars += VENDOR_PRODUCT_RESTRICT_VENDOR_FILES
_product_list_vars += VENDOR_EXCEPTION_MODULES
_product_list_vars += VENDOR_EXCEPTION_PATHS
# Whether the product wants to ship libartd. For rules and meaning, see art/Android.mk.
_product_single_value_vars += PRODUCT_ART_TARGET_INCLUDE_DEBUG_BUILD

# Make this art variable visible to soong_config.mk.
_product_single_value_vars += PRODUCT_ART_USE_READ_BARRIER

# Add reserved headroom to a system image.
_product_single_value_vars += PRODUCT_SYSTEM_HEADROOM

# Whether to save disk space by minimizing java debug info
_product_single_value_vars += PRODUCT_MINIMIZE_JAVA_DEBUG_INFO

# Whether any paths are excluded from sanitization when SANITIZE_TARGET=integer_overflow
_product_list_vars += PRODUCT_INTEGER_OVERFLOW_EXCLUDE_PATHS

_product_single_value_vars += PRODUCT_ADB_KEYS

# Whether any paths should have CFI enabled for components
_product_list_vars += PRODUCT_CFI_INCLUDE_PATHS

# Whether any paths are excluded from sanitization when SANITIZE_TARGET=cfi
_product_list_vars += PRODUCT_CFI_EXCLUDE_PATHS

# Whether any paths should have HWASan enabled for components
_product_list_vars += PRODUCT_HWASAN_INCLUDE_PATHS

# Whether any paths should have Memtag_heap enabled for components
_product_list_vars += PRODUCT_MEMTAG_HEAP_ASYNC_INCLUDE_PATHS
_product_list_vars += PRODUCT_MEMTAG_HEAP_ASYNC_DEFAULT_INCLUDE_PATHS
_product_list_vars += PRODUCT_MEMTAG_HEAP_SYNC_INCLUDE_PATHS
_product_list_vars += PRODUCT_MEMTAG_HEAP_SYNC_DEFAULT_INCLUDE_PATHS
_product_list_vars += PRODUCT_MEMTAG_HEAP_EXCLUDE_PATHS

# Whether this product wants to start with an empty list of default memtag_heap include paths
_product_single_value_vars += PRODUCT_MEMTAG_HEAP_SKIP_DEFAULT_PATHS

# Whether the Scudo hardened allocator is disabled platform-wide
_product_single_value_vars += PRODUCT_DISABLE_SCUDO

# List of extra VNDK versions to be included
_product_list_vars += PRODUCT_EXTRA_VNDK_VERSIONS

# Whether APEX should be compressed or not
_product_single_value_vars += PRODUCT_COMPRESSED_APEX

# VNDK version of product partition. It can be 'current' if the product
# partitions uses PLATFORM_VNDK_VERSION.
_product_single_value_vars += PRODUCT_PRODUCT_VNDK_VERSION

_product_single_value_vars += PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS
_product_single_value_vars += PRODUCT_ENFORCE_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT
_product_list_vars += PRODUCT_ARTIFACT_SYSTEM_CERTIFICATE_REQUIREMENT_ALLOW_LIST
_product_list_vars += PRODUCT_ARTIFACT_PATH_REQUIREMENT_HINT
_product_list_vars += PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST

# List of modules that should be forcefully unmarked from being LOCAL_PRODUCT_MODULE, and hence
# installed on /system directory by default.
_product_list_vars += PRODUCT_FORCE_PRODUCT_MODULES_TO_SYSTEM_PARTITION

# When this is true, dynamic partitions is retrofitted on a device that has
# already been launched without dynamic partitions. Otherwise, the device
# is launched with dynamic partitions.
# This flag implies PRODUCT_USE_DYNAMIC_PARTITIONS.
_product_single_value_vars += PRODUCT_RETROFIT_DYNAMIC_PARTITIONS

# List of tags that will be used to gate blueprint modules from the build graph
_product_list_vars += PRODUCT_INCLUDE_TAGS

# List of directories that will be used to gate blueprint modules from the build graph
_product_list_vars += PRODUCT_SOURCE_ROOT_DIRS

# When this is true, various build time as well as runtime debugfs restrictions are enabled.
_product_single_value_vars += PRODUCT_SET_DEBUGFS_RESTRICTIONS

# Other dynamic partition feature flags.PRODUCT_USE_DYNAMIC_PARTITION_SIZE and
# PRODUCT_BUILD_SUPER_PARTITION default to the value of PRODUCT_USE_DYNAMIC_PARTITIONS.
_product_single_value_vars += \
    PRODUCT_USE_DYNAMIC_PARTITIONS \
    PRODUCT_USE_DYNAMIC_PARTITION_SIZE \
    PRODUCT_BUILD_SUPER_PARTITION \

# If set, kernel configuration requirements are present in OTA package (and will be enforced
# during OTA). Otherwise, kernel configuration requirements are enforced in VTS.
# Devices that checks the running kernel (instead of the kernel in OTA package) should not
# set this variable to prevent OTA failures.
_product_list_vars += PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS

# If set to true, this product builds a generic OTA package, which installs generic system images
# onto matching devices. The product may only build a subset of system images (e.g. only
# system.img), so devices need to install the package in a system-only OTA manner.
_product_single_value_vars += PRODUCT_BUILD_GENERIC_OTA_PACKAGE

_product_list_vars += PRODUCT_MANIFEST_PACKAGE_NAME_OVERRIDES
_product_list_vars += PRODUCT_PACKAGE_NAME_OVERRIDES
_product_list_vars += PRODUCT_CERTIFICATE_OVERRIDES

# Controls for whether different partitions are built for the current product.
_product_single_value_vars += PRODUCT_BUILD_SYSTEM_IMAGE
_product_single_value_vars += PRODUCT_BUILD_SYSTEM_OTHER_IMAGE
_product_single_value_vars += PRODUCT_BUILD_VENDOR_IMAGE
_product_single_value_vars += PRODUCT_BUILD_PRODUCT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_SYSTEM_EXT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_ODM_IMAGE
_product_single_value_vars += PRODUCT_BUILD_VENDOR_DLKM_IMAGE
_product_single_value_vars += PRODUCT_BUILD_ODM_DLKM_IMAGE
_product_single_value_vars += PRODUCT_BUILD_SYSTEM_DLKM_IMAGE
_product_single_value_vars += PRODUCT_BUILD_CACHE_IMAGE
_product_single_value_vars += PRODUCT_BUILD_RAMDISK_IMAGE
_product_single_value_vars += PRODUCT_BUILD_USERDATA_IMAGE
_product_single_value_vars += PRODUCT_BUILD_RECOVERY_IMAGE
_product_single_value_vars += PRODUCT_BUILD_BOOT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_INIT_BOOT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_DEBUG_BOOT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_VENDOR_BOOT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_VENDOR_KERNEL_BOOT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_DEBUG_VENDOR_BOOT_IMAGE
_product_single_value_vars += PRODUCT_BUILD_VBMETA_IMAGE
_product_single_value_vars += PRODUCT_BUILD_SUPER_EMPTY_IMAGE
_product_single_value_vars += PRODUCT_BUILD_PVMFW_IMAGE

# List of boot jars delivered via updatable APEXes, following the same format as
# PRODUCT_BOOT_JARS.
_product_list_vars += PRODUCT_APEX_BOOT_JARS

# If set, device uses virtual A/B.
_product_single_value_vars += PRODUCT_VIRTUAL_AB_OTA

# If set, device uses virtual A/B Compression.
_product_single_value_vars += PRODUCT_VIRTUAL_AB_COMPRESSION

# If set, device retrofits virtual A/B.
_product_single_value_vars += PRODUCT_VIRTUAL_AB_OTA_RETROFIT

# If set, forcefully generate a non-A/B update package.
# Note: A device configuration should inherit from virtual_ab_ota_plus_non_ab.mk
# instead of setting this variable directly.
# Note: Use TARGET_OTA_ALLOW_NON_AB in the build system because
# TARGET_OTA_ALLOW_NON_AB takes the value of AB_OTA_UPDATER into account.
_product_single_value_vars += PRODUCT_OTA_FORCE_NON_AB_PACKAGE

# If set, Java module in product partition cannot use hidden APIs.
_product_single_value_vars += PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE

# If set, only java_sdk_library can be used at inter-partition dependency.
# Note: Build error if BOARD_VNDK_VERSION is not set while
#       PRODUCT_ENFORCE_INTER_PARTITION_JAVA_SDK_LIBRARY is true, because
#       PRODUCT_ENFORCE_INTER_PARTITION_JAVA_SDK_LIBRARY has no meaning if
#       BOARD_VNDK_VERSION is not set.
# Note: When PRODUCT_ENFORCE_PRODUCT_PARTITION_INTERFACE is not set, there are
#       no restrictions at dependency between system and product partition.
_product_single_value_vars += PRODUCT_ENFORCE_INTER_PARTITION_JAVA_SDK_LIBRARY

# Allowlist for PRODUCT_ENFORCE_INTER_PARTITION_JAVA_SDK_LIBRARY option.
# Listed modules are allowed at inter-partition dependency even if it isn't
# a java_sdk_library module.
_product_list_vars += PRODUCT_INTER_PARTITION_JAVA_LIBRARY_ALLOWLIST

_product_single_value_vars += PRODUCT_INSTALL_EXTRA_FLATTENED_APEXES

# Install a copy of the debug policy to the system_ext partition, and allow
# init-second-stage to load debug policy from system_ext.
# This option is only meant to be set by compliance GSI targets.
_product_single_value_vars += PRODUCT_INSTALL_DEBUG_POLICY_TO_SYSTEM_EXT

# If set, fsverity metadata files will be generated for each files in the
# allowlist, plus an manifest APK per partition. For example,
# /system/framework/service.jar will come with service.jar.fsv_meta in the same
# directory; the file information will also be included in
# /system/etc/security/fsverity/BuildManifest.apk
_product_single_value_vars += PRODUCT_FSVERITY_GENERATE_METADATA

# If true, sets the default for MODULE_BUILD_FROM_SOURCE. This overrides
# BRANCH_DEFAULT_MODULE_BUILD_FROM_SOURCE but not an explicitly set value.
_product_single_value_vars += PRODUCT_MODULE_BUILD_FROM_SOURCE

# If true, installs a full version of com.android.virt APEX.
_product_single_value_vars += PRODUCT_AVF_ENABLED

# List of .json files to be merged/compiled into vendor/etc/linker.config.pb
_product_list_vars += PRODUCT_VENDOR_LINKER_CONFIG_FRAGMENTS

# Whether to use userfaultfd GC.
# Possible values are:
# - "default" or empty: both the build system and the runtime determine whether to use userfaultfd
#   GC based on the vendor API level
# - "true": forces the build system to use userfaultfd GC regardless of the vendor API level; the
#   runtime determines whether to use userfaultfd GC based on the kernel support. Note that the
#   device may have to re-compile everything on the first boot if the kernel doesn't support
#   userfaultfd
# - "false": disallows the build system and the runtime to use userfaultfd GC even if the device
#   supports it
_product_single_value_vars += PRODUCT_ENABLE_UFFD_GC

_product_list_vars += PRODUCT_AFDO_PROFILES

.KATI_READONLY := _product_single_value_vars _product_list_vars
_product_var_list :=$= $(_product_single_value_vars) $(_product_list_vars)

#
# Functions for including product makefiles
#

#
# $(1): product to inherit
#
# To be called from product makefiles, and is later evaluated during the import-nodes
# call below. It does the following:
#  1. Inherits all of the variables from $1.
#  2. Records the inheritance in the .INHERITS_FROM variable
#
# (2) and the PRODUCTS variable can be used together to reconstruct the include hierarchy
# See e.g. product-graph.mk for an example of this.
#
define inherit-product
  $(eval _inherit_product_wildcard := $(wildcard $(1)))\
  $(if $(_inherit_product_wildcard),,$(error $(1) does not exist.))\
  $(foreach part,$(_inherit_product_wildcard),\
    $(if $(findstring ../,$(part)),\
      $(eval np := $(call normalize-paths,$(part))),\
      $(eval np := $(strip $(part))))\
    $(foreach v,$(_product_var_list), \
        $(eval $(v) := $($(v)) $(INHERIT_TAG)$(np))) \
    $(eval current_mk := $(strip $(word 1,$(_include_stack)))) \
    $(eval inherit_var := PRODUCTS.$(current_mk).INHERITS_FROM) \
    $(eval $(inherit_var) := $(sort $($(inherit_var)) $(np))) \
    $(call dump-inherit,$(current_mk),$(1)) \
    $(call dump-config-vals,$(current_mk),inherit))
endef

# Specifies a number of path prefixes, relative to PRODUCT_OUT, where the
# product makefile hierarchy rooted in the current node places its artifacts.
# Creating artifacts outside the specified paths will cause a build-time error.
define require-artifacts-in-path
  $(eval current_mk := $(strip $(word 1,$(_include_stack)))) \
  $(eval PRODUCTS.$(current_mk).ARTIFACT_PATH_REQUIREMENTS := $(strip $(1))) \
  $(eval PRODUCTS.$(current_mk).ARTIFACT_PATH_ALLOWED_LIST := $(strip $(2))) \
  $(eval ARTIFACT_PATH_REQUIREMENT_PRODUCTS := \
    $(sort $(ARTIFACT_PATH_REQUIREMENT_PRODUCTS) $(current_mk)))
endef

# Like require-artifacts-in-path, but does not require all allow-list entries to
# have an effect.
define require-artifacts-in-path-relaxed
  $(require-artifacts-in-path) \
  $(eval PRODUCTS.$(current_mk).ARTIFACT_PATH_REQUIREMENT_IS_RELAXED := true)
endef

# Makes including non-existent modules in PRODUCT_PACKAGES an error.
# $(1): list of non-existent modules to allow.
define enforce-product-packages-exist
  $(eval current_mk := $(strip $(word 1,$(_include_stack)))) \
  $(eval PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST := true) \
  $(eval PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST := $(1)) \
  $(eval .KATI_READONLY := PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST) \
  $(eval .KATI_READONLY := PRODUCTS.$(current_mk).PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST)
endef

#
# Do inherit-product only if $(1) exists
#
define inherit-product-if-exists
  $(if $(wildcard $(1)),$(call inherit-product,$(1)),)
endef

#
# $(1): product makefile list
#
#TODO: check to make sure that products have all the necessary vars defined
define import-products
$(call import-nodes,PRODUCTS,$(1),$(_product_var_list),$(_product_single_value_vars))
endef


#
# Does various consistency checks on the current product.
# Takes no parameters, so $(call ) is not necessary.
#
define check-current-product
$(if ,, \
  $(if $(call is-c-identifier,$(PRODUCT_NAME)),, \
    $(error $(INTERNAL_PRODUCT): PRODUCT_NAME must be a valid C identifier, not "$(pn)")) \
  $(if $(PRODUCT_BRAND),, \
    $(error $(INTERNAL_PRODUCT): PRODUCT_BRAND must be defined.)) \
  $(foreach cf,$(strip $(PRODUCT_COPY_FILES)), \
    $(if $(filter 2 3,$(words $(subst :,$(space),$(cf)))),, \
      $(error $(p): malformed COPY_FILE "$(cf)"))))
endef

# BoardConfig variables that are also inherited in product mks. Should ideally
# be cleaned up to not be product variables.
_readonly_late_variables := \
  DEVICE_PACKAGE_OVERLAYS \
  WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY \

# Modified internally in the build system
_readonly_late_variables += \
  PRODUCT_COPY_FILES \
  PRODUCT_DEX_PREOPT_NEVER_ALLOW_STRIPPING \
  PRODUCT_DEX_PREOPT_BOOT_FLAGS \

_readonly_early_variables := $(filter-out $(_readonly_late_variables),$(_product_var_list))

#
# Mark the variables in _product_stash_var_list as readonly
#
define readonly-variables
$(foreach v,$(1), \
  $(eval $(v) ?=) \
  $(eval .KATI_READONLY := $(v)) \
 )
endef
define readonly-product-vars
$(call readonly-variables,$(_readonly_early_variables))
endef

define readonly-final-product-vars
$(call readonly-variables,$(_readonly_late_variables))
endef

# Macro re-defined inside strip-product-vars.
get-product-var = $(PRODUCTS.$(strip $(1)).$(2))
#
# Strip the variables in _product_var_list and a few build-system
# internal variables, and assign the ones for the current product
# to a shorthand that is more convenient to read from elsewhere.
#
define strip-product-vars
$(call dump-phase-start,PRODUCT-EXPAND,,$(_product_var_list),$(_product_single_value_vars), \
		build/make/core/product.mk) \
$(foreach v,\
  $(_product_var_list) \
    PRODUCT_ENFORCE_PACKAGES_EXIST \
    PRODUCT_ENFORCE_PACKAGES_EXIST_ALLOW_LIST, \
  $(eval $(v) := $(strip $(PRODUCTS.$(INTERNAL_PRODUCT).$(v)))) \
  $(eval get-product-var = $$(if $$(filter $$(1),$$(INTERNAL_PRODUCT)),$$($$(2)),$$(PRODUCTS.$$(strip $$(1)).$$(2)))) \
  $(KATI_obsolete_var PRODUCTS.$(INTERNAL_PRODUCT).$(v),Use $(v) instead) \
) \
$(call dump-phase-end,build/make/core/product.mk)
endef

define add-to-product-copy-files-if-exists
$(if $(wildcard $(word 1,$(subst :, ,$(1)))),$(1))
endef

# whitespace placeholder when we record module's dex-preopt config.
_PDPMC_SP_PLACE_HOLDER := |@SP@|
# Set up dex-preopt config for a module.
# $(1) list of module names
# $(2) the modules' dex-preopt config
define add-product-dex-preopt-module-config
$(eval _c := $(subst $(space),$(_PDPMC_SP_PLACE_HOLDER),$(strip $(2))))\
$(eval PRODUCT_DEX_PREOPT_MODULE_CONFIGS += \
  $(foreach m,$(1),$(m)=$(_c)))
endef

# whitespace placeholder when we record module's sanitizer config.
_PSMC_SP_PLACE_HOLDER := |@SP@|
# Set up sanitizer config for a module.
# $(1) list of module names
# $(2) the modules' sanitizer config
define add-product-sanitizer-module-config
$(eval _c := $(subst $(space),$(_PSMC_SP_PLACE_HOLDER),$(strip $(2))))\
$(eval PRODUCT_SANITIZER_MODULE_CONFIGS += \
  $(foreach m,$(1),$(m)=$(_c)))
endef
