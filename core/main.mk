# Only use ANDROID_BUILD_SHELL to wrap around bash.
# DO NOT use other shells such as zsh.
ifdef ANDROID_BUILD_SHELL
SHELL := $(ANDROID_BUILD_SHELL)
else
# Use bash, not whatever shell somebody has installed as /bin/sh
# This is repeated in config.mk, since envsetup.sh runs that file
# directly.
SHELL := /bin/bash
endif

# this turns off the suffix rules built into make
.SUFFIXES:

# this turns off the RCS / SCCS implicit rules of GNU Make
% : RCS/%,v
% : RCS/%
% : %,v
% : s.%
% : SCCS/s.%

# If a rule fails, delete $@.
.DELETE_ON_ERROR:

# Figure out where we are.
#TOP := $(dir $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))
#TOP := $(patsubst %/,%,$(TOP))

# TOPDIR is the normal variable you should use, because
# if we are executing relative to the current directory
# it can be "", whereas TOP must be "." which causes
# pattern matching problems when make strips off the
# trailing "./" from paths in various places.
#ifeq ($(TOP),.)
#TOPDIR :=
#else
#TOPDIR := $(TOP)/
#endif

# Check for broken versions of make.
ifneq (1,$(strip $(shell expr $(MAKE_VERSION) \>= 3.81)))
$(warning ********************************************************************************)
$(warning *  You are using version $(MAKE_VERSION) of make.)
$(warning *  Android can only be built by versions 3.81 and higher.)
$(warning *  see https://source.android.com/source/download.html)
$(warning ********************************************************************************)
$(error stopping)
endif

# Absolute path of the present working direcotry.
# This overrides the shell variable $PWD, which does not necessarily points to
# the top of the source tree, for example when "make -C" is used in m/mm/mmm.
PWD := $(shell pwd)

TOP := .
TOPDIR :=

BUILD_SYSTEM := $(TOPDIR)build/core

# Ensure JAVA_NOT_REQUIRED is not set externally.
JAVA_NOT_REQUIRED := false

# This is the default target.  It must be the first declared target.
.PHONY: droid
DEFAULT_GOAL := droid
$(DEFAULT_GOAL): droid_targets

.PHONY: droid_targets
droid_targets:

# Used to force goals to build.  Only use for conditionally defined goals.
.PHONY: FORCE
FORCE:

# These goals don't need to collect and include Android.mks/CleanSpec.mks
# in the source tree.
dont_bother_goals := clean clobber dataclean installclean \
    help out \
    snod systemimage-nodeps \
    stnod systemtarball-nodeps \
    userdataimage-nodeps userdatatarball-nodeps \
    cacheimage-nodeps \
    vendorimage-nodeps \
    systemotherimage-nodeps \
    ramdisk-nodeps \
    bootimage-nodeps \
    recoveryimage-nodeps \
    product-graph dump-products

ifneq ($(filter $(dont_bother_goals), $(MAKECMDGOALS)),)
dont_bother := true
endif

ORIGINAL_MAKECMDGOALS := $(MAKECMDGOALS)

# Targets that provide quick help on the build system.
include $(BUILD_SYSTEM)/help.mk

# Set up various standard variables based on configuration
# and host information.
include $(BUILD_SYSTEM)/config.mk

relaunch_with_ninja :=
ifneq ($(USE_NINJA),false)
ifndef BUILDING_WITH_NINJA
relaunch_with_ninja := true
endif
endif

ifeq ($(relaunch_with_ninja),true)
# Mark this is a ninja build.
$(shell mkdir -p $(OUT_DIR) && touch $(OUT_DIR)/ninja_build)
include build/core/ninja.mk
else # !relaunch_with_ninja
ifndef BUILDING_WITH_NINJA
# Remove ninja build mark if it exists.
$(shell rm -f $(OUT_DIR)/ninja_build)
endif

# Write the build number to a file so it can be read back in
# without changing the command line every time.  Avoids rebuilds
# when using ninja.
$(shell mkdir -p $(OUT_DIR) && \
    echo -n $(BUILD_NUMBER) > $(OUT_DIR)/build_number.txt && \
    echo -n $(BUILD_DATETIME) > $(OUT_DIR)/build_date.txt)
BUILD_NUMBER_FROM_FILE := $$(cat $(OUT_DIR)/build_number.txt)
BUILD_DATETIME_FROM_FILE := $$(cat $(OUT_DIR)/build_date.txt)
ifeq ($(HOST_OS),darwin)
DATE_FROM_FILE := date -r $(BUILD_DATETIME_FROM_FILE)
else
DATE_FROM_FILE := date -d @$(BUILD_DATETIME_FROM_FILE)
endif

# CTS-specific config.
-include cts/build/config.mk
# VTS-specific config.
-include test/vts/tools/vts-tradefed/build/config.mk

# This allows us to force a clean build - included after the config.mk
# environment setup is done, but before we generate any dependencies.  This
# file does the rm -rf inline so the deps which are all done below will
# be generated correctly
include $(BUILD_SYSTEM)/cleanbuild.mk

# Include the google-specific config
-include vendor/google/build/config.mk

VERSION_CHECK_SEQUENCE_NUMBER := 6
-include $(OUT_DIR)/versions_checked.mk
ifneq ($(VERSION_CHECK_SEQUENCE_NUMBER),$(VERSIONS_CHECKED))

$(info Checking build tools versions...)

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

ifeq ($(JAVA_NOT_REQUIRED), false)
java_version_str := $(shell unset _JAVA_OPTIONS && java -version 2>&1)
javac_version_str := $(shell unset _JAVA_OPTIONS && javac -version 2>&1)

# Check for the correct version of java, should be 1.8 by
# default and only 1.7 if LEGACY_USE_JAVA7 is set.
ifeq ($(LEGACY_USE_JAVA7),) # if LEGACY_USE_JAVA7 == ''
required_version := "1.8.x"
required_javac_version := "1.8"
java_version := $(shell echo '$(java_version_str)' | grep '[ "]1\.8[\. "$$]')
javac_version := $(shell echo '$(javac_version_str)' | grep '[ "]1\.8[\. "$$]')
else
required_version := "1.7.x"
required_javac_version := "1.7"
java_version := $(shell echo '$(java_version_str)' | grep '^java .*[ "]1\.7[\. "$$]')
javac_version := $(shell echo '$(javac_version_str)' | grep '[ "]1\.7[\. "$$]')
endif # if LEGACY_USE_JAVA7 == ''

ifeq ($(strip $(java_version)),)
$(info ************************************************************)
$(info You are attempting to build with the incorrect version)
$(info of java.)
$(info $(space))
$(info Your version is: $(java_version_str).)
$(info The required version is: $(required_version))
$(info $(space))
$(info Please follow the machine setup instructions at)
$(info $(space)$(space)$(space)$(space)https://source.android.com/source/initializing.html)
$(info ************************************************************)
$(error stop)
endif

# Check for the current JDK.
#
# For Java 1.7/1.8, we require OpenJDK on linux and Oracle JDK on Mac OS.
requires_openjdk := false
ifeq ($(BUILD_OS),linux)
requires_openjdk := true
endif


# Check for the current jdk
ifeq ($(requires_openjdk), true)
# The user asked for openjdk, so check that the host
# java version is really openjdk and not some other JDK.
ifeq ($(shell echo '$(java_version_str)' | grep -i openjdk),)
$(info ************************************************************)
$(info You asked for an OpenJDK based build but your version is)
$(info $(java_version_str).)
$(info ************************************************************)
$(error stop)
endif # java version is not OpenJdk
else # if requires_openjdk
ifneq ($(shell echo '$(java_version_str)' | grep -i openjdk),)
$(info ************************************************************)
$(info You are attempting to build with an unsupported JDK.)
$(info $(space))
$(info You use OpenJDK but only Sun/Oracle JDK is supported.)
$(info Please follow the machine setup instructions at)
$(info $(space)$(space)$(space)$(space)https://source.android.com/source/download.html)
$(info ************************************************************)
$(error stop)
endif # java version is not Sun Oracle JDK
endif # if requires_openjdk

KNOWN_INCOMPATIBLE_JAVAC_VERSIONS := google
incompat_javac := $(foreach v,$(KNOWN_INCOMPATIBLE_JAVAC_VERSIONS),$(findstring $(v),$(javac_version_str)))
ifneq ($(incompat_javac),)
javac_version :=
endif

# Check for the correct version of javac
ifeq ($(strip $(javac_version)),)
$(info ************************************************************)
$(info You are attempting to build with the incorrect version)
$(info of javac.)
$(info $(space))
$(info Your version is: $(javac_version_str).)
ifneq ($(incompat_javac),)
$(info This '$(incompat_javac)' version is not supported for Android platform builds.)
$(info Use a publicly available JDK and make sure you have run envsetup.sh / lunch.)
else
$(info The required version is: $(required_javac_version))
endif
$(info $(space))
$(info Please follow the machine setup instructions at)
$(info $(space)$(space)$(space)$(space)https://source.android.com/source/download.html)
$(info ************************************************************)
$(error stop)
endif

endif # if JAVA_NOT_REQUIRED

ifndef BUILD_EMULATOR
  # Emulator binaries are now provided under prebuilts/android-emulator/
  BUILD_EMULATOR := false
endif

$(shell echo 'VERSIONS_CHECKED := $(VERSION_CHECK_SEQUENCE_NUMBER)' \
        > $(OUT_DIR)/versions_checked.mk)
$(shell echo 'BUILD_EMULATOR ?= $(BUILD_EMULATOR)' \
        >> $(OUT_DIR)/versions_checked.mk)
endif

# These are the modifier targets that don't do anything themselves, but
# change the behavior of the build.
# (must be defined before including definitions.make)
INTERNAL_MODIFIER_TARGETS := showcommands all

# EMMA_INSTRUMENT_STATIC merges the static emma library to each emma-enabled module.
ifeq (true,$(EMMA_INSTRUMENT_STATIC))
EMMA_INSTRUMENT := true
endif

# Bring in standard build system definitions.
include $(BUILD_SYSTEM)/definitions.mk

# Bring in dex_preopt.mk
include $(BUILD_SYSTEM)/dex_preopt.mk

ifneq ($(filter user userdebug eng,$(MAKECMDGOALS)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Do not pass '$(filter user userdebug eng,$(MAKECMDGOALS))' on \
       the make command line.)
$(info Set TARGET_BUILD_VARIANT in buildspec.mk, or use lunch or)
$(info choosecombo.)
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

ifneq ($(filter-out $(INTERNAL_VALID_VARIANTS),$(TARGET_BUILD_VARIANT)),)
$(info ***************************************************************)
$(info ***************************************************************)
$(info Invalid variant: $(TARGET_BUILD_VARIANT))
$(info Valid values are: $(INTERNAL_VALID_VARIANTS))
$(info ***************************************************************)
$(info ***************************************************************)
$(error stopping)
endif

# -----------------------------------------------------------------
# Variable to check java support level inside PDK build.
# Not necessary if the components is not in PDK.
# not defined : not supported
# "sdk" : sdk API only
# "platform" : platform API supproted
TARGET_BUILD_JAVA_SUPPORT_LEVEL := platform

# -----------------------------------------------------------------
# The pdk (Platform Development Kit) build
include build/core/pdk_config.mk

#
# -----------------------------------------------------------------
# Jack version configuration
-include $(TOPDIR)prebuilts/sdk/tools/jack_versions.mk
-include $(TOPDIR)prebuilts/sdk/tools/jack_for_module.mk

#
# -----------------------------------------------------------------
# Install and start Jack server
-include $(TOPDIR)prebuilts/sdk/tools/jack_server_setup.mk

#
# -----------------------------------------------------------------
# Jacoco package name for Jack
-include $(TOPDIR)external/jacoco/config.mk

#
# -----------------------------------------------------------------
# Enable dynamic linker developer warnings for all builds except
# final release.
ifneq ($(PLATFORM_VERSION_CODENAME),REL)
  ADDITIONAL_BUILD_PROPERTIES += ro.bionic.ld.warning=1
endif

# -----------------------------------------------------------------
###
### In this section we set up the things that are different
### between the build variants
###

is_sdk_build :=

ifneq ($(filter sdk win_sdk sdk_addon,$(MAKECMDGOALS)),)
is_sdk_build := true
endif

# Add build properties for ART. These define system properties used by installd
# to pass flags to dex2oat.
ADDITIONAL_BUILD_PROPERTIES += persist.sys.dalvik.vm.lib.2=libart.so
ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.isa.$(TARGET_ARCH).variant=$(DEX2OAT_TARGET_CPU_VARIANT)
ifneq ($(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES),)
  ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.isa.$(TARGET_ARCH).features=$(DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
endif

ifdef TARGET_2ND_ARCH
  ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.isa.$(TARGET_2ND_ARCH).variant=$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_CPU_VARIANT)
  ifneq ($($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES),)
    ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.isa.$(TARGET_2ND_ARCH).features=$($(TARGET_2ND_ARCH_VAR_PREFIX)DEX2OAT_TARGET_INSTRUCTION_SET_FEATURES)
  endif
endif

## user/userdebug ##

user_variant := $(filter user userdebug,$(TARGET_BUILD_VARIANT))
enable_target_debugging := true
tags_to_install :=
ifneq (,$(user_variant))
  # Target is secure in user builds.
  ADDITIONAL_DEFAULT_PROPERTIES += ro.secure=1
  ADDITIONAL_DEFAULT_PROPERTIES += security.perf_harden=1

  ifeq ($(user_variant),user)
    ADDITIONAL_DEFAULT_PROPERTIES += ro.adb.secure=1
  endif

  ifeq ($(user_variant),userdebug)
    # Pick up some extra useful tools
    tags_to_install += debug
  else
    # Disable debugging in plain user builds.
    enable_target_debugging :=
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
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=1
  # Enable Dalvik lock contention logging.
  ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.lockprof.threshold=500
  # Include the debugging/testing OTA keys in this build.
  INCLUDE_TEST_OTA_KEYS := true
else # !enable_target_debugging
  # Target is less debuggable and adbd is off by default
  ADDITIONAL_DEFAULT_PROPERTIES += ro.debuggable=0
endif # !enable_target_debugging

## eng ##

ifeq ($(TARGET_BUILD_VARIANT),eng)
tags_to_install := debug eng
ifneq ($(filter ro.setupwizard.mode=ENABLED, $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))),)
  # Don't require the setup wizard on eng builds
  ADDITIONAL_BUILD_PROPERTIES := $(filter-out ro.setupwizard.mode=%,\
          $(call collapse-pairs, $(ADDITIONAL_BUILD_PROPERTIES))) \
          ro.setupwizard.mode=OPTIONAL
endif
ifndef is_sdk_build
  # To speedup startup of non-preopted builds, don't verify or compile the boot image.
  ADDITIONAL_BUILD_PROPERTIES += dalvik.vm.image-dex2oat-filter=verify-at-runtime
endif
endif

## sdk ##

ifdef is_sdk_build

# Detect if we want to build a repository for the SDK
sdk_repo_goal := $(strip $(filter sdk_repo,$(MAKECMDGOALS)))
MAKECMDGOALS := $(strip $(filter-out sdk_repo,$(MAKECMDGOALS)))

ifneq ($(words $(sort $(filter-out $(INTERNAL_MODIFIER_TARGETS) checkbuild emulator_tests target-files-package,$(MAKECMDGOALS)))),1)
$(error The 'sdk' target may not be specified with any other targets)
endif

# TODO: this should be eng I think.  Since the sdk is built from the eng
# variant.
tags_to_install := debug eng
ADDITIONAL_BUILD_PROPERTIES += xmpp.auto-presence=true
ADDITIONAL_BUILD_PROPERTIES += ro.config.nocheckin=yes
else # !sdk
endif

BUILD_WITHOUT_PV := true

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

ifdef is_sdk_build
# For the sdk goal, anything with the "samples" tag should be
# installed in /data even if that module also has "eng"/"debug"/"user".
define should-install-to-system
$(if $(filter samples tests,$(1)),,true)
endef
endif


# If they only used the modifier goals (showcommands, etc), we'll actually
# build the default target.
ifeq ($(filter-out $(INTERNAL_MODIFIER_TARGETS),$(MAKECMDGOALS)),)
.PHONY: $(INTERNAL_MODIFIER_TARGETS)
$(INTERNAL_MODIFIER_TARGETS): $(DEFAULT_GOAL)
endif

#
# Typical build; include any Android.mk files we can find.
#
subdirs := $(TOP)

FULL_BUILD := true

# Before we go and include all of the module makefiles, stash away
# the PRODUCT_* values so that later we can verify they are not modified.
stash_product_vars:=true
ifeq ($(stash_product_vars),true)
  $(call stash-product-vars, __STASHED)
endif

ifneq ($(ONE_SHOT_MAKEFILE),)
# We've probably been invoked by the "mm" shell function
# with a subdirectory's makefile.
include $(ONE_SHOT_MAKEFILE)
# Change CUSTOM_MODULES to include only modules that were
# defined by this makefile; this will install all of those
# modules as a side-effect.  Do this after including ONE_SHOT_MAKEFILE
# so that the modules will be installed in the same place they
# would have been with a normal make.
CUSTOM_MODULES := $(sort $(call get-tagged-modules,$(ALL_MODULE_TAGS)))
FULL_BUILD :=
# Stub out the notice targets, which probably aren't defined
# when using ONE_SHOT_MAKEFILE.
NOTICE-HOST-%: ;
NOTICE-TARGET-%: ;

# A helper goal printing out install paths
.PHONY: GET-INSTALL-PATH
GET-INSTALL-PATH:
	@echo "Install paths for modules in $(ONE_SHOT_MAKEFILE):"
	@$(foreach m, $(ALL_MODULES), $(if $(ALL_MODULES.$(m).INSTALLED), \
		echo 'INSTALL-PATH: $(m) $(ALL_MODULES.$(m).INSTALLED)';))

else # ONE_SHOT_MAKEFILE

ifneq ($(dont_bother),true)
#
# Include all of the makefiles in the system
#

# Can't use first-makefiles-under here because
# --mindepth=2 makes the prunes not work.
subdir_makefiles := \
	$(shell build/tools/findleaves.py $(FIND_LEAVES_EXCLUDES) $(subdirs) Android.mk)

ifeq ($(USE_SOONG),true)
subdir_makefiles := $(SOONG_ANDROID_MK) $(call filter-soong-makefiles,$(subdir_makefiles))
endif

$(foreach mk, $(subdir_makefiles),$(info including $(mk) ...)$(eval include $(mk)))

ifdef PDK_FUSION_PLATFORM_ZIP
# Bring in the PDK platform.zip modules.
include $(BUILD_SYSTEM)/pdk_fusion_modules.mk
endif # PDK_FUSION_PLATFORM_ZIP

endif # dont_bother

endif # ONE_SHOT_MAKEFILE

# Now with all Android.mks loaded we can do post cleaning steps.
include $(BUILD_SYSTEM)/post_clean.mk

ifeq ($(stash_product_vars),true)
  $(call assert-product-vars, __STASHED)
endif

include $(BUILD_SYSTEM)/legacy_prebuilts.mk
ifneq ($(filter-out $(GRANDFATHERED_ALL_PREBUILT),$(strip $(notdir $(ALL_PREBUILT)))),)
  $(warning *** Some files have been added to ALL_PREBUILT.)
  $(warning *)
  $(warning * ALL_PREBUILT is a deprecated mechanism that)
  $(warning * should not be used for new files.)
  $(warning * As an alternative, use PRODUCT_COPY_FILES in)
  $(warning * the appropriate product definition.)
  $(warning * build/target/product/core.mk is the product)
  $(warning * definition used in all products.)
  $(warning *)
  $(foreach bad_prebuilt,$(filter-out $(GRANDFATHERED_ALL_PREBUILT),$(strip $(notdir $(ALL_PREBUILT)))),$(warning * unexpected $(bad_prebuilt) in ALL_PREBUILT))
  $(warning *)
  $(error ALL_PREBUILT contains unexpected files)
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
#
# Resolve the required module name to 32-bit or 64-bit variant.
# Get a list of corresponding 32-bit module names, if one exists.
define get-32-bit-modules
$(strip $(foreach m,$(1),\
  $(if $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).CLASS),\
    $(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX))))
endef
# Get a list of corresponding 32-bit module names, if one exists;
# otherwise return the original module name
define get-32-bit-modules-if-we-can
$(strip $(foreach m,$(1),\
  $(if $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).CLASS),\
    $(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX),
    $(m))))
