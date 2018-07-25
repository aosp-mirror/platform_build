#############################################################
## Set up my_pack_module_relocations
## Input variables:
##   DISABLE_RELOCATION_PACKER,
##   LOCAL_PACK_MODULE_RELOCATIONS*,
##   *TARGET_PACK_MODULE_RELOCATIONS,
##   LOCAL_MODULE_CLASS, HOST_OS
##   LOCAL_IS_HOST_MODULE
## Output variables:
##   my_pack_module_relocations, if false skip relocation_packer
#############################################################

my_pack_module_relocations := false
ifneq ($(DISABLE_RELOCATION_PACKER),true)
  my_pack_module_relocations := $(firstword \
    $(LOCAL_PACK_MODULE_RELOCATIONS_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) \
    $(LOCAL_PACK_MODULE_RELOCATIONS))
endif

ifeq ($(my_pack_module_relocations),)
  my_pack_module_relocations := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_PACK_MODULE_RELOCATIONS)
endif

# Do not pack relocations for executables. Because packing results in
# non-zero p_vaddr which causes kernel to load executables to lower
# address (starting at 0x8000) http://b/20665974
ifeq ($(filter SHARED_LIBRARIES,$(LOCAL_MODULE_CLASS)),)
  my_pack_module_relocations := false
endif

ifdef LOCAL_IS_HOST_MODULE
  # Do not pack relocations on host modules
  my_pack_module_relocations := false
endif
