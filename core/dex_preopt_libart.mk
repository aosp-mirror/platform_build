####################################
# ART boot image installation
# Input variable:
#   my_boot_image_name: the boot image to install
#
####################################

# Install primary arch vdex files into a shared location, and then symlink them to both the primary
# and secondary arch directories.
my_vdex_copy_pairs := $(DEXPREOPT_IMAGE_VDEX_BUILT_INSTALLED_$(my_boot_image_name)_$(TARGET_ARCH))
my_installed := $(foreach v,$(my_vdex_copy_pairs),$(PRODUCT_OUT)$(call word-colon,2,$(v)))
$(firstword $(my_installed)): $(wordlist 2,9999,$(my_installed))

my_built_vdex_dir := $(dir $(call word-colon,1,$(firstword $(my_vdex_copy_pairs))))
my_installed_vdex_dir := $(PRODUCT_OUT)$(dir $(call word-colon,2,$(firstword $(my_vdex_copy_pairs))))

$(my_installed): $(my_installed_vdex_dir)% : $(my_built_vdex_dir)%
	@echo "Install: $@"
	@rm -f $@
	$(copy-file-to-target)
	mkdir -p $(dir $@)/$(TARGET_ARCH)
	ln -sfn ../$(notdir $@) $(dir $@)/$(TARGET_ARCH)
ifdef TARGET_2ND_ARCH
  ifneq ($(TARGET_TRANSLATE_2ND_ARCH),true)
	mkdir -p $(dir $@)/$(TARGET_2ND_ARCH)
	ln -sfn ../$(notdir $@) $(dir $@)/$(TARGET_2ND_ARCH)
  endif
endif

my_dexpreopt_image_extra_deps := $(firstword $(my_installed))

my_2nd_arch_prefix :=
include $(BUILD_SYSTEM)/dex_preopt_libart_boot.mk

ifdef TARGET_2ND_ARCH
  ifneq ($(TARGET_TRANSLATE_2ND_ARCH),true)
    my_2nd_arch_prefix := $(TARGET_2ND_ARCH_VAR_PREFIX)
    include $(BUILD_SYSTEM)/dex_preopt_libart_boot.mk
  endif
endif

my_2nd_arch_prefix :=


my_vdex_copy_pairs :=
my_installed :=
my_built_vdex_dir :=
my_installed_vdex_dir :=
my_dexpreopt_image_extra_deps :=
