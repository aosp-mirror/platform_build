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
  my_prefix := HOST_
  my_host := host-
else
  my_prefix := TARGET_
  my_host :=
endif

my_module_tags := $(LOCAL_MODULE_TAGS)

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
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
ifndef LOCAL_NO_2ND_ARCH_MODULE_SUFFIX
my_register_name := $(LOCAL_MODULE)$($(my_prefix)2ND_ARCH_MODULE_SUFFIX)
endif
endif
# Make sure that this IS_HOST/CLASS/MODULE combination is unique.
module_id := MODULE.$(if \
    $(LOCAL_IS_HOST_MODULE),HOST,TARGET).$(LOCAL_MODULE_CLASS).$(my_register_name)
ifdef $(module_id)
$(error $(LOCAL_PATH): $(module_id) already defined by $($(module_id)))
endif
$(module_id) := $(LOCAL_PATH)

intermediates := $(call local-intermediates-dir,,$(LOCAL_2ND_ARCH_VAR_PREFIX))
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
  ifneq ($(LOCAL_NO_STANDARD_LIBRARIES),true)
    my_module_path := $(my_module_path)/$(LOCAL_MODULE)
  endif
  endif
  LOCAL_INSTALLED_MODULE := $(my_module_path)/$(my_installed_module_stem)
endif

# Assemble the list of targets to create PRIVATE_ variables for.
LOCAL_INTERMEDIATE_TARGETS += $(LOCAL_BUILT_MODULE)


###########################################################
## AIDL: Compile .aidl files to .java
###########################################################

aidl_sources := $(filter %.aidl,$(LOCAL_SRC_FILES))

ifneq ($(strip $(aidl_sources)),)

aidl_java_sources := $(patsubst %.aidl,%.java,$(addprefix $(intermediates.COMMON)/src/, $(aidl_sources)))
aidl_sources := $(addprefix $(TOP_DIR)$(LOCAL_PATH)/, $(aidl_sources))

aidl_preprocess_import :=
LOCAL_SDK_VERSION:=$(strip $(LOCAL_SDK_VERSION))
ifdef LOCAL_SDK_VERSION
ifneq ($(filter current system_current, $(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS)),)
  # LOCAL_SDK_VERSION is current and no TARGET_BUILD_APPS
  aidl_preprocess_import := $(TARGET_OUT_COMMON_INTERMEDIATES)/framework.aidl
else
  aidl_preprocess_import := $(HISTORICAL_SDK_VERSIONS_ROOT)/$(LOCAL_SDK_VERSION)/framework.aidl
endif # not current or system_current
else
# build against the platform.
LOCAL_AIDL_INCLUDES += $(FRAMEWORKS_BASE_JAVA_SRC_DIRS)
endif # LOCAL_SDK_VERSION
$(aidl_java_sources): PRIVATE_AIDL_FLAGS := -b $(addprefix -p,$(aidl_preprocess_import)) -I$(LOCAL_PATH) -I$(LOCAL_PATH)/src $(addprefix -I,$(LOCAL_AIDL_INCLUDES))

$(aidl_java_sources): $(intermediates.COMMON)/src/%.java: $(TOPDIR)$(LOCAL_PATH)/%.aidl $(LOCAL_ADDITIONAL_DEPENDENCIES) $(AIDL) $(aidl_preprocess_import)
	$(transform-aidl-to-java)
-include $(aidl_java_sources:%.java=%.P)

else
aidl_java_sources :=
endif

###########################################################
## logtags: Add .logtags files to global list, emit java source
###########################################################

logtags_sources := $(filter %.logtags,$(LOCAL_SRC_FILES))

ifneq ($(strip $(logtags_sources)),)

event_log_tags := $(addprefix $(LOCAL_PATH)/,$(logtags_sources))

# Emit a java source file with constants for the tags, if
# LOCAL_MODULE_CLASS is "APPS" or "JAVA_LIBRARIES".
ifneq ($(filter $(LOCAL_MODULE_CLASS),APPS JAVA_LIBRARIES),)

