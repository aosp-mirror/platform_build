#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Catch users that directly include base_rules.mk
$(call record-module-type,base_rules)

# Users can define base-rules-hook in their buildspec.mk to perform
# arbitrary operations as each module is included.
ifdef base-rules-hook
$(if $(base-rules-hook),)
endif

###########################################################
## Common instructions for a generic module.
###########################################################

LOCAL_MODULE := $(strip $(LOCAL_MODULE))
ifeq ($(LOCAL_MODULE),)
  $(error $(LOCAL_PATH): LOCAL_MODULE is not defined)
endif

LOCAL_IS_HOST_MODULE := $(strip $(LOCAL_IS_HOST_MODULE))
LOCAL_IS_AUX_MODULE := $(strip $(LOCAL_IS_AUX_MODULE))
ifdef LOCAL_IS_HOST_MODULE
  ifneq ($(LOCAL_IS_HOST_MODULE),true)
    $(error $(LOCAL_PATH): LOCAL_IS_HOST_MODULE must be "true" or empty, not "$(LOCAL_IS_HOST_MODULE)")
  endif
  ifeq ($(LOCAL_HOST_PREFIX),)
    my_prefix := HOST_
  else
    my_prefix := $(LOCAL_HOST_PREFIX)
  endif
  my_host := host-
  my_kind := HOST
else
  ifdef LOCAL_IS_AUX_MODULE
    ifneq ($(LOCAL_IS_AUX_MODULE),true)
      $(error $(LOCAL_PATH): LOCAL_IS_AUX_MODULE must be "true" or empty, not "$(LOCAL_IS_AUX_MODULE)")
    endif
    my_prefix := AUX_
    my_kind := AUX
  else
    my_prefix := TARGET_
    my_kind :=
  endif
  my_host :=
endif

ifeq ($(my_prefix),HOST_CROSS_)
  my_host_cross := true
else
  my_host_cross :=
endif

_path := $(LOCAL_MODULE_PATH) $(LOCAL_MODULE_PATH_32) $(LOCAL_MODULE_PATH_64)
ifneq ($(filter $(TARGET_OUT_VENDOR)%,$(_path)),)
LOCAL_VENDOR_MODULE := true
else ifneq ($(filter $(TARGET_OUT_OEM)/%,$(_path)),)
LOCAL_OEM_MODULE := true
else ifneq ($(filter $(TARGET_OUT_ODM)/%,$(_path)),)
LOCAL_ODM_MODULE := true
else ifneq ($(filter $(TARGET_OUT_PRODUCT)/%,$(_path)),)
LOCAL_PRODUCT_MODULE := true
endif
_path :=

ifndef LOCAL_PROPRIETARY_MODULE
  LOCAL_PROPRIETARY_MODULE := $(LOCAL_VENDOR_MODULE)
endif
ifndef LOCAL_VENDOR_MODULE
  LOCAL_VENDOR_MODULE := $(LOCAL_PROPRIETARY_MODULE)
endif
ifneq ($(filter-out $(LOCAL_PROPRIETARY_MODULE),$(LOCAL_VENDOR_MODULE))$(filter-out $(LOCAL_VENDOR_MODULE),$(LOCAL_PROPRIETARY_MODULE)),)
$(call pretty-error,Only one of LOCAL_PROPRIETARY_MODULE[$(LOCAL_PROPRIETARY_MODULE)] and LOCAL_VENDOR_MODULE[$(LOCAL_VENDOR_MODULE)] may be set, or they must be equal)
endif

include $(BUILD_SYSTEM)/local_vndk.mk
include $(BUILD_SYSTEM)/local_systemsdk.mk

my_module_tags := $(LOCAL_MODULE_TAGS)
ifeq ($(my_host_cross),true)
  my_module_tags :=
endif
ifeq ($(TARGET_TRANSLATE_2ND_ARCH),true)
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
# Don't pull in modules by tags if this is for translation TARGET_2ND_ARCH.
  my_module_tags :=
endif
endif

# Ninja has an implicit dependency on the command being run, and kati will
# regenerate the ninja manifest if any read makefile changes, so there is no
# need to have dependencies on makefiles.
# This won't catch all the cases where LOCAL_ADDITIONAL_DEPENDENCIES contains
# a .mk file, because a few users of LOCAL_ADDITIONAL_DEPENDENCIES don't include
# base_rules.mk, but it will fix the most common ones.
LOCAL_ADDITIONAL_DEPENDENCIES := $(filter-out %.mk,$(LOCAL_ADDITIONAL_DEPENDENCIES))

