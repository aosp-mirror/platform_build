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

# Install boot images. Note that there can be multiple.
DEFAULT_DEX_PREOPT_INSTALLED_IMAGE :=
$(TARGET_2ND_ARCH_VAR_PREFIX)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE :=
$(foreach my_boot_image_name,$(DEXPREOPT_IMAGE_NAMES),$(eval include $(BUILD_SYSTEM)/dex_preopt_libart.mk))

boot_profile_jars_zip := $(PRODUCT_OUT)/boot_profile_jars.zip
bootclasspath_jars := $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES)
system_server_jars := $(foreach m,$(PRODUCT_SYSTEM_SERVER_JARS),$(PRODUCT_OUT)/system/framework/$(m).jar)

$(boot_profile_jars_zip): PRIVATE_BOOTCLASSPATH_JARS := $(bootclasspath_jars)
$(boot_profile_jars_zip): PRIVATE_SYSTEM_SERVER_JARS := $(system_server_jars)
$(boot_profile_jars_zip): $(bootclasspath_jars) $(system_server_jars) $(SOONG_ZIP)
	@echo "Create boot profiles package: $@"
	rm -f $@
	$(SOONG_ZIP) -o $@ \
	  -C $(dir $(firstword $(PRIVATE_BOOTCLASSPATH_JARS)))/.. $(addprefix -f ,$(PRIVATE_BOOTCLASSPATH_JARS)) \
	  -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_SYSTEM_SERVER_JARS))

ifeq ($(PRODUCT_DIST_BOOT_AND_SYSTEM_JARS),true)
$(call dist-for-goals, droidcore, $(boot_profile_jars_zip))
endif