logtags_java_sources := $(patsubst %.logtags,%.java,$(addprefix $(intermediates.COMMON)/src/, $(logtags_sources)))
logtags_sources := $(addprefix $(TOP_DIR)$(LOCAL_PATH)/, $(logtags_sources))

$(logtags_java_sources): $(intermediates.COMMON)/src/%.java: $(TOPDIR)$(LOCAL_PATH)/%.logtags $(TARGET_OUT_COMMON_INTERMEDIATES)/all-event-log-tags.txt
	$(transform-logtags-to-java)

endif

else
logtags_java_sources :=
event_log_tags :=
endif

###########################################################
## .proto files: Compile proto files to .java
###########################################################
proto_sources := $(filter %.proto,$(LOCAL_SRC_FILES))
# Because names of the .java files compiled from .proto files are unknown until the
# .proto files are compiled, we use a timestamp file as depedency.
proto_java_sources_file_stamp :=
ifneq ($(proto_sources),)
proto_sources_fullpath := $(addprefix $(TOP_DIR)$(LOCAL_PATH)/, $(proto_sources))
# By putting the generated java files into $(LOCAL_INTERMEDIATE_SOURCE_DIR), they will be
# automatically found by the java compiling function transform-java-to-classes.jar.
ifneq ($(LOCAL_INTERMEDIATE_SOURCE_DIR),)
proto_java_intemediate_dir := $(LOCAL_INTERMEDIATE_SOURCE_DIR)/proto
else
# LOCAL_INTERMEDIATE_SOURCE_DIR may be not defined in non-java modules.
proto_java_intemediate_dir := $(intermediates)/proto
endif
proto_java_sources_file_stamp := $(proto_java_intemediate_dir)/Proto.stamp
proto_java_sources_dir := $(proto_java_intemediate_dir)/src

$(proto_java_sources_file_stamp): PRIVATE_PROTO_INCLUDES := $(TOP)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_SRC_FILES := $(proto_sources_fullpath)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_DIR := $(proto_java_sources_dir)
ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),micro)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javamicro_out
else
  ifeq ($(LOCAL_PROTOC_OPTIMIZE_TYPE),nano)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --javanano_out
  else
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_OPTION := --java_out
  endif
endif
$(proto_java_sources_file_stamp): PRIVATE_PROTOC_FLAGS := $(LOCAL_PROTOC_FLAGS)
$(proto_java_sources_file_stamp): PRIVATE_PROTO_JAVA_OUTPUT_PARAMS := $(LOCAL_PROTO_JAVA_OUTPUT_PARAMS)
$(proto_java_sources_file_stamp) : $(proto_sources_fullpath) $(PROTOC)
	$(call transform-proto-to-java)

#TODO: protoc should output the dependencies introduced by imports.

LOCAL_INTERMEDIATE_TARGETS += $(proto_java_sources_file_stamp)
endif # proto_sources


###########################################################
## Java: Compile .java files to .class
###########################################################
#TODO: pull this into java.make once host and target are combined

java_sources := $(addprefix $(TOP_DIR)$(LOCAL_PATH)/, $(filter %.java,$(LOCAL_SRC_FILES))) $(aidl_java_sources) $(logtags_java_sources) \
                $(filter %.java,$(LOCAL_GENERATED_SOURCES))
all_java_sources := $(java_sources) $(addprefix $($(my_prefix)OUT_COMMON_INTERMEDIATES)/, $(filter %.java,$(LOCAL_INTERMEDIATE_SOURCES)))

## Java resources #########################################

# Look for resource files in any specified directories.
# Non-java and non-doc files will be picked up as resources
# and included in the output jar file.
java_resource_file_groups :=