my_bad_deps := $(strip $(foreach dep,$(filter-out | ||,$(LOCAL_ADDITIONAL_DEPENDENCIES)),\
                 $(if $(findstring /,$(dep)),,$(dep))))
ifneq ($(my_bad_deps),)
$(call pretty-warning,"Bad LOCAL_ADDITIONAL_DEPENDENCIES: $(my_bad_deps)")
$(call pretty-error,"LOCAL_ADDITIONAL_DEPENDENCIES must only contain paths (not module names)")
endif

###########################################################
## Validate and define fallbacks for input LOCAL_* variables.
###########################################################

## Dump a .csv file of all modules and their tags
#ifneq ($(tag-list-first-time),false)
#$(shell rm -f tag-list.csv)
#tag-list-first-time := false
#endif
#$(shell echo $(lastword $(filter-out config/% out/%,$(MAKEFILE_LIST))),$(LOCAL_MODULE),$(strip $(LOCAL_MODULE_CLASS)),$(subst $(space),$(comma),$(sort $(my_module_tags))) >> tag-list.csv)

LOCAL_UNINSTALLABLE_MODULE := $(strip $(LOCAL_UNINSTALLABLE_MODULE))
my_module_tags := $(sort $(my_module_tags))
ifeq (,$(my_module_tags))
  my_module_tags := optional
endif

# User tags are not allowed anymore.  Fail early because it will not be installed
# like it used to be.
ifneq ($(filter $(my_module_tags),user),)
  $(warning *** Module name: $(LOCAL_MODULE))
  $(warning *** Makefile location: $(LOCAL_MODULE_MAKEFILE))
  $(warning * )
  $(warning * Module is attempting to use the 'user' tag.  This)
  $(warning * used to cause the module to be installed automatically.)
  $(warning * Now, the module must be listed in the PRODUCT_PACKAGES)
  $(warning * section of a product makefile to have it installed.)
  $(warning * )
  $(error user tag detected on module.)
endif

# Only the tags mentioned in this test are expected to be set by module
# makefiles. Anything else is either a typo or a source of unexpected
# behaviors.
ifneq ($(filter-out debug eng tests optional samples,$(my_module_tags)),)
$(call pretty-error,unusual tags: $(filter-out debug eng tests optional samples,$(my_module_tags)))
endif

# Add implicit tags.
#
# If the local directory or one of its parents contains a MODULE_LICENSE_GPL
# file, tag the module as "gnu".  Search for "*_GPL*", "*_LGPL*" and "*_MPL*"
# so that we can also find files like MODULE_LICENSE_GPL_AND_AFL
#
license_files := $(call find-parent-file,$(LOCAL_PATH),MODULE_LICENSE*)
gpl_license_file := $(call find-parent-file,$(LOCAL_PATH),MODULE_LICENSE*_GPL* MODULE_LICENSE*_MPL* MODULE_LICENSE*_LGPL*)
ifneq ($(gpl_license_file),)
  my_module_tags += gnu
  ALL_GPL_MODULE_LICENSE_FILES := $(sort $(ALL_GPL_MODULE_LICENSE_FILES) $(gpl_license_file))
endif

LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))
ifneq ($(words $(LOCAL_MODULE_CLASS)),1)
  $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS must contain exactly one word, not "$(LOCAL_MODULE_CLASS)")
endif

my_32_64_bit_suffix := $(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT),64,32)

ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
ifeq ($(TARGET_TRANSLATE_2ND_ARCH),true)
# When in TARGET_TRANSLATE_2ND_ARCH both TARGET_ARCH and TARGET_2ND_ARCH are 32-bit,
# to avoid path conflict we force using LOCAL_MODULE_PATH_64 for the first arch.
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
my_multilib_module_path := $(LOCAL_MODULE_PATH_32)
else  # ! LOCAL_2ND_ARCH_VAR_PREFIX
my_multilib_module_path := $(LOCAL_MODULE_PATH_64)
endif  # ! LOCAL_2ND_ARCH_VAR_PREFIX
else  # ! TARGET_TRANSLATE_2ND_ARCH
my_multilib_module_path := $(strip $(LOCAL_MODULE_PATH_$(my_32_64_bit_suffix)))
endif # ! TARGET_TRANSLATE_2ND_ARCH
ifdef my_multilib_module_path
my_module_path := $(my_multilib_module_path)
else
my_module_path := $(strip $(LOCAL_MODULE_PATH))
endif
my_module_path := $(patsubst %/,%,$(my_module_path))
my_module_relative_path := $(strip $(LOCAL_MODULE_RELATIVE_PATH))
ifdef LOCAL_IS_HOST_MODULE
  partition_tag :=
