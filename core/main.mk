
# Use bash, not whatever shell somebody has installed as /bin/sh
SHELL := /bin/bash

# this turns off the suffix rules built into make
.SUFFIXES:

# If a rule fails, delete $@.
.DELETE_ON_ERROR:

# Figure out where we are.
#TOP := $(dir $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
#TOP := $(patsubst %/,%,$(TOP))

# TOPDIR is the normal variable you should use, because
# if we are executing relative to the current directory
# it can be "", whereas TOP must be "." which causes
# pattern matching probles when make strips off the
# trailing "./" from paths in various places.
#ifeq ($(TOP),.)
#TOPDIR :=
#else
#TOPDIR := $(TOP)/
#endif

# check for broken versions of make
ifeq (0,$(shell expr $$(echo $(MAKE_VERSION) | sed "s/[^0-9\.].*//") \>= 3.81))
$(warning ********************************************************************************)
$(warning *  You are using version $(MAKE_VERSION) of make.)
$(warning *  You must upgrade to version 3.81 or greater.)
$(warning *  see file://$(shell pwd)/docs/development-environment/machine-setup.html)
$(warning ********************************************************************************)
$(error stopping)
endif

TOP := .
TOPDIR :=

BUILD_SYSTEM := $(TOPDIR)build/core

# Set up various standard variables based on configuration
# and host information.
include $(BUILD_SYSTEM)/config.mk

# This allows us to force a clean build - included after the config.make
# environment setup is done, but before we generate any dependencies.  This
# file does the rm -rf inline so the deps which are all done below will
# be generated correctly
include $(BUILD_SYSTEM)/cleanbuild.mk

ifneq ($(HOST_OS),windows)
ifneq ($(HOST_OS)-$(HOST_ARCH),darwin-ppc)
# check for a case sensitive file system
ifneq (a,$(shell mkdir -p $(OUT_DIR) ; \
                echo a > $(OUT_DIR)/casecheck.txt; \
                    echo B > $(OUT_DIR)/CaseCheck.txt; \
                cat $(OUT_DIR)/casecheck.txt))
$(warning ************************************************************)
$(warning You are building on a case-insensitive filesystem.)
$(warning Please move your source tree to a case-sensitive filesystem.)
$(warning ************************************************************)
$(error Case-insensitive filesystems not supported)
endif
endif
endif

# Make sure that there are no spaces in the absolute path; the
# build system can't deal with them.
ifneq ($(words $(shell pwd)),1)
$(warning ************************************************************)
$(warning You are building in a directory whose absolute path contains)
$(warning a space character:)
$(warning $(space))
$(warning "$(shell pwd)")
$(warning $(space))
$(warning Please move your source tree to a path that does not contain)
$(warning any spaces.)
$(warning ************************************************************)
$(error Directory names containing spaces not supported)
endif

# Set up version information.
include $(BUILD_SYSTEM)/version_defaults.mk

# These are the modifier targets that don't do anything themselves, but
# change the behavior of the build.
# (must be defined before including definitions.make)
INTERNAL_MODIFIER_TARGETS := showcommands

# This is the default target.  It must be the first declared target
DEFAULT_TARGET := droid
.PHONY: $(DEFAULT_TARGET)
$(DEFAULT_TARGET):

# Bring in standard build system definitions.
include $(BUILD_SYSTEM)/definitions.mk

###
### DO NOT USE THIS AS AN EXAMPLE FOR ANYTHING ELSE;
### ONLY 'user'/'userdebug'/'tests'/'sdk' GOALS
### SHOULD REFER TO MAKECMDGOALS.
###

## user/userdebug ##

user_goal := $(filter userdebug user,$(MAKECMDGOALS))
enable_target_debugging := true
ifneq (,$(user_goal))
  # Make sure that exactly one of {userdebug,user} has been specified,
  # and that no non-INTERNAL_MODIFIER_TARGETS goals have been specified.
  non_user_goals := \
      $(filter-out $(INTERNAL_MODIFIER_TARGETS) $(user_goal),$(MAKECMDGOALS))
  ifneq ($(words $(non_user_goals) $(user_goal)),1)
    $(error The '$(word 1,$(user_goal))' target may not be specified with any other targets)
  endif
  # Target is secure in user builds.
  ADDITIONAL_DEFAULT_PROPERTIES += ro.secure=1

  override_build_tags := user
  ifeq ($(user_goal),userdebug)
    # Pick up some extra useful tools
    override_build_tags += debug
  else
    # Disable debugging in plain user builds.
    enable_target_debugging :=
  endif
 
  # TODO: Always set WITH_DEXPREOPT (for user builds) once it works on OSX.
  # Also, remove the corresponding block in config/product_config.make.
  ifeq ($(HOST_OS)-$(WITH_DEXPREOPT_buildbot),linux-true)
    WITH_DEXPREOPT := true
  endif
else # !user_goal
  # Turn on checkjni for non-user builds.
  ADDITIONAL_BUILD_PROPERTIES += ro.kernel.android.checkjni=1
  # Set device insecure for non-user builds.
  ADDITIONAL_DEFAULT_PROPERTIES += ro.secure=0
endif # !user_goal

ifeq (true,$(strip $(enable_target_debugging)))
  # Target is more debuggable and adbd is on by default
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=1 persist.service.adb.enable=1
  # Include the debugging/testing OTA keys in this build.
  INCLUDE_TEST_OTA_KEYS := true
else # !enable_target_debugging
  # Target is less debuggable and adbd is off by default
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=0 persist.service.adb.enable=0
endif # !enable_target_debugging

## tests ##

ifneq ($(filter tests,$(MAKECMDGOALS)),)
ifneq ($(words $(filter-out $(INTERNAL_MODIFIER_TARGETS),$(MAKECMDGOALS))),1)
$(error The 'tests' target may not be specified with any other targets)
endif
override_build_tags := eng debug user development tests
endif

## sdk ##

ifneq ($(filter sdk,$(MAKECMDGOALS)),)
ifneq ($(words $(filter-out $(INTERNAL_MODIFIER_TARGETS),$(MAKECMDGOALS))),1)
$(error The 'sdk' target may not be specified with any other targets)
endif
override_build_tags := development
ADDITIONAL_BUILD_PROPERTIES += xmpp.auto-presence=true
ADDITIONAL_BUILD_PROPERTIES += ro.config.nocheckin=yes
else # !sdk
# Enable sync for non-sdk builds only (sdk builds lack SubscribedFeedsProvider).
ADDITIONAL_BUILD_PROPERTIES += ro.config.sync=yes
endif

ifeq "" "$(filter %:system/etc/apns-conf.xml, $(PRODUCT_COPY_FILES))"
  # Install an apns-conf.xml file if one's not already being installed.
  PRODUCT_COPY_FILES += development/data/etc/apns-conf_sdk.xml:system/etc/apns-conf.xml
  ifeq ($(filter sdk,$(MAKECMDGOALS)),)
    $(warning implicitly installing apns-conf_sdk.xml)
  endif
endif

ADDITIONAL_BUILD_PROPERTIES += net.bt.name=Android

# enable vm tracing in files for now to help track
# the cause of ANRs in the content process
ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.stack-trace-file=/data/anr/traces.txt


# ------------------------------------------------------------
# Define a function that, given a list of module tags, returns
# non-empty if that module should be installed in /system.

# For most goals, anything tagged with "eng"/"debug"/"user" should
# be installed in /system.
define should-install-to-system
$(filter eng debug user,$(1))
endef

ifneq (,$(filter sdk,$(MAKECMDGOALS)))
# For the sdk goal, anything with the "samples" tag should be
# installed in /data even if that module also has "eng"/"debug"/"user".
define should-install-to-system
$(if $(filter samples,$(1)),,$(filter eng debug user development,$(1)))
endef
endif

ifneq (,$(filter user,$(MAKECMDGOALS)))
# For the user goal, everything should be installed in /system.
define should-install-to-system
true
endef
endif


# If all they typed was make showcommands, we'll actually build
# the default target.
ifeq ($(MAKECMDGOALS),showcommands)
.PHONY: showcommands
showcommands: $(DEFAULT_TARGET)
endif

# These targets are going to delete stuff, don't bother including
# the whole directory tree if that's all we're going to do
ifeq ($(MAKECMDGOALS),clean)
dont_bother := true
endif
ifeq ($(MAKECMDGOALS),clobber)
dont_bother := true
endif
ifeq ($(MAKECMDGOALS),dataclean)
dont_bother := true
endif
ifeq ($(MAKECMDGOALS),installclean)
dont_bother := true
endif

# Bring in all modules that need to be built.
ifneq ($(dont_bother),true)

subdir_makefiles :=

ifeq ($(HOST_OS),windows)
SDK_ONLY := true
endif
ifeq ($(HOST_OS)-$(HOST_ARCH),darwin-ppc)
SDK_ONLY := true
endif

ifeq ($(SDK_ONLY),true)

subdirs := \
	build/libs/host \
	dalvik/dexdump \
	dalvik/libdex \
	dalvik/tools/dmtracedump \
	development/emulator/mksdcard \
	development/tools/activitycreator \
	development/tools/line_endings \
	external/expat \
	external/libpng \
	external/qemu \
	external/sqlite/dist \
	external/zlib \
	frameworks/base/libs/utils \
	frameworks/base/tools/aapt \
	frameworks/base/tools/aidl \
	system/core/adb \
	system/core/fastboot \
	system/core/libcutils \
	system/core/liblog \
	system/core/libzipfile

# The following can only be built if "javac" is available.
# This check is used when building parts of the SDK under Cygwin.
ifneq (,$(shell which javac 2>/dev/null))
$(warning sdk-only: javac available.)
subdirs += \
	build/tools/signapk \
	build/tools/zipalign \
	dalvik/dx \
	dalvik/libcore \
	development/apps \
	development/tools/androidprefs \
	development/tools/apkbuilder \
	development/tools/jarutils \
	development/tools/layoutlib_utils \
	development/tools/ninepatch \
	development/tools/sdkstats \
	frameworks/base \
	frameworks/base/tools/layoutlib \
	packages
else
$(warning sdk-only: javac not available.)
endif

# Exclude tools/acp when cross-compiling windows under linux
ifeq ($(findstring Linux,$(UNAME)),)
subdirs += build/tools/acp
endif

else	# !SDK_ONLY
ifeq ($(BUILD_TINY_ANDROID), true)

# TINY_ANDROID is a super-minimal build configuration, handy for board 
# bringup and very low level debugging

INTERNAL_DEFAULT_DOCS_TARGETS := 

subdirs := \
	bionic \
	system/core \
	build/libs \
	build/target \
	build/tools/acp \
	build/tools/apriori \
	build/tools/kcm \
	build/tools/soslim \
	external/elfcopy \
	external/elfutils \
	external/yaffs2 \
	external/zlib
else	# !BUILD_TINY_ANDROID

#
# Typical build; include any Android.mk files we can find.
#
INTERNAL_DEFAULT_DOCS_TARGETS := framework-docs
subdirs := $(TOP)

FULL_BUILD := true

endif	# !BUILD_TINY_ANDROID

endif	# !SDK_ONLY

# Can't use first-makefiles-under here because
# --mindepth=2 makes the prunes not work.
subdir_makefiles += \
	$(shell build/tools/findleaves.sh \
	    --prune="./vendor" --prune="./out" $(subdirs) Android.mk)

# Boards may be defined under $(SRC_TARGET_DIR)/board/$(TARGET_PRODUCT)
# or under vendor/*/$(TARGET_PRODUCT).  Search in both places, but
# make sure only one exists.
# Real boards should always be associated with an OEM vendor.
board_config_mk := \
	$(strip $(wildcard \
		$(SRC_TARGET_DIR)/board/$(TARGET_PRODUCT)/BoardConfig.mk \
		vendor/*/$(TARGET_PRODUCT)/BoardConfig.mk \
	))
ifeq ($(board_config_mk),)
  $(error No config file found for TARGET_PRODUCT $(TARGET_PRODUCT))
endif
ifneq ($(words $(board_config_mk)),1)
  $(error Multiple board config files for TARGET_PRODUCT $(TARGET_PRODUCT): $(board_config_mk))
endif
include $(board_config_mk)
TARGET_PRODUCT_DIR := $(patsubst %/,%,$(dir $(board_config_mk)))
board_config_mk :=

ifdef CUSTOM_PKG
$(info ***************************************************************)
$(info ***************************************************************)
$(error CUSTOM_PKG is obsolete; use CUSTOM_MODULES)
$(info ***************************************************************)
$(info ***************************************************************)
endif
ifdef CUSTOM_TARGETS
$(info ***************************************************************)
$(info ***************************************************************)
$(error CUSTOM_TARGETS is obsolete; use CUSTOM_MODULES)
$(info ***************************************************************)
$(info ***************************************************************)
endif

#
# Include all of the makefiles in the system
#

ifneq ($(ONE_SHOT_MAKEFILE),)
# We've probably been invoked by the "mm" shell function
# with a subdirectory's makefile.
include $(ONE_SHOT_MAKEFILE)
# Change CUSTOM_MODULES to include only modules that were
# defined by this makefile; this will install all of those
# modules as a side-effect.  Do this after including ONE_SHOT_MAKEFILE
# so that the modules will be installed in the same place they
# would have been with a normal make.
CUSTOM_MODULES := $(sort $(call get-tagged-modules,$(ALL_MODULE_TAGS),))
FULL_BUILD :=
INTERNAL_DEFAULT_DOCS_TARGETS :=
# Stub out the notice targets, which probably aren't defined
# when using ONE_SHOT_MAKEFILE.
NOTICE-HOST-%: ;
NOTICE-TARGET-%: ;
else
include $(subdir_makefiles)
endif
# -------------------------------------------------------------------
# All module makefiles have been included at this point.
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# Fix up CUSTOM_MODULES to refer to installed files rather than
# just bare module names.  Leave unknown modules alone in case
# they're actually full paths to a particular file.
known_custom_modules := $(filter $(ALL_MODULES),$(CUSTOM_MODULES))
unknown_custom_modules := $(filter-out $(ALL_MODULES),$(CUSTOM_MODULES))
CUSTOM_MODULES := \
	$(call module-installed-files,$(known_custom_modules)) \
	$(unknown_custom_modules)

# -------------------------------------------------------------------
# Define dependencies for modules that require other modules.
# This can only happen now, after we've read in all module makefiles.
#
# TODO: deal with the fact that a bare module name isn't
# unambiguous enough.  Maybe declare short targets like
# APPS:Quake or HOST:SHARED_LIBRARIES:libutils.
# BUG: the system image won't know to depend on modules that are
# brought in as requirements of other modules.
define add-required-deps
$(1): $(2)
endef
$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).REQUIRED)) \
  $(if $(r), \
    $(eval r := $(call module-installed-files,$(r))) \
    $(eval $(call add-required-deps,$(ALL_MODULES.$(m).INSTALLED),$(r))) \
   ) \
 )
m :=
r :=
add-required-deps :=

# -------------------------------------------------------------------
# Figure out our module sets.

# Of the modules defined by the component makefiles,
# determine what we actually want to build.
# If a module has the "restricted" tag on it, it
# poisons the rest of the tags and shouldn't appear
# on any list.
Default_MODULES := $(sort $(ALL_DEFAULT_INSTALLED_MODULES) \
                          $(ALL_BUILT_MODULES) \
                          $(CUSTOM_MODULES))

ifdef FULL_BUILD
  # The base list of modules to build for this product is specified
  # by the appropriate product definition file, which was included
  # by product_config.make.
  user_PACKAGES := $(call module-installed-files, \
                       $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES))
  ifeq (0,1)
    $(info user packages for $(TARGET_PRODUCT) ($(INTERNAL_PRODUCT)):)
    $(foreach p,$(user_PACKAGES),$(info :   $(p)))
    $(error done)
  endif
else
  # We're not doing a full build, and are probably only including
  # a subset of the module makefiles.  Don't try to build any modules
  # requested by the product, because we probably won't have rules
  # to build them.
  user_PACKAGES :=
endif
# Use tags to get the non-APPS user modules.  Use the product
# definition files to get the APPS user modules.
user_MODULES := $(sort $(call get-tagged-modules,user,_class@APPS restricted))
user_MODULES := $(user_MODULES) $(user_PACKAGES)

eng_MODULES := $(sort $(call get-tagged-modules,eng,restricted))
debug_MODULES := $(sort $(call get-tagged-modules,debug,restricted))
tests_MODULES := $(sort $(call get-tagged-modules,tests,restricted))

# Don't include any GNU targets in the SDK.  It's ok (and necessary)
# to build the host tools, but nothing that's going to be installed
# on the target (including static libraries).
all_development_MODULES := \
	$(sort $(call get-tagged-modules,development,restricted))
target_gnu_MODULES := \
	$(filter \
		$(TARGET_OUT_INTERMEDIATES)/% \
		$(TARGET_OUT)/% \
		$(TARGET_OUT_DATA)/%, \
	    $(sort $(call get-tagged-modules,gnu)))
#$(info Removing from development:)$(foreach d,$(target_gnu_MODULES),$(info : $(d)))
development_MODULES := \
	$(filter-out $(target_gnu_MODULES),$(all_development_MODULES))

droid_MODULES := $(sort $(Default_MODULES) \
			$(eng_MODULES) \
			$(debug_MODULES) \
			$(user_MODULES) \
			$(all_development_MODULES))

# The list of everything that's not on droid_MODULES.
# Also skip modules tagged as "restricted", which are
# never installed unless explicitly mentioned in
# CUSTOM_MODULES.
nonDroid_MODULES := $(sort $(call get-tagged-modules,\
			  $(ALL_MODULE_TAGS),\
			  eng debug user development restricted))

# THIS IS A TOTAL HACK AND SHOULD NOT BE USED AS AN EXAMPLE
modules_to_build := $(droid_MODULES)
ifneq ($(override_build_tags),)
  modules_to_build := $(sort $(Default_MODULES) \
		      $(foreach tag,$(override_build_tags),$($(tag)_MODULES)))
#$(error skipping modules $(filter-out $(modules_to_build),$(Default_MODULES) $(droid_MODULES)))
endif

# Some packages may override others using LOCAL_OVERRIDES_PACKAGES.
# Filter out (do not install) any overridden packages.
overridden_packages := $(call get-package-overrides,$(modules_to_build))
ifdef overridden_packages
#  old_modules_to_build := $(modules_to_build)
  modules_to_build := \
      $(filter-out $(foreach p,$(overridden_packages),%/$(p) %/$(p).apk), \
          $(modules_to_build))
endif
#$(error filtered out $(filter-out $(modules_to_build),$(old_modules_to_build)))

# config/Makefile contains extra stuff that we don't want to pollute this
# top-level makefile with.  It expects that ALL_DEFAULT_INSTALLED_MODULES
# contains everything that's built during the current make, but it also further
# extends ALL_DEFAULT_INSTALLED_MODULES.
ALL_DEFAULT_INSTALLED_MODULES := $(modules_to_build)
include $(BUILD_SYSTEM)/Makefile
modules_to_build := $(sort $(ALL_DEFAULT_INSTALLED_MODULES))
ALL_DEFAULT_INSTALLED_MODULES :=

endif # dont_bother

# -------------------------------------------------------------------
# This is used to to get the ordering right, you can also use these,
# but they're considered undocumented, so don't complain if their
# behavior changes.
.PHONY: prebuilt
prebuilt: $(ALL_PREBUILT) report_config

# An internal target that depends on all copied headers
# (see copy_headers.make).  Other targets that need the
# headers to be copied first can depend on this target.
.PHONY: all_copied_headers
all_copied_headers: ;

$(ALL_C_CPP_ETC_OBJECTS): | all_copied_headers

# All the droid stuff, in directories
.PHONY: files
files: report_config prebuilt $(modules_to_build) $(INSTALLED_ANDROID_INFO_TXT_TARGET)

# -------------------------------------------------------------------

.PHONY: ramdisk
ramdisk: $(INSTALLED_RAMDISK_TARGET) report_config

.PHONY: userdataimage
userdataimage: $(INSTALLED_USERDATAIMAGE_TARGET) report_config

.PHONY: bootimage
bootimage: $(INSTALLED_BOOTIMAGE_TARGET) report_config

ifeq ($(BUILD_TINY_ANDROID), true)
INSTALLED_RECOVERYIMAGE_TARGET :=
endif

# Build files and then package it into the rom formats
.PHONY: droidcore
droidcore: report_config files \
	systemimage \
	$(INSTALLED_BOOTIMAGE_TARGET) \
	$(INSTALLED_RECOVERYIMAGE_TARGET) \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(INTERNAL_DEFAULT_DOCS_TARGETS)

# The actual files built by the droidcore target changes depending
# on MAKECMDGOALS. THIS IS A TOTAL HACK AND SHOULD NOT BE USED AS AN EXAMPLE
.PHONY: droid user userdebug tests
droid user userdebug tests: droidcore

$(call dist-for-goals,user userdebug droid, \
	$(INTERNAL_UPDATE_PACKAGE_TARGET) \
	$(INTERNAL_OTA_PACKAGE_TARGET) \
	$(SYMBOLS_ZIP) \
	$(APPS_ZIP) \
	$(HOST_OUT_EXECUTABLES)/adb$(HOST_EXECUTABLE_SUFFIX) \
	$(INTERNAL_EMULATOR_PACKAGE_TARGET) \
	$(PACKAGE_STATS_FILE) \
	$(INSTALLED_FILES_FILE) \
	$(INSTALLED_BUILD_PROP_TARGET) \
	$(BUILT_TARGET_FILES_PACKAGE) \
 )
# Tests are installed in userdata.img; copy it for "make tests dist".
# Also copy a zip of the contents of userdata.img, so that people can
# easily extract a single .apk.
$(call dist-for-goals,tests, \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(BUILT_TESTS_ZIP_PACKAGE) \
 )

.PHONY: docs
docs: $(ALL_DOCS)

.PHONY: sdk
ALL_SDK_TARGETS := $(INTERNAL_SDK_TARGET)
sdk: report_config $(ALL_SDK_TARGETS)
$(call dist-for-goals,sdk,$(ALL_SDK_TARGETS))

.PHONY: findbugs
findbugs: $(INTERNAL_FINDBUGS_HTML_TARGET) $(INTERNAL_FINDBUGS_XML_TARGET)

# Also do the targets not built by "make droid".
.PHONY: all
all: droid $(nonDroid_MODULES) docs sdk

.PHONY: clean
dirs_to_clean := \
	$(PRODUCT_OUT) \
	$(TARGET_COMMON_OUT_ROOT) \
	$(HOST_OUT) \
	$(HOST_COMMON_OUT_ROOT)
clean:
	@for dir in $(dirs_to_clean) ; do \
	    echo "Cleaning $$dir..."; \
	    rm -rf $$dir; \
	done
	@echo "Clean."; \

.PHONY: clobber
clobber:
	@rm -rf $(OUT_DIR)
	@echo "Entire build directory removed."

.PHONY: dataclean
dataclean:
	@rm -rf $(PRODUCT_OUT)/data/*
	@rm -rf $(PRODUCT_OUT)/data-qemu/*
	@rm -rf $(PRODUCT_OUT)/userdata-qemu.img
	@echo "Deleted emulator userdata images."

.PHONY: installclean
# Deletes all of the files that change between different build types,
# like "make user" vs. "make sdk".  This lets you work with different
# build types without having to do a full clean each time.  E.g.:
#
#     $ make -j8 all
#     $ make installclean
#     $ make -j8 user
#     $ make installclean
#     $ make -j8 sdk
#
installclean: dataclean
	$(hide) rm -rf ./$(PRODUCT_OUT)/system
	$(hide) rm -rf ./$(PRODUCT_OUT)/recovery
	$(hide) rm -rf ./$(PRODUCT_OUT)/data
	$(hide) rm -rf ./$(PRODUCT_OUT)/root
	$(hide) rm -rf ./$(PRODUCT_OUT)/obj/NOTICE_FILES
	@# Remove APPS because they may contain the wrong resources.
	$(hide) rm -rf ./$(PRODUCT_OUT)/obj/APPS
	$(hide) rm -rf ./$(HOST_OUT)/obj/NOTICE_FILES
	$(hide) rm -rf ./$(HOST_OUT)/sdk
	$(hide) rm -rf ./$(PRODUCT_OUT)/obj/PACKAGING
	$(hide) rm -f ./$(PRODUCT_OUT)/*.img
	$(hide) rm -f ./$(PRODUCT_OUT)/*.zip
	$(hide) rm -f ./$(PRODUCT_OUT)/*.txt
	$(hide) rm -f ./$(PRODUCT_OUT)/*.xlb
	@echo "Deleted images and staging directories."

#xxx scrape this from ALL_MODULE_NAME_TAGS
.PHONY: modules
modules:
	@echo "Available sub-modules:"
	@echo "$(call module-names-for-tag-list,$(ALL_MODULE_TAGS))" | \
	      sed -e 's/  */\n/g' | sort -u | $(COLUMN)

.PHONY: showcommands
showcommands:
	@echo >/dev/null


