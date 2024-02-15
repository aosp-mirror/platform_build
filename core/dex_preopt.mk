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
my_boot_image_arch := TARGET_ARCH
my_boot_image_out := $(PRODUCT_OUT)
my_boot_image_syms := $(TARGET_OUT_UNSTRIPPED)
DEFAULT_DEX_PREOPT_INSTALLED_IMAGE_MODULE := \
  $(foreach my_boot_image_name,$(DEXPREOPT_IMAGE_NAMES),$(strip \
    $(eval include $(BUILD_SYSTEM)/dex_preopt_libart.mk) \
    $(my_boot_image_module)))
ifdef TARGET_2ND_ARCH
  my_boot_image_arch := TARGET_2ND_ARCH
  2ND_DEFAULT_DEX_PREOPT_INSTALLED_IMAGE_MODULE := \
    $(foreach my_boot_image_name,$(DEXPREOPT_IMAGE_NAMES),$(strip \
      $(eval include $(BUILD_SYSTEM)/dex_preopt_libart.mk) \
      $(my_boot_image_module)))
endif
# Install boot images for testing on host. We exclude framework image as it is not part of art manifest.
my_boot_image_arch := HOST_ARCH
my_boot_image_out := $(HOST_OUT)
my_boot_image_syms := $(HOST_OUT)/symbols
HOST_BOOT_IMAGE_MODULE := \
  $(foreach my_boot_image_name,art_host,$(strip \
    $(eval include $(BUILD_SYSTEM)/dex_preopt_libart.mk) \
    $(my_boot_image_module)))
HOST_BOOT_IMAGE := $(call module-installed-files,$(HOST_BOOT_IMAGE_MODULE))
ifdef HOST_2ND_ARCH
  my_boot_image_arch := HOST_2ND_ARCH
  2ND_HOST_BOOT_IMAGE_MODULE := \
    $(foreach my_boot_image_name,art_host,$(strip \
      $(eval include $(BUILD_SYSTEM)/dex_preopt_libart.mk) \
      $(my_boot_image_module)))
  2ND_HOST_BOOT_IMAGE := $(call module-installed-files,$(2ND_HOST_BOOT_IMAGE_MODULE))
endif
my_boot_image_arch :=
my_boot_image_out :=
my_boot_image_syms :=
my_boot_image_module :=

# Build the boot.zip which contains the boot jars and their compilation output
# We can do this only if preopt is enabled and if the product uses libart config (which sets the
# default properties for preopting).
# At the time of writing, this is only for ART Cloud.
ifeq ($(WITH_DEXPREOPT), true)
ifneq ($(WITH_DEXPREOPT_ART_BOOT_IMG_ONLY), true)
ifeq ($(PRODUCT_USES_DEFAULT_ART_CONFIG), true)

boot_zip := $(PRODUCT_OUT)/boot.zip
bootclasspath_jars := $(DEXPREOPT_BOOTCLASSPATH_DEX_FILES)

# TODO remove system_server_jars usages from boot.zip and depend directly on system_server.zip file.

# Use "/system" path for JARs with "platform:" prefix.
# These JARs counterintuitively use "platform" prefix but they will
# be actually installed to /system partition.
platform_system_server_jars = $(filter platform:%, $(PRODUCT_SYSTEM_SERVER_JARS))
system_server_jars := \
  $(foreach m,$(platform_system_server_jars),\
    $(PRODUCT_OUT)/system/framework/$(call word-colon,2,$(m)).jar)

# For the remaining system server JARs use the partition signified by the prefix.
# For example, prefix "system_ext:" will use "/system_ext" path.
other_system_server_jars = $(filter-out $(platform_system_server_jars), $(PRODUCT_SYSTEM_SERVER_JARS))
system_server_jars += \
  $(foreach m,$(other_system_server_jars),\
    $(PRODUCT_OUT)/$(call word-colon,1,$(m))/framework/$(call word-colon,2,$(m)).jar)

# Infix can be 'art' (ART image for testing), 'boot' (primary), or 'mainline' (mainline extension).
# Soong creates a set of variables for Make, one or each boot image. The only reason why the ART
# image is exposed to Make is testing (art gtests) and benchmarking (art golem benchmarks). Install
# rules that use those variables are in dex_preopt_libart.mk. Here for dexpreopt purposes the infix
# is always 'boot' or 'mainline'.
DEXPREOPT_INFIX := $(if $(filter true,$(DEX_PREOPT_WITH_UPDATABLE_BCP)),mainline,boot)

# The input variables are written by build/soong/java/dexpreopt_bootjars.go. Examples can be found
# at the bottom of build/soong/java/dexpreopt_config_testing.go.
dexpreopt_root_dir := $(dir $(patsubst %/,%,$(dir $(firstword $(bootclasspath_jars)))))
bootclasspath_arg := $(subst $(space),:,$(patsubst $(dexpreopt_root_dir)%,%,$(DEXPREOPT_BOOTCLASSPATH_DEX_FILES)))
bootclasspath_locations_arg := $(subst $(space),:,$(DEXPREOPT_BOOTCLASSPATH_DEX_LOCATIONS))
boot_images := $(subst :,$(space),$(DEXPREOPT_IMAGE_LOCATIONS_ON_DEVICE$(DEXPREOPT_INFIX)))
boot_image_arg := $(subst $(space),:,$(patsubst /%,%,$(boot_images)))
uffd_gc_flag_txt := $(OUT_DIR)/soong/dexpreopt/uffd_gc_flag.txt