endef

# If a module is for a cross host os, the required modules must be for
# that OS too.
# If a module is built for 32-bit, the required modules must be 32-bit too;
# Otherwise if the module is an exectuable or shared library,
#   the required modules must be 64-bit;
#   otherwise we require both 64-bit and 32-bit variant, if one exists.
$(foreach m,$(ALL_MODULES),\
  $(eval r := $(ALL_MODULES.$(m).REQUIRED))\
  $(if $(r),\
    $(if $(ALL_MODULES.$(m).FOR_HOST_CROSS),\
      $(eval r := $(addprefix host_cross_,$(r))))\
    $(if $(ALL_MODULES.$(m).FOR_2ND_ARCH),\
      $(eval r_r := $(call get-32-bit-modules-if-we-can,$(r))),\
      $(if $(filter EXECUTABLES SHARED_LIBRARIES,$(ALL_MODULES.$(m).CLASS)),\
        $(eval r_r := $(r)),\
        $(eval r_r := $(r) $(call get-32-bit-modules,$(r)))\
       )\
     )\
     $(eval ALL_MODULES.$(m).REQUIRED := $(strip $(r_r)))\
  )\
)
r_r :=

define add-required-deps
$(1): | $(2)
endef

$(foreach m,$(ALL_MODULES), \
  $(eval r := $(ALL_MODULES.$(m).REQUIRED)) \
  $(if $(r), \
    $(eval r := $(call module-installed-files,$(r))) \
    $(eval t_m := $(filter $(TARGET_OUT_ROOT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval h_m := $(filter $(HOST_OUT_ROOT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval hc_m := $(filter $(HOST_CROSS_OUT_ROOT)/%, $(ALL_MODULES.$(m).INSTALLED))) \
    $(eval t_r := $(filter $(TARGET_OUT_ROOT)/%, $(r))) \
    $(eval h_r := $(filter $(HOST_OUT_ROOT)/%, $(r))) \
    $(eval hc_r := $(filter $(HOST_CROSS_OUT_ROOT)/%, $(r))) \
    $(eval t_m := $(filter-out $(t_r), $(t_m))) \
    $(eval h_m := $(filter-out $(h_r), $(h_m))) \
    $(eval hc_m := $(filter-out $(hc_r), $(hc_m))) \
    $(if $(t_m), $(eval $(call add-required-deps, $(t_m),$(t_r)))) \
    $(if $(h_m), $(eval $(call add-required-deps, $(h_m),$(h_r)))) \
    $(if $(hc_m), $(eval $(call add-required-deps, $(hc_m),$(hc_r)))) \
   ) \
 )

t_m :=
h_m :=
hc_m :=
t_r :=
h_r :=
hc_r :=

# Establish the dependecies on the shared libraries.
# It also adds the shared library module names to ALL_MODULES.$(m).REQUIRED,
# so they can be expanded to product_MODULES later.
# $(1): TARGET_ or HOST_ or HOST_CROSS_.
# $(2): non-empty for 2nd arch.
# $(3): non-empty for host cross compile.
define resolve-shared-libs-depes
$(foreach m,$($(if $(2),$($(1)2ND_ARCH_VAR_PREFIX))$(1)DEPENDENCIES_ON_SHARED_LIBRARIES),\
  $(eval p := $(subst :,$(space),$(m)))\
  $(eval mod := $(firstword $(p)))\
  $(eval deps := $(subst $(comma),$(space),$(lastword $(p))))\
  $(if $(2),$(eval deps := $(addsuffix $($(1)2ND_ARCH_MODULE_SUFFIX),$(deps))))\
  $(if $(3),$(eval deps := $(addprefix host_cross_,$(deps))))\
  $(eval r := $(filter $($(1)OUT)/%,$(call module-installed-files,\
    $(deps))))\
  $(eval $(call add-required-deps,$(word 2,$(p)),$(r)))\
  $(eval ALL_MODULES.$(mod).REQUIRED += $(deps)))
endef

$(call resolve-shared-libs-depes,TARGET_)
ifdef TARGET_2ND_ARCH
$(call resolve-shared-libs-depes,TARGET_,true)
endif
$(call resolve-shared-libs-depes,HOST_)
ifdef HOST_2ND_ARCH
$(call resolve-shared-libs-depes,HOST_,true)
endif
ifdef HOST_CROSS_OS
$(call resolve-shared-libs-depes,HOST_CROSS_,,true)
endif

m :=
r :=
p :=
deps :=
add-required-deps :=

# -------------------------------------------------------------------
# Figure out our module sets.
#
# Of the modules defined by the component makefiles,
# determine what we actually want to build.

###########################################################
## Expand a module name list with REQUIRED modules
###########################################################
# $(1): The variable name that holds the initial module name list.
#       the variable will be modified to hold the expanded results.
# $(2): The initial module name list.
# Returns empty string (maybe with some whitespaces).
define expand-required-modules
$(eval _erm_new_modules := $(sort $(filter-out $($(1)),\
  $(foreach m,$(2),$(ALL_MODULES.$(m).REQUIRED)))))\
$(if $(_erm_new_modules),$(eval $(1) += $(_erm_new_modules))\
  $(call expand-required-modules,$(1),$(_erm_new_modules)))
endef

ifdef FULL_BUILD
  # The base list of modules to build for this product is specified
  # by the appropriate product definition file, which was included
  # by product_config.mk.
  product_MODULES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES)
  # Filter out the overridden packages before doing expansion
  product_MODULES := $(filter-out $(foreach p, $(product_MODULES), \
      $(PACKAGES.$(p).OVERRIDES)), $(product_MODULES))

  # Resolve the :32 :64 module name
  modules_32 := $(patsubst %:32,%,$(filter %:32, $(product_MODULES)))
  modules_64 := $(patsubst %:64,%,$(filter %:64, $(product_MODULES)))
  modules_rest := $(filter-out %:32 %:64,$(product_MODULES))
  # Note for 32-bit product, $(modules_32) and $(modules_64) will be
  # added as their original module names.
  product_MODULES := $(call get-32-bit-modules-if-we-can, $(modules_32))
  product_MODULES += $(modules_64)
  # For the rest we add both
  product_MODULES += $(call get-32-bit-modules, $(modules_rest))
  product_MODULES += $(modules_rest)

  $(call expand-required-modules,product_MODULES,$(product_MODULES))

  product_FILES := $(call module-installed-files, $(product_MODULES))
  ifeq (0,1)
    $(info product_FILES for $(TARGET_DEVICE) ($(INTERNAL_PRODUCT)):)
    $(foreach p,$(product_FILES),$(info :   $(p)))
    $(error done)
  endif
else
  # We're not doing a full build, and are probably only including
  # a subset of the module makefiles.  Don't try to build any modules
  # requested by the product, because we probably won't have rules
  # to build them.
  product_FILES :=
endif

eng_MODULES := $(sort \
        $(call get-tagged-modules,eng) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_ENG)) \
    )
debug_MODULES := $(sort \
        $(call get-tagged-modules,debug) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_DEBUG)) \
    )
