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
  ifndef _has_warned_about_base_rules_hook
    $(warning base-rules-hook is deprecated, please remove usages of it and/or convert to Soong.)
    _has_warned_about_base_rules_hook := true
  endif
  $(if $(base-rules-hook),)
endif

###########################################################
## Common instructions for a generic module.
###########################################################

LOCAL_MODULE := $(strip $(LOCAL_MODULE))
ifeq ($(LOCAL_MODULE),)
  $(error $(LOCAL_PATH): LOCAL_MODULE is not defined)
endif
$(call verify-module-name)

my_test_data :=
my_test_config :=

LOCAL_IS_HOST_MODULE := $(strip $(LOCAL_IS_HOST_MODULE))
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
  my_prefix := TARGET_
  my_kind :=
  my_host :=
endif

ifeq ($(my_prefix),HOST_CROSS_)
  my_host_cross := true
else
  my_host_cross :=
endif

ifeq (true, $(LOCAL_PRODUCT_MODULE))
ifneq (,$(filter $(LOCAL_MODULE),$(PRODUCT_FORCE_PRODUCT_MODULES_TO_SYSTEM_PARTITION)))
  LOCAL_PRODUCT_MODULE :=
endif
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
else ifneq ($(filter $(TARGET_OUT_SYSTEM_EXT)/%,$(_path)),)
LOCAL_SYSTEM_EXT_MODULE := true
endif
_path :=

# TODO(b/135957588) Remove following workaround
# LOCAL_PRODUCT_SERVICES_MODULE to LOCAL_PRODUCT_MODULE for all Android.mk
ifndef LOCAL_PRODUCT_MODULE
LOCAL_PRODUCT_MODULE := $(LOCAL_PRODUCT_SERVICES_MODULE)
endif

ifndef LOCAL_PROPRIETARY_MODULE
  LOCAL_PROPRIETARY_MODULE := $(LOCAL_VENDOR_MODULE)
endif
ifndef LOCAL_VENDOR_MODULE
  LOCAL_VENDOR_MODULE := $(LOCAL_PROPRIETARY_MODULE)
endif
ifneq ($(filter-out $(LOCAL_PROPRIETARY_MODULE),$(LOCAL_VENDOR_MODULE))$(filter-out $(LOCAL_VENDOR_MODULE),$(LOCAL_PROPRIETARY_MODULE)),)
$(call pretty-error,Only one of LOCAL_PROPRIETARY_MODULE[$(LOCAL_PROPRIETARY_MODULE)] and LOCAL_VENDOR_MODULE[$(LOCAL_VENDOR_MODULE)] may be set, or they must be equal)
endif

ifeq ($(LOCAL_HOST_MODULE),true)
my_image_variant := host
else ifeq ($(LOCAL_VENDOR_MODULE),true)
my_image_variant := vendor
else ifeq ($(LOCAL_OEM_MODULE),true)
my_image_variant := vendor
else ifeq ($(LOCAL_ODM_MODULE),true)
my_image_variant := vendor
else ifeq ($(LOCAL_PRODUCT_MODULE),true)
my_image_variant := product
else
my_image_variant := core
endif

non_system_module := $(filter true, \
   $(LOCAL_PRODUCT_MODULE) \
   $(LOCAL_SYSTEM_EXT_MODULE) \
   $(LOCAL_VENDOR_MODULE) \
   $(LOCAL_PROPRIETARY_MODULE))

include $(BUILD_SYSTEM)/local_vendor_product.mk

# local_current_sdk needs to run before local_systemsdk because the former may override
# LOCAL_SDK_VERSION which is used by the latter.
include $(BUILD_SYSTEM)/local_current_sdk.mk

# Check if the use of System SDK is correct. Note that, for Soong modules, the system sdk version
# check is done in Soong. No need to do it twice.
ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
include $(BUILD_SYSTEM)/local_systemsdk.mk
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

LOCAL_UNINSTALLABLE_MODULE := $(strip $(LOCAL_UNINSTALLABLE_MODULE))

# Only the tags mentioned in this test are expected to be set by module
# makefiles. Anything else is either a typo or a source of unexpected
# behaviors.
ifneq ($(filter-out tests optional samples,$(LOCAL_MODULE_TAGS)),)
$(call pretty-error,unusual tags: $(filter-out tests optional samples,$(LOCAL_MODULE_TAGS)))
endif

LOCAL_MODULE_CLASS := $(strip $(LOCAL_MODULE_CLASS))
ifneq ($(words $(LOCAL_MODULE_CLASS)),1)
  $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS must contain exactly one word, not "$(LOCAL_MODULE_CLASS)")
endif

my_32_64_bit_suffix := $(if $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)IS_64_BIT),64,32)

ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
my_multilib_module_path := $(strip $(LOCAL_MODULE_PATH_$(my_32_64_bit_suffix)))
ifdef my_multilib_module_path
my_module_path := $(my_multilib_module_path)
else
my_module_path := $(strip $(LOCAL_MODULE_PATH))
endif
my_module_path := $(patsubst %/,%,$(my_module_path))
my_module_relative_path := $(strip $(LOCAL_MODULE_RELATIVE_PATH))

ifdef LOCAL_IS_HOST_MODULE
  partition_tag :=
  actual_partition_tag :=
else
ifeq (true,$(strip $(LOCAL_VENDOR_MODULE)))
  partition_tag := _VENDOR
  # A vendor module could be on the vendor partition at "vendor" or the system
  # partition at "system/vendor".
  actual_partition_tag := $(if $(filter true,$(BOARD_USES_VENDORIMAGE)),vendor,system)
else ifeq (true,$(strip $(LOCAL_OEM_MODULE)))
  partition_tag := _OEM
  actual_partition_tag := oem
else ifeq (true,$(strip $(LOCAL_ODM_MODULE)))
  partition_tag := _ODM
  # An ODM module could be on the odm partition at "odm", the vendor partition
  # at "vendor/odm", or the system partition at "system/vendor/odm".
  actual_partition_tag := $(if $(filter true,$(BOARD_USES_ODMIMAGE)),odm,$(if $(filter true,$(BOARD_USES_VENDORIMAGE)),vendor,system))
else ifeq (true,$(strip $(LOCAL_PRODUCT_MODULE)))
  partition_tag := _PRODUCT
  # A product module could be on the product partition at "product" or the
  # system partition at "system/product".
  actual_partition_tag := $(if $(filter true,$(BOARD_USES_PRODUCTIMAGE)),product,system)
