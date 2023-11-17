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

# The relative paths of the non-module targets in the system.
ALL_NON_MODULES:=
NON_MODULES_WITHOUT_LICENSE_METADATA:=

# List of copied targets that need license metadata copied.
ALL_COPIED_TARGETS:=

# Full paths to targets that should be added to the "make droid"
# set of installed targets.
ALL_DEFAULT_INSTALLED_MODULES:=

# Full path to all asm, C, C++, lex and yacc generated C files.
# These all have an order-only dependency on the copied headers
ALL_C_CPP_ETC_OBJECTS:=

# These files go into the SDK
ALL_SDK_FILES:=

# Files for dalvik.  This is often build without building the rest of the OS.
INTERNAL_DALVIK_MODULES:=

# All findbugs xml files
ALL_FINDBUGS_FILES:=

# Packages with certificate violation
CERTIFICATE_VIOLATION_MODULES :=

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

# All installed initrc files
ALL_INIT_RC_INSTALLED_PAIRS :=

# All installed vintf manifest fragments for a partition at
ALL_VINTF_MANIFEST_FRAGMENTS_LIST:=

# All tests that should be skipped in presubmit check.
ALL_DISABLED_PRESUBMIT_TESTS :=

# All compatibility suites mentioned in LOCAL_COMPATIBILITY_SUITE
ALL_COMPATIBILITY_SUITES :=

# All compatibility suite files to dist.
ALL_COMPATIBILITY_DIST_FILES :=

# All LINK_TYPE entries
ALL_LINK_TYPES :=

# All exported/imported include entries
EXPORTS_LIST :=

# All modules already converted to Soong
SOONG_ALREADY_CONV :=

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

define boolean-not
$(if $(filter true,$(1)),,true)
endef

###########################################################
## Rule for touching GCNO files.
###########################################################
define gcno-touch-rule
$(2): $(1)
	touch -c $$@
endef

###########################################################

###########################################################
## Retrieve the directory of the current makefile
## Must be called before including any other makefile!!
###########################################################

# Figure out where we are.
define my-dir
$(strip \
  $(eval LOCAL_MODULE_MAKEFILE := $$(lastword $$(MAKEFILE_LIST))) \
  $(if $(filter $(BUILD_SYSTEM)/% $(OUT_DIR)/%,$(LOCAL_MODULE_MAKEFILE)), \
    $(error my-dir must be called before including any other makefile.) \
   , \
    $(patsubst %/,%,$(dir $(LOCAL_MODULE_MAKEFILE))) \
   ) \
 )
endef


###########################################################
## Retrieve a list of all makefiles immediately below some directory
###########################################################