tests_MODULES := $(sort \
        $(call get-tagged-modules,tests) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_TESTS)) \
    )

# TODO: Remove the 3 places in the tree that use ALL_DEFAULT_INSTALLED_MODULES
# and get rid of it from this list.
modules_to_install := $(sort \
    $(ALL_DEFAULT_INSTALLED_MODULES) \
    $(product_FILES) \
    $(foreach tag,$(tags_to_install),$($(tag)_MODULES)) \
    $(CUSTOM_MODULES) \
  )

# Some packages may override others using LOCAL_OVERRIDES_PACKAGES.
# Filter out (do not install) any overridden packages.
overridden_packages := $(call get-package-overrides,$(modules_to_install))
ifdef overridden_packages
#  old_modules_to_install := $(modules_to_install)
  modules_to_install := \
      $(filter-out $(foreach p,$(overridden_packages),$(p) %/$(p).apk %/$(p).odex), \
          $(modules_to_install))
endif
#$(error filtered out
#           $(filter-out $(modules_to_install),$(old_modules_to_install)))

# Don't include any GNU General Public License shared objects or static
# libraries in SDK images.  GPL executables (not static/dynamic libraries)
# are okay if they don't link against any closed source libraries (directly
# or indirectly)

# It's ok (and necessary) to build the host tools, but nothing that's
# going to be installed on the target (including static libraries).