boot_zip_metadata_txt := $(dir $(boot_zip))boot_zip/METADATA.txt
$(boot_zip_metadata_txt): $(uffd_gc_flag_txt)
$(boot_zip_metadata_txt):
	rm -f $@
	echo "bootclasspath = $(bootclasspath_arg)" >> $@
	echo "bootclasspath-locations = $(bootclasspath_locations_arg)" >> $@
	echo "boot-image = $(boot_image_arg)" >> $@
	echo "extra-args = `cat $(uffd_gc_flag_txt)`" >> $@

$(call dist-for-goals, droidcore, $(boot_zip_metadata_txt))

$(boot_zip): PRIVATE_BOOTCLASSPATH_JARS := $(bootclasspath_jars)
$(boot_zip): PRIVATE_SYSTEM_SERVER_JARS := $(system_server_jars)
$(boot_zip): $(bootclasspath_jars) $(system_server_jars) $(SOONG_ZIP) $(MERGE_ZIPS) $(DEXPREOPT_IMAGE_ZIP_boot) $(DEXPREOPT_IMAGE_ZIP_art) $(DEXPREOPT_IMAGE_ZIP_mainline) $(boot_zip_metadata_txt)
	@echo "Create boot package: $@"
	rm -f $@
	$(SOONG_ZIP) -o $@.tmp \
	  -C $(dir $(firstword $(PRIVATE_BOOTCLASSPATH_JARS)))/.. $(addprefix -f ,$(PRIVATE_BOOTCLASSPATH_JARS)) \
	  -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_SYSTEM_SERVER_JARS)) \
	  -j -f $(boot_zip_metadata_txt)
	$(MERGE_ZIPS) $@ $@.tmp $(DEXPREOPT_IMAGE_ZIP_boot) $(DEXPREOPT_IMAGE_ZIP_art) $(DEXPREOPT_IMAGE_ZIP_mainline)
	rm -f $@.tmp

$(call dist-for-goals, droidcore, $(boot_zip))

ifneq (,$(filter true,$(ART_MODULE_BUILD_FROM_SOURCE) $(MODULE_BUILD_FROM_SOURCE)))
# Build the system_server.zip which contains the Apex system server jars and standalone system server jars
system_server_zip := $(PRODUCT_OUT)/system_server.zip
apex_system_server_jars := \
  $(foreach m,$(PRODUCT_APEX_SYSTEM_SERVER_JARS),\
    $(PRODUCT_OUT)/apex/$(call word-colon,1,$(m))/javalib/$(call word-colon,2,$(m)).jar)

apex_standalone_system_server_jars := \
  $(foreach m,$(PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS),\
    $(PRODUCT_OUT)/apex/$(call word-colon,1,$(m))/javalib/$(call word-colon,2,$(m)).jar)

standalone_system_server_jars := \
  $(foreach m,$(PRODUCT_STANDALONE_SYSTEM_SERVER_JARS),\
    $(PRODUCT_OUT)/apex/$(call word-colon,1,$(m))/javalib/$(call word-colon,2,$(m)).jar)

$(system_server_zip): PRIVATE_SYSTEM_SERVER_JARS := $(system_server_jars)
$(system_server_zip): PRIVATE_APEX_SYSTEM_SERVER_JARS := $(apex_system_server_jars)
$(system_server_zip): PRIVATE_APEX_STANDALONE_SYSTEM_SERVER_JARS := $(apex_standalone_system_server_jars)
$(system_server_zip): PRIVATE_STANDALONE_SYSTEM_SERVER_JARS := $(standalone_system_server_jars)
$(system_server_zip): $(system_server_jars) $(apex_system_server_jars) $(apex_standalone_system_server_jars) $(standalone_system_server_jars) $(SOONG_ZIP)
	@echo "Create system server package: $@"
	rm -f $@
	$(SOONG_ZIP) -o $@ \
	  -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_SYSTEM_SERVER_JARS)) \
	  -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_APEX_SYSTEM_SERVER_JARS)) \
          -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_APEX_STANDALONE_SYSTEM_SERVER_JARS)) \
	  -C $(PRODUCT_OUT) $(addprefix -f ,$(PRIVATE_STANDALONE_SYSTEM_SERVER_JARS))

$(call dist-for-goals, droidcore, $(system_server_zip))

endif  #ART_MODULE_BUILD_FROM_SOURCE || MODULE_BUILD_FROM_SOURCE
endif  #PRODUCT_USES_DEFAULT_ART_CONFIG
endif  #WITH_DEXPREOPT_ART_BOOT_IMG_ONLY
endif  #WITH_DEXPREOPT
