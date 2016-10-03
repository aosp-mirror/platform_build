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
else
  my_prefix := TARGET_
  my_host :=
endif

ifeq ($(my_prefix),HOST_CROSS_)
  my_host_cross := true
else
  my_host_cross :=
endif

my_module_tags := $(LOCAL_MODULE_TAGS)
ifeq ($(my_host_cross),true)
  my_module_tags :=
endif

ifdef BUILDING_WITH_NINJA
# Ninja has an implicit dependency on the command being run, and kati will
# regenerate the ninja manifest if any read makefile changes, so there is no
# need to have dependencies on makefiles.
# This won't catch all the cases where LOCAL_ADDITIONAL_DEPENDENCIES contains
# a .mk file, because a few users of LOCAL_ADDITIONAL_DEPENDENCIES don't include
# base_rules.mk, but it will fix the most common ones.
LOCAL_ADDITIONAL_DEPENDENCIES := $(filter-out %.mk,$(LOCAL_ADDITIONAL_DEPENDENCIES))
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
$(warning unusual tags $(my_module_tags) on $(LOCAL_MODULE) at $(LOCAL_PATH))
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
my_multilib_module_path := $(strip $(LOCAL_MODULE_PATH_$(my_32_64_bit_suffix)))
ifdef my_multilib_module_path
my_module_path := $(my_multilib_module_path)
else
my_module_path := $(strip $(LOCAL_MODULE_PATH))
endif
my_module_relative_path := $(strip $(LOCAL_MODULE_RELATIVE_PATH))
ifeq ($(my_module_path),)
  ifdef LOCAL_IS_HOST_MODULE
    partition_tag :=
  else
  ifeq (true,$(LOCAL_PROPRIETARY_MODULE))
    partition_tag := _VENDOR
  else ifeq (true,$(LOCAL_OEM_MODULE))
    partition_tag := _OEM
  else ifeq (true,$(LOCAL_ODM_MODULE))
    partition_tag := _ODM
  else
    # The definition of should-install-to-system will be different depending
    # on which goal (e.g., sdk or just droid) is being built.
    partition_tag := $(if $(call should-install-to-system,$(my_module_tags)),,_DATA)
  endif
  endif
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
# Make sure that this IS_HOST/CLASS/MODULE combination is unique.
module_id := MODULE.$(if \
    $(LOCAL_IS_HOST_MODULE),$($(my_prefix)OS),TARGET).$(LOCAL_MODULE_CLASS).$(my_register_name)
ifdef $(module_id)
$(error $(LOCAL_PATH): $(module_id) already defined by $($(module_id)))
endif
$(module_id) := $(LOCAL_PATH)

intermediates := $(call local-intermediates-dir,,$(LOCAL_2ND_ARCH_VAR_PREFIX),$(my_host_cross))
intermediates.COMMON := $(call local-intermediates-dir,COMMON)
generated_sources_dir := $(call local-generated-sources-dir)

###########################################################
# Pick a name for the intermediate and final targets
###########################################################
include $(BUILD_SYSTEM)/configure_module_stem.mk

# OVERRIDE_BUILT_MODULE_PATH is only allowed to be used by the
# internal SHARED_LIBRARIES build files.
OVERRIDE_BUILT_MODULE_PATH := $(strip $(OVERRIDE_BUILT_MODULE_PATH))
ifdef OVERRIDE_BUILT_MODULE_PATH
  ifneq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
    $(error $(LOCAL_PATH): Illegal use of OVERRIDE_BUILT_MODULE_PATH)
  endif
  built_module_path := $(OVERRIDE_BUILT_MODULE_PATH)
else
  built_module_path := $(intermediates)
