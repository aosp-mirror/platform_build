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

include $(BUILD_SYSTEM)/dex_preopt_libart.mk

ifeq ($(PRODUCT_DIST_BOOT_AND_SYSTEM_JARS),true)
boot_profile_jars_zip := $(PRODUCT_OUT)/boot_profile_jars.zip
all_boot_jars := \
  $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES) \
  $(foreach m,$(PRODUCT_SYSTEM_SERVER_JARS),$(PRODUCT_OUT)/system/framework/$(m).jar)

$(boot_profile_jars_zip): PRIVATE_JARS := $(all_boot_jars)
$(boot_profile_jars_zip): $(all_boot_jars) $(SOONG_ZIP)
	echo "Create boot profiles package: $@"
	rm -f $@
	$(SOONG_ZIP) -o $@ -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_JARS))

droidcore: $(boot_profile_jars_zip)

$(call dist-for-goals, droidcore, $(boot_profile_jars_zip))
endif
