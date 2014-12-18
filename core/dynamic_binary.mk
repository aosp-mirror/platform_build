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
linked_module := $(intermediates)/LINKED/$(my_built_module_stem)

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
## Compress
###########################################################
compress_input := $(linked_module)

ifeq ($(strip $(LOCAL_COMPRESS_MODULE_SYMBOLS)),)
  LOCAL_COMPRESS_MODULE_SYMBOLS := $(strip $(TARGET_COMPRESS_MODULE_SYMBOLS))
endif

ifeq ($(LOCAL_COMPRESS_MODULE_SYMBOLS),true)
$(error Symbol compression not yet supported.)
compress_output := $(intermediates)/COMPRESSED-$(my_built_module_stem)

#TODO: write the real $(STRIPPER) rule.
#TODO: define a rule to build TARGET_SYMBOL_FILTER_FILE, and
#      make it depend on ALL_ORIGINAL_DYNAMIC_BINARIES.
$(compress_output): $(compress_input) $(TARGET_SYMBOL_FILTER_FILE) | $(ACP)
	@echo "target Compress Symbols: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)
else
# Skip this step.
compress_output := $(compress_input)
endif

###########################################################
## Store a copy with symbols for symbolic debugging
###########################################################
ifeq ($(LOCAL_UNSTRIPPED_PATH),)
my_unstripped_path := $(TARGET_OUT_UNSTRIPPED)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
else
my_unstripped_path := $(LOCAL_UNSTRIPPED_PATH)
endif
symbolic_input := $(compress_output)
symbolic_output := $(my_unstripped_path)/$(my_installed_module_stem)
$(symbolic_output) : $(symbolic_input) | $(ACP)
	@echo "target Symbolic: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)


###########################################################
## Strip
###########################################################
strip_input := $(symbolic_output)
strip_output := $(LOCAL_BUILT_MODULE)

my_strip_module := $(LOCAL_STRIP_MODULE)
ifeq ($(my_strip_module),)
  my_strip_module := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP_MODULE)
endif

ifeq ($(my_strip_module),true)
# Strip the binary
$(strip_output): PRIVATE_STRIP := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP)
$(strip_output): PRIVATE_OBJCOPY := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJCOPY)
$(strip_output): $(strip_input) | $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP)
	$(transform-to-stripped)
else
ifeq ($(my_strip_module),keep_symbols)
# Strip only the debug frames, but leave the symbol table.
$(strip_output): PRIVATE_STRIP := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_STRIP)
$(strip_output): PRIVATE_OBJCOPY := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_OBJCOPY)
$(strip_output): PRIVATE_READELF := $($(LOCAL_2ND_ARCH_VAR_PREFIX)TARGET_READELF)
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
#
# If the binary we're copying is acp or a prerequisite,
# use cp(1) instead.
ifneq ($(LOCAL_ACP_UNAVAILABLE),true)
$(strip_output): $(strip_input) | $(ACP)
	@echo "target Unstripped: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)
else
$(strip_output): $(strip_input)
	@echo "target Unstripped: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target-with-cp)
endif
endif
endif # my_strip_module


$(cleantarget): PRIVATE_CLEAN_FILES += \
    $(linked_module) \
    $(symbolic_output) \
    $(compress_output)
