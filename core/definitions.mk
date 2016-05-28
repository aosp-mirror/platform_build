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

##
## Common build system definitions.  Mostly standard
## commands for building various types of targets, which
## are used by others to construct the final targets.
##

# These are variables we use to collect overall lists
# of things being processed.

# Full paths to all of the documentation
ALL_DOCS:=

# The short names of all of the targets in the system.
# For each element of ALL_MODULES, two other variables
# are defined:
#   $(ALL_MODULES.$(target)).BUILT
#   $(ALL_MODULES.$(target)).INSTALLED
# The BUILT variable contains LOCAL_BUILT_MODULE for that
# target, and the INSTALLED variable contains the LOCAL_INSTALLED_MODULE.
# Some targets may have multiple files listed in the BUILT and INSTALLED
# sub-variables.
ALL_MODULES:=

# Full paths to targets that should be added to the "make droid"
# set of installed targets.
ALL_DEFAULT_INSTALLED_MODULES:=

# The list of tags that have been defined by
# LOCAL_MODULE_TAGS.  Each word in this variable maps
# to a corresponding ALL_MODULE_TAGS.<tagname> variable
# that contains all of the INSTALLED_MODULEs with that tag.
ALL_MODULE_TAGS:=

# Similar to ALL_MODULE_TAGS, but contains the short names
# of all targets for a particular tag.  The top-level variable
# won't have the list of tags;  ust ALL_MODULE_TAGS to get
# the list of all known tags.  (This means that this variable
# will always be empty; it's just here as a placeholder for
# its sub-variables.)
ALL_MODULE_NAME_TAGS:=

# Full paths to all prebuilt files that will be copied
# (used to make the dependency on acp)
ALL_PREBUILT:=

# Full path to all files that are made by some tool
ALL_GENERATED_SOURCES:=

# Full path to all asm, C, C++, lex and yacc generated C files.
# These all have an order-only dependency on the copied headers
ALL_C_CPP_ETC_OBJECTS:=

# The list of dynamic binaries that haven't been stripped/compressed/etc.
ALL_ORIGINAL_DYNAMIC_BINARIES:=

# These files go into the SDK
ALL_SDK_FILES:=

# Files for dalvik.  This is often build without building the rest of the OS.
INTERNAL_DALVIK_MODULES:=

# All findbugs xml files
ALL_FINDBUGS_FILES:=

# GPL module license files
ALL_GPL_MODULE_LICENSE_FILES:=

# Target and host installed module's dependencies on shared libraries.
# They are list of "<module_name>:<installed_file>:lib1,lib2...".
TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES :=
$(TARGET_2ND_ARCH_VAR_PREFIX)TARGET_DEPENDENCIES_ON_SHARED_LIBRARIES :=
HOST_DEPENDENCIES_ON_SHARED_LIBRARIES :=
$(HOST_2ND_ARCH_VAR_PREFIX)HOST_DEPENDENCIES_ON_SHARED_LIBRARIES :=
HOST_CROSS_DEPENDENCIES_ON_SHARED_LIBRARIES :=
$(HOST_CROSS_2ND_ARCH_VAR_PREFIX)HOST_CROSS_DEPENDENCIES_ON_SHARED_LIBRARIES :=

# Generated class file names for Android resource.
# They are escaped and quoted so can be passed safely to a bash command.
ANDROID_RESOURCE_GENERATED_CLASSES := 'R.class' 'R$$*.class' 'Manifest.class' 'Manifest$$*.class'

# Display names for various build targets
TARGET_DISPLAY := target
HOST_DISPLAY := host
HOST_CROSS_DISPLAY := host cross

###########################################################
## Debugging; prints a variable list to stdout
###########################################################

# $(1): variable name list, not variable values
define print-vars
$(foreach var,$(1), \
  $(info $(var):) \
  $(foreach word,$($(var)), \
    $(info $(space)$(space)$(word)) \
   ) \
 )
endef

###########################################################
## Evaluates to true if the string contains the word true,
## and empty otherwise
## $(1): a var to test
###########################################################

define true-or-empty
$(filter true, $(1))
endef


###########################################################
## Retrieve the directory of the current makefile
## Must be called before including any other makefile!!
###########################################################