define all-makefiles-under
$(wildcard $(1)/*/Android.mk)
endef

###########################################################
## Look under a directory for makefiles that don't have parent
## makefiles.
###########################################################

# $(1): directory to search under
# Ignores $(1)/Android.mk
define first-makefiles-under
$(shell build/make/tools/findleaves.py $(FIND_LEAVES_EXCLUDES) \
        --mindepth=2 $(addprefix --dir=,$(1)) Android.mk)
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
$(wildcard $(addsuffix /Android.mk, $(addprefix $(call my-dir)/,$(1))))
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
$(call find-subdir-files,$(1) \( -name "*.rscript" -or -name "*.fs" \) -and -not -name ".*")
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
  $(shell if [ -d $(1) ] ; then cd $(1) ; find -L ./ -not -name '.*' -and -type f ; fi)), \
  $(warning Empty argument supplied to find-subdir-assets in $(LOCAL_PATH)) \
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
## Find test data in a form required by LOCAL_TEST_DATA
## $(1): the base dir, relative to the root of the source tree.
## $(2): the file name pattern to be passed to find as "-name"
## $(3): a list of subdirs of the base dir
###########################################################

define find-test-data-in-subdirs
$(foreach f,$(sort $(patsubst ./%,%, \
  $(shell cd $(1) ; \
          find -L $(3) -type f -and -name $(2) -and -not -name ".*") \
)),$(1):$(f))
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
## Sometimes a notice dependency will reference an unadorned
## module name that only appears in ALL_MODULES adorned with
## an ARCH suffix or a `host_cross_` prefix.
##
## After all of the modules are processed in base_rules.mk,
## replace all such dependencies with every matching adorned
## module name.
###########################################################

define fix-notice-deps
$(strip \
  $(eval _all_module_refs := \
    $(sort \
      $(foreach m,$(sort $(ALL_MODULES)), \
        $(call word-colon,1,$(ALL_MODULES.$(m).NOTICE_DEPS)) \
      ) \
    ) \
  ) \
  $(foreach m, $(_all_module_refs), \
    $(eval _lookup.$(m) := \
      $(sort \
        $(if $(strip $(ALL_MODULES.$(m).PATH)), \
          $(m), \
          $(filter $(m)_32 $(m)_64 host_cross_$(m) host_cross_$(m)_32 host_cross_$(m)_64, $(ALL_MODULES)) \
        ) \
      ) \
    ) \
  ) \
  $(foreach m, $(ALL_MODULES), \
    $(eval ALL_MODULES.$(m).NOTICE_DEPS := \
      $(sort \
         $(foreach d,$(sort $(ALL_MODULES.$(m).NOTICE_DEPS)), \
           $(foreach n,$(_lookup.$(call word-colon,1,$(d))),$(n):$(call wordlist-colon,2,9999,$(d))) \
        ) \
      ) \
    ) \
  ) \
)
endef

###########################################################
## Target directory for license metadata files.
###########################################################
define license-metadata-dir
$(call generated-sources-dir-for,META,lic,$(filter-out $(PRODUCT_OUT)%,$(1)))
endef

TARGETS_MISSING_LICENSE_METADATA:=

###########################################################
# License metadata targets corresponding to targets in $(1)
###########################################################
define corresponding-license-metadata
$(strip $(filter-out 0p,$(foreach target, $(sort $(1)), \
  $(if $(strip $(ALL_MODULES.$(target).META_LIC)), \
    $(ALL_MODULES.$(target).META_LIC), \
    $(if $(strip $(ALL_TARGETS.$(target).META_LIC)), \
      $(ALL_TARGETS.$(target).META_LIC), \
      $(eval TARGETS_MISSING_LICENSE_METADATA += $(target)) \
    ) \
  ) \
)))
endef

###########################################################
## Record a target $(1) copied from another target(s) $(2) that will need
## license metadata.
###########################################################
define declare-copy-target-license-metadata
$(strip $(if $(filter $(OUT_DIR)%,$(2)),\
  $(eval _tgt:=$(strip $(1)))\
  $(eval ALL_COPIED_TARGETS.$(_tgt).SOURCES := $(sort $(ALL_COPIED_TARGETS.$(_tgt).SOURCES) $(filter $(OUT_DIR)%,$(2))))\
  $(eval ALL_COPIED_TARGETS += $(_tgt))))
endef

###########################################################
## License metadata build rule for my_register_name $(1)
###########################################################
define license-metadata-rule
$(foreach meta_lic, $(ALL_MODULES.$(1).DELAYED_META_LIC),$(call _license-metadata-rule,$(1),$(meta_lic)))
endef

$(KATI_obsolete_var notice-rule, This function has been removed)

define _license-metadata-rule
$(strip $(eval _srcs := $(strip $(foreach d,$(ALL_MODULES.$(1).NOTICE_DEPS),$(if $(strip $(ALL_MODULES.$(call word-colon,1,$(d)).INSTALLED)), $(ALL_MODULES.$(call word-colon,1,$(d)).INSTALLED),$(if $(strip $(ALL_MODULES.$(call word-colon,1,$(d)).BUILT)), $(ALL_MODULES.$(call word-colon,1,$(d)).BUILT), $(call word-colon,1,$d)))))))
$(strip $(eval _deps := $(sort $(filter-out $(2)%,\
   $(foreach d,$(ALL_MODULES.$(1).NOTICE_DEPS),\
     $(addsuffix :$(call wordlist-colon,2,9999,$(d)), \
       $(foreach dt,$(ALL_MODULES.$(d).BUILT) $(ALL_MODULES.$(d).INSTALLED),\
         $(ALL_TARGETS.$(dt).META_LIC))))))))
$(strip $(eval _notices := $(sort $(ALL_MODULES.$(1).NOTICES))))
$(strip $(eval _tgts := $(sort $(ALL_MODULES.$(1).BUILT))))
$(strip $(eval _inst := $(sort $(ALL_MODULES.$(1).INSTALLED))))
$(strip $(eval _path := $(sort $(ALL_MODULES.$(1).PATH))))
$(strip $(eval _map := $(strip $(foreach _m,$(sort $(ALL_MODULES.$(1).LICENSE_INSTALL_MAP)), \
  $(eval _s := $(call word-colon,1,$(_m))) \
  $(eval _d := $(call word-colon,2,$(_m))) \
  $(eval _ns := $(if $(strip $(ALL_MODULES.$(_s).INSTALLED)),$(ALL_MODULES.$(_s).INSTALLED),$(if $(strip $(ALL_MODULES.$(_s).BUILT)),$(ALL_MODULES.$(_s).BUILT),$(_s)))) \
  $(foreach ns,$(_ns),$(ns):$(_d) ) \
))))

$(2): PRIVATE_KINDS := $(sort $(ALL_MODULES.$(1).LICENSE_KINDS))
$(2): PRIVATE_CONDITIONS := $(sort $(ALL_MODULES.$(1).LICENSE_CONDITIONS))
$(2): PRIVATE_NOTICES := $(_notices)
$(2): PRIVATE_NOTICE_DEPS := $(_deps)
$(2): PRIVATE_SOURCES := $(_srcs)
$(2): PRIVATE_TARGETS := $(_tgts)
$(2): PRIVATE_INSTALLED := $(_inst)
$(2): PRIVATE_PATH := $(_path)
$(2): PRIVATE_IS_CONTAINER := $(ALL_MODULES.$(1).IS_CONTAINER)
$(2): PRIVATE_PACKAGE_NAME := $(strip $(ALL_MODULES.$(1).LICENSE_PACKAGE_NAME))
$(2): PRIVATE_INSTALL_MAP := $(_map)
$(2): PRIVATE_MODULE_NAME := $(1)
$(2): PRIVATE_MODULE_TYPE := $(ALL_MODULES.$(1).MODULE_TYPE)
$(2): PRIVATE_MODULE_CLASS := $(ALL_MODULES.$(1).MODULE_CLASS)
$(2): PRIVATE_INSTALL_MAP := $(_map)
$(2): PRIVATE_ARGUMENT_FILE := $(call intermediates-dir-for,PACKAGING,notice)/$(2)/arguments
$(2): $(BUILD_LICENSE_METADATA)
$(2) : $(foreach d,$(_deps),$(call word-colon,1,$(d))) $(foreach n,$(_notices),$(call word-colon,1,$(n)) )
	rm -f $$@
	mkdir -p $$(dir $$@)
	mkdir -p $$(dir $$(PRIVATE_ARGUMENT_FILE))
	$$(call dump-words-to-file,\
	    $$(addprefix -mn ,$$(PRIVATE_MODULE_NAME))\
	    $$(addprefix -mt ,$$(PRIVATE_MODULE_TYPE))\
	    $$(addprefix -mc ,$$(PRIVATE_MODULE_CLASS))\
	    $$(addprefix -k ,$$(PRIVATE_KINDS))\
	    $$(addprefix -c ,$$(PRIVATE_CONDITIONS))\
	    $$(addprefix -n ,$$(PRIVATE_NOTICES))\
	    $$(addprefix -d ,$$(PRIVATE_NOTICE_DEPS))\
	    $$(addprefix -s ,$$(PRIVATE_SOURCES))\
	    $$(addprefix -m ,$$(PRIVATE_INSTALL_MAP))\
	    $$(addprefix -t ,$$(PRIVATE_TARGETS))\
	    $$(addprefix -i ,$$(PRIVATE_INSTALLED))\
	    $$(addprefix -r ,$$(PRIVATE_PATH)),\
	    $$(PRIVATE_ARGUMENT_FILE))
	OUT_DIR=$(OUT_DIR) $(BUILD_LICENSE_METADATA) \
	  $$(if $$(PRIVATE_IS_CONTAINER),-is_container) \
	  -p '$$(PRIVATE_PACKAGE_NAME)' \
	  @$$(PRIVATE_ARGUMENT_FILE) \
	  -o $$@
endef


###########################################################
## License metadata build rule for non-module target $(1)
###########################################################
define non-module-license-metadata-rule
$(strip $(eval _dir := $(call license-metadata-dir,$(1))))
$(strip $(eval _tgt := $(strip $(1))))
$(strip $(eval _meta := $(call append-path,$(_dir),$(patsubst $(OUT_DIR)%,out%,$(_tgt).meta_lic))))
$(strip $(eval _deps := $(sort $(filter-out 0p: :,$(foreach d,$(strip $(ALL_NON_MODULES.$(_tgt).DEPENDENCIES)),$(ALL_TARGETS.$(call word-colon,1,$(d)).META_LIC):$(call wordlist-colon,2,9999,$(d)))))))
$(strip $(eval _notices := $(sort $(ALL_NON_MODULES.$(_tgt).NOTICES))))
$(strip $(eval _path := $(sort $(ALL_NON_MODULES.$(_tgt).PATH))))
$(strip $(eval _install_map := $(ALL_NON_MODULES.$(_tgt).ROOT_MAPPINGS)))

$(_meta): PRIVATE_KINDS := $(sort $(ALL_NON_MODULES.$(_tgt).LICENSE_KINDS))
$(_meta): PRIVATE_CONDITIONS := $(sort $(ALL_NON_MODULES.$(_tgt).LICENSE_CONDITIONS))
$(_meta): PRIVATE_NOTICES := $(_notices)
$(_meta): PRIVATE_NOTICE_DEPS := $(_deps)
$(_meta): PRIVATE_SOURCES := $(ALL_NON_MODULES.$(_tgt).DEPENDENCIES)
$(_meta): PRIVATE_TARGETS := $(_tgt)
$(_meta): PRIVATE_PATH := $(_path)
$(_meta): PRIVATE_IS_CONTAINER := $(ALL_NON_MODULES.$(_tgt).IS_CONTAINER)
$(_meta): PRIVATE_PACKAGE_NAME := $(strip $(ALL_NON_MODULES.$(_tgt).LICENSE_PACKAGE_NAME))
$(_meta): PRIVATE_INSTALL_MAP := $(strip $(_install_map))
$(_meta): PRIVATE_ARGUMENT_FILE := $(call intermediates-dir-for,PACKAGING,notice)/$(_meta)/arguments
$(_meta): $(BUILD_LICENSE_METADATA)
$(_meta) : $(foreach d,$(_deps),$(call word-colon,1,$(d))) $(foreach n,$(_notices),$(call word-colon,1,$(n)) )
	rm -f $$@
	mkdir -p $$(dir $$@)
	mkdir -p $$(dir $$(PRIVATE_ARGUMENT_FILE))
	$$(call dump-words-to-file,\
	    $$(addprefix -k ,$$(PRIVATE_KINDS))\
	    $$(addprefix -c ,$$(PRIVATE_CONDITIONS))\
	    $$(addprefix -n ,$$(PRIVATE_NOTICES))\
	    $$(addprefix -d ,$$(PRIVATE_NOTICE_DEPS))\
	    $$(addprefix -s ,$$(PRIVATE_SOURCES))\
	    $$(addprefix -m ,$$(PRIVATE_INSTALL_MAP))\
	    $$(addprefix -t ,$$(PRIVATE_TARGETS))\
	    $$(addprefix -r ,$$(PRIVATE_PATH)),\
	    $$(PRIVATE_ARGUMENT_FILE))
	OUT_DIR=$(OUT_DIR) $(BUILD_LICENSE_METADATA) \
          -mt raw -mc unknown \
	  $$(if $$(PRIVATE_IS_CONTAINER),-is_container) \
	  $$(addprefix -r ,$$(PRIVATE_PATH)) \
	  @$$(PRIVATE_ARGUMENT_FILE) \
	  -o $$@

endef

###########################################################
## Record missing dependencies for non-module target $(1)
###########################################################
define record-missing-non-module-dependencies
$(strip $(eval _tgt := $(strip $(1))))
$(strip $(foreach d,$(strip $(ALL_NON_MODULES.$(_tgt).DEPENDENCIES)), \
  $(if $(strip $(ALL_TARGETS.$(d).META_LIC)), \
    , \
    $(eval NON_MODULES_WITHOUT_LICENSE_METADATA += $(d))) \
))
endef

###########################################################
## License metadata build rule for copied target $(1)
###########################################################
define copied-target-license-metadata-rule
$(if $(strip $(ALL_TARGETS.$(1).META_LIC)),,$(call _copied-target-license-metadata-rule,$(1)))
endef

define _copied-target-license-metadata-rule
$(strip $(eval _dir := $(call license-metadata-dir,$(1))))
$(strip $(eval _meta := $(call append-path,$(_dir),$(patsubst $(OUT_DIR)%,out%,$(1).meta_lic))))
$(strip $(eval ALL_TARGETS.$(1).META_LIC:=$(_meta)))
$(strip $(eval _dep:=))
$(strip $(foreach s,$(ALL_COPIED_TARGETS.$(1).SOURCES),\
  $(eval _dmeta:=$(ALL_TARGETS.$(s).META_LIC))\
  $(if $(filter-out 0p,$(_dep)),\
      $(if $(filter-out $(_dep),$(_dmeta)),$(error cannot copy target from multiple modules: $(1) from $(_dep) and $(_dmeta))),\
      $(eval _dep:=$(_dmeta)))))
$(if $(filter 0p,$(_dep)),$(eval ALL_TARGETS.$(1).META_LIC:=0p))
$(strip $(if $(strip $(_dep)),,$(error cannot copy target from unknown module: $(1) from $(ALL_COPIED_TARGETS.$(1).SOURCES))))

ifneq (0p,$(ALL_TARGETS.$(1).META_LIC))
$(_meta): PRIVATE_DEST_TARGET := $(1)
$(_meta): PRIVATE_SOURCE_TARGETS := $(ALL_COPIED_TARGETS.$(1).SOURCES)
$(_meta): PRIVATE_SOURCE_METADATA := $(_dep)
$(_meta): PRIVATE_ARGUMENT_FILE := $(call intermediates-dir-for,PACKAGING,copynotice)/$(_meta)/arguments
$(_meta) : $(_dep) $(COPY_LICENSE_METADATA)
	rm -f $$@
	mkdir -p $$(dir $$@)
	mkdir -p $$(dir $$(PRIVATE_ARGUMENT_FILE))
	$$(call dump-words-to-file,\
	    $$(addprefix -i ,$$(PRIVATE_DEST_TARGET))\
	    $$(addprefix -s ,$$(PRIVATE_SOURCE_TARGETS))\
	    $$(addprefix -d ,$$(PRIVATE_SOURCE_METADATA)),\
	    $$(PRIVATE_ARGUMENT_FILE))
	OUT_DIR=$(OUT_DIR) $(COPY_LICENSE_METADATA) \
	  @$$(PRIVATE_ARGUMENT_FILE) \
	  -o $$@

endif

$(eval _dep:=)
$(eval _dmeta:=)
$(eval _meta:=)
$(eval _dir:=)
endef

###########################################################
## Declare the license metadata for non-module target $(1).
##
## $(2) -- license kinds e.g. SPDX-license-identifier-Apache-2.0
## $(3) -- license conditions e.g. notice by_exception_only
## $(4) -- license text filenames (notices)
## $(5) -- package name
## $(6) -- project path
###########################################################
define declare-license-metadata
$(strip \
  $(eval _tgt := $(subst //,/,$(strip $(1)))) \
  $(eval ALL_NON_MODULES += $(_tgt)) \
  $(eval ALL_TARGETS.$(_tgt).META_LIC := $(call license-metadata-dir,$(1))/$(patsubst $(OUT_DIR)%,out%,$(_tgt)).meta_lic) \
  $(eval ALL_NON_MODULES.$(_tgt).LICENSE_KINDS := $(strip $(2))) \
  $(eval ALL_NON_MODULES.$(_tgt).LICENSE_CONDITIONS := $(strip $(3))) \
  $(eval ALL_NON_MODULES.$(_tgt).NOTICES := $(strip $(4))) \
  $(eval ALL_NON_MODULES.$(_tgt).LICENSE_PACKAGE_NAME := $(strip $(5))) \
  $(eval ALL_NON_MODULES.$(_tgt).PATH := $(strip $(6))) \
)
endef

###########################################################
## Declare that non-module targets copied from project $(1) and
## optionally ending in $(2) have the following license
## metadata:
##
## $(3) -- license kinds e.g. SPDX-license-identifier-Apache-2.0
## $(4) -- license conditions e.g. notice by_exception_only
## $(5) -- license text filenames (notices)
## $(6) -- package name
###########################################################
define declare-copy-files-license-metadata
$(strip \
  $(foreach _pair,$(filter $(1)%$(2),$(PRODUCT_COPY_FILES)),$(eval $(call declare-license-metadata,$(PRODUCT_OUT)/$(call word-colon,2,$(_pair)),$(3),$(4),$(5),$(6),$(1)))) \
)
endef

###########################################################
## Declare the license metadata for non-module container-type target $(1).
##
## Container-type targets are targets like .zip files that
## merely aggregate other files.
##
## $(2) -- license kinds e.g. SPDX-license-identifier-Apache-2.0
## $(3) -- license conditions e.g. notice by_exception_only
## $(4) -- license text filenames (notices)
## $(5) -- package name
## $(6) -- project path
###########################################################
define declare-container-license-metadata
$(strip \
  $(eval _tgt := $(subst //,/,$(strip $(1)))) \
  $(eval ALL_NON_MODULES += $(_tgt)) \
  $(eval ALL_TARGETS.$(_tgt).META_LIC := $(call license-metadata-dir,$(1))/$(patsubst $(OUT_DIR)%,out%,$(_tgt)).meta_lic) \
  $(eval ALL_NON_MODULES.$(_tgt).LICENSE_KINDS := $(strip $(2))) \
  $(eval ALL_NON_MODULES.$(_tgt).LICENSE_CONDITIONS := $(strip $(3))) \
  $(eval ALL_NON_MODULES.$(_tgt).NOTICES := $(strip $(4))) \
  $(eval ALL_NON_MODULES.$(_tgt).LICENSE_PACKAGE_NAME := $(strip $(5))) \
  $(eval ALL_NON_MODULES.$(_tgt).PATH := $(strip $(6))) \
  $(eval ALL_NON_MODULES.$(_tgt).IS_CONTAINER := true) \
)
endef

###########################################################
## Declare that non-module target $(1) is a non-copyrightable file.
##
## e.g. an information-only file merely listing other files.
###########################################################
define declare-0p-target
$(strip \
  $(eval _tgt := $(subst //,/,$(strip $(1)))) \
  $(eval ALL_0P_TARGETS += $(_tgt)) \
)
endef

###########################################################
## Declare that non-module targets copied from project $(1) and
## optionally ending in $(2) are non-copyrightable files.
##
## e.g. an information-only file merely listing other files.
###########################################################
define declare-0p-copy-files
$(strip \
  $(foreach _pair,$(filter $(1)%$(2),$(PRODUCT_COPY_FILES)),$(eval $(call declare-0p-target,$(PRODUCT_OUT)/$(call word-colon,2,$(_pair))))) \
)
endef

###########################################################
## Declare non-module target $(1) to have a first-party license
## (Android Apache 2.0)
##
## $(2) -- project path
###########################################################
define declare-1p-target
$(call declare-license-metadata,$(1),SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,Android,$(2))
endef

###########################################################
## Declare that non-module targets copied from project $(1) and
## optionally ending in $(2) are first-party licensed
## (Android Apache 2.0)
###########################################################
define declare-1p-copy-files
$(foreach _pair,$(filter $(1)%$(2),$(PRODUCT_COPY_FILES)),$(call declare-1p-target,$(PRODUCT_OUT)/$(call word-colon,2,$(_pair)),$(1)))
endef

###########################################################
## Declare non-module container-type target $(1) to have a
## first-party license (Android Apache 2.0).
##
## Container-type targets are targets like .zip files that
## merely aggregate other files.
##
## $92) -- project path
###########################################################
define declare-1p-container
$(call declare-container-license-metadata,$(1),SPDX-license-identifier-Apache-2.0,notice,build/soong/licenses/LICENSE,Android,$(2))
endef

###########################################################
## Declare license dependencies $(2) with optional colon-separated
## annotations for non-module target $(1)
###########################################################
define declare-license-deps
$(strip \
  $(eval _tgt := $(subst //,/,$(strip $(1)))) \
  $(eval ALL_NON_MODULES += $(_tgt)) \
  $(eval ALL_TARGETS.$(_tgt).META_LIC := $(call license-metadata-dir,$(1))/$(patsubst $(OUT_DIR)%,out%,$(_tgt)).meta_lic) \
  $(eval ALL_NON_MODULES.$(_tgt).DEPENDENCIES := $(strip $(ALL_NON_MODULES.$(_tgt).DEPENDENCIES) $(2))) \
)
endef

###########################################################
## Declare license dependencies $(2) with optional colon-separated
## annotations for non-module container-type target $(1)
##
## Container-type targets are targets like .zip files that
## merely aggregate other files.
##
## $(3) -- root mappings space-separated source:target
###########################################################
define declare-container-license-deps
$(strip \
  $(eval _tgt := $(subst //,/,$(strip $(1)))) \
  $(eval ALL_NON_MODULES += $(_tgt)) \
  $(eval ALL_TARGETS.$(_tgt).META_LIC := $(call license-metadata-dir,$(1))/$(patsubst $(OUT_DIR)%,out%,$(_tgt)).meta_lic) \
  $(eval ALL_NON_MODULES.$(_tgt).DEPENDENCIES := $(strip $(ALL_NON_MODULES.$(_tgt).DEPENDENCIES) $(2))) \
  $(eval ALL_NON_MODULES.$(_tgt).IS_CONTAINER := true) \
  $(eval ALL_NON_MODULES.$(_tgt).ROOT_MAPPINGS := $(strip $(ALL_NON_MODULES.$(_tgt).ROOT_MAPPINGS) $(3))) \
)
endef

###########################################################
## Declares the rule to report targets with no license metadata.
###########################################################
define report-missing-licenses-rule
.PHONY: reportmissinglicenses
reportmissinglicenses: PRIVATE_NON_MODULES:=$(sort $(NON_MODULES_WITHOUT_LICENSE_METADATA) $(TARGETS_MISSING_LICENSE_METADATA))
reportmissinglicenses: PRIVATE_COPIED_FILES:=$(sort $(filter $(NON_MODULES_WITHOUT_LICENSE_METADATA) $(TARGETS_MISSING_LICENSE_METADATA),\
  $(foreach _pair,$(PRODUCT_COPY_FILES), $(PRODUCT_OUT)/$(call word-colon,2,$(_pair)))))
reportmissinglicenses:
	@echo Reporting $$(words $$(PRIVATE_NON_MODULES)) targets without license metadata
	$$(foreach t,$$(PRIVATE_NON_MODULES),if ! [ -h $$(t) ]; then echo No license metadata for $$(t) >&2; fi;)
	$$(foreach t,$$(PRIVATE_COPIED_FILES),if ! [ -h $$(t) ]; then echo No license metadata for copied file $$(t) >&2; fi;)
	echo $$(words $$(PRIVATE_NON_MODULES)) targets missing license metadata >&2

endef


###########################################################
# Returns the unique list of built license metadata files.
###########################################################
define all-license-metadata
$(sort \
  $(foreach t,$(ALL_NON_MODULES),$(if $(filter 0p,$(ALL_TARGETS.$(t).META_LIC)),, $(ALL_TARGETS.$(t).META_LIC))) \
  $(foreach m,$(ALL_MODULES), $(ALL_MODULES.$(m).META_LIC)) \
)
endef

###########################################################
# Declares the rule to report all library names used in any notice files.
###########################################################
define report-all-notice-library-names-rule
$(strip $(eval _all := $(call all-license-metadata)))

.PHONY: reportallnoticelibrarynames
reportallnoticelibrarynames: PRIVATE_LIST_FILE := $(call license-metadata-dir,COMMON)/filelist
reportallnoticelibrarynames: | $(COMPLIANCENOTICE_SHIPPEDLIBS)
reportallnoticelibrarynames: $(_all)
	@echo Reporting notice library names for at least $$(words $(_all)) license metadata files
	$(hide) rm -f $$(PRIVATE_LIST_FILE)
	$(hide) mkdir -p $$(dir $$(PRIVATE_LIST_FILE))
	$(hide) find out -name '*meta_lic' -type f -printf '"%p"\n' >$$(PRIVATE_LIST_FILE)
	OUT_DIR=$(OUT_DIR) $(COMPLIANCENOTICE_SHIPPEDLIBS) @$$(PRIVATE_LIST_FILE)
endef

###########################################################
# Declares the rule to build all license metadata.
###########################################################
define build-all-license-metadata-rule
$(strip $(eval _all := $(call all-license-metadata)))

.PHONY: alllicensemetadata
alllicensemetadata: $(_all)
	@echo Building all $(words $(_all)) license metadata files
endef


###########################################################
## Declares a license metadata build rule for ALL_MODULES
###########################################################
define build-license-metadata
$(strip \
  $(foreach t,$(sort $(ALL_0P_TARGETS)), \
    $(eval ALL_TARGETS.$(t).META_LIC := 0p) \
  ) \
  $(foreach t,$(sort $(ALL_COPIED_TARGETS)),$(eval $(call copied-target-license-metadata-rule,$(t)))) \
  $(foreach t,$(sort $(ALL_NON_MODULES)),$(eval $(call non-module-license-metadata-rule,$(t)))) \
  $(foreach m,$(sort $(ALL_MODULES)),$(eval $(call license-metadata-rule,$(m)))) \
  $(eval $(call build-all-license-metadata-rule)))
endef

###########################################################
## Returns correct _idfPrefix from the list:
##   { HOST, HOST_CROSS, TARGET }
###########################################################
# the following rules checked in order:
# ($1 is in {HOST_CROSS} => $1;
# ($1 is empty) => TARGET;
# ($2 is not empty) => HOST_CROSS;
# => HOST;
define find-idf-prefix
$(strip \
    $(eval _idf_pfx_:=$(strip $(filter HOST_CROSS,$(1)))) \
    $(eval _idf_pfx_:=$(if $(strip $(1)),$(if $(_idf_pfx_),$(_idf_pfx_),$(if $(strip $(2)),HOST_CROSS,HOST)),TARGET)) \
    $(_idf_pfx_)
)
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
# $(3): { HOST, HOST_CROSS, <empty (TARGET)>, <other non-empty (HOST)> }
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
    $(eval _idfPrefix := $(call find-idf-prefix,$(3),$(6))) \
    $(eval _idf2ndArchPrefix := $(if $(strip $(5)),$(TARGET_2ND_ARCH_VAR_PREFIX))) \
    $(if $(filter $(_idfPrefix)_$(_idfClass),$(COMMON_MODULE_CLASSES))$(4), \
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
    $(call intermediates-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(if $(strip $(LOCAL_IS_HOST_MODULE)),HOST),$(1),$(2),$(3)) \
)
endef

# Uses LOCAL_MODULE_CLASS, LOCAL_MODULE, and LOCAL_IS_HOST_MODULE
# to determine the intermediates directory.
#
# $(1): if non-empty, force the intermediates to be COMMON
# $(2): if non-empty, force the intermediates to be for the 2nd arch
# $(3): if non-empty, force the intermediates to be for the host cross os
define local-meta-intermediates-dir
$(strip \
    $(if $(strip $(LOCAL_MODULE_CLASS)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined before call to local-meta-intermediates-dir)) \
    $(if $(strip $(LOCAL_MODULE)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE not defined before call to local-meta-intermediates-dir)) \
    $(call intermediates-dir-for,META$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(if $(strip $(LOCAL_IS_HOST_MODULE)),HOST),$(1),$(2),$(3)) \
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
# $(3): { HOST, HOST_CROSS, <empty (TARGET)>, <other non-empty (HOST)> }
# $(4): if non-empty, force the generated sources to be COMMON
define generated-sources-dir-for
$(strip \
    $(eval _idfClass := $(strip $(1))) \
    $(if $(_idfClass),, \
        $(error $(LOCAL_PATH): Class not defined in call to generated-sources-dir-for)) \
    $(eval _idfName := $(strip $(2))) \
    $(if $(_idfName),, \
        $(error $(LOCAL_PATH): Name not defined in call to generated-sources-dir-for)) \
    $(eval _idfPrefix := $(call find-idf-prefix,$(3),)) \
    $(if $(filter $(_idfPrefix)_$(_idfClass),$(COMMON_MODULE_CLASSES))$(4), \
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
    $(call generated-sources-dir-for,$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(if $(strip $(LOCAL_IS_HOST_MODULE)),HOST),$(1)) \
)
endef

###########################################################
## The packaging directory for a module.  Similar to intermedates, but
## in a location that will be wiped by an m installclean.
###########################################################

# $(1): subdir in PACKAGING
# $(2): target class, like "APPS"
# $(3): target name, like "NotePad"
# $(4): { HOST, HOST_CROSS, <empty (TARGET)>, <other non-empty (HOST)> }
define packaging-dir-for
$(strip \
    $(eval _pdfClass := $(strip $(2))) \
    $(if $(_pdfClass),, \
        $(error $(LOCAL_PATH): Class not defined in call to generated-sources-dir-for)) \
    $(eval _pdfName := $(strip $(3))) \
    $(if $(_pdfName),, \
        $(error $(LOCAL_PATH): Name not defined in call to generated-sources-dir-for)) \
    $(call intermediates-dir-for,PACKAGING,$(1),$(4))/$(_pdfClass)/$(_pdfName)_intermediates \
)
endef

# Uses LOCAL_MODULE_CLASS, LOCAL_MODULE, and LOCAL_IS_HOST_MODULE
# to determine the packaging directory.
#
# $(1): subdir in PACKAGING
define local-packaging-dir
$(strip \
    $(if $(strip $(LOCAL_MODULE_CLASS)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE_CLASS not defined before call to local-generated-sources-dir)) \
    $(if $(strip $(LOCAL_MODULE)),, \
        $(error $(LOCAL_PATH): LOCAL_MODULE not defined before call to local-generated-sources-dir)) \
    $(call packaging-dir-for,$(1),$(LOCAL_MODULE_CLASS),$(LOCAL_MODULE),$(if $(strip $(LOCAL_IS_HOST_MODULE)),HOST)) \
)
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
## into the list of files that are built *for the target* for those modules.
## NOTE: this won't return reliable results until after all
## sub-makefiles have been included.
## $(1): target list
###########################################################

define module-target-built-files
$(foreach module,$(1),$(ALL_MODULES.$(module).TARGET_BUILT))
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
$(foreach module,$(1),$(if $(filter $(module),$(JAVA_SDK_LIBRARIES)),\
$(call java-lib-files,$(module).stubs),$(ALL_MODULES.$(module).STUBS)))
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

# Get the jar files (you can pass to "javac -classpath") of static or shared
# Java libraries that you want to link against.
# $(1): library name list
# $(2): Non-empty if IS_HOST_MODULE
define java-lib-files
$(foreach lib,$(1),$(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),$(2),COMMON)/classes.jar)
endef

# Get the header jar files (you can pass to "javac -classpath") of static or shared
# Java libraries that you want to link against.
# $(1): library name list
# $(2): Non-empty if IS_HOST_MODULE
ifneq ($(TURBINE_ENABLED),false)
define java-lib-header-files
$(foreach lib,$(1),$(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),$(2),COMMON)/classes-header.jar)
endef
else
define java-lib-header-files
$(call java-lib-files,$(1),$(2))
endef
endif

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

# Get the jar files (you can pass to "javac -classpath") of static or shared
# APK libraries that you want to link against.
# $(1): library name list
define app-lib-files
$(foreach lib,$(1),$(call intermediates-dir-for,APPS,$(lib),,COMMON)/classes.jar)
endef

# Get the header jar files (you can pass to "javac -classpath") of static or shared
# APK libraries that you want to link against.
# $(1): library name list
ifneq ($(TURBINE_ENABLED),false)
define app-lib-header-files
$(foreach lib,$(1),$(call intermediates-dir-for,APPS,$(lib),,COMMON)/classes-header.jar)
endef
else
define app-lib-header-files
$(call app-lib-files,$(1))
endef
endif

# Get the exported-sdk-libs files which collectively give you the list of exported java sdk
# lib names that are (transitively) exported from the given set of java libs
# $(1): library name list
define exported-sdk-libs-files
$(foreach lib,$(1),$(call intermediates-dir-for,JAVA_LIBRARIES,$(lib),,COMMON)/exported-sdk-libs)
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
## Color-coded warnings and errors
## Use echo-(warning|error) in a build rule
## Use pretty-(warning|error) instead of $(warning)/$(error)
###########################################################
ESC_BOLD := \033[1m
ESC_WARNING := \033[35m
ESC_ERROR := \033[31m
ESC_RESET := \033[0m

# $(1): path (and optionally line) information
# $(2): message to print
define echo-warning
echo -e "$(ESC_BOLD)$(1): $(ESC_WARNING)warning:$(ESC_RESET)$(ESC_BOLD)" '$(subst ','\'',$(2))'  "$(ESC_RESET)" >&2
endef

# $(1): path (and optionally line) information
# $(2): message to print
define echo-error
echo -e "$(ESC_BOLD)$(1): $(ESC_ERROR)error:$(ESC_RESET)$(ESC_BOLD)" '$(subst ','\'',$(2))'  "$(ESC_RESET)" >&2
endef

###########################################################
## Legacy showcommands compatibility
###########################################################

define pretty
@echo $1
endef

###########################################################
## Commands for including the dependency files the compiler generates
###########################################################
# $(1): the .P file
# $(2): the main build target
define include-depfile
$(eval $(2) : .KATI_DEPFILE := $1)
endef

# $(1): object files
define include-depfiles-for-objs
$(foreach obj, $(1), $(call include-depfile, $(obj:%.o=%.d), $(obj)))
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
M4=$(M4) $(LEX) -o$@ $<
endef

###########################################################
## Commands for running yacc
##
###########################################################

define transform-y-to-c-or-cpp
@echo "Yacc: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
M4=$(M4) $(YACC) $(PRIVATE_YACCFLAGS) \
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

# b/37755219
RS_CC_ASAN_OPTIONS := ASAN_OPTIONS=detect_leaks=0:detect_container_overflow=0

define transform-renderscripts-to-java-and-bc
@echo "RenderScript: $(PRIVATE_MODULE) <= $(PRIVATE_RS_SOURCE_FILES)"
$(hide) rm -rf $(PRIVATE_RS_OUTPUT_DIR)
$(hide) mkdir -p $(PRIVATE_RS_OUTPUT_DIR)/res/raw
$(hide) mkdir -p $(PRIVATE_RS_OUTPUT_DIR)/src
$(hide) $(RS_CC_ASAN_OPTIONS) $(PRIVATE_RS_CC) \
  -o $(PRIVATE_RS_OUTPUT_DIR)/res/raw \
  -p $(PRIVATE_RS_OUTPUT_DIR)/src \
  -d $(PRIVATE_RS_OUTPUT_DIR) \
  -a $@ -MD \
  $(addprefix -target-api , $(PRIVATE_RS_TARGET_API)) \
  $(PRIVATE_RS_FLAGS) \
  $(foreach inc,$(PRIVATE_RS_INCLUDES),$(addprefix -I , $(inc))) \
  $(PRIVATE_RS_SOURCE_FILES)
$(SOONG_ZIP) -o $@ -C $(PRIVATE_RS_OUTPUT_DIR)/src -D $(PRIVATE_RS_OUTPUT_DIR)/src
$(SOONG_ZIP) -o $(PRIVATE_RS_OUTPUT_RES_ZIP) -C $(PRIVATE_RS_OUTPUT_DIR)/res -D $(PRIVATE_RS_OUTPUT_DIR)/res
$(call _merge-renderscript-d,$(PRIVATE_DEP_FILES),$@.d)
endef

define transform-bc-to-so
@echo "Renderscript compatibility: $(notdir $@) <= $(notdir $<)"
$(hide) mkdir -p $(dir $@)
$(hide) $(BCC_COMPAT) -O3 -o $(dir $@)/$(notdir $(<:.bc=.o)) -fPIC -shared \
  -rt-path $(RS_PREBUILT_CLCORE) -mtriple $(RS_COMPAT_TRIPLE) $<
$(hide) $(PRIVATE_CXX_LINK) -fuse-ld=lld -target $(CLANG_TARGET_TRIPLE) -shared -Wl,-soname,$(notdir $@) -nostdlib \
  -Wl,-rpath,\$$ORIGIN/../lib \
  $(dir $@)/$(notdir $(<:.bc=.o)) \
  $(RS_PREBUILT_COMPILER_RT) \
  -o $@ $(CLANG_TARGET_GLOBAL_LLDFLAGS) -Wl,--hash-style=sysv \
  -L $(SOONG_OUT_DIR)/ndk/platforms/android-$(PRIVATE_SDK_VERSION)/arch-$(TARGET_ARCH)/usr/lib64 \
  -L $(SOONG_OUT_DIR)/ndk/platforms/android-$(PRIVATE_SDK_VERSION)/arch-$(TARGET_ARCH)/usr/lib \
  $(call intermediates-dir-for,SHARED_LIBRARIES,libRSSupport)/libRSSupport.so \
  -lm -lc
endef

###########################################################
## Commands to compile RenderScript to C++
###########################################################

define transform-renderscripts-to-cpp-and-bc
@echo "RenderScript: $(PRIVATE_MODULE) <= $(PRIVATE_RS_SOURCE_FILES)"
$(hide) rm -rf $(PRIVATE_RS_OUTPUT_DIR)
$(hide) mkdir -p $(PRIVATE_RS_OUTPUT_DIR)/
$(hide) $(RS_CC_ASAN_OPTIONS) $(PRIVATE_RS_CC) \
  -o $(PRIVATE_RS_OUTPUT_DIR)/ \
  -d $(PRIVATE_RS_OUTPUT_DIR) \
  -a $@ -MD \
  -reflect-c++ \
  $(addprefix -target-api , $(PRIVATE_RS_TARGET_API)) \
  $(PRIVATE_RS_FLAGS) \
  $(addprefix -I , $(PRIVATE_RS_INCLUDES)) \
  $(PRIVATE_RS_SOURCE_FILES)
$(call _merge-renderscript-d,$(PRIVATE_DEP_FILES),$@.d)
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
$(hide) $(AIDL_CPP) -d$(basename $@).aidl.d --ninja $(PRIVATE_AIDL_FLAGS) \
    $< $(PRIVATE_HEADER_OUTPUT_DIR) $@
endef

## Given a .aidl file path, generate the rule to compile it a .java file
# $(1): a .aidl source file
# $(2): a directory to place the generated .java files in
# $(3): name of a variable to add the path to the generated source file to
#
# You must call this with $(eval).
define define-aidl-java-rule
define_aidl_java_rule_src := $(patsubst %.aidl,%.java,$(subst ../,dotdot/,$(addprefix $(2)/,$(1))))
$$(define_aidl_java_rule_src) : $(call clean-path,$(LOCAL_PATH)/$(1)) $(AIDL)
	$$(transform-aidl-to-java)
$(3) += $$(define_aidl_java_rule_src)
endef

## Given a .aidl file path generate the rule to compile it a .cpp file.
# $(1): a .aidl source file
# $(2): a directory to place the generated .cpp files in
# $(3): name of a variable to add the path to the generated source file to
#
# You must call this with $(eval).
define define-aidl-cpp-rule
define_aidl_cpp_rule_src := $(patsubst %.aidl,%$(LOCAL_CPP_EXTENSION),$(subst ../,dotdot/,$(addprefix $(2)/,$(1))))
$$(define_aidl_cpp_rule_src) : $(call clean-path,$(LOCAL_PATH)/$(1)) $(AIDL_CPP)
	$$(transform-aidl-to-cpp)
$(3) += $$(define_aidl_cpp_rule_src)
endef

###########################################################
## Commands for running vts
###########################################################

define transform-vts-to-cpp
@mkdir -p $(dir $@)
@mkdir -p $(PRIVATE_HEADER_OUTPUT_DIR)
@echo "Generating C++ from VTS: $(PRIVATE_MODULE) <= $<"
$(hide) $(VTSC) -TODO_b/120496070 $(PRIVATE_VTS_FLAGS) \
    $< $(PRIVATE_HEADER_OUTPUT_DIR) $@
endef

## Given a .vts file path generate the rule to compile it a .cpp file.
# $(1): a .vts source file
# $(2): a directory to place the generated .cpp files in
# $(3): name of a variable to add the path to the generated source file to
#
# You must call this with $(eval).
define define-vts-cpp-rule
define_vts_cpp_rule_src := $(patsubst %.vts,%$(LOCAL_CPP_EXTENSION),$(subst ../,dotdot/,$(addprefix $(2)/,$(1))))
$$(define_vts_cpp_rule_src) : $(LOCAL_PATH)/$(1) $(VTSC)
	$$(transform-vts-to-cpp)
$(3) += $$(define_vts_cpp_rule_src)
endef

###########################################################
## Commands for running java-event-log-tags.py
###########################################################

define transform-logtags-to-java
@mkdir -p $(dir $@)
@echo "logtags: $@ <= $<"
$(hide) $(JAVATAGS) -o $@ $< $(PRIVATE_MERGED_TAG)
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
$(SOONG_ZIP) -o $@ -C $(PRIVATE_PROTO_JAVA_OUTPUT_DIR) -D $(PRIVATE_PROTO_JAVA_OUTPUT_DIR)
endef

######################################################################
## Commands for running protoc to compile .proto into .pb.cc (or.pb.c) and .pb.h
######################################################################

define transform-proto-to-cc
@echo "Protoc: $@ <= $<"
@mkdir -p $(dir $@)
$(hide) \
  $(PROTOC) \
  $(addprefix --proto_path=, $(PRIVATE_PROTO_INCLUDES)) \
  $(PRIVATE_PROTOC_FLAGS) \
  $<
@# aprotoc outputs only .cc. Rename it to .cpp if necessary.
$(if $(PRIVATE_RENAME_CPP_EXT),\
  $(hide) mv $(basename $@).cc $@)
endef

###########################################################
## Helper to set include paths form transform-*-to-o
###########################################################
define c-includes
$(addprefix -I , $(PRIVATE_C_INCLUDES)) \
$(foreach i,$(PRIVATE_IMPORTED_INCLUDES),$(EXPORTS.$(i)))\
$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),,\
    $(addprefix -I ,\
        $(filter-out $(PRIVATE_C_INCLUDES), \
            $(PRIVATE_GLOBAL_C_INCLUDES))) \
    $(addprefix -isystem ,\
        $(filter-out $(PRIVATE_C_INCLUDES), \
            $(PRIVATE_GLOBAL_C_SYSTEM_INCLUDES))))
endef

###########################################################
## Commands for running gcc to compile a C++ file
###########################################################

define transform-cpp-to-o-compiler-args
$(c-includes) \
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
$(PRIVATE_CPPFLAGS_NO_OVERRIDE)
endef

# PATH_TO_CLANG_TIDY is defined in build/soong
define call-clang-tidy
$(PATH_TO_CLANG_TIDY) \
  $(PRIVATE_TIDY_FLAGS) \
  -checks=$(PRIVATE_TIDY_CHECKS)
endef

define clang-tidy-cpp
$(hide) $(call-clang-tidy) $< -- $(transform-cpp-to-o-compiler-args)
endef

ifneq (,$(filter 1 true,$(WITH_TIDY_ONLY)))
define transform-cpp-to-o
$(if $(PRIVATE_TIDY_CHECKS),
  @echo "$($(PRIVATE_PREFIX)DISPLAY) tidy $(PRIVATE_ARM_MODE) C++: $<"
  $(clang-tidy-cpp))
endef
else
define transform-cpp-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) $(PRIVATE_ARM_MODE) C++: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(if $(PRIVATE_TIDY_CHECKS),$(clang-tidy-cpp))
$(hide) $(RELATIVE_PWD) $(PRIVATE_CXX) \
  $(transform-cpp-to-o-compiler-args) \
  -MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef
endif


###########################################################
## Commands for running gcc to compile a C file
###########################################################

# $(1): extra flags
define transform-c-or-s-to-o-compiler-args
$(c-includes) \
-c \
$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
    $(PRIVATE_TARGET_GLOBAL_CFLAGS) \
    $(PRIVATE_TARGET_GLOBAL_CONLYFLAGS) \
    $(PRIVATE_ARM_CFLAGS) \
 ) \
 $(1)
endef

define transform-c-to-o-compiler-args
$(call transform-c-or-s-to-o-compiler-args, \
  $(PRIVATE_CFLAGS) \
  $(PRIVATE_CONLYFLAGS) \
  $(PRIVATE_DEBUG_CFLAGS) \
  $(PRIVATE_CFLAGS_NO_OVERRIDE))
endef

define clang-tidy-c
$(hide) $(call-clang-tidy) $< -- $(transform-c-to-o-compiler-args)
endef

ifneq (,$(filter 1 true,$(WITH_TIDY_ONLY)))
define transform-c-to-o
$(if $(PRIVATE_TIDY_CHECKS),
  @echo "$($(PRIVATE_PREFIX)DISPLAY) tidy $(PRIVATE_ARM_MODE) C: $<"
  $(clang-tidy-c))
endef
else
define transform-c-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) $(PRIVATE_ARM_MODE) C: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(if $(PRIVATE_TIDY_CHECKS),$(clang-tidy-c))
$(hide) $(RELATIVE_PWD) $(PRIVATE_CC) \
  $(transform-c-to-o-compiler-args) \
  -MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef
endif

define transform-s-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) asm: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(RELATIVE_PWD) $(PRIVATE_CC) \
  $(call transform-c-or-s-to-o-compiler-args, $(PRIVATE_ASFLAGS)) \
  -MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
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

define transform-m-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) ObjC: $(PRIVATE_MODULE) <= $<"
$(call transform-c-or-s-to-o, $(PRIVATE_CFLAGS) $(PRIVATE_DEBUG_CFLAGS))
endef

###########################################################
## Commands for running gcc to compile a host C++ file
###########################################################

define transform-host-cpp-to-o-compiler-args
$(c-includes) \
-c \
$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
    $(PRIVATE_HOST_GLOBAL_CFLAGS) \
    $(PRIVATE_HOST_GLOBAL_CPPFLAGS) \
 ) \
$(PRIVATE_CFLAGS) \
$(PRIVATE_CPPFLAGS) \
$(PRIVATE_DEBUG_CFLAGS) \
$(PRIVATE_CFLAGS_NO_OVERRIDE) \
$(PRIVATE_CPPFLAGS_NO_OVERRIDE)
endef

define clang-tidy-host-cpp
$(hide) $(call-clang-tidy) $< -- $(transform-host-cpp-to-o-compiler-args)
endef

ifneq (,$(filter 1 true,$(WITH_TIDY_ONLY)))
define transform-host-cpp-to-o
$(if $(PRIVATE_TIDY_CHECKS),
  @echo "tidy $($(PRIVATE_PREFIX)DISPLAY) C++: $<"
  $(clang-tidy-host-cpp))
endef
else
define transform-host-cpp-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) C++: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(if $(PRIVATE_TIDY_CHECKS),$(clang-tidy-host-cpp))
$(hide) $(RELATIVE_PWD) $(PRIVATE_CXX) \
  $(transform-host-cpp-to-o-compiler-args) \
  -MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef
endif


###########################################################
## Commands for running gcc to compile a host C file
###########################################################

define transform-host-c-or-s-to-o-common-args
$(c-includes) \
-c \
$(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
    $(PRIVATE_HOST_GLOBAL_CFLAGS) \
    $(PRIVATE_HOST_GLOBAL_CONLYFLAGS) \
 )
endef

# $(1): extra flags
define transform-host-c-or-s-to-o
@mkdir -p $(dir $@)
$(hide) $(RELATIVE_PWD) $(PRIVATE_CC) \
  $(transform-host-c-or-s-to-o-common-args) \
  $(1) \
  -MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef

define transform-host-c-to-o-compiler-args
  $(transform-host-c-or-s-to-o-common-args) \
  $(PRIVATE_CFLAGS) $(PRIVATE_CONLYFLAGS) \
  $(PRIVATE_DEBUG_CFLAGS) $(PRIVATE_CFLAGS_NO_OVERRIDE)
endef

define clang-tidy-host-c
$(hide) $(call-clang-tidy) $< -- $(transform-host-c-to-o-compiler-args)
endef

ifneq (,$(filter 1 true,$(WITH_TIDY_ONLY)))
define transform-host-c-to-o
$(if $(PRIVATE_TIDY_CHECKS),
  @echo "tidy $($(PRIVATE_PREFIX)DISPLAY) C: $<"
  $(clang-tidy-host-c))
endef
else
define transform-host-c-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) C: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(if $(PRIVATE_TIDY_CHECKS), $(clang-tidy-host-c))
$(hide) $(RELATIVE_PWD) $(PRIVATE_CC) \
  $(transform-host-c-to-o-compiler-args) \
  -MD -MF $(patsubst %.o,%.d,$@) -o $@ $<
endef
endif

define transform-host-s-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) asm: $(PRIVATE_MODULE) <= $<"
$(call transform-host-c-or-s-to-o, $(PRIVATE_ASFLAGS))
endef

###########################################################
## Commands for running gcc to compile a host Objective-C file
###########################################################

define transform-host-m-to-o
@echo "$($(PRIVATE_PREFIX)DISPLAY) ObjC: $(PRIVATE_MODULE) <= $<"
$(call transform-host-c-or-s-to-o, $(PRIVATE_CFLAGS) $(PRIVATE_DEBUG_CFLAGS) $(PRIVATE_CFLAGS_NO_OVERRIDE))
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
# $(4): the ninja pool to use for the rule
define compile-dotdot-cpp-file
o := $(intermediates)/$(patsubst %$(LOCAL_CPP_EXTENSION),%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : .KATI_NINJA_POOL := $(4)
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2) $(CLANG_CXX)
	$$(transform-$$(PRIVATE_HOST)cpp-to-o)
$$(call include-depfiles-for-objs, $$(o))
$(3) += $$(o)
endef

## Rule to compile a C source file with ../ in the path.
## Must be called with $(eval).
# $(1): the C source file in LOCAL_SRC_FILES.
# $(2): the additional dependencies.
# $(3): the variable name to collect the output object file.
# $(4): the ninja pool to use for the rule
define compile-dotdot-c-file
o := $(intermediates)/$(patsubst %.c,%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : .KATI_NINJA_POOL := $(4)
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2) $(CLANG)
	$$(transform-$$(PRIVATE_HOST)c-to-o)
$$(call include-depfiles-for-objs, $$(o))
$(3) += $$(o)
endef

## Rule to compile a .S source file with ../ in the path.
## Must be called with $(eval).
# $(1): the .S source file in LOCAL_SRC_FILES.
# $(2): the additional dependencies.
# $(3): the variable name to collect the output object file.
# $(4): the ninja pool to use for the rule
define compile-dotdot-s-file
o := $(intermediates)/$(patsubst %.S,%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : .KATI_NINJA_POOL := $(4)
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2) $(CLANG)
	$$(transform-$$(PRIVATE_HOST)s-to-o)
$$(call include-depfiles-for-objs, $$(o))
$(3) += $$(o)
endef

## Rule to compile a .s source file with ../ in the path.
## Must be called with $(eval).
# $(1): the .s source file in LOCAL_SRC_FILES.
# $(2): the additional dependencies.
# $(3): the variable name to collect the output object file.
# $(4): the ninja pool to use for the rule
define compile-dotdot-s-file-no-deps
o := $(intermediates)/$(patsubst %.s,%.o,$(subst ../,$(DOTDOT_REPLACEMENT),$(1)))
$$(o) : .KATI_NINJA_POOL := $(4)
$$(o) : $(TOPDIR)$(LOCAL_PATH)/$(1) $(2) $(CLANG)
	$$(transform-$$(PRIVATE_HOST)s-to-o)
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
# $(2): the full path of the destination static library.
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
        $(PRIVATE_ARFLAGS) $(2) $$filelist

endef

# $(1): the full path of the source static library.
# $(2): the full path of the destination static library.
define extract-and-include-whole-static-libs-first
$(if $(strip $(1)),
$(hide) cp $(1) $(2))
endef

# $(1): the full path of the destination static library.
define extract-and-include-target-whole-static-libs
$(call extract-and-include-whole-static-libs-first, $(firstword $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)),$(1))
$(foreach lib,$(wordlist 2,999,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)), \
    $(call _extract-and-include-single-target-whole-static-lib, $(lib), $(1)))
endef

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define transform-o-to-static-lib
@echo "$($(PRIVATE_PREFIX)DISPLAY) StaticLib: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
@rm -f $@ $@.tmp
$(call extract-and-include-target-whole-static-libs,$@.tmp)
$(call split-long-arguments,$($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_AR) \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)TARGET_GLOBAL_ARFLAGS) \
    $(PRIVATE_ARFLAGS) \
    $@.tmp,$(PRIVATE_ALL_OBJECTS))
$(hide) mv -f $@.tmp $@
endef

###########################################################
## Commands for running host ar
###########################################################

# $(1): the full path of the source static library.
# $(2): the full path of the destination static library.
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
        $(2) $$filelist

endef

define extract-and-include-host-whole-static-libs
$(call extract-and-include-whole-static-libs-first, $(firstword $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)),$(1))
$(foreach lib,$(wordlist 2,999,$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)), \
    $(call _extract-and-include-single-host-whole-static-lib, $(lib),$(1)))
endef

ifeq ($(HOST_OS),darwin)
# On Darwin the host ar fails if there is nothing to add to .a at all.
# We work around by adding a dummy.o and then deleting it.
define create-dummy.o-if-no-objs
$(if $(PRIVATE_ALL_OBJECTS),,$(hide) touch $(dir $(1))dummy.o)
endef

define get-dummy.o-if-no-objs
$(if $(PRIVATE_ALL_OBJECTS),,$(dir $(1))dummy.o)
endef

define delete-dummy.o-if-no-objs
$(if $(PRIVATE_ALL_OBJECTS),,$(hide) $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)AR) d $(1) $(dir $(1))dummy.o \
  && rm -f $(dir $(1))dummy.o)
endef
else
create-dummy.o-if-no-objs =
get-dummy.o-if-no-objs =
delete-dummy.o-if-no-objs =
endif  # HOST_OS is darwin

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define transform-host-o-to-static-lib
@echo "$($(PRIVATE_PREFIX)DISPLAY) StaticLib: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
@rm -f $@ $@.tmp
$(call extract-and-include-host-whole-static-libs,$@.tmp)
$(call create-dummy.o-if-no-objs,$@.tmp)
$(call split-long-arguments,$($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)AR) \
    $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)GLOBAL_ARFLAGS) $@.tmp,\
    $(PRIVATE_ALL_OBJECTS) $(call get-dummy.o-if-no-objs,$@.tmp))
$(call delete-dummy.o-if-no-objs,$@.tmp)
$(hide) mv -f $@.tmp $@
endef


###########################################################
## Commands for running gcc to link a shared library or package
###########################################################

# ld just seems to be so finicky with command order that we allow
# it to be overriden en-masse see combo/linux-arm.make for an example.
ifneq ($(HOST_CUSTOM_LD_COMMAND),true)
define transform-host-o-to-shared-lib-inner
$(hide) $(PRIVATE_CXX_LINK) \
  -Wl,-rpath,\$$ORIGIN/../$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_SHARED_LIBRARIES)) \
  -Wl,-rpath,\$$ORIGIN/$(notdir $($(PRIVATE_2ND_ARCH_VAR_PREFIX)$(PRIVATE_PREFIX)OUT_SHARED_LIBRARIES)) \
  -shared -Wl,-soname,$(notdir $@) \
  $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
     $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
  ) \
  $(PRIVATE_LDFLAGS) \
  $(PRIVATE_CRTBEGIN) \
  $(PRIVATE_ALL_OBJECTS) \
  -Wl,--whole-archive \
  $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
  -Wl,--no-whole-archive \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
  $(PRIVATE_ALL_STATIC_LIBRARIES) \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
  $(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_HOST_LIBPROFILE_RT)) \
  $(PRIVATE_LIBCRT_BUILTINS) \
  $(PRIVATE_ALL_SHARED_LIBRARIES) \
  -o $@ \
  $(PRIVATE_CRTEND) \
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
$(hide) $(PRIVATE_CXX_LINK) \
  -nostdlib -Wl,-soname,$(notdir $@) \
  -Wl,--gc-sections \
  -shared \
  $(PRIVATE_TARGET_CRTBEGIN_SO_O) \
  $(PRIVATE_ALL_OBJECTS) \
  -Wl,--whole-archive \
  $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
  -Wl,--no-whole-archive \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
  $(PRIVATE_ALL_STATIC_LIBRARIES) \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
  $(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_TARGET_COVERAGE_LIB)) \
  $(PRIVATE_TARGET_LIBCRT_BUILTINS) \
  $(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
  $(PRIVATE_LDFLAGS) \
  $(PRIVATE_ALL_SHARED_LIBRARIES) \
  -o $@ \
  $(PRIVATE_TARGET_CRTEND_SO_O) \
  $(PRIVATE_LDLIBS)
endef

define transform-o-to-shared-lib
@echo "$($(PRIVATE_PREFIX)DISPLAY) SharedLib: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-o-to-shared-lib-inner)
endef

###########################################################
## Commands for running gcc to link an executable
###########################################################

define transform-o-to-executable-inner
$(hide) $(PRIVATE_CXX_LINK) -pie \
  -nostdlib -Bdynamic \
  -Wl,-dynamic-linker,$(PRIVATE_LINKER) \
  -Wl,--gc-sections \
  -Wl,-z,nocopyreloc \
  $(PRIVATE_TARGET_CRTBEGIN_DYNAMIC_O) \
  $(PRIVATE_ALL_OBJECTS) \
  -Wl,--whole-archive \
  $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
  -Wl,--no-whole-archive \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
  $(PRIVATE_ALL_STATIC_LIBRARIES) \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
  $(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_TARGET_COVERAGE_LIB)) \
  $(PRIVATE_TARGET_LIBCRT_BUILTINS) \
  $(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
  $(PRIVATE_LDFLAGS) \
  $(PRIVATE_ALL_SHARED_LIBRARIES) \
  -o $@ \
  $(PRIVATE_TARGET_CRTEND_O) \
  $(PRIVATE_LDLIBS)
endef

define transform-o-to-executable
@echo "$($(PRIVATE_PREFIX)DISPLAY) Executable: $(PRIVATE_MODULE) ($@)"
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
$(hide) $(PRIVATE_CXX_LINK) \
  -nostdlib -Bstatic \
  $(if $(filter $(PRIVATE_LDFLAGS),-shared),,-static) \
  -Wl,--gc-sections \
  -o $@ \
  $(PRIVATE_TARGET_CRTBEGIN_STATIC_O) \
  $(PRIVATE_TARGET_GLOBAL_LDFLAGS) \
  $(PRIVATE_LDFLAGS) \
  $(PRIVATE_ALL_OBJECTS) \
  -Wl,--whole-archive \
  $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
  -Wl,--no-whole-archive \
  $(filter-out %libcompiler_rt.hwasan.a %libc_nomalloc.hwasan.a %libc.hwasan.a %libcompiler_rt.a %libc_nomalloc.a %libc.a,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
  -Wl,--start-group \
  $(filter %libc.a %libc.hwasan.a,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
  $(filter %libc_nomalloc.a %libc_nomalloc.hwasan.a,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
  $(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_TARGET_COVERAGE_LIB)) \
  $(filter %libcompiler_rt.a %libcompiler_rt.hwasan.a,$(PRIVATE_ALL_STATIC_LIBRARIES)) \
  $(PRIVATE_TARGET_LIBCRT_BUILTINS) \
  -Wl,--end-group \
  $(PRIVATE_TARGET_CRTEND_O)
endef

define transform-o-to-static-executable
@echo "$($(PRIVATE_PREFIX)DISPLAY) StaticExecutable: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-o-to-static-executable-inner)
endef


###########################################################
## Commands for running gcc to link a host executable
###########################################################

ifneq ($(HOST_CUSTOM_LD_COMMAND),true)
define transform-host-o-to-executable-inner
$(hide) $(PRIVATE_CXX_LINK) \
  $(PRIVATE_CRTBEGIN) \
  $(PRIVATE_ALL_OBJECTS) \
  -Wl,--whole-archive \
  $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
  -Wl,--no-whole-archive \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--start-group) \
  $(PRIVATE_ALL_STATIC_LIBRARIES) \
  $(if $(PRIVATE_GROUP_STATIC_LIBRARIES),-Wl$(comma)--end-group) \
  $(if $(filter true,$(NATIVE_COVERAGE)),$(PRIVATE_HOST_LIBPROFILE_RT)) \
  $(PRIVATE_LIBCRT_BUILTINS) \
  $(PRIVATE_ALL_SHARED_LIBRARIES) \
  $(foreach path,$(PRIVATE_RPATHS), \
    -Wl,-rpath,\$$ORIGIN/$(path)) \
  $(if $(PRIVATE_NO_DEFAULT_COMPILER_FLAGS),, \
      $(PRIVATE_HOST_GLOBAL_LDFLAGS) \
  ) \
  $(PRIVATE_LDFLAGS) \
  -o $@ \
  $(PRIVATE_CRTEND) \
  $(PRIVATE_LDLIBS)
endef
endif

define transform-host-o-to-executable
@echo "$($(PRIVATE_PREFIX)DISPLAY) Executable: $(PRIVATE_MODULE) ($@)"
@mkdir -p $(dir $@)
$(transform-host-o-to-executable-inner)
endef

###########################################################
## Commands for packaging native coverage files
###########################################################
define package-coverage-files
  @rm -f $@ $@.lst $@.premerged
  @touch $@.lst
  $(foreach obj,$(strip $(PRIVATE_ALL_OBJECTS)), $(hide) echo $(obj) >> $@.lst$(newline))
  $(hide) $(SOONG_ZIP) -o $@.premerged -C $(OUT_DIR) -l $@.lst
  $(hide) $(MERGE_ZIPS) -ignore-duplicates $@ $@.premerged $(strip $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES))
endef

###########################################################
## Commands for running javac to make .class files
###########################################################

# b/37750224
AAPT_ASAN_OPTIONS := ASAN_OPTIONS=detect_leaks=0

# Search for generated R.java in $1, copy the found R.java as $2.
define find-generated-R.java
$(hide) for GENERATED_R_FILE in `find $(1) \
  -name R.java 2> /dev/null`; do \
    cp $$GENERATED_R_FILE $(2) || exit 32; \
  done;
@# Ensure that the target file is always created, i.e. also in case we did not
@# enter the GENERATED_R_FILE-loop above. This avoids unnecessary rebuilding.
$(hide) touch $(2)
endef

###########################################################
# AAPT2 compilation and link
###########################################################
define aapt2-compile-one-resource-file
@mkdir -p $(dir $@)
$(hide) $(AAPT2) compile -o $(dir $@) $(PRIVATE_AAPT2_CFLAGS) $<
endef

define aapt2-compile-resource-dirs
@mkdir -p $(dir $@)
$(hide) $(AAPT2) compile -o $@ $(addprefix --dir ,$(PRIVATE_SOURCE_RES_DIRS)) \
  $(PRIVATE_AAPT2_CFLAGS)
endef

# TODO(b/74574557): use aapt2 compile --zip if it gets implemented
define aapt2-compile-resource-zips
@mkdir -p $(dir $@)
$(ZIPSYNC) -d $@.contents -l $@.list $(PRIVATE_SOURCE_RES_ZIPS)
$(hide) $(AAPT2) compile -o $@ --dir $@.contents $(PRIVATE_AAPT2_CFLAGS)
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
$(strip \
  $(eval _p_w := $(strip $(subst /,$(space),$(dir $(call clean-path,$(1))))))
  $(2)/$(subst $(space),/,$(_p_w))_$(if $(filter values%,$(lastword $(_p_w))),$(patsubst %.xml,%.arsc,$(notdir $(1))),$(notdir $(1))).flat)
endef

define aapt2-link
@mkdir -p $(dir $@)
rm -rf $(PRIVATE_JAVA_GEN_DIR)
mkdir -p $(PRIVATE_JAVA_GEN_DIR)
$(call dump-words-to-file,$(PRIVATE_RES_FLAT),$(dir $@)aapt2-flat-list)
$(call dump-words-to-file,$(PRIVATE_OVERLAY_FLAT),$(dir $@)aapt2-flat-overlay-list)
cat $(PRIVATE_STATIC_LIBRARY_TRANSITIVE_RES_PACKAGES_LISTS) | sort -u | tr '\n' ' ' > $(dir $@)aapt2-transitive-overlay-list
$(hide) $(AAPT2) link -o $@ \
  $(PRIVATE_AAPT_FLAGS) \
  $(if $(PRIVATE_STATIC_LIBRARY_EXTRA_PACKAGES),$$(cat $(PRIVATE_STATIC_LIBRARY_EXTRA_PACKAGES))) \
  $(addprefix --manifest ,$(PRIVATE_ANDROID_MANIFEST)) \
  $(addprefix -I ,$(PRIVATE_AAPT_INCLUDES)) \
  $(addprefix -I ,$(PRIVATE_SHARED_ANDROID_LIBRARIES)) \
  $(addprefix -A ,$(foreach d,$(PRIVATE_ASSET_DIR),$(call clean-path,$(d)))) \
  $(addprefix --java ,$(PRIVATE_JAVA_GEN_DIR)) \
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
  -R \@$(dir $@)aapt2-flat-overlay-list \
  -R \@$(dir $@)aapt2-transitive-overlay-list \
  \@$(dir $@)aapt2-flat-list
$(SOONG_ZIP) -o $(PRIVATE_SRCJAR) -C $(PRIVATE_JAVA_GEN_DIR) -D $(PRIVATE_JAVA_GEN_DIR)
$(EXTRACT_JAR_PACKAGES) -i $(PRIVATE_SRCJAR) -o $(PRIVATE_AAPT_EXTRA_PACKAGES) --prefix '--extra-packages '
endef

define _create-default-manifest-file
$(1):
	rm -f $1
	(echo '<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="missing.manifest">' && \
	 echo '    <uses-sdk android:minSdkVersion="$(2)" />' && \
	 echo '</manifest>' ) > $1
endef

define create-default-manifest-file
  $(eval $(call _create-default-manifest-file,$(1),$(2)))
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
        @$(call emit-line,$(wordlist 13501,14000,$(1)),$(2))
        @$(call emit-line,$(wordlist 14001,14500,$(1)),$(2))
        @$(call emit-line,$(wordlist 14501,15000,$(1)),$(2))
        @$(call emit-line,$(wordlist 15001,15500,$(1)),$(2))
        @$(call emit-line,$(wordlist 15501,16000,$(1)),$(2))
        @$(call emit-line,$(wordlist 16001,16500,$(1)),$(2))
        @$(call emit-line,$(wordlist 16501,17000,$(1)),$(2))
        @$(call emit-line,$(wordlist 17001,17500,$(1)),$(2))
        @$(call emit-line,$(wordlist 17501,18000,$(1)),$(2))
        @$(call emit-line,$(wordlist 18001,18500,$(1)),$(2))
        @$(call emit-line,$(wordlist 18501,19000,$(1)),$(2))
        @$(call emit-line,$(wordlist 19001,19500,$(1)),$(2))
        @$(call emit-line,$(wordlist 19501,20000,$(1)),$(2))
        @$(call emit-line,$(wordlist 20001,20500,$(1)),$(2))
        @$(call emit-line,$(wordlist 20501,21000,$(1)),$(2))
        @$(call emit-line,$(wordlist 21001,21500,$(1)),$(2))
        @$(call emit-line,$(wordlist 21501,22000,$(1)),$(2))
        @$(call emit-line,$(wordlist 22001,22500,$(1)),$(2))
        @$(call emit-line,$(wordlist 22501,23000,$(1)),$(2))
        @$(call emit-line,$(wordlist 23001,23500,$(1)),$(2))
        @$(call emit-line,$(wordlist 23501,24000,$(1)),$(2))
        @$(call emit-line,$(wordlist 24001,24500,$(1)),$(2))
        @$(call emit-line,$(wordlist 24501,25000,$(1)),$(2))
        @$(call emit-line,$(wordlist 25001,25500,$(1)),$(2))
        @$(call emit-line,$(wordlist 25501,26000,$(1)),$(2))
        @$(call emit-line,$(wordlist 26001,26500,$(1)),$(2))
        @$(call emit-line,$(wordlist 26501,27000,$(1)),$(2))
        @$(call emit-line,$(wordlist 27001,27500,$(1)),$(2))
        @$(call emit-line,$(wordlist 27501,28000,$(1)),$(2))
        @$(call emit-line,$(wordlist 28001,28500,$(1)),$(2))
        @$(call emit-line,$(wordlist 28501,29000,$(1)),$(2))
        @$(call emit-line,$(wordlist 29001,29500,$(1)),$(2))
        @$(call emit-line,$(wordlist 29501,30000,$(1)),$(2))
        @$(call emit-line,$(wordlist 30001,30500,$(1)),$(2))
        @$(call emit-line,$(wordlist 30501,31000,$(1)),$(2))
        @$(call emit-line,$(wordlist 31001,31500,$(1)),$(2))
        @$(call emit-line,$(wordlist 31501,32000,$(1)),$(2))
        @$(call emit-line,$(wordlist 32001,32500,$(1)),$(2))
        @$(call emit-line,$(wordlist 32501,33000,$(1)),$(2))
        @$(call emit-line,$(wordlist 33001,33500,$(1)),$(2))
        @$(call emit-line,$(wordlist 33501,34000,$(1)),$(2))
        @$(call emit-line,$(wordlist 34001,34500,$(1)),$(2))
        @$(call emit-line,$(wordlist 34501,35000,$(1)),$(2))
        @$(call emit-line,$(wordlist 35001,35500,$(1)),$(2))
        @$(call emit-line,$(wordlist 35501,36000,$(1)),$(2))
        @$(call emit-line,$(wordlist 36001,36500,$(1)),$(2))
        @$(call emit-line,$(wordlist 36501,37000,$(1)),$(2))
        @$(call emit-line,$(wordlist 37001,37500,$(1)),$(2))
        @$(call emit-line,$(wordlist 37501,38000,$(1)),$(2))
        @$(call emit-line,$(wordlist 38001,38500,$(1)),$(2))
        @$(call emit-line,$(wordlist 38501,39000,$(1)),$(2))
        @$(call emit-line,$(wordlist 39001,39500,$(1)),$(2))
        @$(call emit-line,$(wordlist 39501,40000,$(1)),$(2))
        @$(call emit-line,$(wordlist 40001,40500,$(1)),$(2))
        @$(call emit-line,$(wordlist 40501,41000,$(1)),$(2))
        @$(call emit-line,$(wordlist 41001,41500,$(1)),$(2))
        @$(call emit-line,$(wordlist 41501,42000,$(1)),$(2))
        @$(call emit-line,$(wordlist 42001,42500,$(1)),$(2))
        @$(call emit-line,$(wordlist 42501,43000,$(1)),$(2))
        @$(call emit-line,$(wordlist 43001,43500,$(1)),$(2))
        @$(call emit-line,$(wordlist 43501,44000,$(1)),$(2))
        @$(call emit-line,$(wordlist 44001,44500,$(1)),$(2))
        @$(call emit-line,$(wordlist 44501,45000,$(1)),$(2))
        @$(call emit-line,$(wordlist 45001,45500,$(1)),$(2))
        @$(call emit-line,$(wordlist 45501,46000,$(1)),$(2))
        @$(call emit-line,$(wordlist 46001,46500,$(1)),$(2))
        @$(call emit-line,$(wordlist 46501,47000,$(1)),$(2))
        @$(call emit-line,$(wordlist 47001,47500,$(1)),$(2))
        @$(call emit-line,$(wordlist 47501,48000,$(1)),$(2))
        @$(call emit-line,$(wordlist 48001,48500,$(1)),$(2))
        @$(call emit-line,$(wordlist 48501,49000,$(1)),$(2))
        @$(call emit-line,$(wordlist 49001,49500,$(1)),$(2))
        @$(call emit-line,$(wordlist 49501,50000,$(1)),$(2))
        @$(call emit-line,$(wordlist 50001,50500,$(1)),$(2))
        @$(call emit-line,$(wordlist 50501,51000,$(1)),$(2))
        @$(call emit-line,$(wordlist 51001,51500,$(1)),$(2))
        @$(call emit-line,$(wordlist 51501,52000,$(1)),$(2))
        @$(call emit-line,$(wordlist 52001,52500,$(1)),$(2))
        @$(call emit-line,$(wordlist 52501,53000,$(1)),$(2))
        @$(call emit-line,$(wordlist 53001,53500,$(1)),$(2))
        @$(call emit-line,$(wordlist 53501,54000,$(1)),$(2))
        @$(call emit-line,$(wordlist 54001,54500,$(1)),$(2))
        @$(call emit-line,$(wordlist 54501,55000,$(1)),$(2))
        @$(call emit-line,$(wordlist 55001,55500,$(1)),$(2))
        @$(call emit-line,$(wordlist 55501,56000,$(1)),$(2))
        @$(call emit-line,$(wordlist 56001,56500,$(1)),$(2))
        @$(call emit-line,$(wordlist 56501,57000,$(1)),$(2))
        @$(call emit-line,$(wordlist 57001,57500,$(1)),$(2))
        @$(call emit-line,$(wordlist 57501,58000,$(1)),$(2))
        @$(call emit-line,$(wordlist 58001,58500,$(1)),$(2))
        @$(call emit-line,$(wordlist 58501,59000,$(1)),$(2))
        @$(call emit-line,$(wordlist 59001,59500,$(1)),$(2))
        @$(call emit-line,$(wordlist 59501,60000,$(1)),$(2))
        @$(call emit-line,$(wordlist 60001,60500,$(1)),$(2))
        @$(call emit-line,$(wordlist 60501,61000,$(1)),$(2))
        @$(call emit-line,$(wordlist 61001,61500,$(1)),$(2))
        @$(call emit-line,$(wordlist 61501,62000,$(1)),$(2))
        @$(call emit-line,$(wordlist 62001,62500,$(1)),$(2))
        @$(call emit-line,$(wordlist 62501,63000,$(1)),$(2))
        @$(call emit-line,$(wordlist 63001,63500,$(1)),$(2))
        @$(call emit-line,$(wordlist 63501,64000,$(1)),$(2))
        @$(call emit-line,$(wordlist 64001,64500,$(1)),$(2))
        @$(call emit-line,$(wordlist 64501,65000,$(1)),$(2))
        @$(call emit-line,$(wordlist 65001,65500,$(1)),$(2))
        @$(call emit-line,$(wordlist 65501,66000,$(1)),$(2))
        @$(call emit-line,$(wordlist 66001,66500,$(1)),$(2))
        @$(call emit-line,$(wordlist 66501,67000,$(1)),$(2))
        @$(call emit-line,$(wordlist 67001,67500,$(1)),$(2))
        @$(call emit-line,$(wordlist 67501,68000,$(1)),$(2))
        @$(call emit-line,$(wordlist 68001,68500,$(1)),$(2))
        @$(call emit-line,$(wordlist 68501,69000,$(1)),$(2))
        @$(call emit-line,$(wordlist 69001,69500,$(1)),$(2))
        @$(call emit-line,$(wordlist 69501,70000,$(1)),$(2))
        @$(call emit-line,$(wordlist 70001,70500,$(1)),$(2))
        @$(call emit-line,$(wordlist 70501,71000,$(1)),$(2))
        @$(call emit-line,$(wordlist 71001,71500,$(1)),$(2))
        @$(call emit-line,$(wordlist 71501,72000,$(1)),$(2))
        @$(call emit-line,$(wordlist 72001,72500,$(1)),$(2))
        @$(call emit-line,$(wordlist 72501,73000,$(1)),$(2))
        @$(call emit-line,$(wordlist 73001,73500,$(1)),$(2))
        @$(call emit-line,$(wordlist 73501,74000,$(1)),$(2))
        @$(call emit-line,$(wordlist 74001,74500,$(1)),$(2))
        @$(call emit-line,$(wordlist 74501,75000,$(1)),$(2))
        @$(call emit-line,$(wordlist 75001,75500,$(1)),$(2))
        @$(call emit-line,$(wordlist 75501,76000,$(1)),$(2))
        @$(call emit-line,$(wordlist 76001,76500,$(1)),$(2))
        @$(call emit-line,$(wordlist 76501,77000,$(1)),$(2))
        @$(call emit-line,$(wordlist 77001,77500,$(1)),$(2))
        @$(call emit-line,$(wordlist 77501,78000,$(1)),$(2))
        @$(call emit-line,$(wordlist 78001,78500,$(1)),$(2))
        @$(call emit-line,$(wordlist 78501,79000,$(1)),$(2))
        @$(call emit-line,$(wordlist 79001,79500,$(1)),$(2))
        @$(call emit-line,$(wordlist 79501,80000,$(1)),$(2))
        @$(call emit-line,$(wordlist 80001,80500,$(1)),$(2))
        @$(call emit-line,$(wordlist 80501,81000,$(1)),$(2))
        @$(call emit-line,$(wordlist 81001,81500,$(1)),$(2))
        @$(call emit-line,$(wordlist 81501,82000,$(1)),$(2))
        @$(call emit-line,$(wordlist 82001,82500,$(1)),$(2))
        @$(call emit-line,$(wordlist 82501,83000,$(1)),$(2))
        @$(call emit-line,$(wordlist 83001,83500,$(1)),$(2))
        @$(call emit-line,$(wordlist 83501,84000,$(1)),$(2))
        @$(call emit-line,$(wordlist 84001,84500,$(1)),$(2))
        @$(call emit-line,$(wordlist 84501,85000,$(1)),$(2))
        @$(call emit-line,$(wordlist 85001,85500,$(1)),$(2))
        @$(call emit-line,$(wordlist 85501,86000,$(1)),$(2))
        @$(call emit-line,$(wordlist 86001,86500,$(1)),$(2))
        @$(call emit-line,$(wordlist 86501,87000,$(1)),$(2))
        @$(call emit-line,$(wordlist 87001,87500,$(1)),$(2))
        @$(call emit-line,$(wordlist 87501,88000,$(1)),$(2))
        @$(call emit-line,$(wordlist 88001,88500,$(1)),$(2))
        @$(call emit-line,$(wordlist 88501,89000,$(1)),$(2))
        @$(call emit-line,$(wordlist 89001,89500,$(1)),$(2))
        @$(call emit-line,$(wordlist 89501,90000,$(1)),$(2))
        @$(call emit-line,$(wordlist 90001,90500,$(1)),$(2))
        @$(call emit-line,$(wordlist 90501,91000,$(1)),$(2))
        @$(call emit-line,$(wordlist 91001,91500,$(1)),$(2))
        @$(call emit-line,$(wordlist 91501,92000,$(1)),$(2))
        @$(call emit-line,$(wordlist 92001,92500,$(1)),$(2))
        @$(call emit-line,$(wordlist 92501,93000,$(1)),$(2))
        @$(call emit-line,$(wordlist 93001,93500,$(1)),$(2))
        @$(call emit-line,$(wordlist 93501,94000,$(1)),$(2))
        @$(call emit-line,$(wordlist 94001,94500,$(1)),$(2))
        @$(call emit-line,$(wordlist 94501,95000,$(1)),$(2))
        @$(call emit-line,$(wordlist 95001,95500,$(1)),$(2))
        @$(call emit-line,$(wordlist 95501,96000,$(1)),$(2))
        @$(call emit-line,$(wordlist 96001,96500,$(1)),$(2))
        @$(call emit-line,$(wordlist 96501,97000,$(1)),$(2))
        @$(call emit-line,$(wordlist 97001,97500,$(1)),$(2))
        @$(call emit-line,$(wordlist 97501,98000,$(1)),$(2))
        @$(call emit-line,$(wordlist 98001,98500,$(1)),$(2))
        @$(call emit-line,$(wordlist 98501,99000,$(1)),$(2))
        @$(call emit-line,$(wordlist 99001,99500,$(1)),$(2))
        @$(if $(wordlist 99501,99502,$(1)),$(error dump-words-to-file: Too many words ($(words $(1)))))
endef
# Return jar arguments to compress files in a given directory
# $(1): directory
#
# Returns an @-file argument that contains the output of a subshell
# that looks like -C $(1) path/to/file1 -C $(1) path/to/file2
# Also adds "-C out/empty ." which avoids errors in jar when
# there are no files in the directory.
define jar-args-sorted-files-in-directory
    @<(find $(1) -type f | sort | $(JAR_ARGS) $(1); echo "-C $(EMPTY_DIRECTORY) .")
endef

# append additional Java sources(resources/Proto sources, and etc) to $(1).
define fetch-additional-java-source
$(hide) if [ -d "$(PRIVATE_SOURCE_INTERMEDIATES_DIR)" ]; then \
    find $(PRIVATE_SOURCE_INTERMEDIATES_DIR) -name '*.java' -and -not -name '.*' >> $(1); \
fi
endef

# Some historical notes:
# - below we write the list of java files to java-source-list to avoid argument
#   list length problems with Cygwin
# - we filter out duplicate java file names because eclipse's compiler
#   doesn't like them.
define write-java-source-list
@echo "$($(PRIVATE_PREFIX)DISPLAY) Java source list: $(PRIVATE_MODULE)"
$(hide) rm -f $@
$(call dump-words-to-file,$(sort $(PRIVATE_JAVA_SOURCES)),$@.tmp)
$(call fetch-additional-java-source,$@.tmp)
$(hide) tr ' ' '\n' < $@.tmp | $(NORMALIZE_PATH) | sort -u > $@
endef

# Common definition to invoke javac on the host and target.
#
# $(1): javac
# $(2): classpath_libs
define compile-java
$(hide) rm -f $@
$(hide) rm -rf $(PRIVATE_CLASS_INTERMEDIATES_DIR) $(PRIVATE_ANNO_INTERMEDIATES_DIR)
$(hide) mkdir -p $(dir $@)
$(hide) mkdir -p $(PRIVATE_CLASS_INTERMEDIATES_DIR) $(PRIVATE_ANNO_INTERMEDIATES_DIR)
$(if $(PRIVATE_SRCJARS),\
    $(ZIPSYNC) -d $(PRIVATE_SRCJAR_INTERMEDIATES_DIR) -l $(PRIVATE_SRCJAR_LIST_FILE) -f "*.java" $(PRIVATE_SRCJARS))
$(hide) if [ -s $(PRIVATE_JAVA_SOURCE_LIST) $(if $(PRIVATE_SRCJARS),-o -s $(PRIVATE_SRCJAR_LIST_FILE) )] ; then \
    $(SOONG_JAVAC_WRAPPER) $(JAVAC_WRAPPER) $(1) -encoding UTF-8 \
    $(if $(findstring true,$(PRIVATE_WARNINGS_ENABLE)),$(xlint_unchecked),) \
    $(if $(PRIVATE_USE_SYSTEM_MODULES), \
      $(addprefix --system=,$(PRIVATE_SYSTEM_MODULES_DIR)), \
      $(addprefix -bootclasspath ,$(strip \
          $(call normalize-path-list,$(PRIVATE_BOOTCLASSPATH)) \
          $(PRIVATE_EMPTY_BOOTCLASSPATH)))) \
    $(if $(PRIVATE_USE_SYSTEM_MODULES), \
      $(if $(PRIVATE_PATCH_MODULE), \
        --patch-module=$(PRIVATE_PATCH_MODULE)=$(call normalize-path-list,. $(2)))) \
    $(addprefix -classpath ,$(call normalize-path-list,$(strip \
      $(if $(PRIVATE_USE_SYSTEM_MODULES), \
        $(filter-out $(PRIVATE_SYSTEM_MODULES_LIBS),$(PRIVATE_BOOTCLASSPATH))) \
      $(2)))) \
    $(if $(findstring true,$(PRIVATE_WARNINGS_ENABLE)),$(xlint_unchecked),) \
    -d $(PRIVATE_CLASS_INTERMEDIATES_DIR) -s $(PRIVATE_ANNO_INTERMEDIATES_DIR) \
    $(PRIVATE_JAVACFLAGS) \
    \@$(PRIVATE_JAVA_SOURCE_LIST) \
    $(if $(PRIVATE_SRCJARS),\@$(PRIVATE_SRCJAR_LIST_FILE)) \
    || ( rm -rf $(PRIVATE_CLASS_INTERMEDIATES_DIR) ; exit 41 ) \
fi
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
$(hide) $(SOONG_ZIP) -jar -o $@ -C $(PRIVATE_CLASS_INTERMEDIATES_DIR) -D $(PRIVATE_CLASS_INTERMEDIATES_DIR)
$(if $(PRIVATE_EXTRA_JAR_ARGS),$(call add-java-resources-to,$@))
endef

define transform-java-to-header.jar
@echo "$($(PRIVATE_PREFIX)DISPLAY) Turbine: $(PRIVATE_MODULE)"
@mkdir -p $(dir $@)
@rm -rf $(dir $@)/classes-turbine
@mkdir $(dir $@)/classes-turbine
$(hide) if [ -s $(PRIVATE_JAVA_SOURCE_LIST) -o -n "$(PRIVATE_SRCJARS)" ] ; then \
    $(JAVA) -jar $(TURBINE) \
    --output $@.premerged --temp_dir $(dir $@)/classes-turbine \
    --sources \@$(PRIVATE_JAVA_SOURCE_LIST) --source_jars $(PRIVATE_SRCJARS) \
    --javacopts $(PRIVATE_JAVACFLAGS) $(COMMON_JDK_FLAGS) -- \
    $(if $(PRIVATE_USE_SYSTEM_MODULES), \
      --system $(PRIVATE_SYSTEM_MODULES_DIR), \
      --bootclasspath $(strip $(PRIVATE_BOOTCLASSPATH))) \
    --classpath $(strip $(if $(PRIVATE_USE_SYSTEM_MODULES), \
        $(filter-out $(PRIVATE_SYSTEM_MODULES_LIBS),$(PRIVATE_BOOTCLASSPATH))) \
      $(PRIVATE_ALL_JAVA_HEADER_LIBRARIES)) \
    || ( rm -rf $(dir $@)/classes-turbine ; exit 41 ) && \
    $(MERGE_ZIPS) -j --ignore-duplicates -stripDir META-INF $@.tmp $@.premerged $(PRIVATE_STATIC_JAVA_HEADER_LIBRARIES) ; \
else \
    $(MERGE_ZIPS) -j --ignore-duplicates -stripDir META-INF $@.tmp $(PRIVATE_STATIC_JAVA_HEADER_LIBRARIES) ; \
fi
$(hide) $(ZIPTIME) $@.tmp
$(hide) $(call commit-change-for-toc,$@)
endef

# Runs jarjar on an input file.  Jarjar doesn't exit with a nonzero return code
# when there is a syntax error in a rules file and doesn't write the output
# file, so removes the output file before running jarjar and check if it exists
# after running jarjar.
define transform-jarjar
echo $($(PRIVATE_PREFIX)DISPLAY) JarJar: $@
rm -f $@
$(JAVA) -jar $(JARJAR) process $(PRIVATE_JARJAR_RULES) $< $@
[ -e $@ ] || (echo "Missing output file"; exit 1)
endef

# Moves $1.tmp to $1 if necessary. This is designed to be used with
# .KATI_RESTAT. For kati, this function doesn't update the timestamp
# of $1 when $1.tmp is identical to $1 so that ninja won't rebuild
# targets which depend on $1.
define commit-change-for-toc
$(hide) if cmp -s $1.tmp $1 ; then \
 rm $1.tmp ; \
else \
 mv $1.tmp $1 ; \
fi
endef

ifeq (,$(TARGET_BUILD_APPS))

## Rule to create a table of contents from a .dex file.
## Must be called with $(eval).
# $(1): The directory which contains classes*.dex files
define _transform-dex-to-toc
$1/classes.dex.toc: PRIVATE_INPUT_DEX_FILES := $1/classes*.dex
$1/classes.dex.toc: $1/classes.dex $(DEXDUMP)
	@echo Generating TOC: $$@
	$(hide) ANDROID_LOG_TAGS="*:e" $(DEXDUMP) -l xml $$(PRIVATE_INPUT_DEX_FILES) > $$@.tmp
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


# Takes an sdk version that might be PLATFORM_VERSION_CODENAME (for example P),
# returns a number greater than the highest existing sdk version if it is, or
# the input if it is not.
define codename-or-sdk-to-sdk
$(if $(filter $(1),$(PLATFORM_VERSION_CODENAME)),10000,$(1))
endef

# Uses LOCAL_SDK_VERSION and PLATFORM_SDK_VERSION to determine a compileSdkVersion
# in the form of a number or a codename (28 or P)
define module-sdk-version
$(strip \
  $(if $(filter-out current system_current test_current core_current,$(LOCAL_SDK_VERSION)), \
    $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION)), \
    $(PLATFORM_SDK_VERSION)))
endef

# Uses LOCAL_SDK_VERSION and DEFAULT_APP_TARGET_SDK to determine
# a targetSdkVersion in the form of a number or a codename (28 or P).
define module-target-sdk-version
$(strip \
  $(if $(filter-out current system_current test_current core_current,$(LOCAL_SDK_VERSION)), \
    $(call get-numeric-sdk-version,$(LOCAL_SDK_VERSION)), \
    $(DEFAULT_APP_TARGET_SDK)))
endef

# Uses LOCAL_MIN_SDK_VERSION, LOCAL_SDK_VERSION and DEFAULT_APP_TARGET_SDK to determine
# a minSdkVersion in the form of a number or a codename (28 or P).
define module-min-sdk-version
$(if $(LOCAL_MIN_SDK_VERSION),$(LOCAL_MIN_SDK_VERSION),$(call module-target-sdk-version))
endef


define transform-classes.jar-to-dex
@echo "target Dex: $(PRIVATE_MODULE)"
@mkdir -p $(dir $@)tmp
$(hide) rm -f $(dir $@)classes*.dex $(dir $@)d8_input.jar
$(hide) $(ZIP2ZIP) -j -i $< -o $(dir $@)d8_input.jar "**/*.class"
$(hide) $(D8_WRAPPER) $(D8_COMMAND) \
    --output $(dir $@)tmp \
    $(addprefix --lib ,$(PRIVATE_D8_LIBS)) \
    --min-api $(PRIVATE_MIN_SDK_VERSION) \
    $(subst --main-dex-list=, --main-dex-list , \
        $(filter-out --core-library --multi-dex --minimal-main-dex,$(PRIVATE_DX_FLAGS))) \
    $(dir $@)d8_input.jar
$(hide) mv $(dir $@)tmp/* $(dir $@)
$(hide) rm -f $(dir $@)d8_input.jar
$(hide) rm -rf $(dir $@)tmp
endef

# We need the extra blank line, so that the command will be on a separate line.
# $(1): the package
# $(2): the ABI name
# $(3): the list of shared libraies
define _add-jni-shared-libs-to-package-per-abi
$(hide) cp $(3) $(dir $(1))lib/$(2)

endef

# $(1): the package file
# $(2): if true, uncompress jni libs
define create-jni-shared-libs-package
rm -rf $(dir $(1))lib
mkdir -p $(addprefix $(dir $(1))lib/,$(PRIVATE_JNI_SHARED_LIBRARIES_ABI))
$(foreach abi,$(PRIVATE_JNI_SHARED_LIBRARIES_ABI),\
  $(call _add-jni-shared-libs-to-package-per-abi,$(1),$(abi),\
    $(patsubst $(abi):%,%,$(filter $(abi):%,$(PRIVATE_JNI_SHARED_LIBRARIES)))))
$(SOONG_ZIP) $(if $(2),-L 0) -o $(1) -C $(dir $(1)) -D $(dir $(1))lib
rm -rf $(dir $(1))lib
endef

# $(1): the jar file.
# $(2): the classes.dex file.
define create-dex-jar
find $(dir $(2)) -maxdepth 1 -name "classes*.dex" | sort > $(1).lst
$(SOONG_ZIP) -o $(1) -C $(dir $(2)) -l $(1).lst
endef

# Add java resources added by the current module to an existing package.
# $(1) destination package.
define add-java-resources-to
  $(call _java-resources,$(1),u)
endef

# Add java resources added by the current module to a new jar.
# $(1) destination jar.
define create-java-resources-jar
  $(call _java-resources,$(1),c)
endef

define _java-resources
$(call dump-words-to-file, $(PRIVATE_EXTRA_JAR_ARGS), $(1).jar-arg-list)
$(hide) $(JAR) $(2)f $(1) @$(1).jar-arg-list
@rm -f $(1).jar-arg-list
endef

# Add resources (non .class files) from a jar to a package
# $(1): the package file
# $(2): the jar file
# $(3): temporary directory
define add-jar-resources-to-package
  rm -rf $(3)
  mkdir -p $(3)
  zipinfo -1 $(2) > /dev/null
  unzip -qo $(2) -d $(3) $$(zipinfo -1 $(2) | grep -v -E "\.class$$")
  $(JAR) uf $(1) $(call jar-args-sorted-files-in-directory,$(3))
endef

# $(1): the output resources jar.
# $(2): the input jar
define extract-resources-jar
  $(ZIP2ZIP) -i $(2) -o $(1) -x '**/*.class' -x '**/*/'
endef

# Sign a package using the specified key/cert.
#
define sign-package
$(call sign-package-arg,$@)
endef

# $(1): the package file we are signing.
define sign-package-arg
$(hide) mv $(1) $(1).unsigned
$(hide) $(JAVA) -Djava.library.path=$$(dirname $(SIGNAPK_JNI_LIBRARY_PATH)) -jar $(SIGNAPK_JAR) \
    $(if $(strip $(PRIVATE_CERTIFICATE_LINEAGE)), --lineage $(PRIVATE_CERTIFICATE_LINEAGE)) \
    $(if $(strip $(PRIVATE_ROTATION_MIN_SDK_VERSION)), --rotation-min-sdk-version $(PRIVATE_ROTATION_MIN_SDK_VERSION)) \
    $(PRIVATE_CERTIFICATE) $(PRIVATE_PRIVATE_KEY) \
    $(PRIVATE_ADDITIONAL_CERTIFICATES) $(1).unsigned $(1).signed
$(hide) mv $(1).signed $(1)
endef

# Align STORED entries of a package on 4-byte boundaries to make them easier to mmap.
#
define align-package
$(hide) if ! $(ZIPALIGN) -c -p 4 $@ >/dev/null ; then \
  mv $@ $@.unaligned; \
  $(ZIPALIGN) \
    -f \
    -p \
    4 \
    $@.unaligned $@.aligned; \
  mv $@.aligned $@; \
  fi
endef

# Verifies ZIP alignment of a package.
#
define check-package-alignment
$(hide) if ! $(ZIPALIGN) -c -p 4 $@ >/dev/null ; then \
    $(call echo-error,$@,Improper package alignment); \
    exit 1; \
  fi
endef

# Compress a package using the standard gzip algorithm.
define compress-package
$(hide) \
  mv $@ $@.uncompressed; \
  $(GZIP) -9 -c $@.uncompressed > $@.compressed; \
  rm -f $@.uncompressed; \
  mv $@.compressed $@;
endef

ifeq ($(HOST_OS),linux)
# Runs appcompat and store logs in $(PRODUCT_OUT)/appcompat
define extract-package
$(AAPT2) dump resources $@ | awk -F ' |=' '/^Package/{print $$3; exit}' >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log &&
endef
define appcompat-header
$(hide) \
  mkdir -p $(PRODUCT_OUT)/appcompat && \
  rm -f $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log && \
  echo -n "Package name: " >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log && \
  $(extract-package) \
  echo "Module name in Android tree: $(PRIVATE_MODULE)" >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log && \
  echo "Local path in Android tree: $(PRIVATE_PATH)" >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log && \
  echo "Install path: $(patsubst $(PRODUCT_OUT)/%,%,$(PRIVATE_INSTALLED_MODULE))" >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log && \
  echo >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log
endef
ART_VERIDEX_APPCOMPAT_SCRIPT:=$(HOST_OUT)/bin/appcompat.sh
define run-appcompat
$(hide) \
  echo "appcompat.sh output:" >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log && \
  PACKAGING=$(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING ANDROID_LOG_TAGS="*:e" $(ART_VERIDEX_APPCOMPAT_SCRIPT) --dex-file=$@ --api-flags=$(INTERNAL_PLATFORM_HIDDENAPI_FLAGS) 2>&1 >> $(PRODUCT_OUT)/appcompat/$(PRIVATE_MODULE).log
endef
appcompat-files = \
  $(AAPT2) \
  $(ART_VERIDEX_APPCOMPAT_SCRIPT) \
  $(INTERNAL_PLATFORM_HIDDENAPI_FLAGS) \
  $(HOST_OUT_EXECUTABLES)/veridex \
  $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/core_dex_intermediates/classes.dex \
  $(TARGET_OUT_COMMON_INTERMEDIATES)/PACKAGING/oahl_dex_intermediates/classes.dex
else
appcompat-header =
run-appcompat =
appcompat-files =
endif  # HOST_OS == linux
.KATI_READONLY: appcompat-header run-appcompat appcompat-files

# Remove dynamic timestamps from packages
#
define remove-timestamps-from-package
$(hide) $(ZIPTIME) $@
endef

# Uncompress dex files embedded in an apk.
#
define uncompress-dexs
  if (zipinfo $@ '*.dex' 2>/dev/null | grep -v ' stor ' >/dev/null) ; then \
    $(ZIP2ZIP) -i $@ -o $@.tmp -0 "classes*.dex" && \
    mv -f $@.tmp $@ ; \
  fi
endef

# Uncompress shared JNI libraries embedded in an apk.
#
define uncompress-prebuilt-embedded-jni-libs
  if (zipinfo $@ 'lib/*.so' 2>/dev/null | grep -v ' stor ' >/dev/null) ; then \
    $(ZIP2ZIP) -i $@ -o $@.tmp -0 'lib/**/*.so' && mv -f $@.tmp $@ ; \
  fi
endef

# Verifies shared JNI libraries and dex files in an apk are uncompressed.
#
define check-jni-dex-compression
  if (zipinfo $@ 'lib/*.so' '*.dex' 2>/dev/null | grep -v ' stor ' >/dev/null) ; then \
    $(call echo-error,$@,Contains compressed JNI libraries and/or dex files); \
    exit 1; \
  fi
endef

# Remove unwanted shared JNI libraries embedded in an apk.
#
define remove-unwanted-prebuilt-embedded-jni-libs
  $(if $(PRIVATE_EMBEDDED_JNI_LIBS), \
    $(ZIP2ZIP) -i $@ -o $@.tmp \
      -x 'lib/**/*.so' $(addprefix -X ,$(PRIVATE_EMBEDDED_JNI_LIBS)) && \
    mv -f $@.tmp $@)
endef

# TODO(joeo): If we can ever upgrade to post 3.81 make and get the
# new prebuilt rules to work, we should change this to copy the
# resources to the out directory and then copy the resources.

# Note: we intentionally don't clean PRIVATE_CLASS_INTERMEDIATES_DIR
# in transform-java-to-classes for the sake of vm-tests.
define transform-host-java-to-package
@echo "Host Java: $(PRIVATE_MODULE) ($(PRIVATE_CLASS_INTERMEDIATES_DIR))"
$(call compile-java,$(HOST_JAVAC),$(PRIVATE_ALL_JAVA_LIBRARIES))
endef

# Note: we intentionally don't clean PRIVATE_CLASS_INTERMEDIATES_DIR
# in transform-java-to-classes for the sake of vm-tests.
define transform-host-java-to-dalvik-package
@echo "Dalvik Java: $(PRIVATE_MODULE) ($(PRIVATE_CLASS_INTERMEDIATES_DIR))"
$(call compile-java,$(HOST_JAVAC),$(PRIVATE_ALL_JAVA_HEADER_LIBRARIES))
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
$(2): $(1)
	@echo "Copy: $$@"
	$$(copy-file-to-target)
endef

# Define a rule to copy a license metadata file. For use via $(eval).
# $(1): source license metadata file
# $(2): destination license metadata file
# $(3): built targets
# $(4): installed targets
define copy-one-license-metadata-file
$(2): PRIVATE_BUILT=$(3)
$(2): PRIVATE_INSTALLED=$(4)
$(2): $(1)
	@echo "Copy: $$@"
	$$(call copy-license-metadata-file-to-target,$$(PRIVATE_BUILT),$$(PRIVATE_INSTALLED))
endef

define copy-and-uncompress-dexs
$(2): $(1) $(ZIPALIGN) $(ZIP2ZIP)
	@echo "Uncompress dexs in: $$@"
	$$(copy-file-to-target)
	$$(uncompress-dexs)
	$$(align-package)
endef

# Create copy pair for compatibility suite
# Filter out $(LOCAL_INSTALLED_MODULE) to prevent overriding target
# $(1): source path
# $(2): destination path
# The format of copy pair is src:dst
define compat-copy-pair
$(if $(filter-out $(2), $(LOCAL_INSTALLED_MODULE)), $(1):$(2))
endef

# Create copy pair for $(1) $(2)
# If $(2) is substring of $(3) do nothing.
# $(1): source path
# $(2): destination path
# $(3): filter-out target
# The format of copy pair is src:dst
define filter-copy-pair
$(if $(findstring $(2), $(3)),,$(1):$(2))
endef

# Copies many files.
# $(1): The files to copy.  Each entry is a ':' separated src:dst pair
# $(2): An optional directory to prepend to the destination
# Evaluates to the list of the dst files (ie suitable for a dependency list)
define copy-many-files
$(foreach f, $(1), $(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(eval _cmf_dest := $(word 2,$(_cmf_tuple))) \
    $(if $(strip $(2)), \
      $(eval _cmf_dest := $(patsubst %/,%,$(strip $(2)))/$(patsubst /%,%,$(_cmf_dest)))) \
    $(if $(filter-out $(_cmf_src), $(_cmf_dest)), \
      $(eval $(call copy-one-file,$(_cmf_src),$(_cmf_dest)))) \
    $(_cmf_dest)))
endef

# Copy the file only if it's a well-formed init script file. For use via $(eval).
# $(1): source file
# $(2): destination file
define copy-init-script-file-checked
ifdef TARGET_BUILD_UNBUNDLED
# TODO (b/185624993): Remove the check on TARGET_BUILD_UNBUNDLED when host_init_verifier can run
# without requiring the HIDL interface map.
$(2): $(1)
else ifneq ($(HOST_OS),darwin)
# Host init verifier doesn't exist on darwin.
$(2): \
	$(1) \
	$(HOST_INIT_VERIFIER) \
	$(call intermediates-dir-for,ETC,passwd_system)/passwd_system \
	$(call intermediates-dir-for,ETC,passwd_system_ext)/passwd_system_ext \
	$(call intermediates-dir-for,ETC,passwd_vendor)/passwd_vendor \
	$(call intermediates-dir-for,ETC,passwd_odm)/passwd_odm \
	$(call intermediates-dir-for,ETC,passwd_product)/passwd_product \
	$(call intermediates-dir-for,ETC,plat_property_contexts)/plat_property_contexts \
	$(call intermediates-dir-for,ETC,system_ext_property_contexts)/system_ext_property_contexts \
	$(call intermediates-dir-for,ETC,product_property_contexts)/product_property_contexts \
	$(call intermediates-dir-for,ETC,vendor_property_contexts)/vendor_property_contexts \
	$(call intermediates-dir-for,ETC,odm_property_contexts)/odm_property_contexts
	$(hide) $(HOST_INIT_VERIFIER) \
	  -p $(call intermediates-dir-for,ETC,passwd_system)/passwd_system \
	  -p $(call intermediates-dir-for,ETC,passwd_system_ext)/passwd_system_ext \
	  -p $(call intermediates-dir-for,ETC,passwd_vendor)/passwd_vendor \
	  -p $(call intermediates-dir-for,ETC,passwd_odm)/passwd_odm \
	  -p $(call intermediates-dir-for,ETC,passwd_product)/passwd_product \
	  --property-contexts=$(call intermediates-dir-for,ETC,plat_property_contexts)/plat_property_contexts \
	  --property-contexts=$(call intermediates-dir-for,ETC,system_ext_property_contexts)/system_ext_property_contexts \
	  --property-contexts=$(call intermediates-dir-for,ETC,product_property_contexts)/product_property_contexts \
	  --property-contexts=$(call intermediates-dir-for,ETC,vendor_property_contexts)/vendor_property_contexts \
	  --property-contexts=$(call intermediates-dir-for,ETC,odm_property_contexts)/odm_property_contexts \
	  $$<
else
$(2): $(1)
endif
	@echo "Copy init script: $$@"
	$$(copy-file-to-target)
endef

# Copies many init script files and check they are well-formed.
# $(1): The init script files to copy.  Each entry is a ':' separated src:dst pair.
# Evaluates to the list of the dst files. (ie suitable for a dependency list.)
define copy-many-init-script-files-checked
$(foreach f, $(1), $(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(eval _cmf_dest := $(word 2,$(_cmf_tuple))) \
    $(eval $(call copy-init-script-file-checked,$(_cmf_src),$(_cmf_dest))) \
    $(_cmf_dest)))
endef

# Copy the file only if it's a well-formed xml file. For use via $(eval).
# $(1): source file
# $(2): destination file, must end with .xml.
define copy-xml-file-checked
$(2): $(1) $(XMLLINT)
	@echo "Copy xml: $$@"
	$(hide) $(XMLLINT) $$< >/dev/null  # Don't print the xml file to stdout.
	$$(copy-file-to-target)
endef

# Copies many xml files and check they are well-formed.
# $(1): The xml files to copy.  Each entry is a ':' separated src:dst pair.
# Evaluates to the list of the dst files. (ie suitable for a dependency list.)
define copy-many-xml-files-checked
$(foreach f, $(1), $(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(eval _cmf_dest := $(word 2,$(_cmf_tuple))) \
    $(eval $(call copy-xml-file-checked,$(_cmf_src),$(_cmf_dest))) \
    $(_cmf_dest)))
endef

# Copy the file only if it is a well-formed manifest file. For use viea $(eval)
# $(1): source file
# $(2): destination file
define copy-vintf-manifest-checked
$(2): $(1) $(HOST_OUT_EXECUTABLES)/assemble_vintf
	@echo "Copy xml: $$@"
	$(hide) mkdir -p "$$(dir $$@)"
	$(hide) VINTF_IGNORE_TARGET_FCM_VERSION=true\
		$(HOST_OUT_EXECUTABLES)/assemble_vintf -i $$< -o $$@
endef

# Copies many vintf manifest files checked.
# $(1): The files to copy.  Each entry is a ':' separated src:dst pair
# Evaluates to the list of the dst files (ie suitable for a dependency list)
define copy-many-vintf-manifest-files-checked
$(foreach f, $(1), $(strip \
    $(eval _cmf_tuple := $(subst :, ,$(f))) \
    $(eval _cmf_src := $(word 1,$(_cmf_tuple))) \
    $(eval _cmf_dest := $(word 2,$(_cmf_tuple))) \
    $(eval $(call copy-vintf-manifest-checked,$(_cmf_src),$(_cmf_dest))) \
    $(_cmf_dest)))
endef

# Copy the file only if it's not an ELF file. For use via $(eval).
# $(1): source file
# $(2): destination file
# $(3): message to print on error
define copy-non-elf-file-checked
$(eval check_non_elf_file_timestamp := \
    $(call intermediates-dir-for,FAKE,check-non-elf-file-timestamps)/$(2).timestamp)
$(check_non_elf_file_timestamp): $(1) $(LLVM_READOBJ)
	@echo "Check non-ELF: $$<"
	$(hide) mkdir -p "$$(dir $$@)"
	$(hide) rm -f "$$@"
	$(hide) \
	    if $(LLVM_READOBJ) -h "$$<" >/dev/null 2>&1; then \
	        $(call echo-error,$(2),$(3)); \
	        $(call echo-error,$(2),found ELF file: $$<); \
	        false; \
	    fi
	$(hide) touch "$$@"

$(2): $(1) $(check_non_elf_file_timestamp)
	@echo "Copy non-ELF: $$@"
	$$(copy-file-to-target)

check-elf-prebuilt-product-copy-files: $(check_non_elf_file_timestamp)
endef

# The -t option to acp and the -p option to cp is
# required for OSX.  OSX has a ridiculous restriction
# where it's an error for a .a file's modification time
# to disagree with an internal timestamp, and this
# macro is used to install .a files (among other things).

# Copy a single file from one place to another,
# preserving permissions and overwriting any existing
# file.
# When we used acp, it could not handle high resolution timestamps
# on file systems like ext4. Because of that, '-t' option was disabled
# and copy-file-to-target was identical to copy-file-to-new-target.
# Keep the behavior until we audit and ensure that switching this back
# won't break anything.
define copy-file-to-target
@mkdir -p $(dir $@)
$(hide) rm -f $@
$(hide) cp "$<" "$@"
endef

# Same as copy-file-to-target, but assume file is a licenes metadata file,
# and append built from $(1) and installed from $(2).
define copy-license-metadata-file-to-target
@mkdir -p $(dir $@)
$(hide) rm -f $@
$(hide) cp "$<" "$@" $(strip \
  $(foreach b,$(1), && (grep -F 'built: "'"$(b)"'"' "$@" >/dev/null || echo 'built: "'"$(b)"'"' >>"$@")) \
  $(foreach i,$(2), && (grep -F 'installed: "'"$(i)"'"' "$@" >/dev/null || echo 'installed: "'"$(i)"'"' >>"$@")) \
)
endef

# The same as copy-file-to-target, but use the local
# cp command instead of acp.
define copy-file-to-target-with-cp
@mkdir -p $(dir $@)
$(hide) rm -f $@
$(hide) cp -p "$<" "$@"
endef

# The same as copy-file-to-target, but don't preserve
# the old modification time.
define copy-file-to-new-target
@mkdir -p $(dir $@)
$(hide) rm -f $@
$(hide) cp $< $@
endef

# The same as copy-file-to-new-target, but use the local
# cp command instead of acp.
define copy-file-to-new-target-with-cp
@mkdir -p $(dir $@)
$(hide) rm -f $@
$(hide) cp $< $@
endef

# The same as copy-file-to-new-target, but preserve symlinks. Symlinks are
# converted to absolute to not break.
define copy-file-or-link-to-new-target
@mkdir -p $(dir $@)
$(hide) rm -f $@
$(hide) if [ -h $< ]; then \
  ln -s $$(realpath $<) $@; \
else \
  cp $< $@; \
fi
endef

# Copy a prebuilt file to a target location.
define transform-prebuilt-to-target
@echo "$($(PRIVATE_PREFIX)DISPLAY) Prebuilt: $(PRIVATE_MODULE) ($@)"
$(copy-file-to-target)
endef

# Copy a prebuilt file to a target location, but preserve symlinks rather than
# dereference them.
define copy-or-link-prebuilt-to-target
@echo "$($(PRIVATE_PREFIX)DISPLAY) Prebuilt: $(PRIVATE_MODULE) ($@)"
$(copy-file-or-link-to-new-target)
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

# Define a rule to create a symlink to a file.
# $(1): any dependencies
# $(2): source (may be relative)
# $(3): full path to destination
define symlink-file
$(eval $(_symlink-file))
$(eval $(call declare-license-metadata,$(3),,,,,,))
$(eval $(call declare-license-deps,$(3),$(1)))
endef

define _symlink-file
$(3): $(1)
	@echo "Symlink: $$@ -> $(2)"
	@mkdir -p $$(dir $$@)
	@rm -rf $$@
	$(hide) ln -sf $(2) $$@
$(3): .KATI_SYMLINK_OUTPUTS := $(3)
endef

# Copy an apk to a target location while removing classes*.dex
# $(1): source file
# $(2): destination file
# $(3): LOCAL_STRIP_DEX, if non-empty then strip classes*.dex
define dexpreopt-copy-jar
$(2): $(1)
	@echo "Copy: $$@"
	$$(copy-file-to-target)
	$(if $(3),$$(call dexpreopt-remove-classes.dex,$$@))
endef

# $(1): the .jar or .apk to remove classes.dex. Note that if all dex files
# are uncompressed in the archive, then dexopt will not do a copy of the dex
# files and we should not strip.
define dexpreopt-remove-classes.dex
$(hide) if (zipinfo $1 '*.dex' 2>/dev/null | grep -v ' stor ' >/dev/null) ; then \
zip --quiet --delete $(1) classes.dex; \
dex_index=2; \
while zip --quiet --delete $(1) classes$${dex_index}.dex > /dev/null; do \
  let dex_index=dex_index+1; \
done \
fi
endef

# Copy an unstripped binary to the symbols directory while also extracting
# a hash mapping to the mapping directory.
# $(1): unstripped intermediates file
# $(2): path in symbols directory
define copy-unstripped-elf-file-with-mapping
$(call _copy-symbols-file-with-mapping,$(1),$(2),\
  elf,$(patsubst $(TARGET_OUT_UNSTRIPPED)/%,$(call intermediates-dir-for,PACKAGING,elf_symbol_mapping)/%,$(2).textproto))
endef

# Copy an R8 dictionary to the packaging directory while also extracting
# a hash mapping to the mapping directory.
# $(1): unstripped intermediates file
# $(2): path in packaging directory
# $(3): path in mappings packaging directory
define copy-r8-dictionary-file-with-mapping
$(call _copy-symbols-file-with-mapping,$(1),$(2),r8,$(3))
endef

# Copy an unstripped binary or R8 dictionary to the symbols directory
# while also extracting a hash mapping to the mapping directory.
# $(1): unstripped intermediates file
# $(2): path in symbols directory
# $(3): file type (elf or r8)
# $(4): path in the mappings directory
#
# Regarding the restats at the end: I think you should only need to use KATI_RESTAT on $(2), but
# there appears to be a bug in kati where it was not adding restat=true in the ninja file unless we
# also added 4 to KATI_RESTAT.
define _copy-symbols-file-with-mapping
$(2): .KATI_IMPLICIT_OUTPUTS := $(4)
$(2): $(SYMBOLS_MAP)
$(2): $(1)
	@echo "Copy symbols with mapping: $$@"
	$$(copy-file-to-target)
	$(SYMBOLS_MAP) -$(strip $(3)) $(2) -write_if_changed $(4)
.KATI_RESTAT: $(2)
.KATI_RESTAT: $(4)
endef


###########################################################
## Commands to call R8
###########################################################

# Use --debug flag for eng builds by default
ifeq (eng,$(TARGET_BUILD_VARIANT))
R8_DEBUG_MODE := --debug
else
R8_DEBUG_MODE :=
endif

define transform-jar-to-dex-r8
@echo R8: $@
$(hide) rm -f $(PRIVATE_PROGUARD_DICTIONARY)
$(hide) $(R8_WRAPPER) $(R8_COMMAND) \
    -injars '$<' \
    --min-api $(PRIVATE_MIN_SDK_VERSION) \
    --no-data-resources \
    --force-proguard-compatibility --output $(subst classes.dex,,$@) \
    $(R8_DEBUG_MODE) \
    $(PRIVATE_PROGUARD_FLAGS) \
    $(addprefix -injars , $(PRIVATE_EXTRA_INPUT_JAR)) \
    $(PRIVATE_DX_FLAGS) \
    -ignorewarnings
$(hide) touch $(PRIVATE_PROGUARD_DICTIONARY)
endef

###########################################################
## Stuff source generated from one-off tools
###########################################################

define transform-generated-source
@echo "$($(PRIVATE_PREFIX)DISPLAY) Generated: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_CUSTOM_TOOL)
endef


###########################################################
## Assertions about attributes of the target
###########################################################

# $(1): The file to check
define get-file-size
stat -c "%s" "$(1)" | tr -d '\n'
endef

# $(1): The file(s) to check (often $@)
# $(2): The partition size.
define assert-max-image-size
$(if $(2), \
  size=$$(for i in $(1); do $(call get-file-size,$$i); echo +; done; echo 0); \
  total=$$(( $$( echo "$$size" ) )); \
  printname=$$(echo -n "$(1)" | tr " " +); \
  maxsize=$$(($(2))); \
  if [ "$$total" -gt "$$maxsize" ]; then \
    echo "error: $$printname too large ($$total > $$maxsize)"; \
    false; \
  elif [ "$$total" -gt $$((maxsize - 32768)) ]; then \
    echo "WARNING: $$printname approaching size limit ($$total now; limit $$maxsize)"; \
  fi \
 , \
  true \
 )
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
$$(PRODUCT_OUT)/$(2) : $$(LOCAL_PATH)/$(1)
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
$$(PRODUCT_OUT)/$(2) : $$(LOCAL_PATH)/$(1)
	$$(transform-prebuilt-to-target)
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

# ###############################################################
# Set up statistics gathering
# ###############################################################
STATS.MODULE_TYPE := \
  HOST_STATIC_LIBRARY \
  HOST_SHARED_LIBRARY \
  STATIC_LIBRARY \
  SHARED_LIBRARY \
  EXECUTABLE \
  HOST_EXECUTABLE \
  PACKAGE \
  PHONY_PACKAGE \
  HOST_PREBUILT \
  PREBUILT \
  MULTI_PREBUILT \
  JAVA_LIBRARY \
  STATIC_JAVA_LIBRARY \
  HOST_JAVA_LIBRARY \
  DROIDDOC \
  COPY_HEADERS \
  NATIVE_TEST \
  NATIVE_BENCHMARK \
  HOST_NATIVE_TEST \
  FUZZ_TEST \
  HOST_FUZZ_TEST \
  STATIC_TEST_LIBRARY \
  HOST_STATIC_TEST_LIBRARY \
  NOTICE_FILE \
  base_rules \
  HEADER_LIBRARY \
  HOST_TEST_CONFIG \
  TARGET_TEST_CONFIG

$(foreach s,$(STATS.MODULE_TYPE),$(eval STATS.MODULE_TYPE.$(s) :=))
define record-module-type
$(strip $(if $(LOCAL_RECORDED_MODULE_TYPE),,
  $(if $(filter-out $(SOONG_ANDROID_MK),$(LOCAL_MODULE_MAKEFILE)),
    $(if $(filter $(1),$(STATS.MODULE_TYPE)),
      $(eval LOCAL_RECORDED_MODULE_TYPE := true)
        $(eval STATS.MODULE_TYPE.$(1) += 1),
      $(error Invalid module type: $(1))))))
endef

###########################################################
## Compatibility suite tools
###########################################################

# Return a list of output directories for a given suite and the current LOCAL_MODULE.
# Can be passed a subdirectory to use for the common testcase directory.
define compatibility_suite_dirs
  $(strip \
    $(if $(COMPATIBILITY_TESTCASES_OUT_$(1)), \
      $(if $(COMPATIBILITY_TESTCASES_OUT_INCLUDE_MODULE_FOLDER_$(1))$(LOCAL_COMPATIBILITY_PER_TESTCASE_DIRECTORY),\
        $(COMPATIBILITY_TESTCASES_OUT_$(1))/$(LOCAL_MODULE)$(2),\
        $(COMPATIBILITY_TESTCASES_OUT_$(1)))) \
    $($(my_prefix)OUT_TESTCASES)/$(LOCAL_MODULE)$(2))
endef

# For each suite:
# 1. Copy the files to the many suite output directories.
#    And for test config files, we'll check the .xml is well-formed before copy.
# 2. Add all the files to each suite's dependent files list.
# 3. Do the dependency addition to my_all_targets.
# 4. Save the module name to COMPATIBILITY.$(suite).MODULES for each suite.
# 5. Collect files to dist to ALL_COMPATIBILITY_DIST_FILES.
# Requires for each suite: use my_compat_dist_config_$(suite) to define the test config.
#    and use my_compat_dist_$(suite) to define the others.
define create-suite-dependencies
$(foreach suite, $(LOCAL_COMPATIBILITY_SUITE), \
  $(eval $(if $(strip $(module_license_metadata)),\
    $$(foreach f,$$(my_compat_dist_$(suite)),$$(call declare-copy-target-license-metadata,$$(call word-colon,2,$$(f)),$$(call word-colon,1,$$(f)))),\
    $$(eval my_test_data += $$(my_compat_dist_$(suite))) \
  )) \
  $(eval $(if $(strip $(module_license_metadata)),\
    $$(foreach f,$$(my_compat_dist_config_$(suite)),$$(call declare-copy-target-license-metadata,$$(call word-colon,2,$$(f)),$$(call word-colon,1,$$(f)))),\
    $$(eval my_test_config += $$(my_compat_dist_config_$(suite))) \
  )) \
  $(if $(filter $(suite),$(ALL_COMPATIBILITY_SUITES)),,\
    $(eval ALL_COMPATIBILITY_SUITES += $(suite)) \
    $(eval COMPATIBILITY.$(suite).FILES :=) \
    $(eval COMPATIBILITY.$(suite).MODULES :=)) \
  $(eval COMPATIBILITY.$(suite).FILES += \
    $$(foreach f,$$(my_compat_dist_$(suite)),$$(call word-colon,2,$$(f))) \
    $$(foreach f,$$(my_compat_dist_config_$(suite)),$$(call word-colon,2,$$(f))) \
    $$(my_compat_dist_test_data_$(suite))) \
  $(eval ALL_COMPATIBILITY_DIST_FILES += $$(my_compat_dist_$(suite))) \
  $(eval COMPATIBILITY.$(suite).MODULES += $$(my_register_name))) \
$(eval $(my_all_targets) : \
  $(sort $(foreach suite,$(LOCAL_COMPATIBILITY_SUITE), \
    $(foreach f,$(my_compat_dist_$(suite)), $(call word-colon,2,$(f))))) \
  $(call copy-many-xml-files-checked, \
    $(sort $(foreach suite,$(LOCAL_COMPATIBILITY_SUITE),$(my_compat_dist_config_$(suite))))))
endef

###########################################################
## Path Cleaning
###########################################################

# Remove "dir .." combinations (but keep ".. ..")
#
# $(1): The expanded path, where / is converted to ' ' to work with $(word)
define _clean-path-strip-dotdot
$(strip \
  $(if $(word 2,$(1)),
    $(if $(call streq,$(word 2,$(1)),..),
      $(if $(call streq,$(word 1,$(1)),..),
        $(word 1,$(1)) $(call _clean-path-strip-dotdot,$(wordlist 2,$(words $(1)),$(1)))
      ,
        $(call _clean-path-strip-dotdot,$(wordlist 3,$(words $(1)),$(1)))
      )
    ,
      $(word 1,$(1)) $(call _clean-path-strip-dotdot,$(wordlist 2,$(words $(1)),$(1)))
    )
  ,
    $(1)
  )
)
endef

# Remove any leading .. from the path (in case of /..)
#
# Should only be called if the original path started with /
# $(1): The expanded path, where / is converted to ' ' to work with $(word)
define _clean-path-strip-root-dotdots
$(strip $(if $(call streq,$(firstword $(1)),..),
  $(call _clean-path-strip-root-dotdots,$(wordlist 2,$(words $(1)),$(1))),
  $(1)))
endef

# Call _clean-path-strip-dotdot until the path stops changing
# $(1): Non-empty if this path started with a /
# $(2): The expanded path, where / is converted to ' ' to work with $(word)
define _clean-path-expanded
$(strip \
  $(eval _ep := $(call _clean-path-strip-dotdot,$(2)))
  $(if $(1),$(eval _ep := $(call _clean-path-strip-root-dotdots,$(_ep))))
  $(if $(call streq,$(2),$(_ep)),
    $(_ep),
    $(call _clean-path-expanded,$(1),$(_ep))))
endef

# Clean the file path -- remove //, dir/.., extra .
#
# This should be the same semantics as golang's filepath.Clean
#
# $(1): The file path to clean
define clean-path
$(strip \
  $(if $(call streq,$(words $(1)),1),
    $(eval _rooted := $(filter /%,$(1)))
    $(eval _expanded_path := $(filter-out .,$(subst /,$(space),$(1))))
    $(eval _path := $(if $(_rooted),/)$(subst $(space),/,$(call _clean-path-expanded,$(_rooted),$(_expanded_path))))
    $(if $(_path),
      $(_path),
      .
     )
  ,
    $(if $(call streq,$(words $(1)),0),
      .,
      $(error Call clean-path with only one path (without spaces))
    )
  )
)
endef

ifeq ($(TEST_MAKE_clean_path),true)
  define my_test
    $(if $(call streq,$(call clean-path,$(1)),$(2)),,
      $(eval my_failed := true)
      $(warning clean-path test '$(1)': expected '$(2)', got '$(call clean-path,$(1))'))
  endef
  my_failed :=

  # Already clean
  $(call my_test,abc,abc)
  $(call my_test,abc/def,abc/def)
  $(call my_test,a/b/c,a/b/c)
  $(call my_test,.,.)
  $(call my_test,..,..)
  $(call my_test,../..,../..)
  $(call my_test,../../abc,../../abc)
  $(call my_test,/abc,/abc)
  $(call my_test,/,/)

  # Empty is current dir
  $(call my_test,,.)

  # Remove trailing slash
  $(call my_test,abc/,abc)
  $(call my_test,abc/def/,abc/def)
  $(call my_test,a/b/c/,a/b/c)
  $(call my_test,./,.)
  $(call my_test,../,..)
  $(call my_test,../../,../..)
  $(call my_test,/abc/,/abc)

  # Remove doubled slash
  $(call my_test,abc//def//ghi,abc/def/ghi)
  $(call my_test,//abc,/abc)
  $(call my_test,///abc,/abc)
  $(call my_test,//abc//,/abc)
  $(call my_test,abc//,abc)

  # Remove . elements
  $(call my_test,abc/./def,abc/def)
  $(call my_test,/./abc/def,/abc/def)
  $(call my_test,abc/.,abc)

  # Remove .. elements
  $(call my_test,abc/def/ghi/../jkl,abc/def/jkl)
  $(call my_test,abc/def/../ghi/../jkl,abc/jkl)
  $(call my_test,abc/def/..,abc)
  $(call my_test,abc/def/../..,.)
  $(call my_test,/abc/def/../..,/)
  $(call my_test,abc/def/../../..,..)
  $(call my_test,/abc/def/../../..,/)
  $(call my_test,abc/def/../../../ghi/jkl/../../../mno,../../mno)
  $(call my_test,/../abc,/abc)

  # Combinations
  $(call my_test,abc/./../def,def)
  $(call my_test,abc//./../def,def)
  $(call my_test,abc/../../././../def,../../def)

  ifdef my_failed
    $(error failed clean-path test)
  endif
endif

###########################################################
## Given a filepath, returns nonempty if the path cannot be
## validated to be contained in the current directory
## This is, this function checks for '/' and '..'
##
## $(1): path to validate
define try-validate-path-is-subdir
$(strip \
    $(if $(filter /%,$(1)),
        $(1) starts with a slash
    )
    $(if $(filter ../%,$(call clean-path,$(1))),
        $(1) escapes its parent using '..'
    )
    $(if $(strip $(1)),
    ,
        '$(1)' is empty
    )
)
endef

define validate-path-is-subdir
$(if $(call try-validate-path-is-subdir,$(1)),
  $(call pretty-error, Illegal path: $(call try-validate-path-is-subdir,$(1)))
)
endef

###########################################################
## Given a space-delimited list of filepaths, returns
## nonempty if any cannot be validated to be contained in
## the current directory
##
## $(1): path list to validate
define try-validate-paths-are-subdirs
$(strip \
  $(foreach my_path,$(1),\
    $(call try-validate-path-is-subdir,$(my_path))\
  )
)
endef

define validate-paths-are-subdirs
$(if $(call try-validate-paths-are-subdirs,$(1)),
    $(call pretty-error,Illegal paths:\'$(call try-validate-paths-are-subdirs,$(1))\')
)
endef

###########################################################
## Tests of try-validate-path-is-subdir
##     and  try-validate-paths-are-subdirs
define test-validate-paths-are-subdirs
$(eval my_error := $(call try-validate-path-is-subdir,/tmp)) \
$(if $(call streq,$(my_error),/tmp starts with a slash),
,
  $(error incorrect error message for path /tmp. Got '$(my_error)')
) \
$(eval my_error := $(call try-validate-path-is-subdir,../sibling)) \
$(if $(call streq,$(my_error),../sibling escapes its parent using '..'),
,
  $(error incorrect error message for path ../sibling. Got '$(my_error)')
) \
$(eval my_error := $(call try-validate-path-is-subdir,child/../../sibling)) \
$(if $(call streq,$(my_error),child/../../sibling escapes its parent using '..'),
,
  $(error incorrect error message for path child/../../sibling. Got '$(my_error)')
) \
$(eval my_error := $(call try-validate-path-is-subdir,)) \
$(if $(call streq,$(my_error),'' is empty),
,
  $(error incorrect error message for empty path ''. Got '$(my_error)')
) \
$(eval my_error := $(call try-validate-path-is-subdir,subdir/subsubdir)) \
$(if $(call streq,$(my_error),),
,
  $(error rejected valid path 'subdir/subsubdir'. Got '$(my_error)')
)

$(eval my_error := $(call try-validate-paths-are-subdirs,a/b /c/d e/f))
$(if $(call streq,$(my_error),/c/d starts with a slash),
,
  $(error incorrect error message for path list 'a/b /c/d e/f'. Got '$(my_error)')
)
$(eval my_error := $(call try-validate-paths-are-subdirs,a/b c/d))
$(if $(call streq,$(my_error),),
,
  $(error rejected valid path list 'a/b c/d'. Got '$(my_error)')
)
endef
# run test
$(strip $(call test-validate-paths-are-subdirs))

###########################################################
## Validate jacoco class filters and convert them to
## file arguments
## Jacoco class filters are comma-separated lists of class
## files (android.app.Application), and may have '*' as the
## last character to match all classes in a package
## including subpackages.
define jacoco-class-filter-to-file-args
$(strip $(call jacoco-validate-file-args,\
  $(subst $(comma),$(space),\
    $(subst .,/,\
      $(strip $(1))))))
endef

define jacoco-validate-file-args
$(strip $(1)\
  $(call validate-paths-are-subdirs,$(1))
  $(foreach arg,$(1),\
    $(if $(findstring ?,$(arg)),$(call pretty-error,\
      '?' filters are not supported in LOCAL_JACK_COVERAGE_INCLUDE_FILTER or LOCAL_JACK_COVERAGE_EXCLUDE_FILTER))\
    $(if $(findstring *,$(patsubst %*,%,$(arg))),$(call pretty-error,\
      '*' is only supported at the end of a filter in LOCAL_JACK_COVERAGE_INCLUDE_FILTER or LOCAL_JACK_COVERAGE_EXCLUDE_FILTER))\
  ))
endef

###########################################################
## Other includes
###########################################################

# Include any vendor specific definitions.mk file
-include $(TOPDIR)vendor/*/build/core/definitions.mk
-include $(TOPDIR)device/*/build/core/definitions.mk
-include $(TOPDIR)product/*/build/core/definitions.mk
# Also the project-specific definitions.mk file
-include $(TOPDIR)vendor/*/*/build/core/definitions.mk
-include $(TOPDIR)device/*/*/build/core/definitions.mk
-include $(TOPDIR)product/*/*/build/core/definitions.mk

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


###########################################################
# Append the information to generate a RRO package for the
# source module.
#
#  $(1): Source module name.
#  $(2): Whether $(3) is a manifest package name or not.
#  $(3): Manifest package name if $(2) is true.
#        Otherwise, android manifest file path of the
#        source module.
#  $(4): Whether LOCAL_EXPORT_PACKAGE_RESOURCES is set or
#        not for the source module.
#  $(5): Resource overlay list.
#  $(6): Target partition
###########################################################
define append_enforce_rro_sources
  $(eval ENFORCE_RRO_SOURCES += \
      $(strip $(1))||$(strip $(2))||$(strip $(3))||$(strip $(4))||$(call normalize-path-list, $(strip $(5)))||$(strip $(6)) \
  )
endef

###########################################################
# Generate all RRO packages for source modules stored in
# ENFORCE_RRO_SOURCES
###########################################################
define generate_all_enforce_rro_packages
$(foreach source,$(ENFORCE_RRO_SOURCES), \
  $(eval _o := $(subst ||,$(space),$(source))) \
  $(eval enforce_rro_source_module := $(word 1,$(_o))) \
  $(eval enforce_rro_source_is_manifest_package_name := $(word 2,$(_o))) \
  $(eval enforce_rro_source_manifest_package_info := $(word 3,$(_o))) \
  $(eval enforce_rro_use_res_lib := $(word 4,$(_o))) \
  $(eval enforce_rro_source_overlays := $(subst :, ,$(word 5,$(_o)))) \
  $(eval enforce_rro_partition := $(word 6,$(_o))) \
  $(eval include $(BUILD_SYSTEM)/generate_enforce_rro.mk) \
  $(eval ALL_MODULES.$$(enforce_rro_source_module).REQUIRED_FROM_TARGET += $$(LOCAL_PACKAGE_NAME)) \
)
endef

###########################################################
## Find system_$(VER) in LOCAL_SDK_VERSION
## note: system_server_* is excluded. It's a different API surface
##
## $(1): LOCAL_SDK_VERSION
###########################################################
define has-system-sdk-version
$(filter-out system_server_%,$(filter system_%,$(1)))
endef

###########################################################
## Get numerical version in LOCAL_SDK_VERSION
##
## $(1): LOCAL_SDK_VERSION
###########################################################
define get-numeric-sdk-version
$(filter-out current,\
  $(if $(call has-system-sdk-version,$(1)),$(patsubst system_%,%,$(1)),$(1)))
endef

###########################################################
## Verify module name meets character requirements:
##   a-z A-Z 0-9
##   _.+-,@~
##
## This is a subset of bazel's target name restrictions:
##   https://docs.bazel.build/versions/master/build-ref.html#name
##
## Kati has problems with '=': https://github.com/google/kati/issues/138
###########################################################
define verify-module-name
$(if $(filter-out $(LOCAL_MODULE),$(subst /,,$(LOCAL_MODULE))), \
  $(call pretty-warning,Module name contains a /$(comma) use LOCAL_MODULE_STEM and LOCAL_MODULE_RELATIVE_PATH instead)) \
$(if $(call _invalid-name-chars,$(LOCAL_MODULE)), \
  $(call pretty-error,Invalid characters in module name: $(call _invalid-name-chars,$(LOCAL_MODULE))))
endef
define _invalid-name-chars
$(subst _,,$(subst .,,$(subst +,,$(subst -,,$(subst $(comma),,$(subst @,,$(subst ~,,$(subst 0,,$(subst 1,,$(subst 2,,$(subst 3,,$(subst 4,,$(subst 5,,$(subst 6,,$(subst 7,,$(subst 8,,$(subst 9,,$(subst a,,$(subst b,,$(subst c,,$(subst d,,$(subst e,,$(subst f,,$(subst g,,$(subst h,,$(subst i,,$(subst j,,$(subst k,,$(subst l,,$(subst m,,$(subst n,,$(subst o,,$(subst p,,$(subst q,,$(subst r,,$(subst s,,$(subst t,,$(subst u,,$(subst v,,$(subst w,,$(subst x,,$(subst y,,$(subst z,,$(call to-lower,$(1)))))))))))))))))))))))))))))))))))))))))))))
endef
.KATI_READONLY := verify-module-name _invalid-name-chars

###########################################################
## Verify module stem meets character requirements:
##   a-z A-Z 0-9
##   _.+-,@~
##
## This is a subset of bazel's target name restrictions:
##   https://docs.bazel.build/versions/master/build-ref.html#name
##
## $(1): The module stem variable to check
###########################################################
define verify-module-stem
$(if $(filter-out $($(1)),$(subst /,,$($(1)))), \
  $(call pretty-warning,Module stem \($(1)\) contains a /$(comma) use LOCAL_MODULE_RELATIVE_PATH instead)) \
$(if $(call _invalid-name-chars,$($(1))), \
  $(call pretty-error,Invalid characters in module stem \($(1)\): $(call _invalid-name-chars,$($(1)))))
endef
.KATI_READONLY := verify-module-stem

$(KATI_obsolete_var \
  create-empty-package \
  initialize-package-file \
  add-jni-shared-libs-to-package \
  inherit-package,\
  These functions have been removed)

###########################################################
## Verify the variants of a VNDK library are identical
##
## $(1): Path to the core variant shared library file.
## $(2): Path to the vendor variant shared library file.
## $(3): TOOLS_PREFIX
###########################################################
LIBRARY_IDENTITY_CHECK_SCRIPT := build/make/tools/check_identical_lib.sh
define verify-vndk-libs-identical
@echo "Checking VNDK vendor variant: $(2)"
$(hide) CLANG_BIN="$(LLVM_PREBUILTS_PATH)" \
  CROSS_COMPILE="$(strip $(3))" \
  XZ="$(XZ)" \
  $(LIBRARY_IDENTITY_CHECK_SCRIPT) $(SOONG_STRIP_PATH) $(1) $(2)
endef

# Convert Soong libraries that have SDK variant
define use_soong_sdk_libraries
  $(foreach l,$(1),$(if $(filter $(l),$(SOONG_SDK_VARIANT_MODULES)),\
      $(l).sdk,$(l)))
endef