else ifeq (true,$(strip $(LOCAL_SYSTEM_EXT_MODULE)))
  partition_tag := _SYSTEM_EXT
  # A system_ext-specific module could be on the system_ext partition at
  # "system_ext" or the system partition at "system/system_ext".
  actual_partition_tag := $(if $(filter true,$(BOARD_USES_SYSTEM_EXTIMAGE)),system_ext,system)
else ifeq (NATIVE_TESTS,$(LOCAL_MODULE_CLASS))
  partition_tag := _DATA
  actual_partition_tag := data
else
  # The definition of should-install-to-system will be different depending
  # on which goal (e.g., sdk or just droid) is being built.
  partition_tag := $(if $(call should-install-to-system,$(LOCAL_MODULE_TAGS)),,_DATA)
  actual_partition_tag := $(if $(partition_tag),data,system)
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
    ifneq ($(filter $(LOCAL_MODULE_TAGS),tests),)
      LOCAL_COMPATIBILITY_SUITE := null-suite
    endif
  endif
endif

use_testcase_folder :=
ifeq ($(my_module_path),)
  ifneq ($(LOCAL_MODULE),$(filter $(LOCAL_MODULE),$(DEFAULT_DATA_OUT_MODULES)))
    ifdef LOCAL_COMPATIBILITY_SUITE
      ifneq (true, $(LOCAL_IS_HOST_MODULE))
        use_testcase_folder := true
      endif
    endif
  endif
endif

ifeq ($(LOCAL_IS_UNIT_TEST),true)
  ifeq ($(LOCAL_IS_HOST_MODULE),true)
    LOCAL_COMPATIBILITY_SUITE += host-unit-tests
  endif
endif

ifeq ($(my_module_path),)
  install_path_var := $(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT$(partition_tag)_$(LOCAL_MODULE_CLASS)
  ifeq (true,$(LOCAL_PRIVILEGED_MODULE))
    install_path_var := $(install_path_var)_PRIVILEGED
  endif

  my_module_path := $($(install_path_var))

  # If use_testcase_folder be set, and LOCAL_MODULE_PATH not set,
  # overwrite the default path under testcase.
  ifeq ($(use_testcase_folder),true)
    arch_dir := $($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
    testcase_folder := $($(my_prefix)OUT_TESTCASES)/$(LOCAL_MODULE)/$(arch_dir)
    my_module_path := $(testcase_folder)
    arch_dir :=
  endif

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

# Make sure that this IS_HOST/CLASS/MODULE combination is unique.
module_id := MODULE.$(if \
    $(LOCAL_IS_HOST_MODULE),$($(my_prefix)OS),TARGET).$(LOCAL_MODULE_CLASS).$(my_register_name)
ifdef $(module_id)
$(error $(LOCAL_PATH): $(module_id) already defined by $($(module_id)))
endif
$(module_id) := $(LOCAL_PATH)

# These are the same as local-intermediates-dir / local-generated-sources dir, but faster
intermediates.COMMON := $($(my_prefix)OUT_COMMON_INTERMEDIATES)/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates
ifneq (,$(filter $(my_prefix)$(LOCAL_MODULE_CLASS),$(COMMON_MODULE_CLASSES)))
  intermediates := $($(my_prefix)OUT_COMMON_INTERMEDIATES)/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates
  generated_sources_dir := $($(my_prefix)OUT_COMMON_GEN)/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates
else
  ifneq (,$(filter $(LOCAL_MODULE_CLASS),$(PER_ARCH_MODULE_CLASSES)))
    intermediates := $($(LOCAL_2ND_ARCH_VAR_PREFIX)$(my_prefix)OUT_INTERMEDIATES)/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates
  else
    intermediates := $($(my_prefix)OUT_INTERMEDIATES)/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates
  endif
  generated_sources_dir := $($(my_prefix)OUT_GEN)/$(LOCAL_MODULE_CLASS)/$(LOCAL_MODULE)_intermediates
endif

ifneq ($(LOCAL_OVERRIDES_MODULES),)
  ifndef LOCAL_IS_HOST_MODULE
    ifeq ($(LOCAL_MODULE_CLASS),EXECUTABLES)
      EXECUTABLES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_MODULES))
    else ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
      SHARED_LIBRARIES.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_MODULES))
    else ifeq ($(LOCAL_MODULE_CLASS),ETC)
      ETC.$(LOCAL_MODULE).OVERRIDES := $(strip $(LOCAL_OVERRIDES_MODULES))
    else
      $(call pretty-error,LOCAL_MODULE_CLASS := $(LOCAL_MODULE_CLASS) cannot use LOCAL_OVERRIDES_MODULES)
    endif
  else
    $(call pretty-error,host modules cannot use LOCAL_OVERRIDES_MODULES)
  endif
endif

###########################################################
# Pick a name for the intermediate and final targets
###########################################################
include $(BUILD_SYSTEM)/configure_module_stem.mk

LOCAL_BUILT_MODULE := $(intermediates)/$(my_built_module_stem)

ifneq (,$(LOCAL_SOONG_INSTALLED_MODULE))
  ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
    $(call pretty-error, LOCAL_SOONG_INSTALLED_MODULE can only be used from $(SOONG_ANDROID_MK))
  endif
  # Use the install path requested by Soong.
  LOCAL_INSTALLED_MODULE := $(LOCAL_SOONG_INSTALLED_MODULE)
else ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  # Apk and its attachments reside in its own subdir.
  ifeq ($(LOCAL_MODULE_CLASS),APPS)
    # framework-res.apk doesn't like the additional layer.
    ifeq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
      # Neither do Runtime Resource Overlay apks, which contain just the overlaid resources.
    else ifeq ($(LOCAL_IS_RUNTIME_RESOURCE_OVERLAY),true)
    else
      ifneq ($(use_testcase_folder),true)
        my_module_path := $(my_module_path)/$(LOCAL_MODULE)
      endif
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
#
# Don't create .toc files for Soong shared libraries, that is handled in
# Soong and soong_cc_prebuilt.mk
###########################################################
ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_BUILT_MODULE).toc
$(LOCAL_BUILT_MODULE).toc: $(LOCAL_BUILT_MODULE)
	$(call $(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)transform-shared-lib-to-toc,$<,$@.tmp)
	$(call commit-change-for-toc,$@)

