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

$(KATI_obsolete_var ADDITIONAL_SYSTEM_PROPERTIES,Use build/soong/scripts/gen_build_prop.py instead)
$(KATI_obsolete_var ADDITIONAL_ODM_PROPERTIES,Use build/soong/scripts/gen_build_prop.py instead)
$(KATI_obsolete_var ADDITIONAL_PRODUCT_PROPERTIES,Use build/soong/scripts/gen_build_prop.py instead)

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
    ro.board.api_level?=$(BOARD_API_LEVEL)
  ifdef BOARD_API_LEVEL_PROP_OVERRIDE
    ADDITIONAL_VENDOR_PROPERTIES += \
      ro.board.api_level=$(BOARD_API_LEVEL_PROP_OVERRIDE)
  endif
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

ifeq ($(AB_OTA_UPDATER),true)
ADDITIONAL_VENDOR_PROPERTIES += ro.vendor.build.ab_ota_partitions=$(subst $(space),$(comma),$(sort $(AB_OTA_PARTITIONS)))
endif

user_variant := $(filter user userdebug,$(TARGET_BUILD_VARIANT))

config_enable_uffd_gc := \
  $(firstword $(OVERRIDE_ENABLE_UFFD_GC) $(PRODUCT_ENABLE_UFFD_GC) default)

ADDITIONAL_VENDOR_PROPERTIES := $(strip $(ADDITIONAL_VENDOR_PROPERTIES))

.KATI_READONLY += \
    ADDITIONAL_VENDOR_PROPERTIES