else
ifeq (true,$(LOCAL_VENDOR_MODULE))
  partition_tag := _VENDOR
else ifeq (true,$(LOCAL_OEM_MODULE))
  partition_tag := _OEM
else ifeq (true,$(LOCAL_ODM_MODULE))
  partition_tag := _ODM
else ifeq (true,$(LOCAL_PRODUCT_MODULE))
  partition_tag := _PRODUCT
else ifeq (NATIVE_TESTS,$(LOCAL_MODULE_CLASS))
  partition_tag := _DATA
else
  # The definition of should-install-to-system will be different depending
  # on which goal (e.g., sdk or just droid) is being built.
  partition_tag := $(if $(call should-install-to-system,$(my_module_tags)),,_DATA)
endif
endif
ifeq ($(my_module_path),)
  install_path_var := $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT$(partition_tag)_$(LOCAL_MODULE_CLASS)
  ifeq (true,$(LOCAL_PRIVILEGED_MODULE))
    install_path_var := $(install_path_var)_PRIVILEGED
  endif

  my_module_path := $($(install_path_var))
  ifeq ($(strip $(my_module_path)),)
    $(error $(LOCAL_PATH): unhandled install path "$(install_path_var) for $(LOCAL_MODULE)")
  endif
endif
ifneq ($(my_module_relative_path),)
  my_module_path := $(my_module_path)/$(my_module_relative_path)
endif
endif # not LOCAL_UNINSTALLABLE_MODULE

ifneq ($(strip $(LOCAL_BUILT_MODULE)$(LOCAL_INSTALLED_MODULE)),)
  $(error $(LOCAL_PATH): LOCAL_BUILT_MODULE and LOCAL_INSTALLED_MODULE must not be defined by component makefiles)
endif

my_register_name := $(LOCAL_MODULE)
ifeq ($(my_host_cross),true)
  my_register_name := host_cross_$(LOCAL_MODULE)
endif
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
ifndef LOCAL_NO_2ND_ARCH_MODULE_SUFFIX
my_register_name := $(my_register_name)$($(my_prefix)2ND_ARCH_MODULE_SUFFIX)
endif
endif

ifeq ($(my_host_cross),true)
  my_all_targets := host_cross_$(my_register_name)_all_targets
else ifneq ($(LOCAL_IS_HOST_MODULE),)
  my_all_targets := host_$(my_register_name)_all_targets
else
  my_all_targets := device_$(my_register_name)_all_targets
endif

# variant is enough to make nano class unique; it serves as a key to lookup (OS,ARCH) tuple
aux_class := $($(my_prefix)OS_VARIANT)
# Make sure that this IS_HOST/CLASS/MODULE combination is unique.
module_id := MODULE.$(if \
    $(LOCAL_IS_HOST_MODULE),$($(my_prefix)OS),$(if \
    $(LOCAL_IS_AUX_MODULE),$(aux_class),TARGET)).$(LOCAL_MODULE_CLASS).$(my_register_name)
ifdef $(module_id)
$(error $(LOCAL_PATH): $(module_id) already defined by $($(module_id)))
endif
$(module_id) := $(LOCAL_PATH)

intermediates := $(call local-intermediates-dir,,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))
intermediates.COMMON := $(call local-intermediates-dir,COMMON)
generated_sources_dir := $(call local-generated-sources-dir)

ifneq ($(LOCAL_OVERRIDES_MODULES),)
  ifeq ($(LOCAL_MODULE_CLASS),EXECUTABLES)
    ifndef LOCAL_IS_HOST_MODULE
      EXECUTABLES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_MODULES))
    else
      $(call pretty-error,host modules cannot use LOCAL_OVERRIDES_MODULES)
    endif
  else
      $(call pretty-error,LOCAL_MODULE_CLASS := $(LOCAL_MODULE_CLASS) cannot use LOCAL_OVERRIDES_MODULES)
  endif
endif

###########################################################
# Pick a name for the intermediate and final targets
###########################################################
include $(BUILD_SYSTEM)/configure_module_stem.mk