# Kati adds restat=1 to ninja. GNU make does nothing for this.
.KATI_RESTAT: $(LOCAL_BUILT_MODULE).toc
# Build .toc file when using mm, mma, or make $(my_register_name)
$(my_all_targets): $(LOCAL_BUILT_MODULE).toc
endif
endif

###########################################################
## logtags: Add .logtags files to global list
###########################################################

logtags_sources := $(filter %.logtags,$(LOCAL_SRC_FILES)) $(LOCAL_LOGTAGS_FILES)

ifneq ($(strip $(logtags_sources)),)
event_log_tags := $(foreach f,$(addprefix $(LOCAL_PATH)/,$(logtags_sources)),$(call clean-path,$(f)))
else
event_log_tags :=
endif

###########################################################
## make clean- targets
###########################################################
cleantarget := clean-$(my_register_name)
.PHONY: $(cleantarget)
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
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_HOST:= $(my_host)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_PREFIX := $(my_prefix)
$(LOCAL_INTERMEDIATE_TARGETS) : .KATI_TAGS += ;module_name=$(LOCAL_MODULE)
ifeq ($(LOCAL_MODULE_CLASS),)
$(error "$(LOCAL_MODULE) in $(LOCAL_PATH) does not set $(LOCAL_MODULE_CLASS)")
else
$(LOCAL_INTERMEDIATE_TARGETS) : .KATI_TAGS += ;module_type=$(LOCAL_MODULE_CLASS)
endif

$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_INTERMEDIATES_DIR:= $(intermediates)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_2ND_ARCH_VAR_PREFIX := $(LOCAL_2ND_ARCH_VAR_PREFIX)

# Tell the module and all of its sub-modules who it is.
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_MODULE:= $(my_register_name)

# Provide a short-hand for building this module.
# We name both BUILT and INSTALLED in case
# LOCAL_UNINSTALLABLE_MODULE is set.
.PHONY: $(my_all_targets)
$(my_all_targets): $(LOCAL_BUILT_MODULE) $(LOCAL_INSTALLED_MODULE) $(LOCAL_ADDITIONAL_CHECKED_MODULE)

.PHONY: $(my_register_name)
$(my_register_name): $(my_all_targets)

ifneq ($(my_register_name),$(LOCAL_MODULE))
# $(LOCAL_MODULE) covers all the multilib targets.
.PHONY: $(LOCAL_MODULE)
$(LOCAL_MODULE) : $(my_all_targets)
endif

# Set up phony targets that covers all modules under the given paths.
# This allows us to build everything in given paths by running mmma/mma.
define my_path_comp
parent := $(patsubst %/,%,$(dir $(1)))
parent_target := MODULES-IN-$$(subst /,-,$$(parent))
.PHONY: $$(parent_target)
$$(parent_target): $(2)
ifndef $$(parent_target)
  $$(parent_target) := true
  ifneq (,$$(findstring /,$$(parent)))
    $$(eval $$(call my_path_comp,$$(parent),$$(parent_target)))
  endif
endif
endef

_local_path := $(patsubst %/,%,$(LOCAL_PATH))
_local_path_target := MODULES-IN-$(subst /,-,$(_local_path))

.PHONY: $(_local_path_target)
$(_local_path_target): $(my_register_name)

ifndef $(_local_path_target)
  $(_local_path_target) := true
  ifneq (,$(findstring /,$(_local_path)))
    $(eval $(call my_path_comp,$(_local_path),$(_local_path_target)))
  endif
endif

_local_path :=
_local_path_target :=
my_path_comp :=

###########################################################
## Module installation rule
###########################################################

my_installed_symlinks :=

ifneq (,$(LOCAL_SOONG_INSTALLED_MODULE))
  # Soong already generated the copy rule, but make the installed location depend on the Make
  # copy of the intermediates for now, as some rules that collect intermediates may expect
  # them to exist.
  $(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE)
else ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  $(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := $(LOCAL_POST_INSTALL_CMD)
  $(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE)
	@echo "Install: $@"
  ifeq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
	$(copy-file-or-link-to-new-target)
  else
	$(copy-file-to-new-target)
  endif
	$(PRIVATE_POST_INSTALL_CMD)

  # Rule to install the module's companion symlinks
  my_installed_symlinks := $(addprefix $(my_module_path)/,$(LOCAL_MODULE_SYMLINKS) $(LOCAL_MODULE_SYMLINKS_$(my_32_64_bit_suffix)))
  $(foreach symlink,$(my_installed_symlinks),\
      $(call symlink-file,$(LOCAL_INSTALLED_MODULE),$(my_installed_module_stem),$(symlink))\
      $(call declare-0p-target,$(symlink)))

  $(my_all_targets) : | $(my_installed_symlinks)

endif # !LOCAL_UNINSTALLABLE_MODULE

# Add dependencies on LOCAL_SOONG_INSTALL_SYMLINKS if we're installing any kind of module, not just
# ones that set LOCAL_SOONG_INSTALLED_MODULE. This is so we can have a soong module that only
# installs symlinks (e.g. install_symlink). We can't set LOCAL_SOONG_INSTALLED_MODULE to a symlink
# because cp commands will fail on symlinks.
ifneq (,$(or $(LOCAL_SOONG_INSTALLED_MODULE),$(call boolean-not,$(LOCAL_UNINSTALLABLE_MODULE))))
  $(foreach symlink, $(LOCAL_SOONG_INSTALL_SYMLINKS), $(call declare-0p-target,$(symlink)))
  $(my_all_targets) : | $(LOCAL_SOONG_INSTALL_SYMLINKS)
endif

###########################################################
## VINTF manifest fragment and init.rc goals
###########################################################

my_vintf_installed:=
my_vintf_path:=
my_vintf_pairs:=
my_init_rc_installed :=
my_init_rc_path :=
my_init_rc_pairs :=
ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  ifndef LOCAL_IS_HOST_MODULE
    # Rule to install the module's companion vintf fragments.
    ifneq ($(strip $(LOCAL_FULL_VINTF_FRAGMENTS)),)
      my_vintf_fragments := $(LOCAL_FULL_VINTF_FRAGMENTS)
    else
      my_vintf_fragments := $(foreach xml,$(LOCAL_VINTF_FRAGMENTS),$(LOCAL_PATH)/$(xml))
    endif
    ifneq ($(strip $(my_vintf_fragments)),)
      # Make doesn't support recovery as an output partition, but some Soong modules installed in recovery
      # have init.rc files that need to be installed alongside them. Manually handle the case where the
      # output file is in the recovery partition.
      my_vintf_path := $(if $(filter $(TARGET_RECOVERY_ROOT_OUT)/%,$(my_module_path)),$(TARGET_RECOVERY_ROOT_OUT)/system/etc,$(TARGET_OUT$(partition_tag)_ETC))
      my_vintf_pairs := $(foreach xml,$(my_vintf_fragments),$(xml):$(my_vintf_path)/vintf/manifest/$(notdir $(xml)))
      my_vintf_installed := $(foreach xml,$(my_vintf_pairs),$(call word-colon,2,$(xml)))

      # Only set up copy rules once, even if another arch variant shares it
      my_vintf_new_pairs := $(filter-out $(ALL_VINTF_MANIFEST_FRAGMENTS_LIST),$(my_vintf_pairs))
      ALL_VINTF_MANIFEST_FRAGMENTS_LIST += $(my_vintf_new_pairs)

      ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
        $(call copy-many-vintf-manifest-files-checked,$(my_vintf_new_pairs))
        $(my_all_targets) : $(my_vintf_installed)
        # Install fragments together with the target
        $(LOCAL_INSTALLED_MODULE) : | $(my_vintf_installed)
     endif
    endif # my_vintf_fragments

    # Rule to install the module's companion init.rc.
    ifneq ($(strip $(LOCAL_FULL_INIT_RC)),)
      my_init_rc := $(LOCAL_FULL_INIT_RC)
    else
      my_init_rc := $(foreach rc,$(LOCAL_INIT_RC_$(my_32_64_bit_suffix)) $(LOCAL_INIT_RC),$(LOCAL_PATH)/$(rc))
    endif
    ifneq ($(strip $(my_init_rc)),)
      # Make doesn't support recovery or ramdisk as an output partition,
      # but some Soong modules installed in recovery or ramdisk
      # have init.rc files that need to be installed alongside them.
      # Manually handle the case where the
      # output file is in the recovery or ramdisk partition.
      ifneq (,$(filter $(TARGET_RECOVERY_ROOT_OUT)/%,$(my_module_path)))
        ifneq (,$(filter $(TARGET_RECOVERY_ROOT_OUT)/first_stage_ramdisk/%,$(my_module_path)))
            my_init_rc_path := $(TARGET_RECOVERY_ROOT_OUT)/first_stage_ramdisk/system/etc
        else
            my_init_rc_path := $(TARGET_RECOVERY_ROOT_OUT)/system/etc
        endif
      else ifneq (,$(filter $(TARGET_RAMDISK_OUT)/%,$(my_module_path)))
        my_init_rc_path := $(TARGET_RAMDISK_OUT)/system/etc
      else
        my_init_rc_path := $(TARGET_OUT$(partition_tag)_ETC)
      endif
      my_init_rc_pairs := $(foreach rc,$(my_init_rc),$(rc):$(my_init_rc_path)/init/$(notdir $(rc)))
      my_init_rc_installed := $(foreach rc,$(my_init_rc_pairs),$(call word-colon,2,$(rc)))

      # Make sure we only set up the copy rules once, even if another arch variant
      # shares a common LOCAL_INIT_RC.
      my_init_rc_new_pairs := $(filter-out $(ALL_INIT_RC_INSTALLED_PAIRS),$(my_init_rc_pairs))
      ALL_INIT_RC_INSTALLED_PAIRS += $(my_init_rc_new_pairs)

      ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
        $(call copy-many-init-script-files-checked,$(my_init_rc_new_pairs))
        $(my_all_targets) : $(my_init_rc_installed)
        # Install init_rc together with the target
        $(LOCAL_INSTALLED_MODULE) : | $(my_init_rc_installed)
      endif
    endif # my_init_rc

  endif # !LOCAL_IS_HOST_MODULE
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

my_checked_module += $(LOCAL_ADDITIONAL_CHECKED_MODULE)

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

ifneq ($(strip $(filter NATIVE_TESTS,$(LOCAL_MODULE_CLASS)) $(LOCAL_IS_FUZZ_TARGET)),)
ifneq ($(strip $(LOCAL_TEST_DATA)),)
ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))

# Soong LOCAL_TEST_DATA is of the form <from_base>:<file>:<relative_install_path>
# or <from_base>:<file>, to be installed to
# <install_root>/<relative_install_path>/<file> or <install_root>/<file>,
# respectively.
ifeq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  define copy_test_data_pairs
    _src_base := $$(call word-colon,1,$$(td))
    _file := $$(call word-colon,2,$$(td))
    _relative_install_path := $$(call word-colon,3,$$(td))
    ifeq (,$$(_relative_install_path))
        _relative_dest_file := $$(_file)
    else
        _relative_dest_file := $$(call append-path,$$(_relative_install_path),$$(_file))
    endif
    my_test_data_pairs += $$(call append-path,$$(_src_base),$$(_file)):$$(call append-path,$$(my_module_path),$$(_relative_dest_file))
    my_test_data_file_pairs += $$(call append-path,$$(_src_base),$$(_file)):$$(_relative_dest_file)
  endef
else
  define copy_test_data_pairs
    _src_base := $$(call word-colon,1,$$(td))
    _file := $$(call word-colon,2,$$(td))
    ifndef _file
      _file := $$(_src_base)
      _src_base := $$(LOCAL_PATH)
    endif
    ifneq (,$$(findstring ..,$$(_file)))
      $$(call pretty-error,LOCAL_TEST_DATA may not include '..': $$(_file))
    endif
    ifneq (,$$(filter/%,$$(_src_base) $$(_file)))
      $$(call pretty-error,LOCAL_TEST_DATA may not include absolute paths: $$(_src_base) $$(_file))
    endif
    my_test_data_pairs += $$(call append-path,$$(_src_base),$$(_file)):$$(call append-path,$$(my_module_path),$$(_file))
    my_test_data_file_pairs += $$(call append-path,$$(_src_base),$$(_file)):$$(_file)
  endef
endif

$(foreach td,$(LOCAL_TEST_DATA),$(eval $(copy_test_data_pairs)))

