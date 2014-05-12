####################################
# dexpreopt support for ART
#
####################################

DEX2OAT := $(HOST_OUT_EXECUTABLES)/dex2oat$(HOST_EXECUTABLE_SUFFIX)
DEX2OATD := $(HOST_OUT_EXECUTABLES)/dex2oatd$(HOST_EXECUTABLE_SUFFIX)

LIBART_COMPILER := $(HOST_OUT_SHARED_LIBRARIES)/libart-compiler$(HOST_SHLIB_SUFFIX)
LIBARTD_COMPILER := $(HOST_OUT_SHARED_LIBRARIES)/libartd-compiler$(HOST_SHLIB_SUFFIX)

# By default, do not run rerun dex2oat if the tool changes.
# Comment out the | to force dex2oat to rerun on after all changes.
DEX2OAT_DEPENDENCY := art/runtime/oat.cc # dependency on oat version number
DEX2OAT_DEPENDENCY += art/runtime/image.cc # dependency on image version number
DEX2OAT_DEPENDENCY += |
DEX2OAT_DEPENDENCY += $(DEX2OAT)
DEX2OAT_DEPENDENCY += $(LIBART_COMPILER)

DEX2OATD_DEPENDENCY := $(DEX2OAT_DEPENDENCY)
DEX2OATD_DEPENDENCY += $(DEX2OATD)
DEX2OATD_DEPENDENCY += $(LIBARTD_COMPILER)

PRELOADED_CLASSES := frameworks/base/preloaded-classes

LIBART_BOOT_IMAGE := /$(DEXPREOPT_BOOT_JAR_DIR)/boot-$(DEX2OAT_TARGET_ARCH).art

DEFAULT_DEX_PREOPT_BUILT_IMAGE := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/boot-$(DEX2OAT_TARGET_ARCH).art

DEFAULT_DEX_PREOPT_INSTALLED_IMAGE :=
ifneq ($(PRODUCT_DEX_PREOPT_IMAGE_IN_DATA),true)
DEFAULT_DEX_PREOPT_INSTALLED_IMAGE := $(PRODUCT_OUT)$(LIBART_BOOT_IMAGE)

# The rule to install boot.art and boot.oat
$(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE) : $(DEFAULT_DEX_PREOPT_BUILT_IMAGE) | $(ACP)
	$(call copy-file-to-target)
	$(hide) $(ACP) -fp $(patsubst %.art,%.oat,$<) $(patsubst %.art,%.oat,$@)
endif

# start of image reserved address space
LIBART_IMG_HOST_BASE_ADDRESS   := 0x60000000

ifeq ($(TARGET_ARCH),mips)
LIBART_IMG_TARGET_BASE_ADDRESS := 0x30000000
else
LIBART_IMG_TARGET_BASE_ADDRESS := 0x70000000
endif

########################################################################
# The full system boot classpath

# note we use core-libart.jar in place of core.jar for ART.
LIBART_TARGET_BOOT_JARS := $(patsubst core, core-libart,$(DEXPREOPT_BOOT_JARS_MODULES))
LIBART_TARGET_BOOT_DEX_LOCATIONS := $(foreach jar,$(LIBART_TARGET_BOOT_JARS),/$(DEXPREOPT_BOOT_JAR_DIR)/$(jar).jar)
LIBART_TARGET_BOOT_DEX_FILES := $(foreach jar,$(LIBART_TARGET_BOOT_JARS),$(call intermediates-dir-for,JAVA_LIBRARIES,$(jar),,COMMON)/javalib.jar)

# The .oat with symbols
LIBART_TARGET_BOOT_OAT_UNSTRIPPED := $(TARGET_OUT_UNSTRIPPED)$(patsubst %.art,%.oat,$(LIBART_BOOT_IMAGE))

# Use dex2oat debug version for better error reporting
$(DEFAULT_DEX_PREOPT_BUILT_IMAGE): $(LIBART_TARGET_BOOT_DEX_FILES) $(DEX2OATD_DEPENDENCY)
	@echo "target dex2oat: $@ ($?)"
	@mkdir -p $(dir $@)
	@mkdir -p $(dir $(LIBART_TARGET_BOOT_OAT_UNSTRIPPED))
	$(hide) $(DEX2OATD) --runtime-arg -Xms256m --runtime-arg -Xmx256m --image-classes=$(PRELOADED_CLASSES) \
		$(addprefix --dex-file=,$(LIBART_TARGET_BOOT_DEX_FILES)) \
		$(addprefix --dex-location=,$(LIBART_TARGET_BOOT_DEX_LOCATIONS)) \
		--oat-symbols=$(LIBART_TARGET_BOOT_OAT_UNSTRIPPED) \
		--oat-file=$(patsubst %.art,%.oat,$@) \
		--oat-location=$(patsubst %.art,%.oat,$(LIBART_BOOT_IMAGE)) \
		--image=$@ --base=$(LIBART_IMG_TARGET_BASE_ADDRESS) \
		--instruction-set=$(DEX2OAT_TARGET_ARCH) \
		--instruction-set-features=$(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES) \
		--android-root=$(PRODUCT_OUT)/system


########################################################################
# For a single jar or APK

# $(1): the boot image to use
# $(2): the input .jar or .apk file
# $(3): the input .jar or .apk target location
# $(4): the output .odex file
define dex2oat-one-file
$(hide) rm -f $(4)
$(hide) mkdir -p $(dir $(4))
$(hide) $(DEX2OATD) \
	--runtime-arg -Xms64m --runtime-arg -Xmx64m \
	--boot-image=$(1) \
	--dex-file=$(2) \
	--dex-location=$(3) \
	--oat-file=$(4) \
	--android-root=$(PRODUCT_OUT)/system \
	--instruction-set=$(DEX2OAT_TARGET_ARCH) \
	--instruction-set-features=$(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
endef