LOCAL_BUILT_MODULE := $(intermediates)/$(my_built_module_stem)

# OVERRIDE_BUILT_MODULE_PATH is only allowed to be used by the
# internal SHARED_LIBRARIES build files.
OVERRIDE_BUILT_MODULE_PATH := $(strip $(OVERRIDE_BUILT_MODULE_PATH))
ifdef OVERRIDE_BUILT_MODULE_PATH
  ifneq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
    $(error $(LOCAL_PATH): Illegal use of OVERRIDE_BUILT_MODULE_PATH)
  endif
  $(eval $(call copy-one-file,$(LOCAL_BUILT_MODULE),$(OVERRIDE_BUILT_MODULE_PATH)/$(my_built_module_stem)))
endif

ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  # Apk and its attachments reside in its own subdir.
  ifeq ($(LOCAL_MODULE_CLASS),APPS)
  # framework-res.apk doesn't like the additional layer.
  ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
  # Neither do Runtime Resource Overlay apks, which contain just the overlaid resources.
  else ifeq ($(LOCAL_IS_RUNTIME_RESOURCE_OVERLAY),true)
  else
    my_module_path := $(my_module_path)/$(LOCAL_MODULE)
  endif
  endif
  LOCAL_INSTALLED_MODULE := $(my_module_path)/$(my_installed_module_stem)
endif

# Assemble the list of targets to create PRIVATE_ variables for.
LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_BUILT_MODULE)

###########################################################
## Create .toc files from shared objects to reduce unnecessary rebuild
# .toc files have the list of external dynamic symbols without their addresses.
# As .KATI_RESTAT is specified to .toc files and commit-change-for-toc is used,
# dependent binaries of a .toc file will be rebuilt only when the content of
# the .toc file is changed.
###########################################################
ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_BUILT_MODULE).toc
$(LOCAL_BUILT_MODULE).toc: $(LOCAL_BUILT_MODULE)
	$(call $(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)transform-shared-lib-to-toc,$<,$@.tmp)
	$(call commit-change-for-toc,$@)

# Kati adds restat=1 to ninja. GNU make does nothing for this.
.KATI_RESTAT: $(LOCAL_BUILT_MODULE).toc
# Build .toc file when using mm, mma, or make $(my_register_name)
$(my_all_targets): $(LOCAL_BUILT_MODULE).toc

ifdef OVERRIDE_BUILT_MODULE_PATH
$(eval $(call copy-one-file,$(LOCAL_BUILT_MODULE).toc,$(OVERRIDE_BUILT_MODULE_PATH)/$(my_built_module_stem).toc))
$(OVERRIDE_BUILT_MODULE_PATH)/$(my_built_module_stem).toc: $(OVERRIDE_BUILT_MODULE_PATH)/$(my_built_module_stem)
endif
endif

###########################################################
## logtags: Add .logtags files to global list
###########################################################

logtags_sources := $(filter %.logtags,$(LOCAL_SRC_FILES)) $(LOCAL_LOGTAGS_FILES)

ifneq ($(strip $(logtags_sources)),)
event_log_tags := $(addprefix $(LOCAL_PATH)/,$(logtags_sources))
else
event_log_tags :=
endif

###########################################################
## make clean- targets
###########################################################
cleantarget := clean-$(my_register_name)
$(cleantarget) : PRIVATE_MODULE := $(my_register_name)
$(cleantarget) : PRIVATE_CLEAN_FILES := \
    $(LOCAL_BUILT_MODULE) \
    $(LOCAL_INSTALLED_MODULE) \
    $(intermediates)
$(cleantarget)::
	@echo "Clean: $(PRIVATE_MODULE)"
	$(hide) rm -rf $(PRIVATE_CLEAN_FILES)

###########################################################
## Common definitions for module.
###########################################################
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_PATH:=$(LOCAL_PATH)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_IS_HOST_MODULE := $(LOCAL_IS_HOST_MODULE)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_IS_AUX_MODULE := $(LOCAL_IS_AUX_MODULE)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_HOST:= $(my_host)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_PREFIX := $(my_prefix)

$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_INTERMEDIATES_DIR:= $(intermediates)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_2ND_ARCH_VAR_PREFIX := $(LOCAL_2ND_ARCH_VAR_PREFIX)

# Tell the module and all of its sub-modules who it is.
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_MODULE:= $(my_register_name)