ifdef is_sdk_build
  target_gnu_MODULES := \
              $(filter \
                      $(TARGET_OUT_INTERMEDIATES)/% \
                      $(TARGET_OUT)/% \
                      $(TARGET_OUT_DATA)/%, \
                              $(sort $(call get-tagged-modules,gnu)))
  target_gnu_MODULES := $(filter-out $(TARGET_OUT_EXECUTABLES)/%,$(target_gnu_MODULES))
  $(info Removing from sdk:)$(foreach d,$(target_gnu_MODULES),$(info : $(d)))
  modules_to_install := \
              $(filter-out $(target_gnu_MODULES),$(modules_to_install))

  # Ensure every module listed in PRODUCT_PACKAGES* gets something installed
  # TODO: Should we do this for all builds and not just the sdk?
  dangling_modules :=
  $(foreach m, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED) $(ALL_MODULES.$(m)$(TARGET_2ND_ARCH_MODULE_SUFFIX).INSTALLED)),,\
      $(eval dangling_modules += $(m))))
  ifneq ($(dangling_modules),)
    $(warning: Modules '$(dangling_modules)' in PRODUCT_PACKAGES have nothing to install!)
  endif
  $(foreach m, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_DEBUG), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED)),,\
      $(warning $(ALL_MODULES.$(m).MAKEFILE): Module '$(m)' in PRODUCT_PACKAGES_DEBUG has nothing to install!)))
  $(foreach m, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_ENG), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED)),,\
      $(warning $(ALL_MODULES.$(m).MAKEFILE): Module '$(m)' in PRODUCT_PACKAGES_ENG has nothing to install!)))
  $(foreach m, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_TESTS), \
    $(if $(strip $(ALL_MODULES.$(m).INSTALLED)),,\
      $(warning $(ALL_MODULES.$(m).MAKEFILE): Module '$(m)' in PRODUCT_PACKAGES_TESTS has nothing to install!)))
