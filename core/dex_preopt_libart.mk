####################################
# dexpreopt support for ART
#
####################################

# Default to debug version to help find bugs.
# Set USE_DEX2OAT_DEBUG to false for only building non-debug versions.
ifeq ($(USE_DEX2OAT_DEBUG),false)
DEX2OAT := $(HOST_OUT_EXECUTABLES)/dex2oat$(HOST_EXECUTABLE_SUFFIX)
PATCHOAT := $(HOST_OUT_EXECUTABLES)/patchoat$(HOST_EXECUTABLE_SUFFIX)
else
DEX2OAT := $(HOST_OUT_EXECUTABLES)/dex2oatd$(HOST_EXECUTABLE_SUFFIX)
PATCHOAT := $(HOST_OUT_EXECUTABLES)/patchoatd$(HOST_EXECUTABLE_SUFFIX)
endif

DEX2OAT_DEPENDENCY += $(DEX2OAT)
PATCHOAT_DEPENDENCY += $(PATCHOAT)

# Use the first preloaded-classes file in PRODUCT_COPY_FILES.
PRELOADED_CLASSES := $(call word-colon,1,$(firstword \
    $(filter %system/etc/preloaded-classes,$(PRODUCT_COPY_FILES))))

# Use the first compiled-classes file in PRODUCT_COPY_FILES.
COMPILED_CLASSES := $(call word-colon,1,$(firstword \
    $(filter %system/etc/compiled-classes,$(PRODUCT_COPY_FILES))))

# Use the first dirty-image-objects file in PRODUCT_COPY_FILES.
DIRTY_IMAGE_OBJECTS := $(call word-colon,1,$(firstword \
    $(filter %system/etc/dirty-image-objects,$(PRODUCT_COPY_FILES))))

define get-product-default-property
$(strip \
  $(eval _prop := $(patsubst $(1)=%,%,$(filter $(1)=%,$(PRODUCT_DEFAULT_PROPERTY_OVERRIDES))))\
  $(if $(_prop),$(_prop),$(patsubst $(1)=%,%,$(filter $(1)=%,$(PRODUCT_SYSTEM_DEFAULT_PROPERTIES)))))
endef

DEX2OAT_IMAGE_XMS := $(call get-product-default-property,dalvik.vm.image-dex2oat-Xms)
DEX2OAT_IMAGE_XMX := $(call get-product-default-property,dalvik.vm.image-dex2oat-Xmx)
DEX2OAT_XMS := $(call get-product-default-property,dalvik.vm.dex2oat-Xms)
DEX2OAT_XMX := $(call get-product-default-property,dalvik.vm.dex2oat-Xmx)

ifeq ($(TARGET_ARCH),$(filter $(TARGET_ARCH),mips mips64))
# MIPS specific overrides.
# For MIPS the ART image is loaded at a lower address. This causes issues
# with the image overlapping with memory on the host cross-compiling and
# building the image. We therefore limit the Xmx value. This isn't done
# via a property as we want the larger Xmx value if we're running on a
# MIPS device.
DEX2OAT_XMX := 128m
endif

########################################################################
# The full system boot classpath

# Returns the path to the .odex file
# $(1): the arch name.
# $(2): the full path (including file name) of the corresponding .jar or .apk.
define get-odex-file-path
$(dir $(2))oat/$(1)/$(basename $(notdir $(2))).odex
endef

# Returns the full path to the installed .odex file.
# This handles BOARD_USES_SYSTEM_OTHER_ODEX to install odex files into another
# partition.
# $(1): the arch name.
# $(2): the full install path (including file name) of the corresponding .apk.
ifeq ($(BOARD_USES_SYSTEM_OTHER_ODEX),true)
define get-odex-installed-file-path
$(if $(call install-on-system-other, $(2)),
  $(call get-odex-file-path,$(1),$(patsubst $(TARGET_OUT)/%,$(TARGET_OUT_SYSTEM_OTHER)/%,$(2))),
  $(call get-odex-file-path,$(1),$(2)))