# Provide a short-hand for building this module.
# We name both BUILT and INSTALLED in case
# LOCAL_UNINSTALLABLE_MODULE is set.
.PHONY: $(my_all_targets)
$(my_all_targets): $(LOCAL_BUILT_MODULE) $(LOCAL_INSTALLED_MODULE)

.PHONY: $(my_register_name)
$(my_register_name): $(my_all_targets)

ifneq ($(my_register_name),$(LOCAL_MODULE))
# $(LOCAL_MODULE) covers all the multilib targets.
.PHONY: $(LOCAL_MODULE)
$(LOCAL_MODULE) : $(my_all_targets)
endif

# Set up phony targets that covers all modules under the given paths.
# This allows us to build everything in given paths by running mmma/mma.
my_path_components := $(subst /,$(space),$(LOCAL_PATH))
my_path_prefix := MODULES-IN
$(foreach c, $(my_path_components),\
  $(eval my_path_prefix := $(my_path_prefix)-$(c))\
  $(eval .PHONY : $(my_path_prefix))\
  $(eval $(my_path_prefix) : $(my_all_targets)))

###########################################################
## Module installation rule
###########################################################

my_init_rc_installed :=
my_init_rc_pairs :=
my_installed_symlinks :=
ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
$(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := $(LOCAL_POST_INSTALL_CMD)
$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE)
	@echo "Install: $@"
	$(copy-file-to-new-target)
	$(PRIVATE_POST_INSTALL_CMD)

ifndef LOCAL_IS_HOST_MODULE
# Rule to install the module's companion init.rc.
my_init_rc := $(LOCAL_INIT_RC_$(my_32_64_bit_suffix)) $(LOCAL_INIT_RC)
ifneq ($(strip $(my_init_rc)),)
my_init_rc_pairs := $(foreach rc,$(my_init_rc),$(LOCAL_PATH)/$(rc):$(TARGET_OUT$(partition_tag)_ETC)/init/$(notdir $(rc)))
my_init_rc_installed := $(foreach rc,$(my_init_rc_pairs),$(call word-colon,2,$(rc)))

# Make sure we only set up the copy rules once, even if another arch variant
# shares a common LOCAL_INIT_RC.
my_init_rc_new_pairs := $(filter-out $(ALL_INIT_RC_INSTALLED_PAIRS),$(my_init_rc_pairs))
my_init_rc_new_installed := $(call copy-many-files,$(my_init_rc_new_pairs))
ALL_INIT_RC_INSTALLED_PAIRS += $(my_init_rc_new_pairs)

$(my_all_targets) : $(my_init_rc_installed)
endif # my_init_rc
endif # !LOCAL_IS_HOST_MODULE

# Rule to install the module's companion symlinks
my_installed_symlinks := $(addprefix $(my_module_path)/,$(LOCAL_MODULE_SYMLINKS) $(LOCAL_MODULE_SYMLINKS_$(my_32_64_bit_suffix)))
$(foreach symlink,$(my_installed_symlinks),\
    $(call symlink-file,$(LOCAL_INSTALLED_MODULE),$(my_installed_module_stem),$(symlink)))

$(my_all_targets) : | $(my_installed_symlinks)

endif # !LOCAL_UNINSTALLABLE_MODULE

###########################################################
## CHECK_BUILD goals
###########################################################
my_checked_module :=
# If nobody has defined a more specific module for the
# checked modules, use LOCAL_BUILT_MODULE.
ifdef LOCAL_CHECKED_MODULE
  my_checked_module := $(LOCAL_CHECKED_MODULE)
else
  my_checked_module := $(LOCAL_BUILT_MODULE)
endif

# If they request that this module not be checked, then don't.
# PLEASE DON'T SET THIS.  ANY PLACES THAT SET THIS WITHOUT
# GOOD REASON WILL HAVE IT REMOVED.
ifdef LOCAL_DONT_CHECK_MODULE
  my_checked_module :=
endif
# Don't check build target module defined for the 2nd arch
ifndef LOCAL_IS_HOST_MODULE
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
  my_checked_module :=
endif
endif

###########################################################
## Test Data
###########################################################
my_test_data_pairs :=
my_installed_test_data :=
# Source to relative dst file paths for reuse in LOCAL_COMPATIBILITY_SUITE.
my_test_data_file_pairs :=

ifneq ($(filter NATIVE_TESTS,$(LOCAL_MODULE_CLASS)),)
ifneq ($(strip $(LOCAL_TEST_DATA)),)
ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))

