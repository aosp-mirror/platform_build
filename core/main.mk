
# Use bash, not whatever shell somebody has installed as /bin/sh
# This is repeated in config.mk, since envsetup.sh runs that file
# directly.
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

# This is the default target.  It must be the first declared target.
DEFAULT_GOAL := droid
$(DEFAULT_GOAL):

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

# Bring in standard build system definitions.
include $(BUILD_SYSTEM)/definitions.mk

ifneq ($(filter eng user userdebug tests,$(MAKECMDGOALS)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Don't pass '$(filter eng user userdebug tests,$(MAKECMDGOALS))' on \
		the make command line.)
# XXX The single quote on this line fixes gvim's syntax highlighting.
# Without which, the rest of this file is impossible to read.
$(info Set TARGET_BUILD_VARIANT in buildspec.mk, or use lunch or)
$(info choosecombo.)
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

ifneq ($(filter-out $(INTERNAL_VALID_VARIANTS),$(TARGET_BUILD_VARIANT)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Invalid variant: $(TARGET_BUILD_VARIANT)
$(info Valid values are: $(INTERNAL_VALID_VARIANTS)
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

###
### In this section we set up the things that are different
### between the build variants
###

## user/userdebug ##

user_variant := $(filter userdebug user,$(TARGET_BUILD_VARIANT))
enable_target_debugging := true
ifneq (,$(user_variant))
  # Target is secure in user builds.
  ADDITIONAL_DEFAULT_PROPERTIES += ro.secure=1

  tags_to_install := user
  ifeq ($(user_variant),userdebug)
    # Pick up some extra useful tools
    tags_to_install += debug
  else
    # Disable debugging in plain user builds.
    enable_target_debugging :=
  endif
 
  # TODO: Always set WITH_DEXPREOPT (for user builds) once it works on OSX.
  # Also, remove the corresponding block in config/product_config.make.
  ifeq ($(HOST_OS)-$(WITH_DEXPREOPT_buildbot),linux-true)
    WITH_DEXPREOPT := true
  endif
  
  # Disallow mock locations by default for user builds
  ADDITIONAL_DEFAULT_PROPERTIES += ro.allow.mock.location=0
  
else # !user_variant
  # Turn on checkjni for non-user builds.
  ADDITIONAL_BUILD_PROPERTIES += ro.kernel.android.checkjni=1
  # Set device insecure for non-user builds.
  ADDITIONAL_DEFAULT_PROPERTIES += ro.secure=0
  # Allow mock locations by default for non user builds
  ADDITIONAL_DEFAULT_PROPERTIES += ro.allow.mock.location=1
endif # !user_variant

ifeq (true,$(strip $(enable_target_debugging)))
  # Target is more debuggable and adbd is on by default
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=1 persist.service.adb.enable=1
  # Include the debugging/testing OTA keys in this build.
  INCLUDE_TEST_OTA_KEYS := true
else # !enable_target_debugging
  # Target is less debuggable and adbd is off by default
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=0 persist.service.adb.enable=0
endif # !enable_target_debugging

## eng ##

ifeq ($(TARGET_BUILD_VARIANT),eng)
tags_to_install := user debug eng
  # Don't require the setup wizard on eng builds
  ADDITIONAL_BUILD_PROPERTIES := $(filter-out ro.setupwizard.mode=%,\
          $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES)))
endif

## tests ##

ifeq ($(TARGET_BUILD_VARIANT),tests)
tags_to_install := user debug eng tests
endif

## sdk ##

ifneq ($(filter sdk,$(MAKECMDGOALS)),)
ifneq ($(words $(filter-out $(INTERNAL_MODIFIER_TARGETS),$(MAKECMDGOALS))),1)
$(error The 'sdk' target may not be specified with any other targets)
endif
# TODO: this should be eng I think.  Since the sdk is built from the eng
# variant.
tags_to_install := user
ADDITIONAL_BUILD_PROPERTIES += xmpp.auto-presence=true
ADDITIONAL_BUILD_PROPERTIES += ro.config.nocheckin=yes
else # !sdk
# Enable sync for non-sdk builds only (sdk builds lack SubscribedFeedsProvider).
ADDITIONAL_BUILD_PROPERTIES += ro.config.sync=yes
endif

# Install an apns-conf.xml file if one's not already being installed.
ifeq (,$(filter %:system/etc/apns-conf.xml, $(PRODUCT_COPY_FILES)))
  PRODUCT_COPY_FILES += \
        development/data/etc/apns-conf_sdk.xml:system/etc/apns-conf.xml
  ifeq ($(filter eng tests,$(TARGET_BUILD_VARIANT)),)
    $(warning implicitly installing apns-conf_sdk.xml)
  endif
endif
# If we're on an eng or tests build, but not on the sdk, and we have
# a better one, use that instead.
ifneq ($(filter eng tests,$(TARGET_BUILD_VARIANT)),)
  ifeq ($(filter sdk,$(MAKECMDGOALS)),)
    apns_to_use := $(wildcard vendor/google/etc/apns-conf.xml)
    ifneq ($(strip $(apns_to_use)),)
      PRODUCT_COPY_FILES := \
            $(filter-out %:system/etc/apns-conf.xml,$(PRODUCT_COPY_FILES)) \
            $(strip $(apns_to_use)):system/etc/apns-conf.xml
    endif
  endif
endif

ADDITIONAL_BUILD_PROPERTIES += net.bt.name=Android

# enable vm tracing in files for now to help track
# the cause of ANRs in the content process
ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.stack-trace-file=/data/anr/traces.txt


# ------------------------------------------------------------
# Define a function that, given a list of module tags, returns
# non-empty if that module should be installed in /system.

# For most goals, anything not tagged with the "tests" tag should
# be installed in /system.
define should-install-to-system
$(if $(filter tests,$(1)),,true)
endef

ifneq (,$(filter sdk,$(MAKECMDGOALS)))
# For the sdk goal, anything with the "samples" tag should be
# installed in /data even if that module also has "eng"/"debug"/"user".
define should-install-to-system
$(if $(filter samples tests,$(1)),,true)
endef
endif


# If all they typed was make showcommands, we'll actually build
# the default target.
ifeq ($(MAKECMDGOALS),showcommands)
.PHONY: showcommands
showcommands: $(DEFAULT_GOAL)
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
	prebuilt \
	build/libs/host \
	dalvik/dexdump \
	dalvik/libdex \
	dalvik/tools/dmtracedump \
	dalvik/tools/hprof-conv \
	development/emulator/mksdcard \
	development/tools/activitycreator \
	development/tools/line_endings \
	development/host \
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
	development/tools/sdkmanager \
	frameworks/base \
	frameworks/base/tools/layoutlib \
	external/googleclient \
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
INTERNAL_DEFAULT_DOCS_TARGETS := offline-sdk-docs
subdirs := $(TOP)

FULL_BUILD := true

endif	# !BUILD_TINY_ANDROID

endif	# !SDK_ONLY

# Can't use first-makefiles-under here because
# --mindepth=2 makes the prunes not work.
subdir_makefiles += \
	$(shell build/tools/findleaves.sh --prune="./out" $(subdirs) Android.mk)

# Boards may be defined under $(SRC_TARGET_DIR)/board/$(TARGET_DEVICE)
# or under vendor/*/$(TARGET_DEVICE).  Search in both places, but
# make sure only one exists.
# Real boards should always be associated with an OEM vendor.
board_config_mk := \
	$(strip $(wildcard \
		$(SRC_TARGET_DIR)/board/$(TARGET_DEVICE)/BoardConfig.mk \
		vendor/*/$(TARGET_DEVICE)/BoardConfig.mk \
	))
ifeq ($(board_config_mk),)
  $(error No config file found for TARGET_DEVICE $(TARGET_DEVICE))
endif
ifneq ($(words $(board_config_mk)),1)
  $(error Multiple board config files for TARGET_DEVICE $(TARGET_DEVICE): $(board_config_mk))
endif
include $(board_config_mk)
TARGET_DEVICE_DIR := $(patsubst %/,%,$(dir $(board_config_mk)))
board_config_mk :=

# Clean up/verify variables defined by the board config file.
TARGET_BOOTLOADER_BOARD_NAME := $(strip $(TARGET_BOOTLOADER_BOARD_NAME))

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
# Include any makefiles that must happen after the module makefiles
# have been included.
# TODO: have these files register themselves via a global var rather
# than hard-coding the list here.
ifdef FULL_BUILD
  # Only include this during a full build, otherwise we can't be
  # guaranteed that any policies were included.
  -include frameworks/policies/base/PolicyConfig.mk
endif

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
# TODO: Remove the 3 places in the tree that use
# ALL_DEFAULT_INSTALLED_MODULES and get rid of it from this list.

ifdef FULL_BUILD
  # The base list of modules to build for this product is specified
  # by the appropriate product definition file, which was included
  # by product_config.make.
  user_PACKAGES := $(call module-installed-files, \
                       $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES))
  ifeq (0,1)
    $(info user packages for $(TARGET_DEVICE) ($(INTERNAL_PRODUCT)):)
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

ifeq ($(strip $(tags_to_install)),)
$(error ASSERTION FAILED: tags_to_install should not be empty)
endif
modules_to_install := $(sort $(Default_MODULES) \
          $(foreach tag,$(tags_to_install),$($(tag)_MODULES)))

# Some packages may override others using LOCAL_OVERRIDES_PACKAGES.
# Filter out (do not install) any overridden packages.
overridden_packages := $(call get-package-overrides,$(modules_to_install))
ifdef overridden_packages
#  old_modules_to_install := $(modules_to_install)
  modules_to_install := \
      $(filter-out $(foreach p,$(overridden_packages),$(p) %/$(p).apk), \
          $(modules_to_install))
endif
#$(error filtered out
#           $(filter-out $(modules_to_install),$(old_modules_to_install)))

# Don't include any GNU targets in the SDK.  It's ok (and necessary)
# to build the host tools, but nothing that's going to be installed
# on the target (including static libraries).
ifneq ($(filter sdk,$(MAKECMDGOALS)),)
  target_gnu_MODULES := \
              $(filter \
                      $(TARGET_OUT_INTERMEDIATES)/% \
                      $(TARGET_OUT)/% \
                      $(TARGET_OUT_DATA)/%, \
                              $(sort $(call get-tagged-modules,gnu)))
  $(info Removing from sdk:)$(foreach d,$(target_gnu_MODULES),$(info : $(d)))
  modules_to_install := \
              $(filter-out $(target_gnu_MODULES),$(modules_to_install))
endif


# config/Makefile contains extra stuff that we don't want to pollute this
# top-level makefile with.  It expects that ALL_DEFAULT_INSTALLED_MODULES
# contains everything that's built during the current make, but it also further
# extends ALL_DEFAULT_INSTALLED_MODULES.
ALL_DEFAULT_INSTALLED_MODULES := $(modules_to_install)
include $(BUILD_SYSTEM)/Makefile
modules_to_install := $(sort $(ALL_DEFAULT_INSTALLED_MODULES))
ALL_DEFAULT_INSTALLED_MODULES :=

endif # dont_bother

# -------------------------------------------------------------------
# This is used to to get the ordering right, you can also use these,
# but they're considered undocumented, so don't complain if their
# behavior changes.
.PHONY: prebuilt
prebuilt: $(ALL_PREBUILT)

# An internal target that depends on all copied headers
# (see copy_headers.make).  Other targets that need the
# headers to be copied first can depend on this target.
.PHONY: all_copied_headers
all_copied_headers: ;

$(ALL_C_CPP_ETC_OBJECTS): | all_copied_headers

# All the droid stuff, in directories
.PHONY: files
files: prebuilt $(modules_to_install) $(INSTALLED_ANDROID_INFO_TXT_TARGET)

# -------------------------------------------------------------------

.PHONY: ramdisk
ramdisk: $(INSTALLED_RAMDISK_TARGET)

.PHONY: systemtarball
systemtarball: $(INSTALLED_SYSTEMTARBALL_TARGET)

.PHONY: userdataimage
userdataimage: $(INSTALLED_USERDATAIMAGE_TARGET)

.PHONY: userdatatarball
userdatatarball: $(INSTALLED_USERDATATARBALL_TARGET)

.PHONY: bootimage
bootimage: $(INSTALLED_BOOTIMAGE_TARGET)

ifeq ($(BUILD_TINY_ANDROID), true)
INSTALLED_RECOVERYIMAGE_TARGET :=
endif

# Build files and then package it into the rom formats
.PHONY: droidcore
droidcore: files \
	systemimage \
	$(INSTALLED_BOOTIMAGE_TARGET) \
	$(INSTALLED_RECOVERYIMAGE_TARGET) \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(INTERNAL_DEFAULT_DOCS_TARGETS) \
	$(INSTALLED_FILES_FILE)

# The actual files built by the droidcore target changes depending
# on the build variant.
.PHONY: droid tests
droid tests: droidcore

$(call dist-for-goals, droid, \
	$(INTERNAL_UPDATE_PACKAGE_TARGET) \
	$(INTERNAL_OTA_PACKAGE_TARGET) \
	$(SYMBOLS_ZIP) \
	$(APPS_ZIP) \
	$(INTERNAL_EMULATOR_PACKAGE_TARGET) \
	$(PACKAGE_STATS_FILE) \
	$(INSTALLED_FILES_FILE) \
	$(INSTALLED_BUILD_PROP_TARGET) \
	$(BUILT_TARGET_FILES_PACKAGE) \
 )

# Tests are installed in userdata.img.  If we're building the tests
# variant, copy it for "make tests dist".  Also copy a zip of the
# contents of userdata.img, so that people can easily extract a
# single .apk.
ifeq ($(TARGET_BUILD_VARIANT),tests)
$(call dist-for-goals, droid, \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(BUILT_TESTS_ZIP_PACKAGE) \
 )
endif

.PHONY: docs
docs: $(ALL_DOCS)

.PHONY: sdk
ALL_SDK_TARGETS := $(INTERNAL_SDK_TARGET)
sdk: $(ALL_SDK_TARGETS)
$(call dist-for-goals,sdk,$(ALL_SDK_TARGETS))

.PHONY: findbugs
findbugs: $(INTERNAL_FINDBUGS_HTML_TARGET) $(INTERNAL_FINDBUGS_XML_TARGET)

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

# The rules for dataclean and installclean are defined in cleanbuild.mk.

#xxx scrape this from ALL_MODULE_NAME_TAGS
.PHONY: modules
modules:
	@echo "Available sub-modules:"
	@echo "$(call module-names-for-tag-list,$(ALL_MODULE_TAGS))" | \
	      sed -e 's/  */\n/g' | sort -u | $(COLUMN)

.PHONY: showcommands
showcommands:
	@echo >/dev/null