# Figure out where we are.
define my-dir
$(strip \
  $(eval LOCAL_MODULE_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(eval LOCAL_MODULE_MAKEFILE_DEP := $(if $(BUILDING_WITH_NINJA),,$$(LOCAL_MODULE_MAKEFILE))) \
  $(if $(filter $(BUILD_SYSTEM)/% $(OUT_DIR)/%,$(LOCAL_MODULE_MAKEFILE)), \
    $(error my-dir must be called before including any other makefile.) \
   , \
    $(patsubst %/,%,$(dir $(LOCAL_MODULE_MAKEFILE))) \
   ) \
 )
endef

###########################################################
## Remove any makefiles that are being handled by soong
###########################################################
ifeq ($(USE_SOONG),true)
define filter-soong-makefiles
$(foreach mk,$(1),\
  $(if $(wildcard $(patsubst %/Android.mk,%/Android.bp,$(mk))),\
    $(info skipping $(mk) ...),\
    $(mk)))
endef
else
define filter-soong-makefiles
$(1)
endef
endif

###########################################################
## Retrieve a list of all makefiles immediately below some directory
###########################################################

define all-makefiles-under
$(sort $(call filter-soong-makefiles,$(wildcard $(1)/*/Android.mk)))
endef

###########################################################
## Look under a directory for makefiles that don't have parent
## makefiles.
###########################################################

# $(1): directory to search under
# Ignores $(1)/Android.mk
define first-makefiles-under
$(call filter-soong-makefiles,\
  $(shell build/tools/findleaves.py $(FIND_LEAVES_EXCLUDES) \
        --mindepth=2 $(1) Android.mk))
endef

###########################################################
## Retrieve a list of all makefiles immediately below your directory
## Must be called before including any other makefile!!
###########################################################

define all-subdir-makefiles
$(call all-makefiles-under,$(call my-dir))
endef

###########################################################
## Look in the named list of directories for makefiles,
## relative to the current directory.
## Must be called before including any other makefile!!
###########################################################

# $(1): List of directories to look for under this directory
define all-named-subdir-makefiles
$(sort $(call filter-soong-makefiles,\
  $(wildcard $(addsuffix /Android.mk, $(addprefix $(call my-dir)/,$(1))))))
endef

###########################################################
## Find all of the directories under the named directories with
## the specified name.
## Meant to be used like:
##    INC_DIRS := $(call all-named-dirs-under,inc,.)
###########################################################

define all-named-dirs-under
$(call find-subdir-files,$(2) -type d -name "$(1)")
endef

###########################################################
## Find all the directories under the current directory that
## haves name that match $(1)
###########################################################

define all-subdir-named-dirs
$(call all-named-dirs-under,$(1),.)
endef

###########################################################
## Find all of the files under the named directories with
## the specified name.
## Meant to be used like:
##    SRC_FILES := $(call all-named-files-under,*.h,src tests)
###########################################################

define all-named-files-under
$(call find-files-in-subdirs,$(LOCAL_PATH),"$(1)",$(2))
endef

###########################################################
## Find all of the files under the current directory with
## the specified name.
###########################################################

define all-subdir-named-files
$(call all-named-files-under,$(1),.)
endef

###########################################################
## Find all of the java files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-java-files-under,src tests)
###########################################################

define all-java-files-under
$(call all-named-files-under,*.java,$(1))
endef

###########################################################
## Find all of the java files from here.  Meant to be used like:
##    SRC_FILES := $(call all-subdir-java-files)
###########################################################

define all-subdir-java-files
$(call all-java-files-under,.)
endef

###########################################################
## Find all of the c files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-c-files-under,src tests)
###########################################################

define all-c-files-under
$(call all-named-files-under,*.c,$(1))
endef

###########################################################
## Find all of the c files from here.  Meant to be used like:
##    SRC_FILES := $(call all-subdir-c-files)
###########################################################

define all-subdir-c-files
$(call all-c-files-under,.)
endef

###########################################################
## Find all of the cpp files under the named directories.
## LOCAL_CPP_EXTENSION is respected if set.
## Meant to be used like:
##    SRC_FILES := $(call all-cpp-files-under,src tests)
###########################################################

define all-cpp-files-under
$(sort $(patsubst ./%,%, \
  $(shell cd $(LOCAL_PATH) ; \
          find -L $(1) -name "*$(or $(LOCAL_CPP_EXTENSION),.cpp)" -and -not -name ".*") \
 ))
endef

###########################################################
## Find all of the cpp files from here.  Meant to be used like:
##    SRC_FILES := $(call all-subdir-cpp-files)
###########################################################

define all-subdir-cpp-files
$(call all-cpp-files-under,.)
endef

###########################################################
## Find all files named "I*.aidl" under the named directories,
## which must be relative to $(LOCAL_PATH).  The returned list
## is relative to $(LOCAL_PATH).
###########################################################

define all-Iaidl-files-under
$(call all-named-files-under,I*.aidl,$(1))
endef

###########################################################
## Find all of the "I*.aidl" files under $(LOCAL_PATH).
###########################################################

define all-subdir-Iaidl-files
$(call all-Iaidl-files-under,.)
endef

###########################################################
## Find all files named "*.vts" under the named directories,
## which must be relative to $(LOCAL_PATH).  The returned list
## is relative to $(LOCAL_PATH).
###########################################################

define all-vts-files-under
$(call all-named-files-under,*.vts,$(1))
endef

###########################################################
## Find all of the "*.vts" files under $(LOCAL_PATH).
###########################################################

define all-subdir-vts-files
$(call all-vts-files-under,.)
endef

###########################################################
## Find all of the logtags files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-logtags-files-under,src)
###########################################################

define all-logtags-files-under
$(call all-named-files-under,*.logtags,$(1))
endef

###########################################################
## Find all of the .proto files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-proto-files-under,src)
###########################################################

define all-proto-files-under
$(call all-named-files-under,*.proto,$(1))
endef

###########################################################
## Find all of the RenderScript files under the named directories.
##  Meant to be used like:
##    SRC_FILES := $(call all-renderscript-files-under,src)
###########################################################

define all-renderscript-files-under
$(call find-subdir-files,$(1) \( -name "*.rs" -or -name "*.fs" \) -and -not -name ".*")
endef

###########################################################
## Find all of the S files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-c-files-under,src tests)
###########################################################

define all-S-files-under
$(call all-named-files-under,*.S,$(1))
endef

###########################################################
## Find all of the html files under the named directories.
## Meant to be used like:
##    SRC_FILES := $(call all-html-files-under,src tests)
###########################################################

define all-html-files-under
$(call all-named-files-under,*.html,$(1))
endef

###########################################################
## Find all of the html files from here.  Meant to be used like:
##    SRC_FILES := $(call all-subdir-html-files)
###########################################################

define all-subdir-html-files
$(call all-html-files-under,.)
endef

###########################################################
## Find all of the files matching pattern
##    SRC_FILES := $(call find-subdir-files, <pattern>)
###########################################################

define find-subdir-files
$(sort $(patsubst ./%,%,$(shell cd $(LOCAL_PATH) ; find -L $(1))))
endef

###########################################################
# find the files in the subdirectory $1 of LOCAL_DIR
# matching pattern $2, filtering out files $3
# e.g.
#     SRC_FILES += $(call find-subdir-subdir-files, \
#                         css, *.cpp, DontWantThis.cpp)
###########################################################

define find-subdir-subdir-files
$(sort $(filter-out $(patsubst %,$(1)/%,$(3)),$(patsubst ./%,%,$(shell cd \
            $(LOCAL_PATH) ; find -L $(1) -maxdepth 1 -name $(2)))))
endef

###########################################################
## Find all of the files matching pattern
##    SRC_FILES := $(call all-subdir-java-files)
###########################################################

define find-subdir-assets
$(sort $(if $(1),$(patsubst ./%,%, \
	$(shell if [ -d $(1) ] ; then cd $(1) ; find -L ./ -not -name '.*' -and -type f -and -not -type l ; fi)), \
	$(warning Empty argument supplied to find-subdir-assets) \
))
endef

###########################################################
## Find various file types in a list of directories relative to $(LOCAL_PATH)
###########################################################

define find-other-java-files
$(call all-java-files-under,$(1))
endef

define find-other-html-files
$(call all-html-files-under,$(1))
endef

###########################################################
# Use utility find to find given files in the given subdirs.
# This function uses $(1), instead of LOCAL_PATH as the base.
# $(1): the base dir, relative to the root of the source tree.
# $(2): the file name pattern to be passed to find as "-name".
# $(3): a list of subdirs of the base dir.
# Returns: a list of paths relative to the base dir.
###########################################################

define find-files-in-subdirs
$(sort $(patsubst ./%,%, \
  $(shell cd $(1) ; \
          find -L $(3) -name $(2) -and -not -name ".*") \
 ))
endef

###########################################################
## Scan through each directory of $(1) looking for files
## that match $(2) using $(wildcard).  Useful for seeing if
## a given directory or one of its parents contains
## a particular file.  Returns the first match found,
## starting furthest from the root.
###########################################################

define find-parent-file
$(strip \
  $(eval _fpf := $(sort $(wildcard $(foreach f, $(2), $(strip $(1))/$(f))))) \
  $(if $(_fpf),$(_fpf), \
       $(if $(filter-out ./ .,$(1)), \
             $(call find-parent-file,$(patsubst %/,%,$(dir $(1))),$(2)) \
        ) \
   ) \
)
endef

###########################################################
## Function we can evaluate to introduce a dynamic dependency
###########################################################

define add-dependency
$(1): $(2)
endef

###########################################################
## Reverse order of a list
###########################################################

define reverse-list
$(if $(1),$(call reverse-list,$(wordlist 2,$(words $(1)),$(1)))) $(firstword $(1))
endef

###########################################################
## The intermediates directory.  Where object files go for
## a given target.  We could technically get away without
## the "_intermediates" suffix on the directory, but it's
## nice to be able to grep for that string to find out if
## anyone's abusing the system.
###########################################################

# $(1): target class, like "APPS"
# $(2): target name, like "NotePad"
# $(3): if non-empty, this is a HOST target.
# $(4): if non-empty, force the intermediates to be COMMON
# $(5): if non-empty, force the intermediates to be for the 2nd arch
# $(6): if non-empty, force the intermediates to be for the host cross os
define intermediates-dir-for
$(strip \
    $(eval _idfClass := $(strip $(1))) \
    $(if $(_idfClass),, \
        $(error $(LOCAL_PATH): Class not defined in call to intermediates-dir-for)) \
    $(eval _idfName := $(strip $(2))) \
    $(if $(_idfName),, \
        $(error $(LOCAL_PATH): Name not defined in call to intermediates-dir-for)) \
    $(eval _idfPrefix := $(if $(strip $(3)),$(if $(strip $(6)),HOST_CROSS,HOST),TARGET)) \
    $(eval _idf2ndArchPrefix := $(if $(strip $(5)),$(TARGET_2ND_ARCH_VAR_PREFIX))) \
    $(if $(filter $(_idfPrefix)-$(_idfClass),$(COMMON_MODULE_CLASSES))$(4), \
        $(eval _idfIntBase := $($(_idfPrefix)_OUT_COMMON_INTERMEDIATES)) \
      ,$(if $(filter $(_idfClass),$(PER_ARCH_MODULE_CLASSES)),\
          $(eval _idfIntBase := $($(_idf2ndArchPrefix)$(_idfPrefix)_OUT_INTERMEDIATES)) \
       ,$(eval _idfIntBase := $($(_idfPrefix)_OUT_INTERMEDIATES)) \
       ) \
     ) \
    $(_idfIntBase)/$(_idfClass)/$(_idfName)_intermediates \
)
endef

# Uses LOCAL_MODULE_CLASS, LOCAL_MODULE, and LOCAL_IS_HOST_MODULE
# to determine the intermediates directory.
#
# $(1): if non-empty, force the intermediates to be COMMON
# $(2): if non-empty, force the intermediates to be for the 2nd arch
# $(3): if non-empty, force the intermediates to be for the host cross os
define local-intermediates-dir
$(strip \
    $(if $(strip $(LOCAL_MODULE_CLASS)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined before call to local-intermediates-dir)) \
    $(if $(strip $(LOCAL_MODULE)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE not defined before call to local-intermediates-dir)) \
    $(call intermediates-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(LOCAL_IS_HOST_MODULE),$(1),$(2),$(3)) \
)
endef

###########################################################
## The generated sources directory.  Placing generated
## source files directly in the intermediates directory
## causes problems for multiarch builds, where there are
## two intermediates directories for a single target. Put
## them in a separate directory, and they will be copied to
## each intermediates directory automatically.
###########################################################

# $(1): target class, like "APPS"
# $(2): target name, like "NotePad"
# $(3): if non-empty, this is a HOST target.
# $(4): if non-empty, force the generated sources to be COMMON
define generated-sources-dir-for
$(strip \
    $(eval _idfClass := $(strip $(1))) \
    $(if $(_idfClass),, \
        $(error $(LOCAL_PATH): Class not defined in call to generated-sources-dir-for)) \
    $(eval _idfName := $(strip $(2))) \
    $(if $(_idfName),, \
        $(error $(LOCAL_PATH): Name not defined in call to generated-sources-dir-for)) \
    $(eval _idfPrefix := $(if $(strip $(3)),HOST,TARGET)) \
    $(if $(filter $(_idfPrefix)-$(_idfClass),$(COMMON_MODULE_CLASSES))$(4), \
        $(eval _idfIntBase := $($(_idfPrefix)_OUT_COMMON_GEN)) \
      , \
        $(eval _idfIntBase := $($(_idfPrefix)_OUT_GEN)) \
     ) \
    $(_idfIntBase)/$(_idfClass)/$(_idfName)_intermediates \
)
endef

# Uses LOCAL_MODULE_CLASS, LOCAL_MODULE, and LOCAL_IS_HOST_MODULE
# to determine the generated sources directory.
#
# $(1): if non-empty, force the intermediates to be COMMON
define local-generated-sources-dir
$(strip \
    $(if $(strip $(LOCAL_MODULE_CLASS)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined before call to local-generated-sources-dir)) \
    $(if $(strip $(LOCAL_MODULE)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE not defined before call to local-generated-sources-dir)) \
    $(call generated-sources-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(LOCAL_IS_HOST_MODULE),$(1)) \
)
endef

###########################################################
## Convert "path/to/libXXX.so" to "-lXXX".
## Any "path/to/libXXX.a" elements pass through unchanged.
###########################################################

define normalize-libraries
$(foreach so,$(filter %.so,$(1)),-l$(patsubst lib%.so,%,$(notdir $(so))))\
$(filter-out %.so,$(1))
endef

# TODO: change users to call the common version.
define normalize-host-libraries
$(call normalize-libraries,$(1))
endef

define normalize-target-libraries
$(call normalize-libraries,$(1))
endef

###########################################################
## Convert a list of short module names (e.g., "framework", "Browser")
## into the list of files that are built for those modules.
## NOTE: this won't return reliable results until after all
## sub-makefiles have been included.
## $(1): target list
###########################################################

define module-built-files
$(foreach module,$(1),$(ALL_MODULES.$(module).BUILT))
endef

###########################################################
## Convert a list of short modules names (e.g., "framework", "Browser")
## into the list of files that are installed for those modules.
## NOTE: this won't return reliable results until after all
## sub-makefiles have been included.
## $(1): target list
###########################################################

define module-installed-files
$(foreach module,$(1),$(ALL_MODULES.$(module).INSTALLED))
endef

###########################################################
## Convert a list of short modules names (e.g., "framework", "Browser")
## into the list of files that should be used when linking
## against that module as a public API.
## TODO: Allow this for more than JAVA_LIBRARIES modules
## NOTE: this won't return reliable results until after all
## sub-makefiles have been included.
## $(1): target list
###########################################################

define module-stubs-files
$(foreach module,$(1),$(ALL_MODULES.$(module).STUBS))
endef

###########################################################
## Evaluates to the timestamp file for a doc module, which
## is the dependency that should be used.
## $(1): doc module
###########################################################

define doc-timestamp-for
$(OUT_DOCS)/$(strip $(1))-timestamp
endef


###########################################################
## Convert "core ext framework" to "out/.../javalib.jar ..."
## $(1): library list
## $(2): Non-empty if IS_HOST_MODULE
###########################################################

# $(1): library name
# $(2): Non-empty if IS_HOST_MODULE
define _java-lib-dir
$(call intermediates-dir-for, \
	JAVA_LIBRARIES,$(1),$(2),COMMON)
endef

# $(1): library name
# $(2): Non-empty if IS_HOST_MODULE
define _java-lib-full-classes.jar
$(call _java-lib-dir,$(1),$(2))/$(if $(2),javalib,classes)$(COMMON_JAVA_PACKAGE_SUFFIX)
endef

# Get the jar files (you can pass to "javac -classpath") of static or shared
# Java libraries that you want to link against.
# $(1): library name list
# $(2): Non-empty if IS_HOST_MODULE
define java-lib-files
$(foreach lib,$(1),$(call _java-lib-full-classes.jar,$(lib),$(2)))
endef

# Get the dependency files (you can put on the right side of "|" of a build rule)
# of the Java libraries.
# $(1): library name list
# $(2): Non-empty if IS_HOST_MODULE
# Historically for target Java libraries we used a different file (javalib.jar)
# as the dependency.
# Now we can use classes.jar as dependency, so java-lib-deps is the same
# as java-lib-files.
define java-lib-deps
$(call java-lib-files,$(1),$(2))
endef

# Get the jar files (you can pass to "javac -classpath") of host dalvik Java libraries.
# You can also use them as dependency files.
# A host dalvik Java library is different from a host Java library in that
# the java lib file is classes.jar, not javalib.jar.
# $(1): library name list
define host-dex-java-lib-files
$(foreach lib,$(1),$(call _java-lib-dir,$(lib),true)/classes.jar)
endef

###########################################################
## Convert "core ext framework" to "out/.../classes.jack ..."
## $(1): library list
## $(2): Non-empty if IS_HOST_MODULE
###########################################################

# $(1): library name
# $(2): Non-empty if IS_HOST_MODULE
define _jack-lib-full-classes
$(call _java-lib-dir,$(1),$(2))/classes.jack
endef

# $(1): library name list
# $(2): Non-empty if IS_HOST_MODULE
define jack-lib-files
$(foreach lib,$(1),$(call _jack-lib-full-classes,$(lib),$(2)))
endef

# $(1): library name list
# $(2): Non-empty if IS_HOST_MODULE
define jack-lib-deps
$(call jack-lib-files,$(1),$(2))
endef

###########################################################
## Run rot13 on a string
## $(1): the string.  Must be one line.
###########################################################
define rot13
$(shell echo $(1) | tr 'a-zA-Z' 'n-za-mN-ZA-M')
endef


###########################################################
## Returns true if $(1) and $(2) are equal.  Returns
## the empty string if they are not equal.
###########################################################
define streq
$(strip $(if $(strip $(1)),\
  $(if $(strip $(2)),\
    $(if $(filter-out __,_$(subst $(strip $(1)),,$(strip $(2)))$(subst $(strip $(2)),,$(strip $(1)))_),,true), \
    ),\
  $(if $(strip $(2)),\
    ,\
    true)\
 ))
endef

###########################################################
## Convert "a b c" into "a:b:c"
###########################################################
define normalize-path-list
$(subst $(space),:,$(strip $(1)))
endef

###########################################################
## Read the word out of a colon-separated list of words.
## This has the same behavior as the built-in function
## $(word n,str).
##
## The individual words may not contain spaces.
##
## $(1): 1 based index
## $(2): value of the form a:b:c...
###########################################################

define word-colon
$(word $(1),$(subst :,$(space),$(2)))
endef

###########################################################
## Convert "a=b c= d e = f" into "a=b c=d e=f"
##
## $(1): list to collapse
## $(2): if set, separator word; usually "=", ":", or ":="
##       Defaults to "=" if not set.
###########################################################

define collapse-pairs
$(eval _cpSEP := $(strip $(if $(2),$(2),=)))\
$(subst $(space)$(_cpSEP)$(space),$(_cpSEP),$(strip \
    $(subst $(_cpSEP), $(_cpSEP) ,$(1))))
endef

###########################################################
## Given a list of pairs, if multiple pairs have the same
## first components, keep only the first pair.
##
## $(1): list of pairs
## $(2): the separator word, such as ":", "=", etc.
define uniq-pairs-by-first-component
$(eval _upbfc_fc_set :=)\
$(strip $(foreach w,$(1), $(eval _first := $(word 1,$(subst $(2),$(space),$(w))))\
    $(if $(filter $(_upbfc_fc_set),$(_first)),,$(w)\
        $(eval _upbfc_fc_set += $(_first)))))\
$(eval _upbfc_fc_set :=)\
$(eval _first:=)
endef

###########################################################
## MODULE_TAG set operations
###########################################################

# Given a list of tags, return the targets that specify
# any of those tags.
# $(1): tag list
define modules-for-tag-list
$(sort $(foreach tag,$(1),$(foreach m,$(ALL_MODULE_NAME_TAGS.$(tag)),$(ALL_MODULES.$(m).INSTALLED))))
endef

# Same as modules-for-tag-list, but operates on
# ALL_MODULE_NAME_TAGS.
# $(1): tag list
define module-names-for-tag-list
$(sort $(foreach tag,$(1),$(ALL_MODULE_NAME_TAGS.$(tag))))
endef

# Given an accept and reject list, find the matching
# set of targets.  If a target has multiple tags and
# any of them are rejected, the target is rejected.
# Reject overrides accept.
# $(1): list of tags to accept
# $(2): list of tags to reject
#TODO(dbort): do $(if $(strip $(1)),$(1),$(ALL_MODULE_TAGS))
#TODO(jbq): as of 20100106 nobody uses the second parameter
define get-tagged-modules
$(filter-out \
	$(call modules-for-tag-list,$(2)), \
	    $(call modules-for-tag-list,$(1)))
endef

###########################################################
## Append a leaf to a base path.  Properly deals with
## base paths ending in /.
##
## $(1): base path
## $(2): leaf path
###########################################################

define append-path
$(subst //,/,$(1)/$(2))
endef


###########################################################
## Package filtering
###########################################################

# Given a list of installed modules (short or long names)
# return a list of the packages (yes, .apk packages, not
# modules in general) that are overridden by this list and,
# therefore, should not be installed.
# $(1): mixed list of installed modules
# TODO: This is fragile; find a reliable way to get this information.
define _get-package-overrides
 $(eval ### Discard any words containing slashes, unless they end in .apk, \
        ### in which case trim off the directory component and the suffix. \
        ### If there are no slashes, keep the entire word.)
 $(eval _gpo_names := $(subst /,@@@ @@@,$(1)))
 $(eval _gpo_names := \
     $(filter %.apk,$(_gpo_names)) \
     $(filter-out %@@@ @@@%,$(_gpo_names)))
 $(eval _gpo_names := $(patsubst %.apk,%,$(_gpo_names)))
 $(eval _gpo_names := $(patsubst @@@%,%,$(_gpo_names)))

 $(eval ### Remove any remaining words that contain dots.)
 $(eval _gpo_names := $(subst .,@@@ @@@,$(_gpo_names)))
 $(eval _gpo_names := $(filter-out %@@@ @@@%,$(_gpo_names)))

 $(eval ### Now we have a list of any words that could possibly refer to \
        ### packages, although there may be words that do not.  Only \
        ### real packages will be present under PACKAGES.*, though.)
 $(foreach _gpo_name,$(_gpo_names),$(PACKAGES.$(_gpo_name).OVERRIDES))
endef

define get-package-overrides
$(sort $(strip $(call _get-package-overrides,$(1))))
endef

###########################################################
## Output the command lines, or not
###########################################################

ifeq ($(strip $(SHOW_COMMANDS)),)
define pretty
@echo $1
endef
else
define pretty
endef
endif

###########################################################
## Commands for munging the dependency files the compiler generates
###########################################################
# $(1): the input .d file
# $(2): the output .P file
define transform-d-to-p-args
$(hide) cp $(1) $(2); \
	sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
		-e '/^$$/ d' -e 's/$$/ :/' < $(1) >> $(2); \
	rm -f $(1)
endef

define transform-d-to-p
$(call transform-d-to-p-args,$(@:%.o=%.d),$(@:%.o=%.P))
endef

###########################################################
## Commands for including the dependency files the compiler generates
###########################################################
# $(1): the .P file
# $(2): the main build target
ifeq ($(BUILDING_WITH_NINJA),true)
define include-depfile
$(eval $(2) : .KATI_DEPFILE := $1)
endef
else
define include-depfile
$(eval -include $1)
endef
endif

# $(1): object files
define include-depfiles-for-objs
$(foreach obj, $(1), $(call include-depfile, $(obj:%.o=%.P), $(obj)))
endef

###########################################################
## Track source files compiled to objects
###########################################################
# $(1): list of sources
# $(2): list of matching objects
define track-src-file-obj
$(eval $(call _track-src-file-obj,$(1)))
endef
define _track-src-file-obj
i := w
$(foreach s,$(1),
my_tracked_src_files += $(s)
my_src_file_obj_$(s) := $$(word $$(words $$(i)),$$(2))
i += w)
endef

# $(1): list of sources
# $(2): list of matching generated sources
define track-src-file-gen
$(eval $(call _track-src-file-gen,$(2)))
endef
define _track-src-file-gen
i := w
$(foreach s,$(1),
my_tracked_gen_files += $(s)
my_src_file_gen_$(s) := $$(word $$(words $$(i)),$$(1))
i += w)
endef

# $(1): list of generated sources
# $(2): list of matching objects
define track-gen-file-obj
$(call track-src-file-obj,$(foreach f,$(1),\
  $(or $(my_src_file_gen_$(f)),$(f))),$(2))
endef

###########################################################
## Commands for running lex
###########################################################

define transform-l-to-c-or-cpp
@echo "Lex: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(hide) $(LEX) -o$@ $<
endef

###########################################################
## Commands for running yacc
##
###########################################################

define transform-y-to-c-or-cpp
@echo "Yacc: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(YACC) $(PRIVATE_YACCFLAGS) \
  --defines=$(basename $@).h \
  -o $@ $<
endef

###########################################################
## Commands to compile RenderScript to Java
###########################################################

## Merge multiple .d files generated by llvm-rs-cc. This is necessary
## because ninja can handle only a single depfile per build target.
## .d files generated by llvm-rs-cc define .stamp, .bc, and optionally
## .java as build targets. However, there's no way to let ninja know
## dependencies to .bc files and .java files, so we give up build
## targets for them. As we write the .stamp file as the target by
## ourselves, the awk script removes the first lines before the colon
## and append a backslash to the last line to concatenate contents of
## multiple files.
# $(1): .d files to be merged
# $(2): merged .d file
define _merge-renderscript-d
$(hide) echo '$@: $(backslash)' > $2
$(foreach d,$1, \
  $(hide) awk 'start { sub(/( \\)?$$/, " \\"); print } /:/ { start=1 }' < $d >> $2$(newline))
$(hide) echo >> $2
endef

define transform-renderscripts-to-java-and-bc
@echo "RenderScript: $(PRIVATE_MODULE) <= $(PRIVATE_RS_SOURCE_FILES)"
$(hide) rm -rf $(PRIVATE_RS_OUTPUT_DIR)
$(hide) mkdir -p $(PRIVATE_RS_OUTPUT_DIR)/res/raw
$(hide) mkdir -p $(PRIVATE_RS_OUTPUT_DIR)/src
$(hide) $(PRIVATE_RS_CC) \
  -o $(PRIVATE_RS_OUTPUT_DIR)/res/raw \
  -p $(PRIVATE_RS_OUTPUT_DIR)/src \
  -d $(PRIVATE_RS_OUTPUT_DIR) \
  -a $@ -MD \
  $(addprefix -target-api , $(PRIVATE_RS_TARGET_API)) \
  $(PRIVATE_RS_FLAGS) \
  $(foreach inc,$(PRIVATE_RS_INCLUDES),$(addprefix -I , $(inc))) \
  $(PRIVATE_RS_SOURCE_FILES)
$(call _merge-renderscript-d,$(PRIVATE_DEP_FILES),$@.d)
$(call transform-d-to-p-args,$@.d,$@.P)
$(hide) mkdir -p $(dir $@)
$(hide) touch $@
endef

define transform-bc-to-so
@echo "Renderscript compatibility: $(notdir $@) <= $(notdir $<)"
$(hide) mkdir -p $(dir $@)
$(hide) $(BCC_COMPAT) -O3 -o $(dir $@)/$(notdir $(<:.bc=.o)) -fPIC -shared \
	-rt-path $(RS_PREBUILT_CLCORE) -mtriple $(RS_COMPAT_TRIPLE) $<
$(hide) $(PRIVATE_CXX) -shared -Wl,-soname,$(notdir $@) -nostdlib \
	-Wl,-rpath,\$$ORIGIN/../lib \
	$(dir $@)/$(notdir $(<:.bc=.o)) \
	$(RS_PREBUILT_COMPILER_RT) \
	-o $@ $(TARGET_GLOBAL_LDFLAGS) -Wl,--hash-style=sysv -L prebuilts/gcc/ \
	$(RS_PREBUILT_LIBPATH) -L $(TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	-lRSSupport -lm -lc
endef

###########################################################
## Commands to compile RenderScript to C++
###########################################################

define transform-renderscripts-to-cpp-and-bc
@echo "RenderScript: $(PRIVATE_MODULE) <= $(PRIVATE_RS_SOURCE_FILES)"
$(hide) rm -rf $(PRIVATE_RS_OUTPUT_DIR)
$(hide) mkdir -p $(PRIVATE_RS_OUTPUT_DIR)/
$(hide) $(PRIVATE_RS_CC) \
  -o $(PRIVATE_RS_OUTPUT_DIR)/ \
  -d $(PRIVATE_RS_OUTPUT_DIR) \
  -a $@ -MD \
  -reflect-c++ \
  $(addprefix -target-api , $(PRIVATE_RS_TARGET_API)) \
  $(PRIVATE_RS_FLAGS) \
  $(addprefix -I , $(PRIVATE_RS_INCLUDES)) \
  $(PRIVATE_RS_SOURCE_FILES)
$(call _merge-renderscript-d,$(PRIVATE_DEP_FILES),$@.d)
$(call transform-d-to-p-args,$@.d,$@.P)
$(hide) mkdir -p $(dir $@)
$(hide) touch $@
endef


###########################################################
## Commands for running aidl
###########################################################

define transform-aidl-to-java
@mkdir -p $(dir $@)
@echo "Aidl: $(PRIVATE_MODULE) <= $<"
$(hide) $(AIDL) -d$(patsubst %.java,%.P,$@) $(PRIVATE_AIDL_FLAGS) $< $@
endef
#$(AIDL) $(PRIVATE_AIDL_FLAGS) $< - | indent -nut -br -npcs -l1000 > $@

define transform-aidl-to-cpp
@mkdir -p $(dir $@)
@mkdir -p $(PRIVATE_HEADER_OUTPUT_DIR)
@echo "Generating C++ from AIDL: $(PRIVATE_MODULE) <= $<"
$(hide) $(AIDL_CPP) -d$(basename $@).aidl.P $(PRIVATE_AIDL_FLAGS) \
    $< $(PRIVATE_HEADER_OUTPUT_DIR) $@
endef

## Given a .aidl file path generate the rule to compile it a .cpp file.
# $(1): a .aidl source file
# $(2): a directory to place the generated .cpp files in
# $(3): name of a variable to add the path to the generated source file to
#
# You must call this with $(eval).
define define-aidl-cpp-rule
define-aidl-cpp-rule-src := $(patsubst %.aidl,%$(LOCAL_CPP_EXTENSION),$(subst ../,dotdot/,$(addprefix $(2)/,$(1))))
$$(define-aidl-cpp-rule-src) : $(LOCAL_PATH)/$(1) $(AIDL_CPP)
	$$(transform-aidl-to-cpp)
$(3) += $$(define-aidl-cpp-rule-src)
endef

###########################################################
## Commands for running vts
###########################################################

define transform-vts-to-cpp
@mkdir -p $(dir $@)
@mkdir -p $(PRIVATE_HEADER_OUTPUT_DIR)
@echo "Generating C++ from VTS: $(PRIVATE_MODULE) <= $<"
$(hide) $(VTSC) -d$(basename $@).vts.P $(PRIVATE_VTS_FLAGS) \
    $< $(PRIVATE_HEADER_OUTPUT_DIR) $@
endef

## Given a .vts file path generate the rule to compile it a .cpp file.
# $(1): a .vts source file
# $(2): a directory to place the generated .cpp files in
# $(3): name of a variable to add the path to the generated source file to
#
# You must call this with $(eval).
define define-vts-cpp-rule
define-vts-cpp-rule-src := $(patsubst %.vts,%$(LOCAL_CPP_EXTENSION),$(subst ../,dotdot/,$(addprefix $(2)/,$(1))))
$$(define-vts-cpp-rule-src) : $(LOCAL_PATH)/$(1) $(VTSC)
	$$(transform-vts-to-cpp)
$(3) += $$(define-vts-cpp-rule-src)
endef

###########################################################
## Commands for running java-event-log-tags.py
###########################################################

define transform-logtags-to-java
@mkdir -p $(dir $@)
@echo "logtags: $@ <= $<"
$(hide) $(JAVATAGS) -o $@ $^
endef


###########################################################
## Commands for running protoc to compile .proto into .java
###########################################################

define transform-proto-to-java
@mkdir -p $(dir $@)
@echo "Protoc: $@ <= $(PRIVATE_PROTO_SRC_FILES)"
@rm -rf $(PRIVATE_PROTO_JAVA_OUTPUT_DIR)
@mkdir -p $(PRIVATE_PROTO_JAVA_OUTPUT_DIR)
$(hide) for f in $(PRIVATE_PROTO_SRC_FILES); do \
        $(PROTOC) \
        $(addprefix --proto_path=, $(PRIVATE_PROTO_INCLUDES)) \
        $(PRIVATE_PROTO_JAVA_OUTPUT_OPTION)="$(PRIVATE_PROTO_JAVA_OUTPUT_PARAMS):$(PRIVATE_PROTO_JAVA_OUTPUT_DIR)" \
        $(PRIVATE_PROTOC_FLAGS) \
        $$f || exit 33; \
        done
$(hide) touch $@
endef

######################################################################
## Commands for running protoc to compile .proto into .pb.cc (or.pb.c) and .pb.h
######################################################################
define transform-proto-to-cc
@echo "Protoc: $@ <= $<"
@mkdir -p $(dir $@)
$(hide) $(PROTOC) \
	$(addprefix --proto_path=, $(PRIVATE_PROTO_INCLUDES)) \
	$(PRIVATE_PROTOC_FLAGS) \
	$<
@# aprotoc outputs only .cc. Rename it to .cpp if necessary.
$(if $(PRIVATE_RENAME_CPP_EXT),\
  $(hide) mv $(basename $@).cc $@)
endef


######################################################################
## Commands for generating DBus adaptors from .dbus-xml files.
######################################################################
define generate-dbus-adaptors
@echo "Generating DBus adaptors for $(PRIVATE_MODULE)"
@mkdir -p $(dir $@)
$(hide) $(DBUS_GENERATOR) \
	--service-config=$(PRIVATE_DBUS_SERVICE_CONFIG) \
	--adaptor=$@ \
	$<
endef

######################################################################
## Commands for generating DBus proxies from .dbus-xml files.
######################################################################
define generate-dbus-proxies
@echo "Generating DBus proxies for $(PRIVATE_MODULE)"
@mkdir -p $(dir $@)
$(hide) $(DBUS_GENERATOR) \
	--service-config=$(PRIVATE_DBUS_SERVICE_CONFIG) \
	--proxy=$@ \
	$(filter %.dbus-xml,$^)
endef


###########################################################
## Commands for running gcc to compile a C++ file
###########################################################

define transform-cpp-to-o
@echo "target $(PRIVATE_ARM_MODE) C++: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(hide) $(RELATIVE_PWD) $(PRIVATE_CXX) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $(PRIVATE_TARGET_PROJECT_INCLUDES) \
	            $(PRIVATE_TARGET_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_TARGET_GLOBAL_CFLAGS) \
	    $(PRIVATE_TARGET_GLOBAL_CPPFLAGS) \
	    $(PRIVATE_ARM_CFLAGS) \
	 ) \
	$(PRIVATE_RTTI_FLAG) \
	$(PRIVATE_CFLAGS) \
	$(PRIVATE_CPPFLAGS) \
	$(PRIVATE_DEBUG_CFLAGS) \
	$(PRIVATE_CFLAGS_NO_OVERRIDE) \
	$(PRIVATE_CPPFLAGS_NO_OVERRIDE) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
$(transform-d-to-p)
endef


###########################################################
## Commands for running gcc to compile a C file
###########################################################

# $(1): extra flags
define transform-c-or-s-to-o-no-deps
@mkdir -p $(dir $@)
$(hide) $(RELATIVE_PWD) $(PRIVATE_CC) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $(PRIVATE_TARGET_PROJECT_INCLUDES) \
	            $(PRIVATE_TARGET_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_TARGET_GLOBAL_CFLAGS) \
	    $(PRIVATE_TARGET_GLOBAL_CONLYFLAGS) \
	    $(PRIVATE_ARM_CFLAGS) \
	 ) \
	 $(1) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef

define transform-c-to-o-no-deps
@echo "target $(PRIVATE_ARM_MODE) C: $(PRIVATE_MODULE) <= $<"
$(call transform-c-or-s-to-o-no-deps, \
    $(PRIVATE_CFLAGS) \
    $(PRIVATE_CONLYFLAGS) \
    $(PRIVATE_DEBUG_CFLAGS) \
    $(PRIVATE_CFLAGS_NO_OVERRIDE))
endef

define transform-s-to-o-no-deps
@echo "target asm: $(PRIVATE_MODULE) <= $<"
$(call transform-c-or-s-to-o-no-deps, $(PRIVATE_ASFLAGS))
endef

define transform-c-to-o
$(transform-c-to-o-no-deps)
$(transform-d-to-p)
endef

define transform-s-to-o
$(transform-s-to-o-no-deps)
$(transform-d-to-p)
endef

# YASM compilation
define transform-asm-to-o
@mkdir -p $(dir $@)
$(hide) $(YASM) \
    $(addprefix -I , $(PRIVATE_C_INCLUDES)) \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_YASM_FLAGS) \
    $(PRIVATE_ASFLAGS) \
    -o $@ $<
endef

###########################################################
## Commands for running gcc to compile an Objective-C file
## This should never happen for target builds but this
## will error at build time.
###########################################################

define transform-m-to-o-no-deps
@echo "target ObjC: $(PRIVATE_MODULE) <= $<"
$(call transform-c-or-s-to-o-no-deps, $(PRIVATE_CFLAGS) $(PRIVATE_DEBUG_CFLAGS))
endef

define transform-m-to-o
$(transform-m-to-o-no-deps)
$(transform-d-to-p)
endef

###########################################################
## Commands for running gcc to compile a host C++ file
###########################################################

define transform-host-cpp-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) C++: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(hide) $(RELATIVE_PWD) $(PRIVATE_CXX) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $($(PRIVATE_PREFIX)PROJECT_INCLUDES) \
	            $(PRIVATE_HOST_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_HOST_GLOBAL_CFLAGS) \
	    $(PRIVATE_HOST_GLOBAL_CPPFLAGS) \
	 ) \
	$(PRIVATE_CFLAGS) \
	$(PRIVATE_CPPFLAGS) \
	$(PRIVATE_DEBUG_CFLAGS) \
	$(PRIVATE_CFLAGS_NO_OVERRIDE) \
	$(PRIVATE_CPPFLAGS_NO_OVERRIDE) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
$(transform-d-to-p)
endef


###########################################################
## Commands for running gcc to compile a host C file
###########################################################

# $(1): extra flags
define transform-host-c-or-s-to-o-no-deps
@mkdir -p $(dir $@)
$(hide) $(RELATIVE_PWD) $(PRIVATE_CC) \
	$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
	$(shell cat $(PRIVATE_IMPORT_INCLUDES)) \
	$(addprefix -isystem ,\
	    $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	        $(filter-out $(PRIVATE_C_INCLUDES), \
	            $($(PRIVATE_PREFIX)PROJECT_INCLUDES) \
	            $(PRIVATE_HOST_C_INCLUDES)))) \
	-c \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	    $(PRIVATE_HOST_GLOBAL_CFLAGS) \
	    $(PRIVATE_HOST_GLOBAL_CONLYFLAGS) \
	 ) \
	$(1) \
	$(PRIVATE_CFLAGS_NO_OVERRIDE) \
	-MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef

define transform-host-c-to-o-no-deps
@echo "$($(PRIVATE_PREFIX)DISPLAY) C: $(PRIVATE_MODULE) <= $<"
$(call transform-host-c-or-s-to-o-no-deps, $(PRIVATE_CFLAGS) $(PRIVATE_CONLYFLAGS) $(PRIVATE_DEBUG_CFLAGS))
endef

define transform-host-s-to-o-no-deps
@echo "$($(PRIVATE_PREFIX)DISPLAY) asm: $(PRIVATE_MODULE) <= $<"
$(call transform-host-c-or-s-to-o-no-deps, $(PRIVATE_ASFLAGS))
endef

define transform-host-c-to-o
$(transform-host-c-to-o-no-deps)
$(transform-d-to-p)
endef

define transform-host-s-to-o
$(transform-host-s-to-o-no-deps)
$(transform-d-to-p)
endef

###########################################################
## Commands for running gcc to compile a host Objective-C file
###########################################################

define transform-host-m-to-o-no-deps
@echo "$($(PRIVATE_PREFIX)DISPLAY) ObjC: $(PRIVATE_MODULE) <= $<"
$(call transform-host-c-or-s-to-o-no-deps, $(PRIVATE_CFLAGS) $(PRIVATE_DEBUG_CFLAGS))
endef

define transform-host-m-to-o
$(transform-host-m-to-o-no-deps)
$(transform-d-to-p)
endef

###########################################################
## Commands for running gcc to compile a host Objective-C++ file
###########################################################

define transform-host-mm-to-o
$(transform-host-cpp-to-o)
endef


###########################################################
## Rules to compile a single C/C++ source with ../ in the path
###########################################################
# Replace "../" in object paths with $(DOTDOT_REPLACEMENT).
DOTDOT_REPLACEMENT := dotdot/

## Rule to compile a C++ source file with ../ in the path.
## Must be called with $(eval).
# $(1): the C++ source file in LOCAL_SRC_FILES.
# $(2): the additional dependencies.
# $(3): the variable name to collect the output object file.
define compile-dotdot-cpp-file
o := $(intermediates)/$(patsubst %$(LOCAL_CPP_EXTENSION),%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2)
	$$(transform-$$(PRIVATE_HOST)cpp-to-o)
$$(call include-depfiles-for-objs, $$(o))
$(3) += $$(o)
endef

## Rule to compile a C source file with ../ in the path.
## Must be called with $(eval).
# $(1): the C source file in LOCAL_SRC_FILES.
# $(2): the additional dependencies.
# $(3): the variable name to collect the output object file.
define compile-dotdot-c-file
o := $(intermediates)/$(patsubst %.c,%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2)
	$$(transform-$$(PRIVATE_HOST)c-to-o)
$$(call include-depfiles-for-objs, $$(o))
$(3) += $$(o)
endef

## Rule to compile a .S source file with ../ in the path.
## Must be called with $(eval).
# $(1): the .S source file in LOCAL_SRC_FILES.
# $(2): the additional dependencies.
# $(3): the variable name to collect the output object file.
define compile-dotdot-s-file
o := $(intermediates)/$(patsubst %.S,%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2)
	$$(transform-$$(PRIVATE_HOST)s-to-o)
$$(call include-depfiles-for-objs, $$(o))
$(3) += $$(o)
endef

## Rule to compile a .s source file with ../ in the path.
## Must be called with $(eval).
# $(1): the .s source file in LOCAL_SRC_FILES.
# $(2): the additional dependencies.
# $(3): the variable name to collect the output object file.
define compile-dotdot-s-file-no-deps
o := $(intermediates)/$(patsubst %.s,%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2)
	$$(transform-$$(PRIVATE_HOST)s-to-o-no-deps)
$(3) += $$(o)
endef

###########################################################
## Commands for running ar
###########################################################

define _concat-if-arg2-not-empty
$(if $(2),$(hide) $(1) $(2))
endef

# Split long argument list into smaller groups and call the command repeatedly
# Call the command at least once even if there are no arguments, as otherwise
# the output file won't be created.
#
# $(1): the command without arguments
# $(2): the arguments
define split-long-arguments
$(hide) $(1) $(wordlist 1,500,$(2))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 501,1000,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 1001,1500,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 1501,2000,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 2001,2500,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 2501,3000,$(2)))
$(call _concat-if-arg2-not-empty,$(1),$(wordlist 3001,99999,$(2)))
endef

# $(1): the full path of the source static library.
define _extract-and-include-single-target-whole-static-lib
$(hide) ldir=$(PRIVATE_INTERMEDIATES_DIR)/WHOLE/$(basename $(notdir $(1)))_objs;\
    rm -rf $$ldir; \
    mkdir -p $$ldir; \
    cp $(1) $$ldir; \
    lib_to_include=$$ldir/$(notdir $(1)); \
    filelist=; \
    subdir=0; \
    for f in `$($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) t $(1)`; do \
        if [ -e $$ldir/$$f ]; then \
            mkdir $$ldir/$$subdir; \
            ext=$$subdir/; \
            subdir=$$((subdir+1)); \
            $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) m $$lib_to_include $$f; \
        else \
            ext=; \
        fi; \
        $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) p $$lib_to_include $$f > $$ldir/$$ext$$f; \
        filelist="$$filelist $$ldir/$$ext$$f"; \
    done ; \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_ARFLAGS) \
        $(PRIVATE_ARFLAGS) $@ $$filelist

endef

# $(1): the full path of the source static library.
define extract-and-include-whole-static-libs-first
$(if $(strip $(1)),
$(hide) cp $(1) $@)
endef

define extract-and-include-target-whole-static-libs
$(call extract-and-include-whole-static-libs-first, $(firstword $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)))
$(foreach lib,$(wordlist 2,999,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)), \
    $(call _extract-and-include-single-target-whole-static-lib, $(lib)))
endef

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define transform-o-to-static-lib
@echo "target StaticLib: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
@rm -f $@
$(extract-and-include-target-whole-static-libs)
$(call split-long-arguments,$($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_ARFLAGS) \
    $(PRIVATE_ARFLAGS) $@,$(PRIVATE_ALL_OBJECTS))
endef

###########################################################
## Commands for running host ar
###########################################################

# $(1): the full path of the source static library.
define _extract-and-include-single-host-whole-static-lib
$(hide) ldir=$(PRIVATE_INTERMEDIATES_DIR)/WHOLE/$(basename $(notdir $(1)))_objs;\
    rm -rf $$ldir; \
    mkdir -p $$ldir; \
    cp $(1) $$ldir; \
    lib_to_include=$$ldir/$(notdir $(1)); \
    filelist=; \
    subdir=0; \
    for f in `$($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)AR) t $(1) | \grep '\.o$$'`; do \
        if [ -e $$ldir/$$f ]; then \
           mkdir $$ldir/$$subdir; \
           ext=$$subdir/; \
           subdir=$$((subdir+1)); \
           $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)AR) m $$lib_to_include $$f; \
        else \
           ext=; \
        fi; \
        $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)AR) p $$lib_to_include $$f > $$ldir/$$ext$$f; \
        filelist="$$filelist $$ldir/$$ext$$f"; \
    done ; \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)AR) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)GLOBAL_ARFLAGS) \
        $(PRIVATE_ARFLAGS) $@ $$filelist

endef

define extract-and-include-host-whole-static-libs
$(call extract-and-include-whole-static-libs-first, $(firstword $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)))
$(foreach lib,$(wordlist 2,999,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)), \
    $(call _extract-and-include-single-host-whole-static-lib, $(lib)))
endef

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define transform-host-o-to-static-lib
@echo "$($(PRIVATE_PREFIX)DISPLAY) StaticLib: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
@rm -f $@
$(extract-and-include-host-whole-static-libs)
$(call split-long-arguments,$($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)AR) \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)GLOBAL_ARFLAGS) \
    $(PRIVATE_ARFLAGS) $@,$(PRIVATE_ALL_OBJECTS))
endef


###########################################################
## Commands for running gcc to link a shared library or package
###########################################################

# ld just seems to be so finicky with command order that we allow
# it to be overriden en-masse see combo/linux-arm.make for an example.
ifneq ($(HOST_CUSTOM_LD_COMMAND),true)
define transform-host-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
	-Wl,-rpath-link=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_INTERMEDIATE_LIBRARIES) \
	-Wl,-rpath,\$$ORIGIN/../$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_SHARED_LIBRARIES)) \
	-Wl,-rpath,\$$ORIGIN/$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_SHARED_LIBRARIES)) \
	-shared -Wl,-soname,$(notdir $@) \
	$($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)GLOBAL_LD_DIRS) \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
	   $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
	) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(if $(filter true,$(NATIVE_COVERAGE)),-lgcov) \
	$(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_HOST_LIBPROFILE_RT)) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_LDLIBS)
endef
endif

define transform-host-o-to-shared-lib
@echo "$($(PRIVATE_PREFIX)DISPLAY) SharedLib: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-host-o-to-shared-lib-inner)
endef

define transform-host-o-to-package
@echo "$($(PRIVATE_PREFIX)DISPLAY) Package: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-host-o-to-shared-lib-inner)
endef


###########################################################
## Commands for running gcc to link a shared library or package
###########################################################

define transform-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX) \
	-nostdlib -Wl,-soname,$(notdir $@) \
	-Wl,--gc-sections \
	$(if $(filter true,$(PRIVATE_CLANG)),-shared,-Wl$(comma)-shared) \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(PRIVATE_TARGET_CRTBEGIN_SO_O) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_TARGET_COVERAGE_LIB)) \
	$(PRIVATE_TARGET_LIBATOMIC) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_CRTEND_SO_O) \
	$(PRIVATE_LDLIBS)
endef

define transform-o-to-shared-lib
@echo "target SharedLib: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-o-to-shared-lib-inner)
endef

###########################################################
## Commands for filtering a target executable or library
###########################################################

ifneq ($(TARGET_BUILD_VARIANT),user)
  TARGET_STRIP_EXTRA = && $(PRIVATE_OBJCOPY) --add-gnu-debuglink=$< $@
  TARGET_STRIP_KEEP_SYMBOLS_EXTRA = --add-gnu-debuglink=$<
endif

define transform-to-stripped
@echo "target Strip: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_STRIP) --strip-all $< -o $@ \
  $(if $(PRIVATE_NO_DEBUGLINK),,$(TARGET_STRIP_EXTRA))
endef

define transform-to-stripped-keep-symbols
@echo "target Strip (keep symbols): $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_OBJCOPY) \
    `$(PRIVATE_READELF) -S $< | awk '/.debug_/ {print "-R " $$2}' | xargs` \
    $(TARGET_STRIP_KEEP_SYMBOLS_EXTRA) $< $@
endef

###########################################################
## Commands for packing a target executable or library
###########################################################

define pack-elf-relocations
@echo "target Pack Relocations: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target)
$(hide) $(RELOCATION_PACKER) $@
endef

###########################################################
## Commands for running gcc to link an executable
###########################################################

define transform-o-to-executable-inner
$(hide) $(PRIVATE_CXX) -pie \
	-nostdlib -Bdynamic \
	-Wl,-dynamic-linker,$(PRIVATE_LINKER) \
	-Wl,--gc-sections \
	-Wl,-z,nocopyreloc \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	-Wl,-rpath-link=$(PRIVATE_TARGET_OUT_INTERMEDIATE_LIBRARIES) \
	$(PRIVATE_TARGET_CRTBEGIN_DYNAMIC_O) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_TARGET_COVERAGE_LIB)) \
	$(PRIVATE_TARGET_LIBATOMIC) \
	$(PRIVATE_TARGET_LIBGCC) \
	$(call normalize-target-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_TARGET_CRTEND_O) \
	$(PRIVATE_LDLIBS)
endef

define transform-o-to-executable
@echo "target Executable: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-o-to-executable-inner)
endef


###########################################################
## Commands for linking a static executable. In practice,
## we only use this on arm, so the other platforms don't
## have transform-o-to-static-executable defined.
## Clang driver needs -static to create static executable.
## However, bionic/linker uses -shared to overwrite.
## Linker for x86 targets does not allow coexistance of -static and -shared,
## so we add -static only if -shared is not used.
###########################################################

define transform-o-to-static-executable-inner
$(hide) $(PRIVATE_CXX) \
	-nostdlib -Bstatic \
	$(if $(filter $(PRIVATE_LDFLAGS),-shared),,-static) \
	-Wl,--gc-sections \
	-o $@ \
	$(PRIVATE_TARGET_GLOBAL_LD_DIRS) \
	$(PRIVATE_TARGET_CRTBEGIN_STATIC_O) \
	$(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-target-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(call normalize-target-libraries,$(filter-out %libcompiler_rt.a,$(filter-out %libc_nomalloc.a,$(filter-out %libc.a,$(PRIVATE_ALL_STATIC_LIBRARIES))))) \
	-Wl,--start-group \
	$(call normalize-target-libraries,$(filter %libc.a,$(PRIVATE_ALL_STATIC_LIBRARIES))) \
	$(call normalize-target-libraries,$(filter %libc_nomalloc.a,$(PRIVATE_ALL_STATIC_LIBRARIES))) \
	$(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_TARGET_COVERAGE_LIB)) \
	$(PRIVATE_TARGET_LIBATOMIC) \
	$(call normalize-target-libraries,$(filter %libcompiler_rt.a,$(PRIVATE_ALL_STATIC_LIBRARIES))) \
	$(PRIVATE_TARGET_LIBGCC) \
	-Wl,--end-group \
	$(PRIVATE_TARGET_CRTEND_O)
endef

define transform-o-to-static-executable
@echo "target StaticExecutable: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-o-to-static-executable-inner)
endef


###########################################################
## Commands for running gcc to link a host executable
###########################################################
ifdef BUILD_HOST_static
HOST_FPIE_FLAGS :=
else
HOST_FPIE_FLAGS := -pie
# Force the correct entry point to workaround a bug in binutils that manifests with -pie
ifeq ($(HOST_CROSS_OS),windows)
HOST_CROSS_FPIE_FLAGS += -Wl,-e_mainCRTStartup
endif
endif

ifneq ($(HOST_CUSTOM_LD_COMMAND),true)
define transform-host-o-to-executable-inner
$(hide) $(PRIVATE_CXX) \
	$(PRIVATE_ALL_OBJECTS) \
	-Wl,--whole-archive \
	$(call normalize-host-libraries,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--no-whole-archive \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
	$(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
	$(if $(filter true,$(NATIVE_COVERAGE)),-lgcov) \
	$(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_HOST_LIBPROFILE_RT)) \
	$(call normalize-host-libraries,$(PRIVATE_ALL_SHARED_LIBRARIES)) \
	-Wl,-rpath-link=$($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_INTERMEDIATE_LIBRARIES) \
	-Wl,-rpath,\$$ORIGIN/../$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_SHARED_LIBRARIES)) \
	-Wl,-rpath,\$$ORIGIN/$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_SHARED_LIBRARIES)) \
	$($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)GLOBAL_LD_DIRS) \
	$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
		$(PRIVATE_HOST_GLOBAL_LDFLAGS) \
	) \
	$(PRIVATE_LDFLAGS) \
	-o $@ \
	$(PRIVATE_LDLIBS)
endef
endif

define transform-host-o-to-executable
@echo "$($(PRIVATE_PREFIX)DISPLAY) Executable: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-host-o-to-executable-inner)
endef


###########################################################
## Commands for running javac to make .class files
###########################################################

# Add BUILD_NUMBER to apps default version name if it's unbundled build.
ifdef TARGET_BUILD_APPS
TARGET_BUILD_WITH_APPS_VERSION_NAME := true
endif

ifdef TARGET_BUILD_WITH_APPS_VERSION_NAME
APPS_DEFAULT_VERSION_NAME := $(PLATFORM_VERSION)-$(BUILD_NUMBER_FROM_FILE)
else
APPS_DEFAULT_VERSION_NAME := $(PLATFORM_VERSION)
endif

# TODO: Right now we generate the asset resources twice, first as part
# of generating the Java classes, then at the end when packaging the final
# assets.  This should be changed to do one of two things: (1) Don't generate
# any resource files the first time, only create classes during that stage;
# or (2) Don't use the -c flag with the second stage, instead taking the
# resource files from the first stage as additional input.  My original intent
# was to use approach (2), but this requires a little more work in the tool.
# Maybe we should just use approach (1).

# This rule creates the R.java and Manifest.java files, both of which
# are PRODUCT-neutral.  Don't pass PRIVATE_PRODUCT_AAPT_CONFIG to this invocation.
define create-resource-java-files
@mkdir -p $(PRIVATE_SOURCE_INTERMEDIATES_DIR)
@mkdir -p $(dir $(PRIVATE_RESOURCE_PUBLICS_OUTPUT))
$(hide) $(AAPT) package $(PRIVATE_AAPT_FLAGS) -m \
    $(eval # PRIVATE_PRODUCT_AAPT_CONFIG is intentionally missing-- see comment.) \
    $(addprefix -J , $(PRIVATE_SOURCE_INTERMEDIATES_DIR)) \
    $(addprefix -M , $(PRIVATE_ANDROID_MANIFEST)) \
    $(addprefix -P , $(PRIVATE_RESOURCE_PUBLICS_OUTPUT)) \
    $(addprefix -S , $(PRIVATE_RESOURCE_DIR)) \
    $(addprefix -A , $(PRIVATE_ASSET_DIR)) \
    $(addprefix -I , $(PRIVATE_AAPT_INCLUDES)) \
    $(addprefix -G , $(PRIVATE_PROGUARD_OPTIONS_FILE)) \
    $(addprefix --min-sdk-version , $(PRIVATE_DEFAULT_APP_TARGET_SDK)) \
    $(addprefix --target-sdk-version , $(PRIVATE_DEFAULT_APP_TARGET_SDK)) \
    $(if $(filter --version-code,$(PRIVATE_AAPT_FLAGS)),,--version-code $(PLATFORM_SDK_VERSION)) \
    $(if $(filter --version-name,$(PRIVATE_AAPT_FLAGS)),,--version-name $(APPS_DEFAULT_VERSION_NAME)) \
    $(addprefix --rename-manifest-package , $(PRIVATE_MANIFEST_PACKAGE_NAME)) \
    $(addprefix --rename-instrumentation-target-package , $(PRIVATE_MANIFEST_INSTRUMENTATION_FOR)) \
    --skip-symbols-without-default-localization
endef

# Search for generated R.java/Manifest.java, copy the found R.java as $@.
# Also copy them to a central 'R' directory to make it easier to add the files to an IDE.
define find-generated-R.java
$(hide) for GENERATED_MANIFEST_FILE in `find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) \
  -name Manifest.java 2> /dev/null`; do \
    dir=`awk '/package/{gsub(/\./,"/",$$2);gsub(/;/,"",$$2);print $$2;exit}' $$GENERATED_MANIFEST_FILE`; \
    mkdir -p $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
    $(ACP) -fp $$GENERATED_MANIFEST_FILE $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
  done;
$(hide) for GENERATED_R_FILE in `find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) \
  -name R.java 2> /dev/null`; do \
    dir=`awk '/package/{gsub(/\./,"/",$$2);gsub(/;/,"",$$2);print $$2;exit}' $$GENERATED_R_FILE`; \
    mkdir -p $(TARGET_COMMON_OUT_ROOT)/R/$$dir; \
    $(ACP) -fp $$GENERATED_R_FILE $(TARGET_COMMON_OUT_ROOT)/R/$$dir \
      || exit 31; \
    $(ACP) -fp $$GENERATED_R_FILE $@ || exit 32; \
  done;
@# Ensure that the target file is always created, i.e. also in case we did not
@# enter the GENERATED_R_FILE-loop above. This avoids unnecessary rebuilding.
$(hide) touch $@
endef

###########################################################
# AAPT2 compilation and link
###########################################################
define aapt2-compile-one-resource-file
@mkdir -p $(dir $@)
$(hide) $(AAPT2) compile -o $(dir $@) $(PRIVATE_AAPT2_CFLAGS) --legacy $<
endef

define aapt2-compile-resource-dirs
@mkdir -p $(dir $@)
$(hide) $(AAPT2) compile -o $@ $(addprefix --dir ,$(PRIVATE_SOURCE_RES_DIRS)) \
  $(PRIVATE_AAPT2_CFLAGS) --legacy
endef

# Set up rule to compile one resource file with aapt2.
# Must be called with $(eval).
# $(1): the source file
# $(2): the output file
define aapt2-compile-one-resource-file-rule
$(2) : $(1) $(AAPT2)
	@echo "AAPT2 compile $$@ <- $$<"
	$$(call aapt2-compile-one-resource-file)
endef

# Convert input resource file path to output file path.
# values-[config]/<file>.xml -> values-[config]_<file>.arsc.flat;
# For other resource file, just replace the last "/" with "_" and
# add .flat extension.
#
# $(1): the input resource file path
# $(2): the base dir of the output file path
# Returns: the compiled output file path
define aapt2-compiled-resource-out-file
$(eval _p_w := $(strip $(subst /,$(space),$(dir $(1)))))$(2)/$(subst $(space),/,$(_p_w))_$(if $(filter values%,$(lastword $(_p_w))),$(patsubst %.xml,%.arsc,$(notdir $(1))),$(notdir $(1))).flat
endef

define aapt2-link
@mkdir -p $(dir $@)
$(call dump-words-to-file,$(PRIVATE_RES_FLAT),$(dir $@)aapt2-flat-list)
$(hide) $(AAPT2) link -o $@ \
  $(PRIVATE_AAPT_FLAGS) \
  $(addprefix --manifest ,$(PRIVATE_ANDROID_MANIFEST)) \
  $(addprefix -I ,$(PRIVATE_AAPT_INCLUDES)) \
  $(addprefix -I ,$(PRIVATE_SHARED_ANDROID_LIBRARIES)) \
  $(addprefix --java ,$(PRIVATE_SOURCE_INTERMEDIATES_DIR)) \
  $(addprefix --proguard ,$(PRIVATE_PROGUARD_OPTIONS_FILE)) \
  $(addprefix --min-sdk-version ,$(PRIVATE_DEFAULT_APP_TARGET_SDK)) \
  $(addprefix --target-sdk-version ,$(PRIVATE_DEFAULT_APP_TARGET_SDK)) \
  $(if $(filter --product,$(PRIVATE_AAPT_FLAGS)),,$(addprefix --product ,$(PRIVATE_TARGET_AAPT_CHARACTERISTICS))) \
  $(addprefix -c ,$(PRIVATE_PRODUCT_AAPT_CONFIG)) \
  $(addprefix --preferred-density ,$(PRIVATE_PRODUCT_AAPT_PREF_CONFIG)) \
  $(if $(filter --version-code,$(PRIVATE_AAPT_FLAGS)),,--version-code $(PLATFORM_SDK_VERSION)) \
  $(if $(filter --version-name,$(PRIVATE_AAPT_FLAGS)),,--version-name $(APPS_DEFAULT_VERSION_NAME)) \
  $(addprefix --rename-manifest-package ,$(PRIVATE_MANIFEST_PACKAGE_NAME)) \
  $(addprefix --rename-instrumentation-target-package ,$(PRIVATE_MANIFEST_INSTRUMENTATION_FOR)) \
  $(addprefix -R , $(PRIVATE_OVERLAY_FLAT)) \
  \@$(dir $@)aapt2-flat-list
endef

###########################################################
xlint_unchecked := -Xlint:unchecked

# emit-line, <word list>, <output file>
define emit-line
   $(if $(1),echo -n '$(strip $(1)) ' >> $(2))
endef

# dump-words-to-file, <word list>, <output file>
define dump-words-to-file
        @rm -f $(2)
        @touch $(2)
        @$(call emit-line,$(wordlist 1,500,$(1)),$(2))
        @$(call emit-line,$(wordlist 501,1000,$(1)),$(2))
        @$(call emit-line,$(wordlist 1001,1500,$(1)),$(2))
        @$(call emit-line,$(wordlist 1501,2000,$(1)),$(2))
        @$(call emit-line,$(wordlist 2001,2500,$(1)),$(2))
        @$(call emit-line,$(wordlist 2501,3000,$(1)),$(2))
        @$(call emit-line,$(wordlist 3001,3500,$(1)),$(2))
        @$(call emit-line,$(wordlist 3501,4000,$(1)),$(2))
        @$(call emit-line,$(wordlist 4001,4500,$(1)),$(2))
        @$(call emit-line,$(wordlist 4501,5000,$(1)),$(2))
        @$(call emit-line,$(wordlist 5001,5500,$(1)),$(2))
        @$(call emit-line,$(wordlist 5501,6000,$(1)),$(2))
        @$(call emit-line,$(wordlist 6001,6500,$(1)),$(2))
        @$(call emit-line,$(wordlist 6501,7000,$(1)),$(2))
        @$(call emit-line,$(wordlist 7001,7500,$(1)),$(2))
        @$(call emit-line,$(wordlist 7501,8000,$(1)),$(2))
        @$(call emit-line,$(wordlist 8001,8500,$(1)),$(2))
        @$(call emit-line,$(wordlist 8501,9000,$(1)),$(2))
        @$(call emit-line,$(wordlist 9001,9500,$(1)),$(2))
        @$(call emit-line,$(wordlist 9501,10000,$(1)),$(2))
        @$(call emit-line,$(wordlist 10001,10500,$(1)),$(2))
        @$(call emit-line,$(wordlist 10501,11000,$(1)),$(2))
        @$(call emit-line,$(wordlist 11001,11500,$(1)),$(2))
        @$(call emit-line,$(wordlist 11501,12000,$(1)),$(2))
        @$(call emit-line,$(wordlist 12001,12500,$(1)),$(2))
        @$(call emit-line,$(wordlist 12501,13000,$(1)),$(2))
        @$(call emit-line,$(wordlist 13001,13500,$(1)),$(2))
        @$(if $(wordlist 13501,13502,$(1)),$(error Too many words ($(words $(1)))))
endef

# For a list of jar files, unzip them to a specified directory,
# but make sure that no META-INF files come along for the ride,
# unless PRIVATE_DONT_DELETE_JAR_META_INF is set.
#
# $(1): files to unzip
# $(2): destination directory
define unzip-jar-files
  $(hide) for f in $(1); \
  do \
    if [ ! -f $$f ]; then \
      echo Missing file $$f; \
      exit 1; \
    fi; \
    unzip -qo $$f -d $(2); \
  done
  $(if $(PRIVATE_DONT_DELETE_JAR_META_INF),,$(hide) rm -rf $(2)/META-INF)
endef

# Call jack
#
define call-jack
 JACK_VERSION=$(PRIVATE_JACK_VERSION) $(JACK) $(DEFAULT_JACK_EXTRA_ARGS)
endef

# Common definition to invoke javac on the host and target.
#
# Some historical notes:
# - below we write the list of java files to java-source-list to avoid argument
#   list length problems with Cygwin
# - we filter out duplicate java file names because eclipse's compiler
#   doesn't like them.
#
# $(1): javac
# $(2): bootclasspath
define compile-java
$(hide) rm -f $@
$(hide) rm -rf $(PRIVATE_CLASS_INTERMEDIATES_DIR)
$(hide) mkdir -p $(dir $@)
$(hide) mkdir -p $(PRIVATE_CLASS_INTERMEDIATES_DIR)
$(call unzip-jar-files,$(PRIVATE_STATIC_JAVA_LIBRARIES),$(PRIVATE_CLASS_INTERMEDIATES_DIR))
$(call dump-words-to-file,$(PRIVATE_JAVA_SOURCES),$(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list)
$(hide) if [ -d "$(PRIVATE_SOURCE_INTERMEDIATES_DIR)" ]; then \
          find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) -name '*.java' -and -not -name '.*' >> $(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list; \
fi
$(hide) tr ' ' '\n' < $(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list \
    | $(NORMALIZE_PATH) | sort -u > $(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list-uniq
$(hide) if [ -s $(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list-uniq ] ; then \
    $(1) -encoding UTF-8 \
    $(if $(findstring true,$(PRIVATE_WARNINGS_ENABLE)),$(xlint_unchecked),) \
    $(2) \
    $(addprefix -classpath ,$(strip \
        $(call normalize-path-list,$(PRIVATE_ALL_JAVA_LIBRARIES)))) \
    $(if $(findstring true,$(PRIVATE_WARNINGS_ENABLE)),$(xlint_unchecked),) \
    -extdirs "" -d $(PRIVATE_CLASS_INTERMEDIATES_DIR) \
    $(PRIVATE_JAVACFLAGS) \
    \@$(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list-uniq \
    || ( rm -rf $(PRIVATE_CLASS_INTERMEDIATES_DIR) ; exit 41 ) \
fi
$(if $(PRIVATE_JAVA_LAYERS_FILE), $(hide) build/tools/java-layers.py \
    $(PRIVATE_JAVA_LAYERS_FILE) \@$(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list-uniq,)
$(hide) rm -f $(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list
$(hide) rm -f $(PRIVATE_CLASS_INTERMEDIATES_DIR)/java-source-list-uniq
$(if $(PRIVATE_JAR_EXCLUDE_FILES), $(hide) find $(PRIVATE_CLASS_INTERMEDIATES_DIR) \
    -name $(word 1, $(PRIVATE_JAR_EXCLUDE_FILES)) \
    $(addprefix -o -name , $(wordlist 2, 999, $(PRIVATE_JAR_EXCLUDE_FILES))) \
    | xargs rm -rf)
$(if $(PRIVATE_JAR_PACKAGES), \
    $(hide) find $(PRIVATE_CLASS_INTERMEDIATES_DIR) -mindepth 1 -type f \
        $(foreach pkg, $(PRIVATE_JAR_PACKAGES), \
            -not -path $(PRIVATE_CLASS_INTERMEDIATES_DIR)/$(subst .,/,$(pkg))/\*) -delete ; \
        find $(PRIVATE_CLASS_INTERMEDIATES_DIR) -empty -delete)
$(if $(PRIVATE_JAR_EXCLUDE_PACKAGES), $(hide) rm -rf \
    $(foreach pkg, $(PRIVATE_JAR_EXCLUDE_PACKAGES), \
        $(PRIVATE_CLASS_INTERMEDIATES_DIR)/$(subst .,/,$(pkg))))
$(if $(PRIVATE_RMTYPEDEFS), $(hide) $(RMTYPEDEFS) -v $(PRIVATE_CLASS_INTERMEDIATES_DIR))
$(if $(PRIVATE_JAR_MANIFEST), \
    $(hide) sed -e "s/%BUILD_NUMBER%/$(BUILD_NUMBER_FROM_FILE)/" \
            $(PRIVATE_JAR_MANIFEST) > $(dir $@)/manifest.mf && \
        jar -cfm $@ $(dir $@)/manifest.mf \
            -C $(PRIVATE_CLASS_INTERMEDIATES_DIR) ., \
    $(hide) jar -cf $@ -C $(PRIVATE_CLASS_INTERMEDIATES_DIR) .)
$(if $(PRIVATE_EXTRA_JAR_ARGS),$(call add-java-resources-to,$@))
endef

define transform-java-to-classes.jar
@echo "target Java: $(PRIVATE_MODULE) ($(PRIVATE_CLASS_INTERMEDIATES_DIR))"
$(call compile-java,$(TARGET_JAVAC),$(PRIVATE_BOOTCLASSPATH))
endef

# Invoke Jack to compile java from source to dex and jack files.
#
# Some historical notes:
# - below we write the list of java files to java-source-list to avoid argument
#   list length problems with Cygwin
# - we filter out duplicate java file names because Jack doesn't like them.
define jack-java-to-dex
$(hide) rm -f $@
$(hide) rm -f $(PRIVATE_CLASSES_JACK)
$(hide) rm -rf $(PRIVATE_JACK_INTERMEDIATES_DIR)
$(hide) mkdir -p $(dir $@)
$(hide) mkdir -p $(dir $(PRIVATE_CLASSES_JACK))
$(hide) mkdir -p $(PRIVATE_JACK_INTERMEDIATES_DIR)
$(if $(PRIVATE_JACK_INCREMENTAL_DIR),$(hide) mkdir -p $(PRIVATE_JACK_INCREMENTAL_DIR))
$(call dump-words-to-file,$(PRIVATE_JAVA_SOURCES),$(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list)
$(hide) if [ -d "$(PRIVATE_SOURCE_INTERMEDIATES_DIR)" ]; then \
          find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) -name '*.java' >> $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list; \
fi
$(hide) tr ' ' '\n' < $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list \
    | $(NORMALIZE_PATH) | sort -u > $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq
$(if $(PRIVATE_JACK_PROGUARD_FLAGS), \
    $(hide) echo -basedirectory $(CURDIR) > $@.flags; \
    echo $(PRIVATE_JACK_PROGUARD_FLAGS) >> $@.flags; \
)
$(if $(PRIVATE_EXTRA_JAR_ARGS),
    $(hide) mkdir -p $@.res.tmp
    $(hide) $(call create-empty-package-at,$@.res.tmp.zip)
    $(hide) $(call add-java-resources-to,$@.res.tmp.zip)
    $(hide) unzip -qo $@.res.tmp.zip -d $@.res.tmp
    $(hide) rm $@.res.tmp.zip)
$(hide) if [ -s $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq ] ; then \
    export tmpEcjArg="@$(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq"; \
else \
    export tmpEcjArg=""; \
fi; \
$(call call-jack) \
    $(strip $(PRIVATE_JACK_FLAGS)) \
    $(strip $(PRIVATE_JACK_COVERAGE_OPTIONS)) \
    $(if $(NO_OPTIMIZE_DX), \
        -D jack.dex.optimize="false") \
    $(if $(PRIVATE_RMTYPEDEFS), \
        -D jack.android.remove-typedef="true") \
    $(addprefix --classpath ,$(strip \
        $(call normalize-path-list,$(PRIVATE_BOOTCLASSPATH_JAVA_LIBRARIES) $(PRIVATE_ALL_JACK_LIBRARIES)))) \
    $(addprefix --import ,$(call reverse-list,$(PRIVATE_STATIC_JACK_LIBRARIES))) \
    $(if $(PRIVATE_EXTRA_JAR_ARGS),--import-resource $@.res.tmp) \
    -D jack.android.min-api-level=$(PRIVATE_JACK_MIN_SDK_VERSION) \
    -D jack.import.resource.policy=keep-first \
    -D jack.import.type.policy=keep-first \
    --output-jack $(PRIVATE_CLASSES_JACK) \
    $(if $(PRIVATE_JACK_INCREMENTAL_DIR),--incremental-folder $(PRIVATE_JACK_INCREMENTAL_DIR)) \
    --output-dex $(PRIVATE_JACK_INTERMEDIATES_DIR) \
    $(addprefix --config-jarjar ,$(strip $(PRIVATE_JARJAR_RULES))) \
    $(if $(PRIVATE_JACK_PROGUARD_FLAGS),--config-proguard $@.flags) \
    $$tmpEcjArg \
    || ( rm -rf $(PRIVATE_CLASSES_JACK); exit 41 )
$(hide) mv $(PRIVATE_JACK_INTERMEDIATES_DIR)/classes*.dex $(dir $@)
$(hide) rm -f $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list
$(if $(PRIVATE_EXTRA_JAR_ARGS),$(hide) rm -rf $@.res.tmp)
$(hide) mv $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq $(PRIVATE_JACK_INTERMEDIATES_DIR).java-source-list
$(if $(PRIVATE_JAR_PACKAGES), $(hide) echo unsupported options PRIVATE_JAR_PACKAGES in $@; exit 53)
$(if $(PRIVATE_JAR_EXCLUDE_PACKAGES), $(hide) echo unsupported options JAR_EXCLUDE_PACKAGES in $@; exit 53)
$(if $(PRIVATE_JAR_MANIFEST), $(hide) echo unsupported options JAR_MANIFEST in $@; exit 53)
endef

# Invoke Jack to compile java source just to check it compiles correctly.
#
# Some historical notes:
# - below we write the list of java files to java-source-list to avoid argument
#   list length problems with Cygwin
# - we filter out duplicate java file names because Jack doesn't like them.
define jack-check-java
$(hide) rm -f $@
$(hide) rm -f $@.java-source-list
$(hide) rm -f $@.java-source-list-uniq
$(hide) mkdir -p $(dir $@)
$(if $(PRIVATE_JACK_INCREMENTAL_DIR),$(hide) mkdir -p $(PRIVATE_JACK_INCREMENTAL_DIR))
$(call dump-words-to-file,$(PRIVATE_JAVA_SOURCES),$@.java-source-list)
$(hide) if [ -d "$(PRIVATE_SOURCE_INTERMEDIATES_DIR)" ]; then \
          find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) -name '*.java' >> $@.java-source-list; \
fi
$(hide) tr ' ' '\n' < $@.java-source-list \
    | sort -u > $@.java-source-list-uniq
$(hide) if [ -s $@.java-source-list-uniq ] ; then \
	$(call call-jack,$(PRIVATE_JACK_EXTRA_ARGS)) \
	    $(strip $(PRIVATE_JACK_FLAGS)) \
	    $(strip $(PRIVATE_JACK_DEBUG_FLAGS)) \
	    $(addprefix --classpath ,$(strip \
	        $(call normalize-path-list,$(call reverse-list,$(PRIVATE_STATIC_JACK_LIBRARIES)) $(PRIVATE_BOOTCLASSPATH_JAVA_LIBRARIES) $(PRIVATE_ALL_JACK_LIBRARIES)))) \
	    -D jack.import.resource.policy=keep-first \
	    -D jack.android.min-api-level=$(PRIVATE_JACK_MIN_SDK_VERSION) \
	    -D jack.import.type.policy=keep-first \
	    $(if $(PRIVATE_JACK_INCREMENTAL_DIR),--incremental-folder $(PRIVATE_JACK_INCREMENTAL_DIR)) \
	    @$@.java-source-list-uniq; \
fi
touch $@
endef

define transform-jar-to-jack
	$(hide) mkdir -p $(dir $@)
	$(hide) mkdir -p $@.tmpjill.res
	$(hide) unzip -qo $< -d $@.tmpjill.res
	$(hide) find $@.tmpjill.res -iname "*.class" -delete
	$(hide) $(call call-jack) \
	    $(PRIVATE_JACK_FLAGS) \
        -D jack.import.resource.policy=keep-first \
        -D jack.import.type.policy=keep-first \
        -D jack.android.min-api-level=$(PRIVATE_JACK_MIN_SDK_VERSION) \
	    --import $< \
	    --import-resource $@.tmpjill.res \
	    --output-jack $@
	$(hide) rm -rf $@.tmpjill.res
endef

# Moves $1.tmp to $1 if necessary. This is designed to be used with
# .KATI_RESTAT. For kati, this function doesn't update the timestamp
# of $1 when $1.tmp is identical to $1 so that ninja won't rebuild
# targets which depend on $1. For GNU make, this function simply
# copies $1.tmp to $1.
ifeq ($(BUILDING_WITH_NINJA),true)
define commit-change-for-toc
$(hide) if cmp -s $1.tmp $1 ; then \
 rm $1.tmp ; \
else \
 mv $1.tmp $1 ; \
fi
endef
else
define commit-change-for-toc
@# make doesn't support restat. We always update .toc files so the dependents will always be updated too.
$(hide) mv $1.tmp $1
endef
endif

## Rule to create a table of contents from a .jar file.
## Must be called with $(eval).
# $(1): A .jar file
define _transform-jar-to-toc
$1.toc: $1 | $(IJAR)
	@echo Generating TOC: $$@
	$(hide) $(IJAR) $$< $$@.tmp
	$$(call commit-change-for-toc,$$@)
endef

## Define a rule which generates .jar.toc and mark it as .KATI_RESTAT.
# $(1): A .jar file
define define-jar-to-toc-rule
$(eval $(call _transform-jar-to-toc,$1))\
$(eval .KATI_RESTAT: $1.toc)
endef

ifeq (,$(TARGET_BUILD_APPS))

## Rule to create a table of contents from a .dex file.
## Must be called with $(eval).
# $(1): The directory which contains classes*.dex files
define _transform-dex-to-toc
$1/classes.dex.toc: PRIVATE_INPUT_DEX_FILES := $1/classes*.dex
$1/classes.dex.toc: $1/classes.dex $(DEXDUMP)
	@echo Generating TOC: $$@
	$(hide) $(DEXDUMP) -l xml $$(PRIVATE_INPUT_DEX_FILES) > $$@.tmp
	$$(call commit-change-for-toc,$$@)
endef

## Define a rule which generates .dex.toc and mark it as .KATI_RESTAT.
# $(1): The directory which contains classes*.dex files
define define-dex-to-toc-rule
$(eval $(call _transform-dex-to-toc,$1))\
$(eval .KATI_RESTAT: $1/classes.dex.toc)
endef

else

# Turn off .toc optimization for apps build as we cannot build dexdump.
define define-dex-to-toc-rule
endef

endif  # TARGET_BUILD_APPS


# Invoke Jack to compile java from source to jack files without shrink or obfuscation.
#
# Some historical notes:
# - below we write the list of java files to java-source-list to avoid argument
#   list length problems with Cygwin
# - we filter out duplicate java file names because Jack doesn't like them.
define java-to-jack
$(hide) rm -f $@
$(hide) rm -rf $(PRIVATE_JACK_INTERMEDIATES_DIR)
$(hide) mkdir -p $(dir $@)
$(hide) mkdir -p $(PRIVATE_JACK_INTERMEDIATES_DIR)
$(if $(PRIVATE_JACK_INCREMENTAL_DIR),$(hide) mkdir -p $(PRIVATE_JACK_INCREMENTAL_DIR))
$(call dump-words-to-file,$(PRIVATE_JAVA_SOURCES),$(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list)
$(hide) if [ -d "$(PRIVATE_SOURCE_INTERMEDIATES_DIR)" ]; then \
          find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) -name '*.java' >> $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list; \
fi
$(hide) tr ' ' '\n' < $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list \
    | $(NORMALIZE_PATH) | sort -u > $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq
$(if $(PRIVATE_JACK_PROGUARD_FLAGS), \
    $(hide) echo -basedirectory $(CURDIR) > $@.flags; \
    echo $(PRIVATE_JACK_PROGUARD_FLAGS) >> $@.flags; \
)
$(if $(PRIVATE_EXTRA_JAR_ARGS),
	$(hide) mkdir -p $@.res.tmp
	$(hide) $(call create-empty-package-at,$@.res.tmp.zip)
	$(hide) $(call add-java-resources-to,$@.res.tmp.zip)
	$(hide) unzip -qo $@.res.tmp.zip -d $@.res.tmp
	$(hide) rm $@.res.tmp.zip)
$(hide) if [ -s $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq ] ; then \
    export tmpEcjArg="@$(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq"; \
else \
    export tmpEcjArg=""; \
fi; \
$(call call-jack) \
    $(strip $(PRIVATE_JACK_FLAGS)) \
    $(if $(NO_OPTIMIZE_DX), \
        -D jack.dex.optimize="false") \
    $(addprefix --classpath ,$(strip \
        $(call normalize-path-list,$(PRIVATE_BOOTCLASSPATH_JAVA_LIBRARIES) $(PRIVATE_ALL_JACK_LIBRARIES)))) \
    $(addprefix --import ,$(call reverse-list,$(PRIVATE_STATIC_JACK_LIBRARIES))) \
    $(if $(PRIVATE_EXTRA_JAR_ARGS),--import-resource $@.res.tmp) \
    -D jack.import.resource.policy=keep-first \
    -D jack.import.type.policy=keep-first \
    -D jack.android.min-api-level=$(PRIVATE_JACK_MIN_SDK_VERSION) \
    $(if $(PRIVATE_JACK_INCREMENTAL_DIR),--incremental-folder $(PRIVATE_JACK_INCREMENTAL_DIR)) \
    --output-jack $@ \
    $(addprefix --config-jarjar ,$(strip $(PRIVATE_JARJAR_RULES))) \
    $(if $(PRIVATE_JACK_PROGUARD_FLAGS),--config-proguard $@.flags) \
    $$tmpEcjArg \
    || ( rm -f $@ ; exit 41 )
$(hide) rm -f $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list
$(if $(PRIVATE_EXTRA_JAR_ARGS),$(hide) rm -rf $@.res.tmp)
$(hide) mv $(PRIVATE_JACK_INTERMEDIATES_DIR)/java-source-list-uniq $(PRIVATE_JACK_INTERMEDIATES_DIR).java-source-list
$(if $(PRIVATE_JAR_PACKAGES), $(hide) echo unsupported options PRIVATE_JAR_PACKAGES in $@; exit 53)
$(if $(PRIVATE_JAR_EXCLUDE_PACKAGES), $(hide) echo unsupported options JAR_EXCLUDE_PACKAGES in $@; exit 53)
$(if $(PRIVATE_JAR_MANIFEST), $(hide) echo unsupported options JAR_MANIFEST in $@; exit 53)
endef

define transform-classes.jar-to-emma
$(hide) java -classpath $(EMMA_JAR) emma instr -outmode fullcopy -outfile \
    $(PRIVATE_EMMA_COVERAGE_FILE) -ip $< -d $(PRIVATE_EMMA_INTERMEDIATES_DIR) \
    $(addprefix -ix , $(PRIVATE_EMMA_COVERAGE_FILTER))
endef

# Create a mostly-empty .jar file that we'll add to later.
# The MacOS jar tool doesn't like creating empty jar files,
# so we need to give it something.
# $(1) package to create
define create-empty-package-at
@mkdir -p $(dir $(1))
$(hide) touch $(dir $(1))zipdummy
$(hide) (cd $(dir $(1)) && jar cf $(notdir $(1)) zipdummy)
$(hide) zip -qd $(1) zipdummy
$(hide) rm $(dir $(1))zipdummy
endef

# Create a mostly-empty .jar file that we'll add to later.
# The MacOS jar tool doesn't like creating empty jar files,
# so we need to give it something.
define create-empty-package
$(call create-empty-package-at,$@)
endef

# Copy an arhchive file and delete any class files and empty folders inside.
# $(1): the source archive file.
# $(2): the destination archive file.
define initialize-package-file
@mkdir -p $(dir $(2))
$(hide) cp -f $(1) $(2)
$(hide) zip -qd $(2) "*.class" \
    $(if $(strip $(PRIVATE_DONT_DELETE_JAR_DIRS)),,"*/") \
    || true # Ignore the error when nothing to delete.
endef

#TODO: we kinda want to build different asset packages for
#      different configurations, then combine them later (or something).
#      Per-locale, etc.
#      A list of dynamic and static parameters;  build layers for
#      dynamic params that lay over the static ones.
#TODO: update the manifest to point to the package file
#Note that the version numbers are given to aapt as simple default
#values; applications can override these by explicitly stating
#them in their manifest.
define add-assets-to-package
$(hide) $(AAPT) package -u $(PRIVATE_AAPT_FLAGS) \
    $(addprefix -c , $(PRIVATE_PRODUCT_AAPT_CONFIG)) \
    $(addprefix --preferred-density , $(PRIVATE_PRODUCT_AAPT_PREF_CONFIG)) \
    $(addprefix -M , $(PRIVATE_ANDROID_MANIFEST)) \
    $(addprefix -S , $(PRIVATE_RESOURCE_DIR)) \
    $(addprefix -A , $(PRIVATE_ASSET_DIR)) \
    $(addprefix -I , $(PRIVATE_AAPT_INCLUDES)) \
    $(addprefix --min-sdk-version , $(PRIVATE_DEFAULT_APP_TARGET_SDK)) \
    $(addprefix --target-sdk-version , $(PRIVATE_DEFAULT_APP_TARGET_SDK)) \
    $(if $(filter --product,$(PRIVATE_AAPT_FLAGS)),,$(addprefix --product , $(PRIVATE_TARGET_AAPT_CHARACTERISTICS))) \
    $(if $(filter --version-code,$(PRIVATE_AAPT_FLAGS)),,--version-code $(PLATFORM_SDK_VERSION)) \
    $(if $(filter --version-name,$(PRIVATE_AAPT_FLAGS)),,--version-name $(APPS_DEFAULT_VERSION_NAME)) \
    $(addprefix --rename-manifest-package , $(PRIVATE_MANIFEST_PACKAGE_NAME)) \
    $(addprefix --rename-instrumentation-target-package , $(PRIVATE_MANIFEST_INSTRUMENTATION_FOR)) \
    --skip-symbols-without-default-localization \
    -F $@
endef

# We need the extra blank line, so that the command will be on a separate line.
# $(1): the ABI name
# $(2): the list of shared libraies
define _add-jni-shared-libs-to-package-per-abi
$(hide) cp $(2) $(dir $@)lib/$(1)

endef

# For apps_only build, don't uncompress/page-align the jni libraries,
# because the apk may be run on older platforms that don't support loading jni directly from apk.
ifdef TARGET_BUILD_APPS
JNI_COMPRESS_FLAGS :=
ZIPALIGN_PAGE_ALIGN_FLAGS :=
else
JNI_COMPRESS_FLAGS := -0
ZIPALIGN_PAGE_ALIGN_FLAGS := -p
endif

define add-jni-shared-libs-to-package
$(hide) rm -rf $(dir $@)lib
$(hide) mkdir -p $(addprefix $(dir $@)lib/,$(PRIVATE_JNI_SHARED_LIBRARIES_ABI))
$(foreach abi,$(PRIVATE_JNI_SHARED_LIBRARIES_ABI),\
  $(call _add-jni-shared-libs-to-package-per-abi,$(abi),\
    $(patsubst $(abi):%,%,$(filter $(abi):%,$(PRIVATE_JNI_SHARED_LIBRARIES)))))
$(hide) (cd $(dir $@) && zip -qrX $(JNI_COMPRESS_FLAGS) $(notdir $@) lib)
$(hide) rm -rf $(dir $@)lib
endef

#TODO: update the manifest to point to the dex file
define add-dex-to-package
$(call add-dex-to-package-arg,$@)
endef

# $(1): the package file.
define add-dex-to-package-arg
$(hide) find $(dir $(PRIVATE_DEX_FILE)) -maxdepth 1 -name "classes*.dex" | sort | xargs zip -qjX $(1)
endef

# Add java resources added by the current module.
# $(1) destination package
#
define add-java-resources-to
$(call dump-words-to-file, $(PRIVATE_EXTRA_JAR_ARGS), $(1).jar-arg-list)
$(hide) jar uf $(1) @$(1).jar-arg-list
@rm -f $(1).jar-arg-list
endef

# Add resources carried by static Jack libraries.
#
define add-carried-jack-resources
 $(hide) if [ -d $(PRIVATE_JACK_INTERMEDIATES_DIR) ] ; then \
    find $(PRIVATE_JACK_INTERMEDIATES_DIR) -type f | sort \
        | sed -e "s?^$(PRIVATE_JACK_INTERMEDIATES_DIR)/? -C \"$(PRIVATE_JACK_INTERMEDIATES_DIR)\" \"?" -e "s/$$/\"/" \
        > $(dir $@)jack_res_jar_flags; \
    if [ -s $(dir $@)jack_res_jar_flags ] ; then \
        jar uf $@ @$(dir $@)jack_res_jar_flags; \
    fi; \
fi
endef

# Returns the minSdkVersion of the specified APK as a decimal number. If the
# version is a codename, returns the current platform SDK version (always a
# decimal number) instead. If the APK does not specify a minSdkVersion, returns
# 0 to match how the Android platform interprets this situation at runtime.
#
# This currently substitutes any version which contains characters other than
# digits with the current platform's API Level number. This is because I
# couldn't figure out an easy way to perform the substitution only for the
# version codes listed in PLATFORM_VERSION_ALL_CODENAMES.
define get-package-min-sdk-version-int
$$(($(AAPT) dump badging $(1) 2>&1 | grep '^sdkVersion' || echo "sdkVersion:'0'") \
    | cut -d"'" -f2 | \
    sed -e s/^.*[^0-9].*$$/$(PLATFORM_SDK_VERSION)/)
endef

# Sign a package using the specified key/cert.
#
define sign-package
$(call sign-package-arg,$@)
endef

# $(1): the package file we are signing.
define sign-package-arg
$(hide) mv $(1) $(1).unsigned
$(hide) java -Djava.library.path=$(SIGNAPK_JNI_LIBRARY_PATH) -jar $(SIGNAPK_JAR) \
    --min-sdk-version $(call get-package-min-sdk-version-int,$@.unsigned) \
    $(PRIVATE_CERTIFICATE) $(PRIVATE_PRIVATE_KEY) \
    $(PRIVATE_ADDITIONAL_CERTIFICATES) $(1).unsigned $(1).signed
$(hide) mv $(1).signed $(1)
endef

# Align STORED entries of a package on 4-byte boundaries to make them easier to mmap.
#
define align-package
$(hide) if ! $(ZIPALIGN) -c $(ZIPALIGN_PAGE_ALIGN_FLAGS) 4 $@ >/dev/null ; then \
  mv $@ $@.unaligned; \
  $(ZIPALIGN) \
    -f \
    $(ZIPALIGN_PAGE_ALIGN_FLAGS) \
    4 \
    $@.unaligned $@.aligned; \
  mv $@.aligned $@; \
  fi
endef

# Remove dynamic timestamps from packages
#
ifndef TARGET_BUILD_APPS
define remove-timestamps-from-package
$(hide) $(ZIPTIME) $@
endef
endif

# Uncompress shared libraries embedded in an apk.
#
define uncompress-shared-libs
$(hide) if (zipinfo $@ $(PRIVATE_EMBEDDED_JNI_LIBS) 2>/dev/null | grep -v ' stor ' >/dev/null) ; then \
  rm -rf $(dir $@)uncompressedlibs && mkdir $(dir $@)uncompressedlibs; \
  unzip $@ $(PRIVATE_EMBEDDED_JNI_LIBS) -d $(dir $@)uncompressedlibs && \
  zip -d $@ 'lib/*.so' && \
  ( cd $(dir $@)uncompressedlibs && find lib -type f | sort | zip -D -X -0 ../$(notdir $@) -@ ) && \
  rm -rf $(dir $@)uncompressedlibs; \
  fi
endef

define install-dex-debug
$(hide) if [ -f "$(PRIVATE_INTERMEDIATES_DIR)/classes.dex" ]; then \
	    mkdir -p $(TOP)/dalvik/DEBUG-FILES; \
	    $(ACP) $(PRIVATE_INTERMEDIATES_DIR)/classes.dex \
		$(TOP)/dalvik/DEBUG-FILES/$(PRIVATE_MODULE).dex; \
	fi
$(hide) if [ -f "$(PRIVATE_INTERMEDIATES_DIR)/classes.lst" ]; then \
	    mkdir -p $(TOP)/dalvik/DEBUG-FILES; \
	    $(ACP) $(PRIVATE_INTERMEDIATES_DIR)/classes.lst \
		$(TOP)/dalvik/DEBUG-FILES/$(PRIVATE_MODULE).lst; \
	fi
endef

# TODO(joeo): If we can ever upgrade to post 3.81 make and get the
# new prebuilt rules to work, we should change this to copy the
# resources to the out directory and then copy the resources.

# Note: we intentionally don't clean PRIVATE_CLASS_INTERMEDIATES_DIR
# in transform-java-to-classes for the sake of vm-tests.
define transform-host-java-to-package
@echo "$($(PRIVATE_PREFIX)DISPLAY) Java: $(PRIVATE_MODULE) ($(PRIVATE_CLASS_INTERMEDIATES_DIR))"
$(call compile-java,$(HOST_JAVAC),$(PRIVATE_BOOTCLASSPATH))
endef

###########################################################
## Commands for copying files
###########################################################

# Define a rule to copy a header.  Used via $(eval) by copy_headers.make.
# $(1): source header
# $(2): destination header
define copy-one-header
$(2): $(1)
	@echo "Header: $$@"
	$$(copy-file-to-new-target-with-cp)
endef

# Define a rule to copy a file.  For use via $(eval).
# $(1): source file
# $(2): destination file
define copy-one-file
$(2): $(1) | $(ACP)
	@echo "Copy: $$@"
	$$(copy-file-to-target)
endef

# Copies many files.
# $(1): The files to copy.  Each entry is a ':' separated src:dst pair
# Evaluates to the list of the dst files (ie suitable for a dependency list)
define copy-many-files
$(foreach f, $(1), $(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(eval _cmf_dest := $(word 2,$(_cmf_tuple))) \
    $(eval $(call copy-one-file,$(_cmf_src),$(_cmf_dest))) \
    $(_cmf_dest)))
endef

# Copy the file only if it's a well-formed xml file. For use via $(eval).
# $(1): source file
# $(2): destination file, must end with .xml.
define copy-xml-file-checked
$(2): $(1) | $(ACP)
	@echo "Copy xml: $$@"
	$(hide) xmllint $$< >/dev/null  # Don't print the xml file to stdout.
	$$(copy-file-to-target)
endef

# The -t option to acp and the -p option to cp is
# required for OSX.  OSX has a ridiculous restriction
# where it's an error for a .a file's modification time
# to disagree with an internal timestamp, and this
# macro is used to install .a files (among other things).

# Copy a single file from one place to another,
# preserving permissions and overwriting any existing
# file.
# We disable the "-t" option for acp cannot handle
# high resolution timestamp correctly on file systems like ext4.
# Therefore copy-file-to-target is the same as copy-file-to-new-target.
define copy-file-to-target
@mkdir -p $(dir $@)
$(hide) $(ACP) -fp $< $@
endef

# The same as copy-file-to-target, but use the local
# cp command instead of acp.
define copy-file-to-target-with-cp
@mkdir -p $(dir $@)
$(hide) cp -fp $< $@
endef

# The same as copy-file-to-target, but use the zipalign tool to do so.
define copy-file-to-target-with-zipalign
@mkdir -p $(dir $@)
$(hide) $(ZIPALIGN) -f 4 $< $@
endef

# The same as copy-file-to-target, but strip out "# comment"-style
# comments (for config files and such).
define copy-file-to-target-strip-comments
@mkdir -p $(dir $@)
$(hide) sed -e 's/#.*$$//' -e 's/[ \t]*$$//' -e '/^$$/d' < $< > $@
endef

# The same as copy-file-to-target, but don't preserve
# the old modification time.
define copy-file-to-new-target
@mkdir -p $(dir $@)
$(hide) $(ACP) -fp $< $@
endef

# The same as copy-file-to-new-target, but use the local
# cp command instead of acp.
define copy-file-to-new-target-with-cp
@mkdir -p $(dir $@)
$(hide) cp -f $< $@
endef

# Copy a prebuilt file to a target location.
define transform-prebuilt-to-target
@echo "$(if $(PRIVATE_IS_HOST_MODULE),host,target) Prebuilt: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target)
endef

# Copy a prebuilt file to a target location, using zipalign on it.
define transform-prebuilt-to-target-with-zipalign
@echo "$(if $(PRIVATE_IS_HOST_MODULE),host,target) Prebuilt APK: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target-with-zipalign)
endef

# Copy a prebuilt file to a target location, stripping "# comment" comments.
define transform-prebuilt-to-target-strip-comments
@echo "$(if $(PRIVATE_IS_HOST_MODULE),host,target) Prebuilt: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target-strip-comments)
endef

# Copy a list of files/directories to target location, with sub dir structure preserved.
# For example $(HOST_OUT_EXECUTABLES)/aapt -> $(staging)/bin/aapt .
# $(1): the source list of files/directories.
# $(2): the path prefix to strip. In the above example it would be $(HOST_OUT).
# $(3): the target location.
define copy-files-with-structure
$(foreach t,$(1),\
  $(eval s := $(patsubst $(2)%,%,$(t)))\
  $(hide) mkdir -p $(dir $(3)/$(s)); cp -Rf $(t) $(3)/$(s)$(newline))
endef


###########################################################
## Commands to call Proguard
###########################################################
define transform-jar-to-proguard
@echo Proguard: $@
$(hide) $(PROGUARD) -injars $< -outjars $@ $(PRIVATE_PROGUARD_FLAGS) \
    $(addprefix -injars , $(PRIVATE_EXTRA_INPUT_JAR))
endef

###########################################################
## Stuff source generated from one-off tools
###########################################################

define transform-generated-source
@echo "target Generated: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_CUSTOM_TOOL)
endef


###########################################################
## Assertions about attributes of the target
###########################################################

# $(1): The file to check
ifndef get-file-size
$(error HOST_OS must define get-file-size)
endif

# Convert a partition data size (eg, as reported in /proc/mtd) to the
# size of the image used to flash that partition (which includes a
# spare area for each page).
# $(1): the partition data size
define image-size-from-data-size
$(strip $(eval _isfds_value := $$(shell echo $$$$(($(1) / $(BOARD_NAND_PAGE_SIZE) * \
  ($(BOARD_NAND_PAGE_SIZE)+$(BOARD_NAND_SPARE_SIZE))))))\
$(if $(filter 0, $(_isfds_value)),$(shell echo $$(($(BOARD_NAND_PAGE_SIZE)+$(BOARD_NAND_SPARE_SIZE)))),$(_isfds_value))\
$(eval _isfds_value :=))
endef

# $(1): The file(s) to check (often $@)
# $(2): The maximum total image size, in decimal bytes.
#    Make sure to take into account any reserved space needed for the FS.
#
# If $(2) is empty, evaluates to "true"
#
# Reserve bad blocks.  Make sure that MAX(1% of partition size, 2 blocks)
# is left over after the image has been flashed.  Round the 1% up to the
# next whole flash block size.
define assert-max-file-size
$(if $(2), \
  size=$$(for i in $(1); do $(call get-file-size,$$i); echo +; done; echo 0); \
  total=$$(( $$( echo "$$size" ) )); \
  printname=$$(echo -n "$(1)" | tr " " +); \
  img_blocksize=$(call image-size-from-data-size,$(BOARD_FLASH_BLOCK_SIZE)); \
  twoblocks=$$((img_blocksize * 2)); \
  onepct=$$((((($(2) / 100) - 1) / img_blocksize + 1) * img_blocksize)); \
  reserve=$$((twoblocks > onepct ? twoblocks : onepct)); \
  maxsize=$$(($(2) - reserve)); \
  echo "$$printname maxsize=$$maxsize blocksize=$$img_blocksize total=$$total reserve=$$reserve"; \
  if [ "$$total" -gt "$$maxsize" ]; then \
    echo "error: $$printname too large ($$total > [$(2) - $$reserve])"; \
    false; \
  elif [ "$$total" -gt $$((maxsize - 32768)) ]; then \
    echo "WARNING: $$printname approaching size limit ($$total now; limit $$maxsize)"; \
  fi \
 , \
  true \
 )
endef

# Like assert-max-file-size, but the second argument is a partition
# size, which we'll convert to a max image size before checking it
# against the files.
#
# $(1): The file(s) to check (often $@)
# $(2): The partition size.
define assert-max-image-size
$(if $(2), \
  $(call assert-max-file-size,$(1),$(call image-size-from-data-size,$(2))))
endef


###########################################################
## Define device-specific radio files
###########################################################
INSTALLED_RADIOIMAGE_TARGET :=

# Copy a radio image file to the output location, and add it to
# INSTALLED_RADIOIMAGE_TARGET.
# $(1): filename
define add-radio-file
  $(eval $(call add-radio-file-internal,$(1),$(notdir $(1))))
endef
define add-radio-file-internal
INSTALLED_RADIOIMAGE_TARGET += $$(PRODUCT_OUT)/$(2)
$$(PRODUCT_OUT)/$(2) : $$(LOCAL_PATH)/$(1) | $$(ACP)
	$$(transform-prebuilt-to-target)
endef

# Version of add-radio-file that also arranges for the version of the
# file to be checked against the contents of
# $(TARGET_BOARD_INFO_FILE).
# $(1): filename
# $(2): name of version variable in board-info (eg, "version-baseband")
define add-radio-file-checked
  $(eval $(call add-radio-file-checked-internal,$(1),$(notdir $(1)),$(2)))
endef
define add-radio-file-checked-internal
INSTALLED_RADIOIMAGE_TARGET += $$(PRODUCT_OUT)/$(2)
BOARD_INFO_CHECK += $(3):$(LOCAL_PATH)/$(1)
$$(PRODUCT_OUT)/$(2) : $$(LOCAL_PATH)/$(1) | $$(ACP)
	$$(transform-prebuilt-to-target)
endef


###########################################################
# Override the package defined in $(1), setting the
# variables listed below differently.
#
#  $(1): The makefile to override (relative to the source
#        tree root)
#  $(2): Old LOCAL_PACKAGE_NAME value.
#  $(3): New LOCAL_PACKAGE_NAME value.
#  $(4): New LOCAL_MANIFEST_PACKAGE_NAME value.
#  $(5): New LOCAL_CERTIFICATE value.
#  $(6): New LOCAL_INSTRUMENTATION_FOR value.
#  $(7): New LOCAL_MANIFEST_INSTRUMENTATION_FOR value.
#
# Note that LOCAL_PACKAGE_OVERRIDES is NOT cleared in
# clear_vars.mk.
###########################################################
define inherit-package
  $(eval $(call inherit-package-internal,$(1),$(2),$(3),$(4),$(5),$(6),$(7)))
endef

define inherit-package-internal
  LOCAL_PACKAGE_OVERRIDES \
      := $(strip $(1))||$(strip $(2))||$(strip $(3))||$(strip $(4))||&&$(strip $(5))||&&$(strip $(6))||&&$(strip $(7)) $(LOCAL_PACKAGE_OVERRIDES)
  include $(1)
  LOCAL_PACKAGE_OVERRIDES \
      := $(wordlist 1,$(words $(LOCAL_PACKAGE_OVERRIDES)), $(LOCAL_PACKAGE_OVERRIDES))
endef

# To be used with inherit-package above
# Evalutes to true if the package was overridden
define set-inherited-package-variables
$(strip $(call set-inherited-package-variables-internal))
endef

define keep-or-override
$(eval $(1) := $(if $(2),$(2),$($(1))))
endef

define set-inherited-package-variables-internal
  $(eval _o := $(subst ||, ,$(lastword $(LOCAL_PACKAGE_OVERRIDES))))
  $(eval _n := $(subst ||, ,$(firstword $(LOCAL_PACKAGE_OVERRIDES))))
  $(if $(filter $(word 2,$(_n)),$(LOCAL_PACKAGE_NAME)), \
    $(eval LOCAL_PACKAGE_NAME := $(word 3,$(_o))) \
    $(eval LOCAL_MANIFEST_PACKAGE_NAME := $(word 4,$(_o))) \
    $(call keep-or-override,LOCAL_CERTIFICATE,$(patsubst &&%,%,$(word 5,$(_o)))) \
    $(call keep-or-override,LOCAL_INSTRUMENTATION_FOR,$(patsubst &&%,%,$(word 6,$(_o)))) \
    $(call keep-or-override,LOCAL_MANIFEST_INSTRUMENTATION_FOR,$(patsubst &&%,%,$(word 7,$(_o)))) \
    $(eval LOCAL_OVERRIDES_PACKAGES := $(sort $(LOCAL_OVERRIDES_PACKAGES) $(word 2,$(_o)))) \
    true \
  ,)
endef

###########################################################
## API Check
###########################################################

# eval this to define a rule that runs apicheck.
#
# Args:
#    $(1)  target
#    $(2)  stable api file
#    $(3)  api file to be tested
#    $(4)  stable removed api file
#    $(5)  removed api file to be tested
#    $(6)  arguments for apicheck
#    $(7)  command to run if apicheck failed
#    $(8)  target dependent on this api check
#    $(9)  additional dependencies
define check-api
$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(strip $(1))-timestamp: $(2) $(3) $(4) $(APICHECK) $(9)
	@echo "Checking API:" $(1)
	$(hide) ( $(APICHECK_COMMAND) $(6) $(2) $(3) $(4) $(5) || ( $(7) ; exit 38 ) )
	$(hide) mkdir -p $$(dir $$@)
	$(hide) touch $$@
$(8): $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/$(strip $(1))-timestamp
endef

## Whether to build from source if prebuilt alternative exists
###########################################################
# $(1): module name
# $(2): LOCAL_PATH
# Expands to empty string if not from source.
ifeq (true,$(ANDROID_BUILD_FROM_SOURCE))
define if-build-from-source
true
endef
else
define if-build-from-source
$(if $(filter $(ANDROID_NO_PREBUILT_MODULES),$(1))$(filter \
    $(addsuffix %,$(ANDROID_NO_PREBUILT_PATHS)),$(2)),true)
endef
endif

# Include makefile $(1) if build from source for module $(2)
# $(1): the makefile to include
# $(2): module name
# $(3): LOCAL_PATH
define include-if-build-from-source
$(if $(call if-build-from-source,$(2),$(3)),$(eval include $(1)))
endef

# Return the arch for the source file of a prebuilt
# Return "none" if no matching arch found and return empty
# if the input is empty, so the result can be passed to
# LOCAL_MODULE_TARGET_ARCH.
# $(1) the list of archs supported by the prebuilt
define get-prebuilt-src-arch
$(strip $(if $(filter $(TARGET_ARCH),$(1)),$(TARGET_ARCH),\
  $(if $(filter $(TARGET_2ND_ARCH),$(1)),$(TARGET_2ND_ARCH),$(if $(1),none))))
endef

###########################################################
## Other includes
###########################################################

# -----------------------------------------------------------------
# Rules and functions to help copy important files to DIST_DIR
# when requested.
include $(BUILD_SYSTEM)/distdir.mk

# Include any vendor specific definitions.mk file
-include $(TOPDIR)vendor/*/build/core/definitions.mk
-include $(TOPDIR)device/*/build/core/definitions.mk
-include $(TOPDIR)product/*/build/core/definitions.mk

# broken:
#	$(foreach file,$^,$(if $(findstring,.a,$(suffix $file)),-l$(file),$(file)))

###########################################################
## Misc notes
###########################################################

#DEPDIR = .deps
#df = $(DEPDIR)/$(*F)

#SRCS = foo.c bar.c ...

#%.o : %.c
#	@$(MAKEDEPEND); \
#	  cp $(df).d $(df).P; \
#	  sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
#	      -e '/^$$/ d' -e 's/$$/ :/' < $(df).d >> $(df).P; \
#	  rm -f $(df).d
#	$(COMPILE.c) -o $@ $<

#-include $(SRCS:%.c=$(DEPDIR)/%.P)


#%.o : %.c
#	$(COMPILE.c) -MD -o $@ $<
#	@cp $*.d $*.P; \
#	  sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
#	      -e '/^$$/ d' -e 's/$$/ :/' < $*.d >> $*.P; \
#	  rm -f $*.d