endif

# build/core/Makefile contains extra stuff that we don't want to pollute this
# top-level makefile with.  It expects that ALL_DEFAULT_INSTALLED_MODULES
# contains everything that's built during the current make, but it also further
# extends ALL_DEFAULT_INSTALLED_MODULES.
ALL_DEFAULT_INSTALLED_MODULES := $(modules_to_install)
include $(BUILD_SYSTEM)/Makefile
modules_to_install := $(sort $(ALL_DEFAULT_INSTALLED_MODULES))
ALL_DEFAULT_INSTALLED_MODULES :=


# These are additional goals that we build, in order to make sure that there
# is as little code as possible in the tree that doesn't build.
modules_to_check := $(foreach m,$(ALL_MODULES),$(ALL_MODULES.$(m).CHECKED))

# If you would like to build all goals, and not skip any intermediate
# steps, you can pass the "all" modifier goal on the commandline.
ifneq ($(filter all,$(MAKECMDGOALS)),)
modules_to_check += $(foreach m,$(ALL_MODULES),$(ALL_MODULES.$(m).BUILT))
endif

# for easier debugging
modules_to_check := $(sort $(modules_to_check))
#$(error modules_to_check $(modules_to_check))

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
files: prebuilt \
        $(modules_to_install) \
        $(INSTALLED_ANDROID_INFO_TXT_TARGET)