my_test_data_pairs := $(strip $(foreach td,$(LOCAL_TEST_DATA), \
    $(eval _file := $(call word-colon,2,$(td))) \
    $(if $(_file), \
      $(eval _src_base := $(call word-colon,1,$(td))), \
      $(eval _src_base := $(LOCAL_PATH)) \
        $(eval _file := $(call word-colon,1,$(td)))) \
    $(if $(findstring ..,$(_file)),$(error $(LOCAL_MODULE_MAKEFILE): LOCAL_TEST_DATA may not include '..': $(_file))) \
    $(if $(filter /%,$(_src_base) $(_file)),$(error $(LOCAL_MODULE_MAKEFILE): LOCAL_TEST_DATA may not include absolute paths: $(_src_base) $(_file))) \
    $(eval my_test_data_file_pairs := $(my_test_data_file_pairs) $(call append-path,$(_src_base),$(_file)):$(_file)) \
    $(call append-path,$(_src_base),$(_file)):$(call append-path,$(my_module_path),$(_file))))

my_installed_test_data := $(call copy-many-files,$(my_test_data_pairs))
$(LOCAL_INSTALLED_MODULE): $(my_installed_test_data)

endif
endif
endif

# For test modules that lack a suite tag, set null-suite as the default.
# We only support adding a default suite to native tests, native benchmarks, and instrumentation tests.
# This is because they are the only tests we currently auto-generate test configs for.
ifndef LOCAL_COMPATIBILITY_SUITE
ifneq ($(filter NATIVE_TESTS NATIVE_BENCHMARK, $(LOCAL_MODULE_CLASS)),)
LOCAL_COMPATIBILITY_SUITE := null-suite
endif
ifneq ($(filter APPS, $(LOCAL_MODULE_CLASS)),)
ifneq ($(filter $(my_module_tags),tests),)
LOCAL_COMPATIBILITY_SUITE := null-suite
endif
endif
endif

###########################################################
## Compatibility suite files.
###########################################################
ifdef LOCAL_COMPATIBILITY_SUITE

# If we are building a native test or benchmark and its stem variants are not defined,
# separate the multiple architectures into subdirectories of the testcase folder.
arch_dir :=
is_native :=
multi_arch :=
ifeq ($(LOCAL_MODULE_CLASS),NATIVE_TESTS)
  is_native := true
  multi_arch := true
endif
ifeq ($(LOCAL_MODULE_CLASS),NATIVE_BENCHMARK)
  is_native := true
  multi_arch := true
endif
ifdef LOCAL_MULTILIB
  multi_arch := true
endif
ifdef multi_arch
  arch_dir := /$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
endif
multi_arch :=

# The module itself.
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_$(suite) := $(foreach dir, $(call compatibility_suite_dirs,$(suite),$(arch_dir)), \
    $(LOCAL_BUILT_MODULE):$(dir)/$(my_installed_module_stem))))

# Make sure we only add the files once for multilib modules.
ifndef $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files
$(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files := true

# LOCAL_COMPATIBILITY_SUPPORT_FILES is a list of <src>[:<dest>].
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_$(suite) += $(foreach f, $(LOCAL_COMPATIBILITY_SUPPORT_FILES), \
    $(eval p := $(subst :,$(space),$(f))) \
    $(eval s := $(word 1,$(p))) \
    $(eval n := $(or $(word 2,$(p)),$(notdir $(word 1, $(p))))) \
    $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
      $(s):$(dir)/$(n)))))

test_config := $(wildcard $(LOCAL_PATH)/AndroidTest.xml)
ifeq (,$(test_config))
  ifneq (true,$(is_native))
    is_instrumentation_test := true
    ifeq (true, $(LOCAL_IS_HOST_MODULE))
      is_instrumentation_test := false
    endif
    # If LOCAL_MODULE_CLASS is not APPS, it's certainly not an instrumentation
    # test. However, some packages for test data also have LOCAL_MODULE_CLASS
    # set to APPS. These will require flag LOCAL_DISABLE_AUTO_GENERATE_TEST_CONFIG
    # to disable auto-generating test config file.
    ifneq (APPS, $(LOCAL_MODULE_CLASS))
      is_instrumentation_test := false
    endif
  endif
  # CTS modules can be used for test data, so test config files must be
  # explicitly created using AndroidTest.xml
  ifeq (,$(filter cts, $(LOCAL_COMPATIBILITY_SUITE)))
    ifneq (true, $(LOCAL_DISABLE_AUTO_GENERATE_TEST_CONFIG))
      ifeq (true, $(filter true,$(is_native) $(is_instrumentation_test)))
        include $(BUILD_SYSTEM)/autogen_test_config.mk
        test_config := $(autogen_test_config_file)
        autogen_test_config_file :=
      endif
    endif
  endif
