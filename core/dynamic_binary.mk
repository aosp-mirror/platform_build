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

LOCAL_UNSTRIPPED_PATH := $(strip $(LOCAL_UNSTRIPPED_PATH))
ifeq ($(LOCAL_UNSTRIPPED_PATH),)
  ifeq ($(LOCAL_MODULE_PATH),)
    LOCAL_UNSTRIPPED_PATH := $(TARGET_OUT_$(LOCAL_MODULE_CLASS)_UNSTRIPPED)
  else
    # We have to figure out the corresponding unstripped path if LOCAL_MODULE_PATH is customized.
    LOCAL_UNSTRIPPED_PATH := $(TARGET_OUT_UNSTRIPPED)/$(patsubst $(PRODUCT_OUT)/%,%,$(LOCAL_MODULE_PATH))
  endif
endif

# The name of the target file, without any path prepended.
# TODO: This duplicates logic from base_rules.mk because we need to
#       know its results before base_rules.mk is included.
#       Consolidate the duplicates.
LOCAL_MODULE_STEM := $(strip $(LOCAL_MODULE_STEM))
ifeq ($(LOCAL_MODULE_STEM),)
  LOCAL_MODULE_STEM := $(LOCAL_MODULE)
endif
LOCAL_INSTALLED_MODULE_STEM := $(LOCAL_MODULE_STEM)$(LOCAL_MODULE_SUFFIX)
LOCAL_BUILT_MODULE_STEM := $(LOCAL_INSTALLED_MODULE_STEM)

# base_rules.make defines $(intermediates), but we need its value
# before we include base_rules.  Make a guess, and verify that
# it's correct once the real value is defined.
guessed_intermediates := $(call local-intermediates-dir)

# Define the target that is the unmodified output of the linker.
# The basename of this target must be the same as the final output
# binary name, because it's used to set the "soname" in the binary.
# The includer of this file will define a rule to build this target.
linked_module := $(guessed_intermediates)/LINKED/$(LOCAL_BUILT_MODULE_STEM)

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

# Make sure that our guess at the value of intermediates was correct.
ifneq ($(intermediates),$(guessed_intermediates))
$(error Internal error: guessed path '$(guessed_intermediates)' doesn't match '$(intermediates))
endif

###########################################################
## Compress
###########################################################
compress_input := $(linked_module)

ifeq ($(strip $(LOCAL_COMPRESS_MODULE_SYMBOLS)),)
  LOCAL_COMPRESS_MODULE_SYMBOLS := $(strip $(TARGET_COMPRESS_MODULE_SYMBOLS))
endif

ifeq ($(LOCAL_COMPRESS_MODULE_SYMBOLS),true)
$(error Symbol compression not yet supported.)
compress_output := $(intermediates)/COMPRESSED-$(LOCAL_BUILT_MODULE_STEM)

#TODO: write the real $(SOSLIM) rule.
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
## Pre-link
###########################################################
prelink_input := $(compress_output)
# The output of the prelink step is the binary we want to use
# for symbolic debugging;  the prelink step may move sections
# around, so we have to use this version.
prelink_output := $(LOCAL_UNSTRIPPED_PATH)/$(LOCAL_MODULE_SUBDIR)$(LOCAL_BUILT_MODULE_STEM)

# Skip prelinker if it is FDO instrumentation build.
ifneq ($(strip $(BUILD_FDO_INSTRUMENT)),)
ifneq ($(LOCAL_NO_FDO_SUPPORT),true)
LOCAL_PRELINK_MODULE := false
endif
endif

ifeq ($(LOCAL_PRELINK_MODULE),true)
$(prelink_output): $(prelink_input) $(TARGET_PRELINKER_MAP) $(APRIORI)
	$(transform-to-prelinked)
else
# Don't prelink the binary, just copy it.  We can't skip this step
# because people always expect a copy of the binary to appear
# in the UNSTRIPPED directory.
#
# If the binary we're copying is acp or a prerequisite,
# use cp(1) instead.
ifneq ($(LOCAL_ACP_UNAVAILABLE),true)
$(prelink_output): $(prelink_input) | $(ACP)
	@echo "target Non-prelinked: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)
else
$(prelink_output): $(prelink_input)
	@echo "target Non-prelinked: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target-with-cp)
endif
endif


###########################################################
## Strip
###########################################################
strip_input := $(prelink_output)
strip_output := $(LOCAL_BUILT_MODULE)

ifeq ($(strip $(LOCAL_STRIP_MODULE)),)
  LOCAL_STRIP_MODULE := $(strip $(TARGET_STRIP_MODULE))
endif

ifeq ($(LOCAL_STRIP_MODULE),true)
# Strip the binary
$(strip_output): $(strip_input) | $(SOSLIM)
	$(transform-to-stripped)
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
endif # LOCAL_STRIP_MODULE


$(cleantarget): PRIVATE_CLEAN_FILES := \
			$(PRIVATE_CLEAN_FILES) \
			$(linked_module) \
			$(compress_output) \
			$(prelink_output)
