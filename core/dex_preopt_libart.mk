####################################
# dexpreopt support for ART
#
####################################

DEX2OAT := $(HOST_OUT_EXECUTABLES)/dex2oat$(HOST_EXECUTABLE_SUFFIX)
DEX2OATD := $(HOST_OUT_EXECUTABLES)/dex2oatd$(HOST_EXECUTABLE_SUFFIX)

# By default, do not run rerun dex2oat if the tool changes.
# Comment out the | to force dex2oat to rerun on after all changes.
DEX2OAT_DEPENDENCY := art/runtime/oat.cc # dependency on oat version number
DEX2OAT_DEPENDENCY += art/runtime/image.cc # dependency on image version number
DEX2OAT_DEPENDENCY += |
DEX2OAT_DEPENDENCY += $(DEX2OAT)

DEX2OATD_DEPENDENCY := $(DEX2OAT_DEPENDENCY)
DEX2OATD_DEPENDENCY += $(DEX2OATD)

PRELOADED_CLASSES := frameworks/base/preloaded-classes

# start of image reserved address space
LIBART_IMG_HOST_BASE_ADDRESS   := 0x60000000

ifeq ($(TARGET_ARCH),mips)
LIBART_IMG_TARGET_BASE_ADDRESS := 0x30000000
else
LIBART_IMG_TARGET_BASE_ADDRESS := 0x70000000
endif

########################################################################
# The full system boot classpath

# Returns the path to the .odex file
# $(1): the arch name.
# $(2): the full path (including file name) of the corresponding .jar or .apk.
define get-odex-file-path
$(dir $(2))$(1)/$(basename $(notdir $(2))).odex
endef

# Returns the path to the image file (such as "/system/framework/<arch>/boot.art"
# $(1): the arch name (such as "arm")
# $(2): the image location (such as "/system/framework/boot.art")
define get-image-file-path
$(dir $(2))$(1)/$(notdir $(2))
endef

# note we use core-libart.jar in place of core.jar for ART.
LIBART_TARGET_BOOT_JARS := $(patsubst core, core-libart,$(DEXPREOPT_BOOT_JARS_MODULES))
LIBART_TARGET_BOOT_DEX_LOCATIONS := $(foreach jar,$(LIBART_TARGET_BOOT_JARS),/$(DEXPREOPT_BOOT_JAR_DIR)/$(jar).jar)
LIBART_TARGET_BOOT_DEX_FILES := $(foreach jar,$(LIBART_TARGET_BOOT_JARS),$(call intermediates-dir-for,JAVA_LIBRARIES,$(jar),,COMMON)/javalib.jar)

my_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/dex_preopt_libart_boot.mk

ifdef TARGET_2ND_ARCH
my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/dex_preopt_libart_boot.mk
my_2nd_arch_prefix :=
endif


########################################################################
# For a single jar or APK

# $(1): the input .jar or .apk file
# $(2): the output .odex file
define dex2oat-one-file
$(hide) rm -f $(2)
$(hide) mkdir -p $(dir $(2))
$(hide) $(DEX2OATD) \
	--runtime-arg -Xms64m --runtime-arg -Xmx64m \
	--boot-image=$(PRIVATE_DEX_PREOPT_IMAGE_LOCATION) \
	--dex-file=$(1) \
	--dex-location=$(PRIVATE_DEX_LOCATION) \
	--oat-file=$(2) \
	--android-root=$(PRODUCT_OUT)/system \
	--instruction-set=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH) \
	--instruction-set-features=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
endef