LOCAL_JAVA_RESOURCE_DIRS := $(strip $(LOCAL_JAVA_RESOURCE_DIRS))
ifneq ($(LOCAL_JAVA_RESOURCE_DIRS),)
  # This makes a list of words like
  #     <dir1>::<file1>:<file2> <dir2>::<file1> <dir3>:
  # where each of the files is relative to the directory it's grouped with.
  # Directories that don't contain any resource files will result in groups
  # that end with a colon, and they are stripped out in the next step.
  java_resource_file_groups += \
    $(foreach dir,$(LOCAL_JAVA_RESOURCE_DIRS), \
	$(subst $(space),:,$(strip \
		$(TOP_DIR)$(LOCAL_PATH)/$(dir): \
	    $(patsubst ./%,%,$(shell cd $(TOP_DIR)$(LOCAL_PATH)/$(dir) && \
		find . \
		    -type d -a -name ".svn" -prune -o \
		    -type f \
			-a \! -name "*.java" \
			-a \! -name "package.html" \
			-a \! -name "overview.html" \
			-a \! -name ".*.swp" \
			-a \! -name ".DS_Store" \
			-a \! -name "*~" \
			-print \
		    )) \
	)) \
    )
  java_resource_file_groups := $(filter-out %:,$(java_resource_file_groups))
endif # LOCAL_JAVA_RESOURCE_DIRS

LOCAL_JAVA_RESOURCE_FILES := $(strip $(LOCAL_JAVA_RESOURCE_FILES))
ifneq ($(LOCAL_JAVA_RESOURCE_FILES),)
  java_resource_file_groups += \
    $(foreach f,$(LOCAL_JAVA_RESOURCE_FILES), \
	$(patsubst %/,%,$(dir $(f)))::$(notdir $(f)) \
     )
endif # LOCAL_JAVA_RESOURCE_FILES

ifdef java_resource_file_groups
  # The full paths to all resources, used for dependencies.
  java_resource_sources := \
    $(foreach group,$(java_resource_file_groups), \
	$(addprefix $(word 1,$(subst :,$(space),$(group)))/, \
	    $(wordlist 2,9999,$(subst :,$(space),$(group))) \
	) \
    )
  # The arguments to jar that will include these files in a jar file.
  # Quote the file name to handle special characters (such as #) correctly.
  extra_jar_args := \
    $(foreach group,$(java_resource_file_groups), \
	$(addprefix -C "$(word 1,$(subst :,$(space),$(group)))" , \
	    $(foreach w, $(wordlist 2,9999,$(subst :,$(space),$(group))), "$(w)" ) \
	) \
    )
  java_resource_file_groups :=
else
  java_resource_sources :=
  extra_jar_args :=
endif # java_resource_file_groups

## PRIVATE java vars ######################################
# LOCAL_SOURCE_FILES_ALL_GENERATED is set only if the module does not have static source files,
# but generated source files in its LOCAL_INTERMEDIATE_SOURCE_DIR.
# You have to set up the dependency in some other way.
need_compile_java := $(strip $(all_java_sources)$(all_res_assets))$(LOCAL_STATIC_JAVA_LIBRARIES)$(filter true,$(LOCAL_SOURCE_FILES_ALL_GENERATED))
ifdef need_compile_java

full_static_java_libs := \
    $(foreach lib,$(LOCAL_STATIC_JAVA_LIBRARIES), \
      $(call intermediates-dir-for, \
        JAVA_LIBRARIES,$(lib),$(LOCAL_IS_HOST_MODULE),COMMON)/javalib.jar)

$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_INSTALL_DIR := $(dir $(LOCAL_INSTALLED_MODULE))
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_CLASS_INTERMEDIATES_DIR := $(intermediates)/classes
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_SOURCE_INTERMEDIATES_DIR := $(intermediates)/src
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAVA_SOURCES := $(all_java_sources)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAVA_OBJECTS := $(patsubst %.java,%.class,$(LOCAL_SRC_FILES))
ifeq ($(my_prefix),TARGET_)
ifeq ($(LOCAL_SDK_VERSION),)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH := -bootclasspath $(call java-lib-files,core-libart)
else
ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),current)
# LOCAL_SDK_VERSION is current and no TARGET_BUILD_APPS.
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH := -bootclasspath $(call java-lib-files,android_stubs_current)
else ifeq ($(LOCAL_SDK_VERSION)$(TARGET_BUILD_APPS),system_current)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH := -bootclasspath $(call java-lib-files,android_system_stubs_current)
else
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH := -bootclasspath $(call java-lib-files,sdk_v$(LOCAL_SDK_VERSION))
endif # current or system_current
endif # LOCAL_SDK_VERSION
endif # TARGET_
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_RESOURCE_DIR := $(LOCAL_RESOURCE_DIR)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_ASSET_DIR := $(LOCAL_ASSET_DIR)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_STATIC_JAVA_LIBRARIES := $(full_static_java_libs)