endef
else
get-odex-installed-file-path = $(get-odex-file-path)
endif

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

# dex preopt on the bootclasspath produces multiple files.  The first dex file
# is converted into to boot.art (to match the legacy assumption that boot.art
# exists), and the rest are converted to boot-<name>.art.
# In addition, each .art file has an associated .oat file.
LIBART_TARGET_BOOT_ART_EXTRA_FILES := $(foreach jar,$(wordlist 2,999,$(LIBART_TARGET_BOOT_JARS)),boot-$(jar).art boot-$(jar).art.rel boot-$(jar).oat)
LIBART_TARGET_BOOT_ART_EXTRA_FILES += boot.art.rel boot.oat
LIBART_TARGET_BOOT_ART_VDEX_FILES := $(foreach jar,$(wordlist 2,999,$(LIBART_TARGET_BOOT_JARS)),boot-$(jar).vdex)
LIBART_TARGET_BOOT_ART_VDEX_FILES += boot.vdex

# If we use a boot image profile.
my_use_profile_for_boot_image := $(PRODUCT_USE_PROFILE_FOR_BOOT_IMAGE)
ifeq (,$(my_use_profile_for_boot_image))
# If not set, set the default to true if we are not a PDK build. PDK builds
# can't build the profile since they don't have frameworks/base.
ifneq (true,$(TARGET_BUILD_PDK))
my_use_profile_for_boot_image := true
endif
endif

ifeq (true,$(my_use_profile_for_boot_image))

# Location of text based profile for the boot image.
my_boot_image_profile_location := $(PRODUCT_DEX_PREOPT_BOOT_IMAGE_PROFILE_LOCATION)
ifeq (,$(my_boot_image_profile_location))
# If not set, use the default.
my_boot_image_profile_location := frameworks/base/config/boot-image-profile.txt
endif

# Code to create the boot image profile, not in dex_preopt_libart_boot.mk since the profile is the same for all archs.
my_out_boot_image_profile_location := $(DEXPREOPT_BOOT_JAR_DIR_FULL_PATH)/boot.prof
$(my_out_boot_image_profile_location): PRIVATE_PROFILE_INPUT_LOCATION := $(my_boot_image_profile_location)
$(my_out_boot_image_profile_location): $(PROFMAN) $(LIBART_TARGET_BOOT_DEX_FILES) $(my_boot_image_profile_location)
	@echo "target profman: $@"
	@mkdir -p $(dir $@)
	ANDROID_LOG_TAGS="*:e" $(PROFMAN) \
		--create-profile-from=$(PRIVATE_PROFILE_INPUT_LOCATION) \
		$(addprefix --apk=,$(LIBART_TARGET_BOOT_DEX_FILES)) \
		$(addprefix --dex-location=,$(LIBART_TARGET_BOOT_DEX_LOCATIONS)) \
		--reference-profile-file=$@

# We want to install the profile even if we are not using preopt since it is required to generate
# the image on the device.
my_installed_profile := $(TARGET_OUT)/etc/boot-image.prof
$(eval $(call copy-one-file,$(my_out_boot_image_profile_location),$(my_installed_profile)))
ALL_DEFAULT_INSTALLED_MODULES += $(my_installed_profile)

endif

LIBART_TARGET_BOOT_ART_VDEX_INSTALLED_SHARED_FILES := $(addprefix $(PRODUCT_OUT)/$(DEXPREOPT_BOOT_JAR_DIR)/,$(LIBART_TARGET_BOOT_ART_VDEX_FILES))

my_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/dex_preopt_libart_boot.mk

ifneq ($(TARGET_TRANSLATE_2ND_ARCH),true)
ifdef TARGET_2ND_ARCH
my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
include $(BUILD_SYSTEM)/dex_preopt_libart_boot.mk
endif
endif