endif
LOCAL_BUILT_MODULE := $(built_module_path)/$(my_built_module_stem)

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
ifndef LOCAL_IS_HOST_MODULE
# Disable .toc optimization for host modules: we may run the host binaries during the build process
# and the libraries' implementation matters.
ifeq ($(LOCAL_MODULE_CLASS),SHARED_LIBRARIES)
LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_BUILT_MODULE).toc
$(LOCAL_BUILT_MODULE).toc: $(LOCAL_BUILT_MODULE)
	$(call $(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)transform-shared-lib-to-toc,$<,$@.tmp)
	$(call commit-change-for-toc,$@)

# Kati adds restat=1 to ninja. GNU make does nothing for this.
.KATI_RESTAT: $(LOCAL_BUILT_MODULE).toc
# Build .toc file when using mm, mma, or make $(my_register_name)
$(my_register_name): $(LOCAL_BUILT_MODULE).toc
endif
endif

###########################################################
## logtags: Add .logtags files to global list
###########################################################

logtags_sources := $(filter %.logtags,$(LOCAL_SRC_FILES))

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
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_HOST:= $(my_host)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_PREFIX := $(my_prefix)

$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_INTERMEDIATES_DIR:= $(intermediates)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_2ND_ARCH_VAR_PREFIX := $(LOCAL_2ND_ARCH_VAR_PREFIX)

# Tell the module and all of its sub-modules who it is.
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_MODULE:= $(my_register_name)

# Provide a short-hand for building this module.
# We name both BUILT and INSTALLED in case
# LOCAL_UNINSTALLABLE_MODULE is set.
.PHONY: $(my_register_name)
$(my_register_name): $(LOCAL_BUILT_MODULE) $(LOCAL_INSTALLED_MODULE)

# Set up phony targets that covers all modules under the given paths.
# This allows us to build everything in given paths by running mmma/mma.
my_path_components := $(subst /,$(space),$(LOCAL_PATH))
my_path_prefix := MODULES-IN
$(foreach c, $(my_path_components),\
  $(eval my_path_prefix := $(my_path_prefix)-$(c))\
  $(eval .PHONY : $(my_path_prefix))\
  $(eval $(my_path_prefix) : $(my_register_name)))

###########################################################
## Module installation rule
###########################################################

# Some hosts do not have ACP; override the LOCAL version if that's the case.
ifneq ($(strip $(HOST_ACP_UNAVAILABLE)),)
  LOCAL_ACP_UNAVAILABLE := $(strip $(HOST_ACP_UNAVAILABLE))
endif

ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
  # Define a copy rule to install the module.
  # acp and libraries that it uses can't use acp for
  # installation;  hence, LOCAL_ACP_UNAVAILABLE.
$(LOCAL_INSTALLED_MODULE): PRIVATE_POST_INSTALL_CMD := $(LOCAL_POST_INSTALL_CMD)
ifneq ($(LOCAL_ACP_UNAVAILABLE),true)
$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE) | $(ACP)
	@echo "Install: $@"
	$(copy-file-to-new-target)
	$(PRIVATE_POST_INSTALL_CMD)
else
$(LOCAL_INSTALLED_MODULE): $(LOCAL_BUILT_MODULE)
	@echo "Install: $@"
	$(copy-file-to-target-with-cp)
endif

# Rule to install the module's companion init.rc.
my_init_rc := $(LOCAL_INIT_RC_$(my_32_64_bit_suffix))
my_init_rc_src :=
my_init_rc_installed :=
ifndef my_init_rc
my_init_rc := $(LOCAL_INIT_RC)
# Make sure we don't define the rule twice in multilib module.
LOCAL_INIT_RC :=
endif
ifdef my_init_rc
my_init_rc_src := $(LOCAL_PATH)/$(my_init_rc)
my_init_rc_installed := $(TARGET_OUT$(partition_tag)_ETC)/init/$(notdir $(my_init_rc_src))
$(my_init_rc_installed) : $(my_init_rc_src) | $(ACP)
	@echo "Install: $@"
	$(copy-file-to-new-target)

