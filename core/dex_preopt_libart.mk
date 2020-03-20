####################################
# ART boot image installation
# Input variables:
#   my_boot_image_name: the boot image to install
#   my_boot_image_arch: the architecture to install (e.g. TARGET_ARCH, not expanded)
#   my_boot_image_out:  the install directory (e.g. $(PRODUCT_OUT))
#   my_boot_image_syms: the symbols director (e.g. $(TARGET_OUT_UNSTRIPPED))
#   my_boot_image_root: make variable used to store installed image path
#
####################################

# Install $(1) to $(2) so that it is shared between architectures.
define copy-vdex-file
my_vdex_shared := $$(dir $$(patsubst %/,%,$$(dir $(2))))$$(notdir $(2))  # Remove the arch dir.
ifneq ($(my_boot_image_arch),$(filter $(my_boot_image_arch), TARGET_2ND_ARCH HOST_2ND_ARCH))
$$(my_vdex_shared): $(1)  # Copy $(1) to directory one level up (i.e. with the arch dir removed).
	@echo "Install: $$@"
	$$(copy-file-to-target)
endif
$(2): $$(my_vdex_shared)  # Create symlink at $(2) which points to the actual physical copy.
	@echo "Symlink: $$@"
	mkdir -p $$(dir $$@)
	ln -sfn ../$$(notdir $$@) $$@
my_vdex_shared :=
endef

# Same as 'copy-many-files' but it uses the vdex-specific helper above.
define copy-vdex-files
$(foreach v,$(1),$(eval $(call copy-vdex-file, $(call word-colon,1,$(v)), $(2)$(call word-colon,2,$(v)))))
$(foreach v,$(1),$(2)$(call word-colon,2,$(v)))
endef

# Install the boot images compiled by Soong.
# The first file is saved in $(my_boot_image_root) and the rest are added as it's dependencies.
my_suffix := BUILT_INSTALLED_$(my_boot_image_name)_$($(my_boot_image_arch))
my_installed := $(call copy-many-files,$(DEXPREOPT_IMAGE_$(my_suffix)),$(my_boot_image_out))
my_installed += $(call copy-many-files,$(DEXPREOPT_IMAGE_UNSTRIPPED_$(my_suffix)),$(my_boot_image_syms))
my_installed += $(call copy-vdex-files,$(DEXPREOPT_IMAGE_VDEX_$(my_suffix)),$(my_boot_image_out))
$(my_boot_image_root) += $(firstword $(my_installed))
$(firstword $(my_installed)): $(wordlist 2,9999,$(my_installed))
my_installed :=
my_suffix :=