# full_java_libs: The list of files that should be used as the classpath.
#                 Using this list as a dependency list WILL NOT WORK.
# full_java_lib_deps: Should be specified as a prerequisite of this module
#                 to guarantee that the files in full_java_libs will
#                 be up-to-date.
ifdef LOCAL_IS_HOST_MODULE
ifeq ($(USE_CORE_LIB_BOOTCLASSPATH),true)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH := -bootclasspath $(call java-lib-deps,core-libart-hostdex,$(LOCAL_IS_HOST_MODULE))

full_shared_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
full_java_lib_deps := $(call java-lib-deps,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
else
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_BOOTCLASSPATH :=

full_shared_java_libs := $(addprefix $(HOST_OUT_JAVA_LIBRARIES)/,\
    $(addsuffix $(COMMON_JAVA_PACKAGE_SUFFIX),$(LOCAL_JAVA_LIBRARIES)))
full_java_lib_deps := $(full_shared_java_libs)
endif # USE_CORE_LIB_BOOTCLASSPATH
else # !LOCAL_IS_HOST_MODULE
full_shared_java_libs := $(call java-lib-files,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
full_java_lib_deps := $(call java-lib-deps,$(LOCAL_JAVA_LIBRARIES),$(LOCAL_IS_HOST_MODULE))
endif # !LOCAL_IS_HOST_MODULE
full_java_libs := $(full_shared_java_libs) $(full_static_java_libs) $(LOCAL_CLASSPATH)
full_java_lib_deps += $(full_static_java_libs) $(LOCAL_CLASSPATH)

# This is set by packages that are linking to other packages that export
# shared libraries, allowing them to make use of the code in the linked apk.
apk_libraries := $(sort $(LOCAL_APK_LIBRARIES) $(LOCAL_RES_LIBRARIES))
ifneq ($(apk_libraries),)
  link_apk_libraries := \
      $(foreach lib,$(apk_libraries), \
        $(call intermediates-dir-for, \
              APPS,$(lib),,COMMON)/classes.jar)

  # link against the jar with full original names (before proguard processing).
  full_shared_java_libs += $(link_apk_libraries)
  full_java_libs += $(link_apk_libraries)
  full_java_lib_deps += $(link_apk_libraries)
endif

# This is set by packages that contain instrumentation, allowing them to
# link against the package they are instrumenting.  Currently only one such
# package is allowed.
LOCAL_INSTRUMENTATION_FOR := $(strip $(LOCAL_INSTRUMENTATION_FOR))
ifdef LOCAL_INSTRUMENTATION_FOR
  ifneq ($(words $(LOCAL_INSTRUMENTATION_FOR)),1)
    $(error \
        $(LOCAL_PATH): Multiple LOCAL_INSTRUMENTATION_FOR members defined)
  endif

  link_instr_intermediates_dir.COMMON := $(call intermediates-dir-for, \
      APPS,$(LOCAL_INSTRUMENTATION_FOR),,COMMON)
  # link against the jar with full original names (before proguard processing).
  link_instr_classes_jar := $(link_instr_intermediates_dir.COMMON)/classes.jar
  full_java_libs += $(link_instr_classes_jar)
  full_java_lib_deps += $(link_instr_classes_jar)
endif

endif  # need_compile_java

# We may want to add jar manifest or jar resource files even if there is no java code at all.
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_EXTRA_JAR_ARGS := $(extra_jar_args)
jar_manifest_file :=
ifneq ($(strip $(LOCAL_JAR_MANIFEST)),)
jar_manifest_file := $(LOCAL_PATH)/$(LOCAL_JAR_MANIFEST)
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAR_MANIFEST := $(jar_manifest_file)
else
$(LOCAL_INTERMEDIATE_TARGETS): PRIVATE_JAR_MANIFEST :=
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

# aapt doesn't accept multiple --extra-packages flags.
# We have to collapse them into a single --extra-packages flag here.
LOCAL_AAPT_FLAGS := $(strip $(LOCAL_AAPT_FLAGS))
ifdef LOCAL_AAPT_FLAGS
ifeq ($(filter 0 1,$(words $(filter --extra-packages,$(LOCAL_AAPT_FLAGS)))),)
aapt_flags := $(subst --extra-packages$(space),--extra-packages@,$(LOCAL_AAPT_FLAGS))
aapt_flags_extra_packages := $(patsubst --extra-packages@%,%,$(filter --extra-packages@%,$(aapt_flags)))
aapt_flags_extra_packages := $(sort $(subst :,$(space),$(aapt_flags_extra_packages)))
LOCAL_AAPT_FLAGS := $(filter-out --extra-packages@%,$(aapt_flags)) \
    --extra-packages $(subst $(space),:,$(aapt_flags_extra_packages))
aapt_flags_extra_packages :=
aapt_flags :=
endif
endif

# Propagate local configuration options to this target.
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_PATH:=$(LOCAL_PATH)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_AAPT_FLAGS:= $(LOCAL_AAPT_FLAGS) $(PRODUCT_AAPT_FLAGS)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_JAVA_LIBRARIES:= $(LOCAL_JAVA_LIBRARIES)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_MANIFEST_PACKAGE_NAME:= $(LOCAL_MANIFEST_PACKAGE_NAME)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_MANIFEST_INSTRUMENTATION_FOR:= $(LOCAL_MANIFEST_INSTRUMENTATION_FOR)

$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_ALL_JAVA_LIBRARIES:= $(full_java_libs)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_IS_HOST_MODULE := $(LOCAL_IS_HOST_MODULE)
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_HOST:= $(my_host)

$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_INTERMEDIATES_DIR:= $(intermediates)

$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_2ND_ARCH_VAR_PREFIX := $(LOCAL_2ND_ARCH_VAR_PREFIX)

# Tell the module and all of its sub-modules who it is.
$(LOCAL_INTERMEDIATE_TARGETS) : PRIVATE_MODULE:= $(my_register_name)

# Provide a short-hand for building this module.
# We name both BUILT and INSTALLED in case
# LOCAL_UNINSTALLABLE_MODULE is set.
.PHONY: $(my_register_name)
$(my_register_name): $(LOCAL_BUILT_MODULE) $(LOCAL_INSTALLED_MODULE)

###########################################################
## Module installation rule
###########################################################

# Some hosts do not have ACP; override the LOCAL version if that's the case.
ifneq ($(strip $(HOST_ACP_UNAVAILABLE)),)
  LOCAL_ACP_UNAVAILABLE := $(strip $(HOST_ACP_UNAVAILABLE))
endif

ifndef LOCAL_UNINSTALLABLE_MODULE
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

endif # !LOCAL_UNINSTALLABLE_MODULE


###########################################################
## CHECK_BUILD goals
###########################################################

ifdef java_alternative_checked_module
  LOCAL_CHECKED_MODULE := $(java_alternative_checked_module)
endif

# If nobody has defined a more specific module for the
# checked modules, use LOCAL_BUILT_MODULE.
ifndef LOCAL_CHECKED_MODULE
  LOCAL_CHECKED_MODULE := $(LOCAL_BUILT_MODULE)
endif

# If they request that this module not be checked, then don't.
# PLEASE DON'T SET THIS.  ANY PLACES THAT SET THIS WITHOUT
# GOOD REASON WILL HAVE IT REMOVED.
ifdef LOCAL_DONT_CHECK_MODULE
  LOCAL_CHECKED_MODULE :=
endif
# Don't check build target module defined for the 2nd arch
ifndef LOCAL_IS_HOST_MODULE
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
  LOCAL_CHECKED_MODULE :=
endif
endif

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
    $(ALL_MODULES.$(my_register_name).CHECKED) $(LOCAL_CHECKED_MODULE)
ALL_MODULES.$(my_register_name).BUILT := \
    $(ALL_MODULES.$(my_register_name).BUILT) $(LOCAL_BUILT_MODULE)
ifneq (true,$(LOCAL_UNINSTALLABLE_MODULE))
ALL_MODULES.$(my_register_name).INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).INSTALLED) $(LOCAL_INSTALLED_MODULE))
ALL_MODULES.$(my_register_name).BUILT_INSTALLED := \
    $(strip $(ALL_MODULES.$(my_register_name).BUILT_INSTALLED) $(LOCAL_BUILT_MODULE):$(LOCAL_INSTALLED_MODULE))