# -------------------------------------------------------------------

.PHONY: checkbuild
checkbuild: $(modules_to_check) droid_targets
ifeq ($(USE_SOONG),true)
checkbuild: checkbuild-soong
endif
ifeq (true,$(ANDROID_BUILD_EVERYTHING_BY_DEFAULT))
droid: checkbuild
endif

.PHONY: ramdisk
ramdisk: $(INSTALLED_RAMDISK_TARGET)

.PHONY: systemtarball
systemtarball: $(INSTALLED_SYSTEMTARBALL_TARGET)

.PHONY: boottarball
boottarball: $(INSTALLED_BOOTTARBALL_TARGET)

.PHONY: userdataimage
userdataimage: $(INSTALLED_USERDATAIMAGE_TARGET)

ifneq (,$(filter userdataimage, $(MAKECMDGOALS)))
$(call dist-for-goals, userdataimage, $(BUILT_USERDATAIMAGE_TARGET))
endif

.PHONY: userdatatarball
userdatatarball: $(INSTALLED_USERDATATARBALL_TARGET)

.PHONY: cacheimage
cacheimage: $(INSTALLED_CACHEIMAGE_TARGET)

.PHONY: vendorimage
vendorimage: $(INSTALLED_VENDORIMAGE_TARGET)

.PHONY: systemotherimage
systemotherimage: $(INSTALLED_SYSTEMOTHERIMAGE_TARGET)