endif

is_instrumentation_test :=

ifneq (,$(test_config))
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
    $(test_config):$(dir)/$(LOCAL_MODULE).config)))
endif

test_config :=

ifneq (,$(wildcard $(LOCAL_PATH)/DynamicConfig.xml))
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
    $(LOCAL_PATH)/DynamicConfig.xml:$(dir)/$(LOCAL_MODULE).dynamic)))
endif

ifneq (,$(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE)_*.config))
$(foreach extra_config, $(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE)_*.config), \
  $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
    $(eval my_compat_dist_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
      $(extra_config):$(dir)/$(notdir $(extra_config))))))
endif
endif # $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files

ifneq ($(my_test_data_file_pairs),)
$(foreach pair, $(my_test_data_file_pairs), \
  $(eval parts := $(subst :,$(space),$(pair))) \
  $(eval src_path := $(word 1,$(parts))) \
  $(eval file := $(word 2,$(parts))) \
  $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
    $(eval my_compat_dist_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite),$(arch_dir)), \
      $(src_path):$(call append-path,$(dir),$(file))))))
endif

arch_dir :=
is_native :=

$(call create-suite-dependencies)

endif  # LOCAL_COMPATIBILITY_SUITE

###########################################################
## Register with ALL_MODULES
###########################################################

ALL_MODULES += $(my_register_name)

# Don't use += on subvars, or else they'll end up being
# recursively expanded.
ALL_MODULES.$(my_register_name).CLASS := \
    $(ALL_MODULES.$(my_register_name).CLASS) $(LOCAL_MODULE_CLASS)
ALL_MODULES.$(my_register_name).PATH := \
    $(ALL_MODULES.$(my_register_name).PATH) $(LOCAL_PATH)
ALL_MODULES.$(my_register_name).TAGS := \
    $(ALL_MODULES.$(my_register_name).TAGS) $(my_module_tags)
ALL_MODULES.$(my_register_name).CHECKED := \
    $(ALL_MODULES.$(my_register_name).CHECKED) $(my_checked_module)
ALL_MODULES.$(my_register_name).BUILT := \
    $(ALL_MODULES.$(my_register_name).BUILT) $(LOCAL_BUILT_MODULE)
ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
ALL_MODULES.$(my_register_name).INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).INSTALLED) \
    $(LOCAL_INSTALLED_MODULE) $(my_init_rc_installed) $(my_installed_symlinks) \
    $(my_installed_test_data))
ALL_MODULES.$(my_register_name).BUILT_INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).BUILT_INSTALLED) \
    $(LOCAL_BUILT_MODULE):$(LOCAL_INSTALLED_MODULE) \
    $(my_init_rc_pairs) $(my_test_data_pairs))
endif
ifdef LOCAL_PICKUP_FILES
# Files or directories ready to pick up by the build system
# when $(LOCAL_BUILT_MODULE) is done.
ALL_MODULES.$(my_register_name).PICKUP_FILES := \
    $(ALL_MODULES.$(my_register_name).PICKUP_FILES) $(LOCAL_PICKUP_FILES)