copy_test_data_pairs :=

ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  my_installed_test_data := $(call copy-many-files,$(my_test_data_pairs))
  $(LOCAL_INSTALLED_MODULE): $(my_installed_test_data)
else
  # Skip installing test data for Soong modules, it's already been handled.
  # Just compute my_installed_test_data.
  my_installed_test_data := $(foreach f, $(my_test_data_pairs), $(call word-colon,2,$(f)))
endif

endif
endif
endif

###########################################################
## Compatibility suite files.
###########################################################
ifdef LOCAL_COMPATIBILITY_SUITE

ifneq (,$(LOCAL_FULL_TEST_CONFIG))
  test_config := $(LOCAL_FULL_TEST_CONFIG)
else ifneq (,$(LOCAL_TEST_CONFIG))
  test_config := $(LOCAL_PATH)/$(LOCAL_TEST_CONFIG)
else
  test_config := $(wildcard $(LOCAL_PATH)/AndroidTest.xml)
endif

ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))

# If we are building a native test or benchmark and its stem variants are not defined,
# separate the multiple architectures into subdirectories of the testcase folder.
arch_dir :=
is_native :=
multi_arch :=
ifeq ($(LOCAL_MODULE_CLASS),NATIVE_TESTS)
  is_native := true
  multi_arch := true
endif
ifdef LOCAL_MULTILIB
  multi_arch := true
# These conditionals allow this functionality to be mimicked in Soong
else ifeq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
  ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
    multi_arch := true
  endif
endif

ifdef multi_arch
arch_dir := /$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
else
ifeq ($(use_testcase_folder),true)
  arch_dir := /$($(my_prefix)$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)
endif
endif

multi_arch :=

my_default_test_module :=
my_default_test_module := $($(my_prefix)OUT_TESTCASES)/$(LOCAL_MODULE)$(arch_dir)/$(my_installed_module_stem)
ifneq ($(LOCAL_INSTALLED_MODULE),$(my_default_test_module))
# Install into the testcase folder
$(LOCAL_INSTALLED_MODULE) : $(my_default_test_module)
endif

# The module itself.
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_$(suite) := $(patsubst %:$(LOCAL_INSTALLED_MODULE),$(LOCAL_INSTALLED_MODULE):$(LOCAL_INSTALLED_MODULE),\
    $(foreach dir, $(call compatibility_suite_dirs,$(suite),$(arch_dir)), \
      $(LOCAL_BUILT_MODULE):$(dir)/$(my_installed_module_stem)))) \
  $(eval my_compat_dist_config_$(suite) := ))


# Auto-generate build config.
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

# Currently this flag variable is true only for the `android_test_helper_app` type module
# which should not have any .config file
ifeq (true, $(LOCAL_DISABLE_TEST_CONFIG))
  test_config :=
endif

# Make sure we only add the files once for multilib modules.
ifdef $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files
  # Sync the auto_test_config value for multilib modules.
  ifdef $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_autogen
    ALL_MODULES.$(my_register_name).auto_test_config := true
  endif
else
  $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files := true
  # LOCAL_COMPATIBILITY_SUPPORT_FILES is a list of <src>[:<dest>].
  $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
    $(eval my_compat_dist_$(suite) += $(foreach f, $(LOCAL_COMPATIBILITY_SUPPORT_FILES), \
      $(eval p := $(subst :,$(space),$(f))) \
      $(eval s := $(word 1,$(p))) \
      $(eval n := $(or $(word 2,$(p)),$(notdir $(word 1, $(p))))) \
      $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
        $(s):$(dir)/$(n)))))

  ifneq (,$(test_config))
    $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
      $(eval my_compat_dist_config_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
        $(test_config):$(dir)/$(LOCAL_MODULE).config$(LOCAL_TEST_CONFIG_SUFFIX))))
  endif

  ifneq (,$(LOCAL_EXTRA_FULL_TEST_CONFIGS))
    $(foreach test_config_file, $(LOCAL_EXTRA_FULL_TEST_CONFIGS), \
      $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
        $(eval my_compat_dist_config_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
          $(test_config_file):$(dir)/$(basename $(notdir $(test_config_file))).config))))
  endif

  ifneq (,$(wildcard $(LOCAL_PATH)/DynamicConfig.xml))
    $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
      $(eval my_compat_dist_config_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
        $(LOCAL_PATH)/DynamicConfig.xml:$(dir)/$(LOCAL_MODULE).dynamic)))
  endif

  ifneq (,$(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE)_*.config))
  $(foreach extra_config, $(wildcard $(LOCAL_PATH)/$(LOCAL_MODULE)_*.config), \
    $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
      $(eval my_compat_dist_config_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite)), \
        $(extra_config):$(dir)/$(notdir $(extra_config))))))
  endif
endif # $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files


ifeq ($(use_testcase_folder),true)
ifneq ($(my_test_data_file_pairs),)
# Filter out existng installed test data paths when collecting test data files to be installed and
# indexed as they cause build rule conflicts. Instead put them in a separate list which is only
# used for indexing.
$(foreach pair, $(my_test_data_file_pairs), \
  $(eval parts := $(subst :,$(space),$(pair))) \
  $(eval src_path := $(word 1,$(parts))) \
  $(eval file := $(word 2,$(parts))) \
  $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
    $(eval my_compat_dist_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite),$(arch_dir)), \
      $(call filter-copy-pair,$(src_path),$(call append-path,$(dir),$(file)),$(my_installed_test_data)))) \
    $(eval my_compat_dist_test_data_$(suite) += \
      $(foreach dir, $(call compatibility_suite_dirs,$(suite),$(arch_dir)), \
        $(filter $(my_installed_test_data),$(call append-path,$(dir),$(file)))))))
endif
else
ifneq ($(my_test_data_file_pairs),)
$(foreach pair, $(my_test_data_file_pairs), \
  $(eval parts := $(subst :,$(space),$(pair))) \
  $(eval src_path := $(word 1,$(parts))) \
  $(eval file := $(word 2,$(parts))) \
  $(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
    $(eval my_compat_dist_$(suite) += $(foreach dir, $(call compatibility_suite_dirs,$(suite),$(arch_dir)), \
      $(src_path):$(call append-path,$(dir),$(file))))))
endif
endif



arch_dir :=
is_native :=

