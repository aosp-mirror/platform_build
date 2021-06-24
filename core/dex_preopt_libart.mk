####################################
# ART boot image installation
# Input variables:
#   my_boot_image_name: the boot image to install
#   my_boot_image_arch: the architecture to install (e.g. TARGET_ARCH, not expanded)
#   my_boot_image_out:  the install directory (e.g. $(PRODUCT_OUT))
#   my_boot_image_syms: the symbols director (e.g. $(TARGET_OUT_UNSTRIPPED))
#
# Output variables:
#   my_boot_image_module: the created module name. Empty if no module is created.
#
# Install the boot images compiled by Soong.
# Create a module named dexpreopt_bootjar.$(my_boot_image_name)_$($(my_boot_image_arch))
# that installs all of boot image files.
# If there is no file to install for $(my_boot_image_name), for example when
# building an unbundled build, then no module is created.
#
####################################

# Install $(1) to $(2) so that it is shared between architectures.
# Returns the target path of the shared vdex file and installed symlink.
define copy-vdex-file
$(strip \
  $(eval # Remove the arch dir) \
  $(eval my_vdex_shared := $(dir $(patsubst %/,%,$(dir $(2))))$(notdir $(2))) \
  $(if $(filter-out %_2ND_ARCH,$(my_boot_image_arch)), \
    $(eval # Copy $(1) to directory one level up (i.e. with the arch dir removed).) \
    $(eval $(call copy-one-file,$(1),$(my_vdex_shared))) \
  ) \
  $(eval # Create symlink at $(2) which points to the actual physical copy.) \
  $(call symlink-file,$(my_vdex_shared),../$(notdir $(2)),$(2)) \
  $(my_vdex_shared) $(2) \
)
endef

# Same as 'copy-many-files' but it uses the vdex-specific helper above.
define copy-vdex-files
$(foreach v,$(1),$(call copy-vdex-file,$(call word-colon,1,$(v)),$(2)$(call word-colon,2,$(v))))
endef

my_boot_image_module :=

my_suffix := $(my_boot_image_name)_$($(my_boot_image_arch))
my_copy_pairs := $(strip $(DEXPREOPT_IMAGE_BUILT_INSTALLED_$(my_suffix)))

# Generate the boot image module only if there is any file to install.
ifneq (,$(my_copy_pairs))
  my_first_pair := $(firstword $(my_copy_pairs))
  my_rest_pairs := $(wordlist 2,$(words $(my_copy_pairs)),$(my_copy_pairs))

  my_first_src := $(call word-colon,1,$(my_first_pair))
  my_first_dest := $(my_boot_image_out)$(call word-colon,2,$(my_first_pair))

  my_installed := $(call copy-many-files,$(my_rest_pairs),$(my_boot_image_out))
  my_installed += $(call copy-vdex-files,$(DEXPREOPT_IMAGE_VDEX_BUILT_INSTALLED_$(my_suffix)),$(my_boot_image_out))
  my_unstripped_installed := $(call copy-many-files,$(DEXPREOPT_IMAGE_UNSTRIPPED_BUILT_INSTALLED_$(my_suffix)),$(my_boot_image_syms))

  # We don't have a LOCAL_PATH for the auto-generated modules, so let it be the $(BUILD_SYSTEM).
  LOCAL_PATH := $(BUILD_SYSTEM)

  include $(CLEAR_VARS)
  LOCAL_MODULE := dexpreopt_bootjar.$(my_suffix)
  LOCAL_PREBUILT_MODULE_FILE := $(my_first_src)
  LOCAL_MODULE_PATH := $(dir $(my_first_dest))
  LOCAL_MODULE_STEM := $(notdir $(my_first_dest))
  ifneq (,$(strip $(filter HOST_%,$(my_boot_image_arch))))
    LOCAL_IS_HOST_MODULE := true
  endif
  LOCAL_MODULE_CLASS := ETC
  include $(BUILD_PREBUILT)
  $(LOCAL_BUILT_MODULE): | $(my_unstripped_installed)
  # Installing boot.art causes all boot image bits to be installed.
  # Keep this old behavior in case anyone still needs it.
  $(LOCAL_INSTALLED_MODULE): $(my_installed)
  ALL_MODULES.$(my_register_name).INSTALLED += $(my_installed)
  $(my_all_targets): $(my_installed)

  my_boot_image_module := $(LOCAL_MODULE)
endif  # my_copy_pairs != empty