.PHONY: bootimage
bootimage: $(INSTALLED_BOOTIMAGE_TARGET)

# phony target that include any targets in $(ALL_MODULES)
.PHONY: all_modules
ifndef BUILD_MODULES_IN_PATHS
all_modules: $(ALL_MODULES)
else
# BUILD_MODULES_IN_PATHS is a list of paths relative to the top of the tree
build_modules_in_paths := $(patsubst ./%,%,$(BUILD_MODULES_IN_PATHS))
module_path_patterns := $(foreach p, $(build_modules_in_paths),\
    $(if $(filter %/,$(p)),$(p)%,$(p)/%))
my_all_modules := $(sort $(foreach m, $(ALL_MODULES),$(if $(filter\
    $(module_path_patterns), $(addsuffix /,$(ALL_MODULES.$(m).PATH))),$(m))))
all_modules: $(my_all_modules)
endif


# Build files and then package it into the rom formats
.PHONY: droidcore
droidcore: files \
	systemimage \
	$(INSTALLED_BOOTIMAGE_TARGET) \
	$(INSTALLED_RECOVERYIMAGE_TARGET) \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(INSTALLED_CACHEIMAGE_TARGET) \
	$(INSTALLED_VENDORIMAGE_TARGET) \
	$(INSTALLED_SYSTEMOTHERIMAGE_TARGET) \
	$(INSTALLED_FILES_FILE) \
	$(INSTALLED_FILES_FILE_VENDOR) \
	$(INSTALLED_FILES_FILE_SYSTEMOTHER)

# dist_files only for putting your library into the dist directory with a full build.
.PHONY: dist_files

ifneq ($(TARGET_BUILD_APPS),)
  # If this build is just for apps, only build apps and not the full system by default.

  unbundled_build_modules :=
  ifneq ($(filter all,$(TARGET_BUILD_APPS)),)
    # If they used the magic goal "all" then build all apps in the source tree.
    unbundled_build_modules := $(foreach m,$(sort $(ALL_MODULES)),$(if $(filter APPS,$(ALL_MODULES.$(m).CLASS)),$(m)))
  else
    unbundled_build_modules := $(TARGET_BUILD_APPS)
  endif

  # Dist the installed files if they exist.
  apps_only_installed_files := $(foreach m,$(unbundled_build_modules),$(ALL_MODULES.$(m).INSTALLED))
  $(call dist-for-goals,apps_only, $(apps_only_installed_files))
  # For uninstallable modules such as static Java library, we have to dist the built file,
  # as <module_name>.<suffix>
  apps_only_dist_built_files := $(foreach m,$(unbundled_build_modules),$(if $(ALL_MODULES.$(m).INSTALLED),,\
      $(if $(ALL_MODULES.$(m).BUILT),$(ALL_MODULES.$(m).BUILT):$(m)$(suffix $(ALL_MODULES.$(m).BUILT)))\
      $(if $(ALL_MODULES.$(m).AAR),$(ALL_MODULES.$(m).AAR):$(m).aar)\
      ))
  $(call dist-for-goals,apps_only, $(apps_only_dist_built_files))

  ifeq ($(EMMA_INSTRUMENT),true)
    $(EMMA_META_ZIP) : $(apps_only_installed_files)

    $(call dist-for-goals,apps_only, $(EMMA_META_ZIP))
  endif

  $(PROGUARD_DICT_ZIP) : $(apps_only_installed_files)
  $(call dist-for-goals,apps_only, $(PROGUARD_DICT_ZIP))

  $(SYMBOLS_ZIP) : $(apps_only_installed_files)
  $(call dist-for-goals,apps_only, $(SYMBOLS_ZIP))

