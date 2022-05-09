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

# Takes a list of src:dest install pairs and returns a new list with a path
# prefixed to each dest value.
# $(1): list of src:dest install pairs
# $(2): path to prefix to each dest value
define prefix-copy-many-files-dest
$(foreach v,$(1),$(call word-colon,1,$(v)):$(2)$(call word-colon,2,$(v)))
endef

# Converts an architecture-specific vdex path into a location that can be shared
# between architectures.
define vdex-shared-install-path
$(dir $(patsubst %/,%,$(dir $(1))))$(notdir $(1))
endef

# Takes a list of src:dest install pairs of vdex files and returns a new list
# where each dest has been rewritten to the shared location for vdex files.
define vdex-copy-many-files-shared-dest
$(foreach v,$(1),$(call word-colon,1,$(v)):$(call vdex-shared-install-path,$(call word-colon,2,$(v))))
endef

# Creates a rule to symlink an architecture specific vdex file to the shared
# location for that vdex file.
define symlink-vdex-file
$(strip \
  $(call symlink-file,\
    $(call vdex-shared-install-path,$(1)),\
    ../$(notdir $(1)),\
    $(1))\
  $(1))
endef

# Takes a list of src:dest install pairs of vdex files and creates rules to
# symlink each dest to the shared location for that vdex file.
define symlink-vdex-files
$(foreach v,$(1),$(call symlink-vdex-file,$(call word-colon,2,$(v))))
endef

my_boot_image_module :=

my_suffix := $(my_boot_image_name)_$($(my_boot_image_arch))
my_copy_pairs := $(call prefix-copy-many-files-dest,$(DEXPREOPT_IMAGE_BUILT_INSTALLED_$(my_suffix)),$(my_boot_image_out))
my_vdex_copy_pairs := $(call prefix-copy-many-files-dest,$(DEXPREOPT_IMAGE_VDEX_BUILT_INSTALLED_$(my_suffix)),$(my_boot_image_out))
my_vdex_copy_shared_pairs := $(call vdex-copy-many-files-shared-dest,$(my_vdex_copy_pairs))
ifeq (,$(filter %_2ND_ARCH,$(my_boot_image_arch)))
  # Only install the vdex to the shared location for the primary architecture.
  my_copy_pairs += $(my_vdex_copy_shared_pairs)
endif

my_unstripped_copy_pairs := $(call prefix-copy-many-files-dest,$(DEXPREOPT_IMAGE_UNSTRIPPED_BUILT_INSTALLED_$(my_suffix)),$(my_boot_image_syms))

# Generate the boot image module only if there is any file to install.
ifneq (,$(strip $(my_copy_pairs)))
  my_first_pair := $(firstword $(my_copy_pairs))
  my_rest_pairs := $(wordlist 2,$(words $(my_copy_pairs)),$(my_copy_pairs))

  my_first_src := $(call word-colon,1,$(my_first_pair))
  my_first_dest := $(call word-colon,2,$(my_first_pair))

  my_installed := $(call copy-many-files,$(my_copy_pairs))
  my_unstripped_installed := $(call copy-many-files,$(my_unstripped_copy_pairs))

  my_symlinks := $(call symlink-vdex-files,$(my_vdex_copy_pairs))

  # We don't have a LOCAL_PATH for the auto-generated modules, so let it be the $(BUILD_SYSTEM).
  LOCAL_PATH := $(BUILD_SYSTEM)
  # Hack to let these pseudo-modules wrapped around Soong modules use LOCAL_SOONG_INSTALLED_MODULE.
  LOCAL_MODULE_MAKEFILE := $(SOONG_ANDROID_MK)

  include $(CLEAR_VARS)
  LOCAL_MODULE := dexpreopt_bootjar.$(my_suffix)
  LOCAL_PREBUILT_MODULE_FILE := $(my_first_src)
  LOCAL_MODULE_PATH := $(dir $(my_first_dest))
  LOCAL_MODULE_STEM := $(notdir $(my_first_dest))
  LOCAL_SOONG_INSTALL_PAIRS := $(my_copy_pairs)
  LOCAL_SOONG_INSTALL_SYMLINKS := $(my_symlinks)
  LOCAL_SOONG_INSTALLED_MODULE := $(my_first_dest)
  LOCAL_SOONG_LICENSE_METADATA := $(DEXPREOPT_IMAGE_LICENSE_METADATA_$(my_suffix))
  ifneq (,$(strip $(filter HOST_%,$(my_boot_image_arch))))
    LOCAL_IS_HOST_MODULE := true
  endif
  LOCAL_MODULE_CLASS := ETC
  include $(BUILD_PREBUILT)
  $(LOCAL_BUILT_MODULE): | $(my_unstripped_installed)
  # Installing boot.art causes all boot image bits to be installed.
  # Keep this old behavior in case anyone still needs it.
  $(LOCAL_INSTALLED_MODULE): $(wordlist 2,$(words $(my_installed)),$(my_installed)) $(my_symlinks)
  $(my_all_targets): $(my_installed) $(my_symlinks)

  my_boot_image_module := $(LOCAL_MODULE)
endif  # my_copy_pairs != empty