$(call create-suite-dependencies)
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval my_compat_dist_config_$(suite) := ) \
  $(eval my_compat_dist_test_data_$(suite) := ))

endif  # LOCAL_UNINSTALLABLE_MODULE

# HACK: pretend a soong LOCAL_FULL_TEST_CONFIG is autogenerated by setting the flag in
# module-info.json
# TODO: (b/113029686) Add explicit flag from Soong to determine if a test was
# autogenerated.
ifneq (,$(filter $(SOONG_OUT_DIR)%,$(LOCAL_FULL_TEST_CONFIG)))
  ifeq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
    ALL_MODULES.$(my_register_name).auto_test_config := true
  endif
endif

endif  # LOCAL_COMPATIBILITY_SUITE

my_supported_variant :=
ifeq ($(my_host_cross),true)
  my_supported_variant := HOST_CROSS
else
  ifdef LOCAL_IS_HOST_MODULE
    my_supported_variant := HOST
  else
    my_supported_variant := DEVICE
  endif
endif
###########################################################
## Add test module to ALL_DISABLED_PRESUBMIT_TESTS if LOCAL_PRESUBMIT_DISABLED is set to true.
###########################################################
ifeq ($(LOCAL_PRESUBMIT_DISABLED),true)
  ALL_DISABLED_PRESUBMIT_TESTS += $(LOCAL_MODULE)
endif  # LOCAL_PRESUBMIT_DISABLED

###########################################################
## Register with ALL_MODULES
###########################################################

ifndef ALL_MODULES.$(my_register_name).PATH
    # These keys are no longer used, they've been replaced by keys that specify
    # target/host/host_cross (REQUIRED_FROM_TARGET / REQUIRED_FROM_HOST) and similar.
    #
    # Marking them obsolete to ensure that anyone using these internal variables looks for
    # alternates.
    $(KATI_obsolete_var ALL_MODULES.$(my_register_name).REQUIRED)
    $(KATI_obsolete_var ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED)
    $(KATI_obsolete_var ALL_MODULES.$(my_register_name).HOST_REQUIRED)
    $(KATI_obsolete_var ALL_MODULES.$(my_register_name).TARGET_REQUIRED)
endif

ALL_MODULES += $(my_register_name)

# Don't use += on subvars, or else they'll end up being
# recursively expanded.
ALL_MODULES.$(my_register_name).CLASS := \
    $(ALL_MODULES.$(my_register_name).CLASS) $(LOCAL_MODULE_CLASS)
ALL_MODULES.$(my_register_name).PATH := \
    $(ALL_MODULES.$(my_register_name).PATH) $(LOCAL_PATH)
ALL_MODULES.$(my_register_name).TAGS := \
    $(ALL_MODULES.$(my_register_name).TAGS) $(LOCAL_MODULE_TAGS)
ALL_MODULES.$(my_register_name).CHECKED := \
    $(ALL_MODULES.$(my_register_name).CHECKED) $(my_checked_module)
ALL_MODULES.$(my_register_name).BUILT := \
    $(ALL_MODULES.$(my_register_name).BUILT) $(LOCAL_BUILT_MODULE)
ALL_MODULES.$(my_register_name).SOONG_MODULE_TYPE := \
    $(ALL_MODULES.$(my_register_name).SOONG_MODULE_TYPE) $(LOCAL_SOONG_MODULE_TYPE)
ifndef LOCAL_IS_HOST_MODULE
ALL_MODULES.$(my_register_name).TARGET_BUILT := \
    $(ALL_MODULES.$(my_register_name).TARGET_BUILT) $(LOCAL_BUILT_MODULE)
endif
ifneq (,$(LOCAL_SOONG_INSTALLED_MODULE))
  # Store the list of paths to installed locations of files provided by this
  # module.  Used as dependencies of the image packaging rules when the module
  # is installed by the current product.
  ALL_MODULES.$(my_register_name).INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).INSTALLED) \
      $(foreach f, $(LOCAL_SOONG_INSTALL_PAIRS),\
        $(word 2,$(subst :,$(space),$(f)))) \
      $(LOCAL_SOONG_INSTALL_SYMLINKS) \
      $(my_init_rc_installed) \
      $(my_installed_test_data) \
      $(my_vintf_installed))

  ALL_MODULES.$(my_register_name).INSTALLED_SYMLINKS := $(LOCAL_SOONG_INSTALL_SYMLINKS)

  # Store the list of colon-separated pairs of the built and installed locations
  # of files provided by this module.  Used by custom packaging rules like
  # package-modules.mk that need to copy the built files to a custom install
  # location during packaging.
  #
  # Translate copies from $(LOCAL_PREBUILT_MODULE_FILE) to $(LOCAL_BUILT_MODULE)
  # so that package-modules.mk gets any transtive dependencies added to
  # $(LOCAL_BUILT_MODULE), for example unstripped symbols files.
  ALL_MODULES.$(my_register_name).BUILT_INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).BUILT_INSTALLED) \
      $(patsubst $(LOCAL_PREBUILT_MODULE_FILE):%,$(LOCAL_BUILT_MODULE):%,$(LOCAL_SOONG_INSTALL_PAIRS)) \
      $(my_init_rc_pairs) \
      $(my_test_data_pairs) \
      $(my_vintf_pairs))
  # Store the list of vintf/init_rc as order-only dependencies
  ALL_MODULES.$(my_register_name).ORDERONLY_INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).ORDERONLY_INSTALLED) \
      $(my_init_rc_installed) \
      $(my_vintf_installed))
else ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  ALL_MODULES.$(my_register_name).INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).INSTALLED) \
    $(LOCAL_INSTALLED_MODULE) $(my_init_rc_installed) $(my_installed_symlinks) \
    $(my_installed_test_data) $(my_vintf_installed))
  ALL_MODULES.$(my_register_name).BUILT_INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).BUILT_INSTALLED) \
    $(LOCAL_BUILT_MODULE):$(LOCAL_INSTALLED_MODULE) \
    $(my_init_rc_pairs) $(my_test_data_pairs) $(my_vintf_pairs))
  ALL_MODULES.$(my_register_name).ORDERONLY_INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).ORDERONLY_INSTALLED) \
      $(my_init_rc_installed) \
      $(my_vintf_installed))
endif

