# caller might have included aux_toolchain, e.g. if custom build steps are defined
ifeq ($(LOCAL_IS_AUX_MODULE),)
include $(BUILD_SYSTEM)/aux_toolchain.mk
endif

ifeq ($(AUX_BUILD_NOT_COMPATIBLE),)

###########################################################
## Standard rules for building an executable file.
##
## Additional inputs from base_rules.make:
## None.
###########################################################

ifeq ($(strip $(LOCAL_MODULE_CLASS)),)
LOCAL_MODULE_CLASS := EXECUTABLES
endif

$(call $(aux-executable-hook))

###########################################################
## Standard rules for building any target-side binaries
## with dynamic linkage (dynamic libraries or executables
## that link with dynamic libraries)
##
## Files including this file must define a rule to build
## the target $(linked_module).
###########################################################

# The name of the target file, without any path prepended.
# This duplicates logic from base_rules.mk because we need to
# know its results before base_rules.mk is included.
include $(BUILD_SYSTEM)/configure_module_stem.mk

intermediates := $(call local-intermediates-dir)

# Define the target that is the unmodified output of the linker.
# The basename of this target must be the same as the final output
# binary name, because it's used to set the "soname" in the binary.
# The includer of this file will define a rule to build this target.
linked_module := $(intermediates)/LINKED/$(my_built_module_stem)

ALL_ORIGINAL_DYNAMIC_BINARIES += $(linked_module)

# Because AUX_SYMBOL_FILTER_FILE depends on ALL_ORIGINAL_DYNAMIC_BINARIES,
# the linked_module rules won't necessarily inherit the PRIVATE_
# variables from LOCAL_BUILT_MODULE.  This tells binary.make to explicitly
# define the PRIVATE_ variables for linked_module as well as for
# LOCAL_BUILT_MODULE.
LOCAL_INTERMEDIATE_TARGETS += $(linked_module)

###################################
include $(BUILD_SYSTEM)/binary.mk
###################################

aux_output := $(linked_module)

ifneq ($(LOCAL_CUSTOM_BUILD_STEP_INPUT),)
ifneq ($(LOCAL_CUSTOM_BUILD_STEP_OUTPUT),)

# injecting custom build steps
$(LOCAL_CUSTOM_BUILD_STEP_INPUT): $(aux_output)
	@echo "$(AUX_DISPLAY) custom copy: $(PRIVATE_MODULE) ($@)"
	@mkdir -p $(dir $@)
	$(hide) $(copy-file-to-target)

aux_output := $(LOCAL_CUSTOM_BUILD_STEP_OUTPUT)

endif
endif

$(LOCAL_BUILT_MODULE): $(aux_output)
	@echo "$(AUX_DISPLAY) final copy: $(PRIVATE_MODULE) ($@)"
	@mkdir -p $(dir $@)
	$(hide) $(copy-file-to-target)

INSTALLED_AUX_TARGETS += $(LOCAL_INSTALLED_MODULE)

$(cleantarget): PRIVATE_CLEAN_FILES += \
    $(linked_module) \

# Define PRIVATE_ variables from global vars
$(linked_module): PRIVATE_POST_LINK_CMD := $(LOCAL_POST_LINK_CMD)

ifeq ($(LOCAL_FORCE_STATIC_EXECUTABLE),true)
$(linked_module): $(all_objects) $(all_libraries) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-o-to-aux-static-executable)
	$(PRIVATE_POST_LINK_CMD)
else
$(linked_module): $(all_objects) $(all_libraries) $(LOCAL_ADDITIONAL_DEPENDENCIES)
	$(transform-o-to-aux-executable)
	$(PRIVATE_POST_LINK_CMD)
endif

endif # AUX_BUILD_NOT_COMPATIBLE
