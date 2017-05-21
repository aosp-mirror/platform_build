###########################################################
## Standard rules for building any target-side binaries
## with dynamic linkage (dynamic libraries or executables
## that link with dynamic libraries)
##
## Files including this file must define a rule to build
## the target $(linked_module).
###########################################################

# This constraint means that we can hard-code any $(TARGET_*) variables.
ifdef LOCAL_IS_HOST_MODULE
$(error This file should not be used to build host binaries.  Included by (or near) $(lastword $(filter-out config/%,$(MAKEFILE_LIST))))
endif

# The name of the target file, without any path prepended.
# This duplicates logic from base_rules.mk because we need to
# know its results before base_rules.mk is included.
include $(BUILD_SYSTEM)/configure_module_stem.mk

intermediates := $(call local-intermediates-dir,,$(LOCAL_2ND_ARCH_VAR_PREFIX))

# Define the target that is the unmodified output of the linker.
# The basename of this target must be the same as the final output
# binary name, because it's used to set the "soname" in the binary.
# The includer of this file will define a rule to build this target.
linked_module := $(intermediates)/LINKED/$(notdir $(my_installed_module_stem))

ALL_ORIGINAL_DYNAMIC_BINARIES += $(linked_module)

# Because TARGET_SYMBOL_FILTER_FILE depends on ALL_ORIGINAL_DYNAMIC_BINARIES,
# the linked_module rules won't necessarily inherit the PRIVATE_
# variables from LOCAL_BUILT_MODULE.  This tells binary.make to explicitly
# define the PRIVATE_ variables for linked_module as well as for
# LOCAL_BUILT_MODULE.
LOCAL_INTERMEDIATE_TARGETS := $(linked_module)

###################################
include $(BUILD_SYSTEM)/binary.mk
###################################

###########################################################
## Pack relocation tables
###########################################################
relocation_packer_input := $(linked_module)
relocation_packer_output := $(intermediates)/PACKED/$(my_built_module_stem)

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

ifeq (true,$(my_pack_module_relocations))
# Pack relocations
$(relocation_packer_output): $(relocation_packer_input)
	$(pack-elf-relocations)
else
$(relocation_packer_output): $(relocation_packer_input)
	@echo "target Unpacked: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)
endif

###########################################################
## Store a copy with symbols for symbolic debugging
###########################################################
ifeq ($(LOCAL_UNSTRIPPED_PATH),)
my_unstripped_path := $(TARGET_OUT_UNSTRIPPED)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
else
my_unstripped_path := $(LOCAL_UNSTRIPPED_PATH)
endif
symbolic_input := $(relocation_packer_output)
symbolic_output := $(my_unstripped_path)/$(my_installed_module_stem)
$(symbolic_output) : $(symbolic_input)
	@echo "target Symbolic: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)

###########################################################
## Store breakpad symbols
###########################################################

ifeq ($(BREAKPAD_GENERATE_SYMBOLS),true)
my_breakpad_path := $(TARGET_OUT_BREAKPAD)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
breakpad_input := $(relocation_packer_output)
breakpad_output := $(my_breakpad_path)/$(my_installed_module_stem).sym
$(breakpad_output) : $(breakpad_input) | $(BREAKPAD_DUMP_SYMS)
	@echo "target breakpad: $(PRIVATE_MODULE) ($@)"
	@mkdir -p $(dir $@)
	$(hide) $(BREAKPAD_DUMP_SYMS) -c $< > $@
$(LOCAL_BUILT_MODULE) : $(breakpad_output)
endif

###########################################################
## Strip
###########################################################
strip_input := $(symbolic_output)
strip_output := $(LOCAL_BUILT_MODULE)

my_strip_module := $(firstword \
  $(LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) \
  $(LOCAL_STRIP_MODULE))
ifeq ($(my_strip_module),)
  my_strip_module := mini-debug-info
endif

ifeq ($(my_strip_module),mini-debug-info)
# Don't use mini-debug-info on mips (both 32-bit and 64-bit). objcopy checks that all
# SH_MIPS_DWARF sections having name prefix .debug_ or .zdebug_, so there seems no easy
# way using objcopy to remove all debug sections except .debug_frame on mips.
ifneq ($(filter mips mips64,$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)),)
  my_strip_module := true
endif
endif

$(strip_output): PRIVATE_STRIP := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP)
$(strip_output): PRIVATE_OBJCOPY := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJCOPY)
$(strip_output): PRIVATE_NM := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_NM)
$(strip_output): PRIVATE_READELF := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_READELF)
ifeq ($(my_strip_module),no_debuglink)
$(strip_output): PRIVATE_NO_DEBUGLINK := true
else
$(strip_output): PRIVATE_NO_DEBUGLINK :=
endif

ifeq ($(my_strip_module),mini-debug-info)
# Strip the binary, but keep debug frames and symbol table in a compressed .gnu_debugdata section.
$(strip_output): $(strip_input) | $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP) $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJCOPY) $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_NM)
	$(transform-to-stripped-keep-mini-debug-info)
else ifneq ($(filter true no_debuglink,$(my_strip_module)),)
# Strip the binary
$(strip_output): $(strip_input) | $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP)
	$(transform-to-stripped)
else ifeq ($(my_strip_module),keep_symbols)
# Strip only the debug frames, but leave the symbol table.
$(strip_output): $(strip_input) | $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP)
	$(transform-to-stripped-keep-symbols)

# A product may be configured to strip everything in some build variants.
# We do the stripping as a post-install command so that LOCAL_BUILT_MODULE
# is still with the symbols and we don't need to clean it (and relink) when
# you switch build variant.
ifneq ($(filter $(STRIP_EVERYTHING_BUILD_VARIANTS),$(TARGET_BUILD_VARIANT)),)
$(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := \
  $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP) --strip-all $(LOCAL_INSTALLED_MODULE)
endif
else
# Don't strip the binary, just copy it.  We can't skip this step
# because a copy of the binary must appear at LOCAL_BUILT_MODULE.
$(strip_output): $(strip_input)
	@echo "target Unstripped: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)
endif # my_strip_module

$(cleantarget): PRIVATE_CLEAN_FILES += \
    $(linked_module) \
    $(breakpad_output) \
    $(symbolic_output) \
    $(strip_output)