# Mark LOCAL_SOONG_INSTALL_SYMLINKS as installed if we're installing any kind of module, not just
# ones that set LOCAL_SOONG_INSTALLED_MODULE. This is so we can have a soong module that only
# installs symlinks (e.g. installed_symlink). We can't set LOCAL_SOONG_INSTALLED_MODULE to a symlink
# because cp commands will fail on symlinks.
ifneq (,$(or $(LOCAL_SOONG_INSTALLED_MODULE),$(call boolean-not,$(LOCAL_UNINSTALLABLE_MODULE))))
  ALL_MODULES.$(my_register_name).INSTALLED += $(LOCAL_SOONG_INSTALL_SYMLINKS)
  ALL_MODULES.$(my_register_name).INSTALLED_SYMLINKS := $(LOCAL_SOONG_INSTALL_SYMLINKS)
endif

ifdef LOCAL_PICKUP_FILES
# Files or directories ready to pick up by the build system
# when $(LOCAL_BUILT_MODULE) is done.
ALL_MODULES.$(my_register_name).PICKUP_FILES := \
    $(ALL_MODULES.$(my_register_name).PICKUP_FILES) $(LOCAL_PICKUP_FILES)
endif
# Record the platform availability of this module. Note that the availability is not
# meaningful for non-installable modules (e.g., static libs) or host modules.
# We only care about modules that are installable to the device.
ifeq (true,$(LOCAL_NOT_AVAILABLE_FOR_PLATFORM))
  ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
    ifndef LOCAL_IS_HOST_MODULE
      ALL_MODULES.$(my_register_name).NOT_AVAILABLE_FOR_PLATFORM := true
    endif
  endif
endif

my_required_modules := $(LOCAL_REQUIRED_MODULES) \
    $(LOCAL_REQUIRED_MODULES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH))
ifdef LOCAL_IS_HOST_MODULE
my_required_modules += $(LOCAL_REQUIRED_MODULES_$($(my_prefix)OS))
endif

ifdef LOCAL_ACONFIG_FILES
  ALL_MODULES.$(my_register_name).ACONFIG_FILES := \
      $(ALL_MODULES.$(my_register_name).ACONFIG_FILES) $(LOCAL_ACONFIG_FILES)
endif

ifndef LOCAL_SOONG_MODULE_INFO_JSON
  ALL_MAKE_MODULE_INFO_JSON_MODULES += $(my_register_name)
  ALL_MODULES.$(my_register_name).SHARED_LIBS := \
      $(ALL_MODULES.$(my_register_name).SHARED_LIBS) $(LOCAL_SHARED_LIBRARIES)

  ALL_MODULES.$(my_register_name).STATIC_LIBS := \
      $(ALL_MODULES.$(my_register_name).STATIC_LIBS) $(LOCAL_STATIC_LIBRARIES)

  ALL_MODULES.$(my_register_name).SYSTEM_SHARED_LIBS := \
      $(ALL_MODULES.$(my_register_name).SYSTEM_SHARED_LIBS) $(LOCAL_SYSTEM_SHARED_LIBRARIES)

  ALL_MODULES.$(my_register_name).LOCAL_RUNTIME_LIBRARIES := \
      $(ALL_MODULES.$(my_register_name).LOCAL_RUNTIME_LIBRARIES) $(LOCAL_RUNTIME_LIBRARIES) \
      $(LOCAL_JAVA_LIBRARIES)

  ALL_MODULES.$(my_register_name).LOCAL_STATIC_LIBRARIES := \
      $(ALL_MODULES.$(my_register_name).LOCAL_STATIC_LIBRARIES) $(LOCAL_STATIC_JAVA_LIBRARIES)

  ifneq ($(my_test_data_file_pairs),)
    # Export the list of targets that are handled as data inputs and required
    # by tests at runtime. The format of my_test_data_file_pairs is
    # is $(path):$(relative_file) but for module-info, only the string after
    # ":" is needed.
    ALL_MODULES.$(my_register_name).TEST_DATA := \
      $(strip $(ALL_MODULES.$(my_register_name).TEST_DATA) \
        $(foreach f, $(my_test_data_file_pairs),\
          $(call word-colon,2,$(f))))
  endif

  ifdef LOCAL_TEST_DATA_BINS
    ALL_MODULES.$(my_register_name).TEST_DATA_BINS := \
        $(ALL_MODULES.$(my_register_name).TEST_DATA_BINS) $(LOCAL_TEST_DATA_BINS)
  endif

  ALL_MODULES.$(my_register_name).SUPPORTED_VARIANTS := \
      $(ALL_MODULES.$(my_register_name).SUPPORTED_VARIANTS) \
      $(filter-out $(ALL_MODULES.$(my_register_name).SUPPORTED_VARIANTS),$(my_supported_variant))

  ALL_MODULES.$(my_register_name).COMPATIBILITY_SUITES := \
      $(ALL_MODULES.$(my_register_name).COMPATIBILITY_SUITES) $(LOCAL_COMPATIBILITY_SUITE)
  ALL_MODULES.$(my_register_name).MODULE_NAME := $(LOCAL_MODULE)
  ALL_MODULES.$(my_register_name).TEST_CONFIG := $(test_config)
  ALL_MODULES.$(my_register_name).EXTRA_TEST_CONFIGS := $(LOCAL_EXTRA_FULL_TEST_CONFIGS)
  ALL_MODULES.$(my_register_name).TEST_MAINLINE_MODULES := $(LOCAL_TEST_MAINLINE_MODULES)
  ifdef LOCAL_IS_UNIT_TEST
    ALL_MODULES.$(my_register_name).IS_UNIT_TEST := $(LOCAL_IS_UNIT_TEST)
  endif
  ifdef LOCAL_TEST_OPTIONS_TAGS
    ALL_MODULES.$(my_register_name).TEST_OPTIONS_TAGS := $(LOCAL_TEST_OPTIONS_TAGS)
  endif

  ##########################################################
  # Track module-level dependencies.
  # (b/204397180) Unlock RECORD_ALL_DEPS was acknowledged reasonable for better Atest performance.
  ALL_MODULES.$(my_register_name).ALL_DEPS := \
    $(ALL_MODULES.$(my_register_name).ALL_DEPS) \
    $(LOCAL_STATIC_LIBRARIES) \
    $(LOCAL_WHOLE_STATIC_LIBRARIES) \
    $(LOCAL_SHARED_LIBRARIES) \
    $(LOCAL_DYLIB_LIBRARIES) \
    $(LOCAL_RLIB_LIBRARIES) \
    $(LOCAL_PROC_MACRO_LIBRARIES) \
    $(LOCAL_HEADER_LIBRARIES) \
    $(LOCAL_STATIC_JAVA_LIBRARIES) \
    $(LOCAL_JAVA_LIBRARIES) \
    $(LOCAL_JNI_SHARED_LIBRARIES)

