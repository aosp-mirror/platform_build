# Rules to install a boot image built by dexpreopt_bootjars.go
# Input variables:
#   my_boot_image_name: the boot image to install
#   my_2nd_arch_prefix: indicates if this is to build for the 2nd arch.
#   my_dexpreopt_image_extra_deps: extra dependencies to add on the installed boot.art

# Install the boot images compiled by Soong
# The first file (generally boot.art) is saved as DEFAULT_DEX_PREOPT_INSTALLED_IMAGE,
# and the rest are added as dependencies of the first.

my_installed := $(call copy-many-files,$(DEXPREOPT_IMAGE_BUILT_INSTALLED_$(my_boot_image_name)_$(TARGET_$(my_2nd_arch_prefix)ARCH)),$(PRODUCT_OUT))
$(firstword $(my_installed)): $(wordlist 2,9999,$(my_installed))
$(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE += $(firstword $(my_installed))

# Install the unstripped boot images compiled by Soong into the symbols directory
# The first file (generally boot.art) made a dependency of DEFAULT_DEX_PREOPT_INSTALLED_IMAGE,
# and the rest are added as dependencies of the first.
my_installed := $(call copy-many-files,$(DEXPREOPT_IMAGE_UNSTRIPPED_BUILT_INSTALLED_$(my_boot_image_name)_$(TARGET_$(my_2nd_arch_prefix)ARCH)),$(TARGET_OUT_UNSTRIPPED))
$(firstword $(my_installed)): $(wordlist 2,9999,$(my_installed))
$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE): $(firstword $(my_installed))

$($(my_2nd_arch_prefix)DEFAULT_DEX_PREOPT_INSTALLED_IMAGE): $(my_dexpreopt_image_extra_deps)

my_installed :=
my_built_installed :=