endif
ifdef LOCAL_PICKUP_FILES
# Files or directories ready to pick up by the build system
# when $(LOCAL_BUILT_MODULE) is done.
ALL_MODULES.$(my_register_name).PICKUP_FILES := \
    $(ALL_MODULES.$(my_register_name).PICKUP_FILES) $(LOCAL_PICKUP_FILES)
endif
ALL_MODULES.$(my_register_name).REQUIRED := \
    $(strip $(ALL_MODULES.$(my_register_name).REQUIRED) $(LOCAL_REQUIRED_MODULES) \
      $(LOCAL_REQUIRED_MODULES_$(TARGET_$(LOCAL_2ND_ARCH_VAR_PREFIX)ARCH)))
ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS := \
    $(ALL_MODULES.$(my_register_name).EVENT_LOG_TAGS) $(event_log_tags)
ALL_MODULES.$(my_register_name).INTERMEDIATE_SOURCE_DIR := \
    $(ALL_MODULES.$(my_register_name).INTERMEDIATE_SOURCE_DIR) $(LOCAL_INTERMEDIATE_SOURCE_DIR)
ALL_MODULES.$(my_register_name).MAKEFILE := \
    $(ALL_MODULES.$(my_register_name).MAKEFILE) $(LOCAL_MODULE_MAKEFILE)
