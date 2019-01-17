####################################
# dexpreopt support for ART
#
####################################

########################################################################
# The full system boot classpath

LIBART_TARGET_BOOT_JARS := $(DEXPREOPT_BOOT_JARS_MODULES)
LIBART_TARGET_BOOT_DEX_LOCATIONS := $(DEXPREOPT_BOOTCLASSPATH_DEX_LOCATIONS)
LIBART_TARGET_BOOT_DEX_FILES := $(foreach mod,$(NON_UPDATABLE_BOOT_MODULES),$(call intermediates-dir-for,JAVA_LIBRARIES,$(mod),,COMMON)/javalib.jar)

# dex preopt on the bootclasspath produces multiple files.  The first dex file
# is converted into to boot.art (to match the legacy assumption that boot.art
# exists), and the rest are converted to boot-<name>.art.
# In addition, each .art file has an associated .oat file.
LIBART_TARGET_BOOT_ART_EXTRA_FILES := $(foreach jar,$(wordlist 2,999,$(LIBART_TARGET_BOOT_JARS)),boot-$(jar).art boot-$(jar).oat)
LIBART_TARGET_BOOT_ART_EXTRA_FILES += boot.oat
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
ifeq (,$(strip $(LIBART_TARGET_BOOT_DEX_FILES)))
my_use_profile_for_boot_image := false
endif

ifeq (true,$(my_use_profile_for_boot_image))

boot_image_profiles := $(PRODUCT_DEX_PREOPT_BOOT_IMAGE_PROFILE_LOCATION)

ifeq (,$(boot_image_profiles))
# If not set, use the default.
boot_image_profiles := frameworks/base/config/boot-image-profile.txt
endif

# Location of text based profile for the boot image.
my_boot_image_profile_location := $(PRODUCT_OUT)/dex_bootjars/boot-image-profile.txt

$(my_boot_image_profile_location): $(boot_image_profiles)
	@echo 'Generating $@ for profman'
	@rm -rf $@
	$(hide) cat $^ > $@

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
