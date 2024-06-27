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

ADDITIONAL_SYSTEM_PROPERTIES += ro.treble.enabled=${PRODUCT_FULL_TREBLE}

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

ifdef PRODUCT_SHIPPING_VENDOR_API_LEVEL
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.vendor.api_level=$(PRODUCT_SHIPPING_VENDOR_API_LEVEL)
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
# RELEASE_BOARD_API_LEVEL_FROZEN is true when the vendor API surface is frozen.
ifdef RELEASE_BOARD_API_LEVEL_FROZEN
ADDITIONAL_VENDOR_PROPERTIES += \
    ro.board.api_frozen=$(RELEASE_BOARD_API_LEVEL_FROZEN)
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

ADDITIONAL_PRODUCT_PROPERTIES += ro.build.characteristics=$(TARGET_AAPT_CHARACTERISTICS)

ifeq ($(AB_OTA_UPDATER),true)
ADDITIONAL_PRODUCT_PROPERTIES += ro.product.ab_ota_partitions=$(subst $(space),$(comma),$(sort $(AB_OTA_PARTITIONS)))
ADDITIONAL_VENDOR_PROPERTIES += ro.vendor.build.ab_ota_partitions=$(subst $(space),$(comma),$(sort $(AB_OTA_PARTITIONS)))
endif

# Set this property for VTS to skip large page size tests on unsupported devices.
ADDITIONAL_PRODUCT_PROPERTIES += \
    ro.product.cpu.pagesize.max=$(TARGET_MAX_PAGE_SIZE_SUPPORTED)

ifeq ($(PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO),true)
ADDITIONAL_PRODUCT_PROPERTIES += ro.product.build.no_bionic_page_size_macro=true
endif

user_variant := $(filter user userdebug,$(TARGET_BUILD_VARIANT))
enable_target_debugging := true
enable_dalvik_lock_contention_logging := true
ifneq (,$(user_variant))
  # Target is secure in user builds.
  ADDITIONAL_SYSTEM_PROPERTIES += ro.secure=1
  ADDITIONAL_SYSTEM_PROPERTIES += security.perf_harden=1

  ifeq ($(user_variant),user)
    ADDITIONAL_SYSTEM_PROPERTIES += ro.adb.secure=1
  endif

  ifneq ($(user_variant),userdebug)
    # Disable debugging in plain user builds.
    enable_target_debugging :=
    enable_dalvik_lock_contention_logging :=
  else
    # Disable debugging in userdebug builds if PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG
    # is set.
    ifneq (,$(strip $(PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG)))
      enable_target_debugging :=
    endif
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

ifeq (true,$(strip $(enable_dalvik_lock_contention_logging)))
  # Enable Dalvik lock contention logging.
  ADDITIONAL_SYSTEM_PROPERTIES += dalvik.vm.lockprof.threshold=500
endif # !enable_dalvik_lock_contention_logging

ifeq (true,$(strip $(enable_target_debugging)))
  # Target is more debuggable and adbd is on by default
  ADDITIONAL_SYSTEM_PROPERTIES += ro.debuggable=1
else # !enable_target_debugging
  # Target is less debuggable and adbd is off by default
  ADDITIONAL_SYSTEM_PROPERTIES += ro.debuggable=0
endif # !enable_target_debugging

enable_target_debugging:=
enable_dalvik_lock_contention_logging:=

ifneq ($(filter sdk sdk_addon,$(MAKECMDGOALS)),)
_is_sdk_build := true
endif

ifeq ($(TARGET_BUILD_VARIANT),eng)
ifneq ($(filter ro.setupwizard.mode=ENABLED, $(call collapse-pairs, $(ADDITIONAL_SYSTEM_PROPERTIES))),)
  # Don't require the setup wizard on eng builds
  ADDITIONAL_SYSTEM_PROPERTIES := $(filter-out ro.setupwizard.mode=%,\
          $(call collapse-pairs, $(ADDITIONAL_SYSTEM_PROPERTIES))) \
          ro.setupwizard.mode=OPTIONAL
endif
ifndef _is_sdk_build
  # To speedup startup of non-preopted builds, don't verify or compile the boot image.
  ADDITIONAL_SYSTEM_PROPERTIES += dalvik.vm.image-dex2oat-filter=extract
endif
# b/323566535
ADDITIONAL_SYSTEM_PROPERTIES += init.svc_debug.no_fatal.zygote=true
endif

ifdef _is_sdk_build
ADDITIONAL_SYSTEM_PROPERTIES += xmpp.auto-presence=true
ADDITIONAL_SYSTEM_PROPERTIES += ro.config.nocheckin=yes
endif

_is_sdk_build :=

ADDITIONAL_SYSTEM_PROPERTIES += net.bt.name=Android

# This property is set by flashing debug boot image, so default to false.
ADDITIONAL_SYSTEM_PROPERTIES += ro.force.debuggable=0

config_enable_uffd_gc := \
  $(firstword $(OVERRIDE_ENABLE_UFFD_GC) $(PRODUCT_ENABLE_UFFD_GC) default)

# This is a temporary system property that controls the ART module. The plan is
# to remove it by Aug 2025, at which time Mainline updates of the ART module
# will ignore it as well.
# If the value is "default", it will be mangled by post_process_props.py.
ADDITIONAL_PRODUCT_PROPERTIES += ro.dalvik.vm.enable_uffd_gc=$(config_enable_uffd_gc)

ADDITIONAL_SYSTEM_PROPERTIES := $(strip $(ADDITIONAL_SYSTEM_PROPERTIES))
ADDITIONAL_PRODUCT_PROPERTIES := $(strip $(ADDITIONAL_PRODUCT_PROPERTIES))
ADDITIONAL_VENDOR_PROPERTIES := $(strip $(ADDITIONAL_VENDOR_PROPERTIES))

.KATI_READONLY += \
    ADDITIONAL_SYSTEM_PROPERTIES \
    ADDITIONAL_PRODUCT_PROPERTIES \
    ADDITIONAL_VENDOR_PROPERTIES
