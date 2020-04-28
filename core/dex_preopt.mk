####################################
# dexpreopt support - typically used on user builds to run dexopt (for Dalvik) or dex2oat (for ART) ahead of time
#
####################################

include $(BUILD_SYSTEM)/dex_preopt_config.mk

# Method returning whether the install path $(1) should be for system_other.
# Under SANITIZE_LITE, we do not want system_other. Just put things under /data/asan.
ifeq ($(SANITIZE_LITE),true)
install-on-system-other =
else
install-on-system-other = $(filter-out $(PRODUCT_DEXPREOPT_SPEED_APPS) $(PRODUCT_SYSTEM_SERVER_APPS),$(basename $(notdir $(filter $(foreach f,$(SYSTEM_OTHER_ODEX_FILTER),$(TARGET_OUT)/$(f)),$(1)))))
endif

# We want to install the profile even if we are not using preopt since it is required to generate
# the image on the device.
ALL_DEFAULT_INSTALLED_MODULES += $(call copy-many-files,$(DEXPREOPT_IMAGE_PROFILE_BUILT_INSTALLED),$(PRODUCT_OUT))

# Install boot images. Note that there can be multiple.
DEFAULT_DEX_PREOPT_INSTALLED_IMAGE :=
$(TARGET_2ND_ARCH_VAR_PREFIX)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE :=
$(foreach my_boot_image_name,$(DEXPREOPT_IMAGE_NAMES),$(eval include $(BUILD_SYSTEM)/dex_preopt_libart.mk))

# Build the boot.zip which contains the boot jars and their compilation output
# We can do this only if preopt is enabled and if the product uses libart config (which sets the
# default properties for preopting).
ifeq ($(WITH_DEXPREOPT), true)
ifeq ($(PRODUCT_USES_ART), true)

boot_zip := $(PRODUCT_OUT)/boot.zip
bootclasspath_jars := $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES)
system_server_jars := $(foreach m,$(PRODUCT_SYSTEM_SERVER_JARS),$(PRODUCT_OUT)/system/framework/$(m).jar)

$(boot_zip): PRIVATE_BOOTCLASSPATH_JARS := $(bootclasspath_jars)
$(boot_zip): PRIVATE_SYSTEM_SERVER_JARS := $(system_server_jars)
$(boot_zip): $(bootclasspath_jars) $(system_server_jars) $(SOONG_ZIP) $(MERGE_ZIPS) $(DEXPREOPT_IMAGE_ZIP_boot)
	@echo "Create boot package: $@"
	rm -f $@
	$(SOONG_ZIP) -o $@.tmp \
	  -C $(dir $(firstword $(PRIVATE_BOOTCLASSPATH_JARS)))/.. $(addprefix -f ,$(PRIVATE_BOOTCLASSPATH_JARS)) \
	  -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_SYSTEM_SERVER_JARS))
	$(MERGE_ZIPS) $@ $@.tmp $(DEXPREOPT_IMAGE_ZIP_boot)
	rm -f $@.tmp

$(call dist-for-goals, droidcore, $(boot_zip))

endif  #PRODUCT_USES_ART
endif  #WITH_DEXPREOPT