.PHONY: apps_only
apps_only: $(unbundled_build_modules)

droid_targets: apps_only

# Combine the NOTICE files for a apps_only build
$(eval $(call combine-notice-files, \
    $(target_notice_file_txt), \
    $(target_notice_file_html), \
    "Notices for files for apps:", \
    $(TARGET_OUT_NOTICE_FILES), \
    $(apps_only_installed_files)))


else # TARGET_BUILD_APPS
  $(call dist-for-goals, droidcore, \
    $(INTERNAL_UPDATE_PACKAGE_TARGET) \
    $(INTERNAL_OTA_PACKAGE_TARGET) \
    $(BUILT_OTATOOLS_PACKAGE) \
    $(SYMBOLS_ZIP) \
    $(INSTALLED_FILES_FILE) \
    $(INSTALLED_FILES_FILE_VENDOR) \
    $(INSTALLED_FILES_FILE_SYSTEMOTHER) \
    $(INSTALLED_BUILD_PROP_TARGET) \
    $(BUILT_TARGET_FILES_PACKAGE) \
    $(INSTALLED_ANDROID_INFO_TXT_TARGET) \
    $(INSTALLED_RAMDISK_TARGET) \
   )

  # Put a copy of the radio/bootloader files in the dist dir.
  $(foreach f,$(INSTALLED_RADIOIMAGE_TARGET), \
    $(call dist-for-goals, droidcore, $(f)))

  ifneq ($(ANDROID_BUILD_EMBEDDED),true)
  ifneq ($(TARGET_BUILD_PDK),true)
    $(call dist-for-goals, droidcore, \
      $(APPS_ZIP) \
      $(INTERNAL_EMULATOR_PACKAGE_TARGET) \
      $(PACKAGE_STATS_FILE) \
    )
  endif
  endif

  ifeq ($(EMMA_INSTRUMENT),true)
    $(EMMA_META_ZIP) : $(INSTALLED_SYSTEMIMAGE)

    $(call dist-for-goals, dist_files, $(EMMA_META_ZIP))
  endif

# Building a full system-- the default is to build droidcore
droid_targets: droidcore dist_files

endif # TARGET_BUILD_APPS

.PHONY: docs
docs: $(ALL_DOCS)

.PHONY: sdk
ALL_SDK_TARGETS := $(INTERNAL_SDK_TARGET)
sdk: $(ALL_SDK_TARGETS)
$(call dist-for-goals,sdk win_sdk, \
    $(ALL_SDK_TARGETS) \
    $(SYMBOLS_ZIP) \
    $(INSTALLED_BUILD_PROP_TARGET) \
)

# umbrella targets to assit engineers in verifying builds
.PHONY: java native target host java-host java-target native-host native-target \
        java-host-tests java-target-tests native-host-tests native-target-tests \
        java-tests native-tests host-tests target-tests tests
# some synonyms
.PHONY: host-java target-java host-native target-native \
        target-java-tests target-native-tests
host-java : java-host
target-java : java-target
host-native : native-host
target-native : native-target
target-java-tests : java-target-tests
target-native-tests : native-target-tests
tests : host-tests target-tests

# To catch more build breakage, check build tests modules in eng and userdebug builds.
ifneq ($(ANDROID_NO_TEST_CHECK),true)
ifneq ($(TARGET_BUILD_PDK),true)
ifneq ($(filter eng userdebug,$(TARGET_BUILD_VARIANT)),)
droidcore : target-tests host-tests
endif
endif
endif

ifneq (,$(filter samplecode, $(MAKECMDGOALS)))
.PHONY: samplecode
sample_MODULES := $(sort $(call get-tagged-modules,samples))
sample_APKS_DEST_PATH := $(TARGET_COMMON_OUT_ROOT)/samples
sample_APKS_COLLECTION := \
        $(foreach module,$(sample_MODULES),$(sample_APKS_DEST_PATH)/$(notdir $(module)))
$(foreach module,$(sample_MODULES),$(eval $(call \
        copy-one-file,$(module),$(sample_APKS_DEST_PATH)/$(notdir $(module)))))
sample_ADDITIONAL_INSTALLED := \
        $(filter-out $(modules_to_install) $(modules_to_check) $(ALL_PREBUILT),$(sample_MODULES))
samplecode: $(sample_APKS_COLLECTION)
	@echo "Collect sample code apks: $^"
	# remove apks that are not intended to be installed.
	rm -f $(sample_ADDITIONAL_INSTALLED)
endif  # samplecode in $(MAKECMDGOALS)

.PHONY: findbugs
findbugs: $(INTERNAL_FINDBUGS_HTML_TARGET) $(INTERNAL_FINDBUGS_XML_TARGET)

.PHONY: clean
clean:
	@rm -rf $(OUT_DIR)/*
	@echo "Entire build directory removed."

.PHONY: clobber
clobber: clean

# The rules for dataclean and installclean are defined in cleanbuild.mk.

#xxx scrape this from ALL_MODULE_NAME_TAGS
.PHONY: modules
modules:
	@echo "Available sub-modules:"
	@echo "$(call module-names-for-tag-list,$(ALL_MODULE_TAGS))" | \
	      tr -s ' ' '\n' | sort -u | $(COLUMN)

.PHONY: showcommands
showcommands:
	@echo >/dev/null

.PHONY: nothing
nothing:
	@echo Successfully read the makefiles.
endif # !relaunch_with_ninja
