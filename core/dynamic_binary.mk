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

# This tells binary.make to explicitly define the PRIVATE_ variables for
# linked_module as well as for LOCAL_BUILT_MODULE.
LOCAL_INTERMEDIATE_TARGETS := $(linked_module)

###################################
include $(BUILD_SYSTEM)/use_lld_setup.mk
include $(BUILD_SYSTEM)/binary.mk
###################################

ifdef LOCAL_INJECT_BSSL_HASH
inject_module := $(intermediates)/INJECT_BSSL_HASH/$(notdir $(my_installed_module_stem))
LOCAL_INTERMEDIATE_TARGETS += $(inject_module)
$(inject_module): $(SOONG_HOST_OUT)/bin/bssl_inject_hash
$(inject_module): $(linked_module)
	@echo "target inject BSSL hash: $(PRIVATE_MODULE) ($@)"
	$(SOONG_HOST_OUT)/bin/bssl_inject_hash -in-object $< -o $@
else
inject_module := $(linked_module)
endif

###########################################################
## Store a copy with symbols for symbolic debugging
###########################################################
ifeq ($(LOCAL_UNSTRIPPED_PATH),)
my_unstripped_path := $(TARGET_OUT_UNSTRIPPED)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
else
my_unstripped_path := $(LOCAL_UNSTRIPPED_PATH)
endif
symbolic_input := $(inject_module)
symbolic_output := $(my_unstripped_path)/$(my_installed_module_stem)
elf_mapping_path := $(patsubst $(TARGET_OUT_UNSTRIPPED)/%,$(call intermediates-dir-for,PACKAGING,elf_symbol_mapping)/%,$(symbolic_output).textproto)

ALL_MODULES.$(my_register_name).SYMBOLIC_OUTPUT_PATH := $(symbolic_output)
ALL_MODULES.$(my_register_name).ELF_SYMBOL_MAPPING_PATH := $(elf_mapping_path)

$(eval $(call copy-unstripped-elf-file-with-mapping,$(symbolic_input),$(symbolic_output),$(elf_mapping_path)))

###########################################################
## Store breakpad symbols
###########################################################

ifeq ($(BREAKPAD_GENERATE_SYMBOLS),true)
my_breakpad_path := $(TARGET_OUT_BREAKPAD)/$(patsubst $(PRODUCT_OUT)/%,%,$(my_module_path))
breakpad_input := $(inject_module)
breakpad_output := $(my_breakpad_path)/$(my_installed_module_stem).sym
$(breakpad_output) : $(breakpad_input) | $(BREAKPAD_DUMP_SYMS) $(PRIVATE_READELF)
	@echo "target breakpad: $(PRIVATE_MODULE) ($@)"
	@mkdir -p $(dir $@)
	$(hide) if $(PRIVATE_READELF) -S $< > /dev/null 2>&1 ; then \
	  $(BREAKPAD_DUMP_SYMS) -c $< > $@ ; \
	else \
	  echo "skipped for non-elf file."; \
	  touch $@; \
	fi
$(LOCAL_BUILT_MODULE) : $(breakpad_output)
endif

###########################################################
## Strip
###########################################################
strip_input := $(inject_module)
strip_output := $(LOCAL_BUILT_MODULE)

# Use an order-only dependency to ensure the unstripped file in the symbols
# directory is copied when the module is built, but does not force the
# module to be rebuilt when the symbols directory is cleaned by installclean.
$(strip_output): | $(symbolic_output)

my_strip_module := $(firstword \
  $(LOCAL_STRIP_MODULE_$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)) \
  $(LOCAL_STRIP_MODULE))
ifeq ($(my_strip_module),)
  my_strip_module := mini-debug-info
endif

ifeq ($(my_strip_module),false)
  my_strip_module :=
endif

my_strip_args :=
ifeq ($(my_strip_module),mini-debug-info)
  my_strip_args += --keep-mini-debug-info
else ifeq ($(my_strip_module),keep_symbols)
  my_strip_args += --keep-symbols
endif

ifeq (,$(filter no_debuglink mini-debug-info,$(my_strip_module)))
  ifneq ($(TARGET_BUILD_VARIANT),user)
    my_strip_args += --add-gnu-debuglink
  endif
endif

ifeq ($($(my_prefix)OS),darwin)
  # llvm-strip does not support Darwin Mach-O yet.
  my_strip_args += --use-gnu-strip
endif

valid_strip := mini-debug-info keep_symbols true no_debuglink
ifneq (,$(filter-out $(valid_strip),$(my_strip_module)))
  $(call pretty-error,Invalid strip value $(my_strip_module), only one of $(valid_strip) allowed)
endif

ifneq (,$(my_strip_module))
  $(strip_output): PRIVATE_STRIP_ARGS := $(my_strip_args)
  $(strip_output): PRIVATE_TOOLS_PREFIX := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)TOOLS_PREFIX)
  $(strip_output): $(strip_input) $(SOONG_STRIP_PATH) $(XZ)
	@echo "$($(PRIVATE_PREFIX)DISPLAY) Strip: $(PRIVATE_MODULE) ($@)"
	CLANG_BIN=$(LLVM_PREBUILTS_PATH) \
	CROSS_COMPILE=$(PRIVATE_TOOLS_PREFIX) \
	XZ=$(XZ) \
	CREATE_MINIDEBUGINFO=${CREATE_MINIDEBUGINFO} \
	$(SOONG_STRIP_PATH) -i $< -o $@ -d $@.strip.d $(PRIVATE_STRIP_ARGS)
  ifneq ($(HOST_OS),darwin)
    $(strip_output): $(CREATE_MINIDEBUGINFO)
  endif
  $(call include-depfile,$(strip_output).strip.d,$(strip_output))
else
  # Don't strip the binary, just copy it.  We can't skip this step
  # because a copy of the binary must appear at LOCAL_BUILT_MODULE.
  $(strip_output): $(strip_input)
	@echo "target Unstripped: $(PRIVATE_MODULE) ($@)"
	$(copy-file-to-target)
endif # my_strip_module

$(cleantarget): PRIVATE_CLEAN_FILES += \
    $(linked_module) \
    $(inject_module) \
    $(breakpad_output) \
    $(symbolic_output) \
    $(strip_output)