ifdef LOCAL_MODULE_OWNER
ALL_MODULES.$(my_register_name).OWNER := \
    $(sort $(ALL_MODULES.$(my_register_name).OWNER) $(LOCAL_MODULE_OWNER))
endif
ifdef LOCAL_2ND_ARCH_VAR_PREFIX
ALL_MODULES.$(my_register_name).FOR_2ND_ARCH := true
endif
ifdef aidl_sources
ALL_MODULES.$(my_register_name).AIDL_FILES := $(aidl_sources)
endif

INSTALLABLE_FILES.$(LOCAL_INSTALLED_MODULE).MODULE := $(my_register_name)

###########################################################
## Take care of my_module_tags
###########################################################

# Keep track of all the tags we've seen.
ALL_MODULE_TAGS := $(sort $(ALL_MODULE_TAGS) $(my_module_tags))

# Add this module to the tag list of each specified tag.
# Don't use "+=". If the variable hasn't been set with ":=",
# it will default to recursive expansion.
$(foreach tag,$(my_module_tags),\
    $(eval ALL_MODULE_TAGS.$(tag) := \
        $(ALL_MODULE_TAGS.$(tag)) \
        $(LOCAL_INSTALLED_MODULE)))

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
$(j_or_n) $(h_or_t) $(j_or_n)-$(h_or_t) : $(LOCAL_CHECKED_MODULE)
ifneq (,$(filter $(my_module_tags),tests))
$(j_or_n)-$(h_or_t)-tests $(j_or_n)-tests $(h_or_t)-tests : $(LOCAL_CHECKED_MODULE)
endif
endif

###########################################################
## NOTICE files
###########################################################

include $(BUILD_NOTICE_FILE)

#:vi noexpandtab