endif

##########################################################################
## When compiling against API imported module, use API import stub
## libraries.
##########################################################################
ifneq ($(call module-in-vendor-or-product),)
  ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
    apiimport_postfix := .apiimport
    ifeq ($(LOCAL_IN_PRODUCT),true)
      apiimport_postfix := .apiimport.product
    else
      apiimport_postfix := .apiimport.vendor
    endif

    my_required_modules := $(foreach l,$(my_required_modules), \
      $(if $(filter $(l), $(API_IMPORTED_SHARED_LIBRARIES)), $(l)$(apiimport_postfix), $(l)))
  endif
endif

##########################################################################
## When compiling against the VNDK, add the .vendor or .product suffix to
## required modules.
##########################################################################
ifneq ($(call module-in-vendor-or-product),)
  #####################################################
  ## Soong modules may be built three times, once for
  ## /system, once for /vendor and once for /product.
  ## If we're using the VNDK, switch all soong
  ## libraries over to the /vendor or /product variant.
  #####################################################
  ifneq ($(LOCAL_MODULE_MAKEFILE),$(SOONG_ANDROID_MK))
    # We don't do this renaming for soong-defined modules since they already
    # have correct names (with .vendor or .product suffix when necessary) in
    # their LOCAL_*_LIBRARIES.
    ifeq ($(LOCAL_IN_PRODUCT),true)
      my_required_modules := $(foreach l,$(my_required_modules),\
        $(if $(SPLIT_PRODUCT.SHARED_LIBRARIES.$(l)),$(l).product,$(l)))
    else
      my_required_modules := $(foreach l,$(my_required_modules),\
        $(if $(SPLIT_VENDOR.SHARED_LIBRARIES.$(l)),$(l).vendor,$(l)))
    endif
  endif
endif

ifdef LOCAL_IS_HOST_MODULE
    ifneq ($(my_host_cross),true)
        ALL_MODULES.$(my_register_name).REQUIRED_FROM_HOST := \
            $(strip $(ALL_MODULES.$(my_register_name).REQUIRED_FROM_HOST) $(my_required_modules))
        ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED_FROM_HOST := \
            $(strip $(ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED_FROM_HOST)\
                $(my_required_modules))
        ALL_MODULES.$(my_register_name).TARGET_REQUIRED_FROM_HOST := \
            $(strip $(ALL_MODULES.$(my_register_name).TARGET_REQUIRED_FROM_HOST)\
                $(LOCAL_TARGET_REQUIRED_MODULES))
    else
        ALL_MODULES.$(my_register_name).REQUIRED_FROM_HOST_CROSS := \
            $(strip $(ALL_MODULES.$(my_register_name).REQUIRED_FROM_HOST_CROSS) $(my_required_modules))
        ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED_FROM_HOST_CROSS := \
            $(strip $(ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED_FROM_HOST_CROSS)\
                $(my_required_modules))
        ifdef LOCAL_TARGET_REQUIRED_MODULES
            $(call pretty-error,LOCAL_TARGET_REQUIRED_MODULES may not be used from host_cross modules)
        endif
    endif
    ifdef LOCAL_HOST_REQUIRED_MODULES
        $(call pretty-error,LOCAL_HOST_REQUIRED_MODULES may not be used from host modules. Use LOCAL_REQUIRED_MODULES instead)
    endif
else
    ALL_MODULES.$(my_register_name).REQUIRED_FROM_TARGET := \
        $(strip $(ALL_MODULES.$(my_register_name).REQUIRED_FROM_TARGET) $(my_required_modules))
    ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED_FROM_TARGET := \
        $(strip $(ALL_MODULES.$(my_register_name).EXPLICITLY_REQUIRED_FROM_TARGET)\
            $(my_required_modules))
    ALL_MODULES.$(my_register_name).HOST_REQUIRED_FROM_TARGET := \
        $(strip $(ALL_MODULES.$(my_register_name).HOST_REQUIRED_FROM_TARGET)\
            $(LOCAL_HOST_REQUIRED_MODULES))
    ifdef LOCAL_TARGET_REQUIRED_MODULES
        $(call pretty-error,LOCAL_TARGET_REQUIRED_MODULES may not be used from target modules. Use LOCAL_REQUIRED_MODULES instead)
    endif
endif

ifdef event_log_tags
  ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS := \
      $(ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS) $(event_log_tags)
endif

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
ifndef LOCAL_IS_HOST_MODULE
ALL_MODULES.$(my_register_name).APEX_KEYS_FILE := $(LOCAL_APEX_KEY_PATH)
endif
test_config :=

INSTALLABLE_FILES.$(LOCAL_INSTALLED_MODULE).MODULE := $(my_register_name)

###########################################################
## umbrella targets used to verify builds
###########################################################
j_or_n :=
ifneq (,$(filter EXECUTABLES SHARED_LIBRARIES STATIC_LIBRARIES HEADER_LIBRARIES NATIVE_TESTS RLIB_LIBRARIES DYLIB_LIBRARIES PROC_MACRO_LIBRARIES,$(LOCAL_MODULE_CLASS)))
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
ifneq (,$(filter $(LOCAL_MODULE_TAGS),tests))
$(j_or_n)-$(h_or_t)-tests $(j_or_n)-tests $(h_or_t)-tests : $(my_checked_module)
endif
$(LOCAL_MODULE)-$(h_or_hc_or_t) : $(my_all_targets)
.PHONY: $(LOCAL_MODULE)-$(h_or_hc_or_t)
ifeq ($(j_or_n),native)
$(LOCAL_MODULE)-$(h_or_hc_or_t)$(my_32_64_bit_suffix) : $(my_all_targets)
.PHONY: $(LOCAL_MODULE)-$(h_or_hc_or_t)$(my_32_64_bit_suffix)
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

###########################################################
## SBOM generation
###########################################################
include $(BUILD_SBOM_GEN)