$(my_register_name) : $(my_init_rc_installed)
endif # my_init_rc
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
## Compatibiliy suite files.
###########################################################
ifdef LOCAL_COMPATIBILITY_SUITE
ifneq ($(words $(LOCAL_COMPATIBILITY_SUITE)),1)
$(error $(LOCAL_PATH):$(LOCAL_MODULE) LOCAL_COMPATIBILITY_SUITE can be only one name)
endif

# The module itself.
my_compat_dist := \
  $(LOCAL_BUILT_MODULE):$(COMPATIBILITY_TESTCASES_OUT_$(LOCAL_COMPATIBILITY_SUITE))/$(my_installed_module_stem)

# Make sure we only add the files once for multilib modules.
ifndef $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files
$(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files := true

# LOCAL_COMPATIBILITY_SUPPORT_FILES is a list of <src>[:<dest>].
my_compat_dist += $(foreach f, $(LOCAL_COMPATIBILITY_SUPPORT_FILES),\
  $(eval p := $(subst :,$(space),$(f)))\
  $(eval s := $(word 1,$(p)))\
  $(eval d := $(COMPATIBILITY_TESTCASES_OUT_$(LOCAL_COMPATIBILITY_SUITE))/$(or $(word 2,$(p)),$(notdir $(word 1,$(p)))))\
  $(s):$(d))

ifneq (,$(wildcard $(LOCAL_PATH)/AndroidTest.xml))
my_compat_dist += \
  $(LOCAL_PATH)/AndroidTest.xml:$(COMPATIBILITY_TESTCASES_OUT_$(LOCAL_COMPATIBILITY_SUITE))/$(LOCAL_MODULE).config
endif

ifneq (,$(wildcard $(LOCAL_PATH)/DynamicConfig.xml))
my_compat_dist += \
  $(LOCAL_PATH)/DynamicConfig.xml:$(COMPATIBILITY_TESTCASES_OUT_$(LOCAL_COMPATIBILITY_SUITE))/$(LOCAL_MODULE).dynamic
endif
endif # $(my_prefix)$(LOCAL_MODULE_CLASS)_$(LOCAL_MODULE)_compat_files

my_compat_files := $(call copy-many-files, $(my_compat_dist))

COMPATIBILITY.$(LOCAL_COMPATIBILITY_SUITE).FILES := \
  $(COMPATIBILITY.$(LOCAL_COMPATIBILITY_SUITE).FILES) \
  $(my_compat_files)

# Copy over the compatibility files when user runs mm/mmm.
$(my_register_name) : $(my_compat_files)
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
    $(LOCAL_INSTALLED_MODULE) $(my_init_rc_installed))
ALL_MODULES.$(my_register_name).BUILT_INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).BUILT_INSTALLED) \
    $(LOCAL_BUILT_MODULE):$(LOCAL_INSTALLED_MODULE) \
    $(addprefix $(my_init_rc_src):,$(my_init_rc_installed)))
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
    $(eval ALL_MODULE_NAME_TAGS.$(tag) += $(my_register_name)))

###########################################################
## umbrella targets used to verify builds
###########################################################
j_or_n :=
ifneq (,$(filter EXECUTABLES SHARED_LIBRARIES STATIC_LIBRARIES,$(LOCAL_MODULE_CLASS)))
j_or_n := native
else
ifneq (,$(filter JAVA_LIBRARIES APPS,$(LOCAL_MODULE_CLASS)))
j_or_n := java
endif
endif
ifdef LOCAL_IS_HOST_MODULE
h_or_t := host
else
h_or_t := target
endif

ifdef j_or_n
$(j_or_n) $(h_or_t) $(j_or_n)-$(h_or_t) : $(my_checked_module)
ifneq (,$(filter $(my_module_tags),tests))
$(j_or_n)-$(h_or_t)-tests $(j_or_n)-tests $(h_or_t)-tests : $(my_checked_module)
endif
endif

###########################################################
## NOTICE files
###########################################################

include $(BUILD_NOTICE_FILE)