# Copy shared vdex to the directory and create corresponding symlinks in primary and secondary arch.
$(LIBART_TARGET_BOOT_ART_VDEX_INSTALLED_SHARED_FILES) : PRIMARY_ARCH_DIR := $(dir $(DEFAULT_DEX_PREOPT_INSTALLED_IMAGE))
$(LIBART_TARGET_BOOT_ART_VDEX_INSTALLED_SHARED_FILES) : SECOND_ARCH_DIR := $(dir $($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE))
$(LIBART_TARGET_BOOT_ART_VDEX_INSTALLED_SHARED_FILES) : $(DEFAULT_DEX_PREOPT_BUILT_IMAGE_FILENAME)
	@echo "Install: $@"
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) cp "$(dir $<)$(notdir $@)" "$@"
	# Make symlink for both the archs. In the case its single arch the symlink will just get overridden.
	@mkdir -p $(PRIMARY_ARCH_DIR)
	$(hide) ln -sf /$(DEXPREOPT_BOOT_JAR_DIR)/$(notdir $@) $(PRIMARY_ARCH_DIR)$(notdir $@)
	@mkdir -p $(SECOND_ARCH_DIR)
	$(hide) ln -sf /$(DEXPREOPT_BOOT_JAR_DIR)/$(notdir $@) $(SECOND_ARCH_DIR)$(notdir $@)

my_2nd_arch_prefix :=

########################################################################
# For a single jar or APK

# $(1): the input .jar or .apk file
# $(2): the output .odex file
# In the case where LOCAL_ENFORCE_USES_LIBRARIES is true, PRIVATE_DEX2OAT_CLASS_LOADER_CONTEXT
# contains the normalized path list of the libraries. This makes it easier to conditionally prepend
# org.apache.http.legacy.boot based on the SDK level if required.
define dex2oat-one-file
$(hide) rm -f $(2)
$(hide) mkdir -p $(dir $(2))
stored_class_loader_context_libs=$(PRIVATE_DEX2OAT_STORED_CLASS_LOADER_CONTEXT_LIBS) && \
class_loader_context_arg=--class-loader-context=$(PRIVATE_DEX2OAT_CLASS_LOADER_CONTEXT) && \
class_loader_context=$(PRIVATE_DEX2OAT_CLASS_LOADER_CONTEXT) && \
stored_class_loader_context_arg="" && \
uses_library_names="$(PRIVATE_USES_LIBRARY_NAMES)" && \
optional_uses_library_names="$(PRIVATE_OPTIONAL_USES_LIBRARY_NAMES)" && \
$(if $(PRIVATE_ENFORCE_USES_LIBRARIES), \
source build/make/core/verify_uses_libraries.sh "$(1)" && \
source build/make/core/construct_context.sh "$(PRIVATE_CONDITIONAL_USES_LIBRARIES_HOST)" "$(PRIVATE_CONDITIONAL_USES_LIBRARIES_TARGET)" && \
,) \
ANDROID_LOG_TAGS="*:e" $(DEX2OAT) \
	--runtime-arg -Xms$(DEX2OAT_XMS) --runtime-arg -Xmx$(DEX2OAT_XMX) \
	$${class_loader_context_arg} \
	$${stored_class_loader_context_arg} \
	--boot-image=$(PRIVATE_DEX_PREOPT_IMAGE_LOCATION) \
	--dex-file=$(1) \
	--dex-location=$(PRIVATE_DEX_LOCATION) \
	--oat-file=$(2) \
	--android-root=$(PRODUCT_OUT)/system \
	--instruction-set=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_ARCH) \
	--instruction-set-variant=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT) \
	--instruction-set-features=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES) \
	--runtime-arg -Xnorelocate --compile-pic \
	--no-generate-debug-info --generate-build-id \
	--abort-on-hard-verifier-error \
	--force-determinism \
	--no-inline-from=core-oj.jar \
	$(PRIVATE_DEX_PREOPT_FLAGS) \
	$(PRIVATE_ART_FILE_PREOPT_FLAGS) \
	$(PRIVATE_PROFILE_PREOPT_FLAGS) \
	$(GLOBAL_DEXPREOPT_FLAGS)
endef
