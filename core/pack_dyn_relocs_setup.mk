#############################################################
## Set up my_pack_module_relocations
## Input variables:
##   DISABLE_RELOCATION_PACKER,
##   LOCAL_PACK_MODULE_RELOCATIONS*,
##   *TARGET_PACK_MODULE_RELOCATIONS,
##   LOCAL_MODULE_CLASS, HOST_OS
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
ifneq ($(filter EXECUTABLES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
  my_pack_module_relocations := false
endif

# TODO (dimitry): Relocation packer is not yet available for darwin
ifneq ($(HOST_OS),linux)
  my_pack_module_relocations := false
endif