endif
my_required_modules := $(LOCAL_REQUIRED_MODULES) \
    $(LOCAL_REQUIRED_MODULES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
ifdef LOCAL_IS_HOST_MODULE
my_required_modules += $(LOCAL_REQUIRED_MODULES_$($(my_prefix)OS))
endif
ALL_MODULES.$(my_register_name).REQUIRED := \
    $(strip $(ALL_MODULES.$(my_register_name).REQUIRED) $(my_required_modules))
ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED := \
    $(strip $(ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED)\
        $(my_required_modules))
ALL_MODULES.$(my_register_name).TARGET_REQUIRED := \
    $(strip $(ALL_MODULES.$(my_register_name).TARGET_REQUIRED)\
        $(LOCAL_TARGET_REQUIRED_MODULES))
ALL_MODULES.$(my_register_name).HOST_REQUIRED := \
    $(strip $(ALL_MODULES.$(my_register_name).HOST_REQUIRED)\
        $(LOCAL_HOST_REQUIRED_MODULES))
ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS := \
    $(ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS) $(event_log_tags)
ALL_MODULES.$(my_register_name).MAKEFILE := \
    $(ALL_MODULES.$(my_register_name).MAKEFILE) $(LOCAL_MODULE_MAKEFILE)
ifdef LOCAL_MODULE_OWNER
ALL_MODULES.$(my_register_name).OWNER := \
    $(sort $(ALL_MODULES.$(my_register_name).OWNER) $(LOCAL_MODULE_OWNER))
endif
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
ALL_MODULES.$(my_register_name).FOR_2ND_ARCH := true
endif
ALL_MODULES.$(my_register_name).FOR_HOST_CROSS := $(my_host_cross)
ALL_MODULES.$(my_register_name).COMPATIBILITY_SUITES := $(LOCAL_COMPATIBILITY_SUITE)

INSTALLABLE_FILES.$(LOCAL_INSTALLED_MODULE).MODULE := $(my_register_name)

##########################################################
# Track module-level dependencies.
# Use $(LOCAL_MODULE) instead of $(my_register_name) to ignore module's bitness.
ALL_DEPS.MODULES := $(sort $(ALL_DEPS.MODULES) $(LOCAL_MODULE))
ALL_DEPS.$(LOCAL_MODULE).ALL_DEPS := $(sort \
  $(ALL_MODULES.$(LOCAL_MODULE).ALL_DEPS) \
  $(LOCAL_STATIC_LIBRARIES) \
  $(LOCAL_WHOLE_STATIC_LIBRARIES) \
  $(LOCAL_SHARED_LIBRARIES) \
  $(LOCAL_HEADER_LIBRARIES) \
  $(LOCAL_STATIC_JAVA_LIBRARIES) \
  $(LOCAL_JAVA_LIBRARIES)\
  $(LOCAL_JNI_SHARED_LIBRARIES))

ALL_DEPS.$(LOCAL_MODULE).LICENSE := $(sort $(ALL_DEPS.$(LOCAL_MODULE).LICENSE) $(license_files))

###########################################################
## Take care of my_module_tags
###########################################################

# Keep track of all the tags we've seen.
ALL_MODULE_TAGS := $(sort $(ALL_MODULE_TAGS) $(my_module_tags))

# Add this module name to the tag list of each specified tag.
$(foreach tag,$(my_module_tags),\
    $(eval ALL_MODULE_NAME_TAGS.$(tag) := $$(ALL_MODULE_NAME_TAGS.$(tag)) $(my_register_name)))

###########################################################
## umbrella targets used to verify builds
###########################################################
j_or_n :=
ifneq (,$(filter EXECUTABLES SHARED_LIBRARIES STATIC_LIBRARIES HEADER_LIBRARIES NATIVE_TESTS,$(LOCAL_MODULE_CLASS)))
j_or_n := native
else
ifneq (,$(filter JAVA_LIBRARIES APPS,$(LOCAL_MODULE_CLASS)))
j_or_n := java
endif
endif
ifdef LOCAL_IS_HOST_MODULE
h_or_t := host
ifeq ($(my_host_cross),true)
h_or_hc_or_t := host-cross
else
h_or_hc_or_t := host
endif
else
h_or_hc_or_t := target
h_or_t := target
endif


ifdef j_or_n
$(j_or_n) $(h_or_t) $(j_or_n)-$(h_or_hc_or_t) : $(my_checked_module)
ifneq (,$(filter $(my_module_tags),tests))
$(j_or_n)-$(h_or_t)-tests $(j_or_n)-tests $(h_or_t)-tests : $(my_checked_module)
endif
$(LOCAL_MODULE)-$(h_or_hc_or_t) : $(my_all_targets)
ifeq ($(j_or_n),native)
$(LOCAL_MODULE)-$(h_or_hc_or_t)$(my_32_64_bit_suffix) : $(my_all_targets)
endif
endif

###########################################################
# Ensure privileged applications always have LOCAL_PRIVILEGED_MODULE
###########################################################
ifndef LOCAL_PRIVILEGED_MODULE
  ifneq (,$(filter $(TARGET_OUT_APPS_PRIVILEGED)/% $(TARGET_OUT_VENDOR_APPS_PRIVILEGED)/%,$(my_module_path)))
    LOCAL_PRIVILEGED_MODULE := true
  endif
endif

###########################################################
## NOTICE files
###########################################################

include $(BUILD_NOTICE_FILE)
