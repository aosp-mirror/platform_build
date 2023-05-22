#
# Copyright (C) 2007 The Android Open Source Project
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

# When specifying "dist", the user has asked that we copy the important
# files from this build into DIST_DIR.

# list of all goals that depend on any dist files
_all_dist_goals :=
# pairs of goal:distfile
_all_dist_goal_output_pairs :=
# pairs of srcfile:distfile
_all_dist_src_dst_pairs :=

# Other parts of the system should use this function to associate
# certain files with certain goals.  When those goals are built
# and "dist" is specified, the marked files will be copied to DIST_DIR.
#
# $(1): a list of goals  (e.g. droid, sdk, ndk). These must be PHONY
# $(2): the dist files to add to those goals.  If the file contains ':',
#       the text following the colon is the name that the file is copied
#       to under the dist directory.  Subdirs are ok, and will be created
#       at copy time if necessary.
define dist-for-goals
$(if $(strip $(2)), \
  $(eval _all_dist_goals += $$(1))) \
$(foreach file,$(2), \
  $(eval src := $(call word-colon,1,$(file))) \
  $(eval dst := $(call word-colon,2,$(file))) \
  $(if $(dst),,$(eval dst := $$(notdir $$(src)))) \
  $(eval _all_dist_src_dst_pairs += $$(src):$$(dst)) \
  $(foreach goal,$(1), \
    $(eval _all_dist_goal_output_pairs += $$(goal):$$(dst))))
endef

define add_file_name_tag_suffix
$(basename $(notdir $1))-FILE_NAME_TAG_PLACEHOLDER$(suffix $1)
endef

# This function appends suffix FILE_NAME_TAG_PLACEHOLDER from the input file
# $(1): a list of goals  (e.g. droid, sdk, ndk). These must be PHONY
# $(2): the dist files to add to those goals.
define dist-for-goals-with-filenametag
$(if $(strip $(2)), \
  $(foreach file,$(2), \
    $(call dist-for-goals,$(1),$(file):$(call add_file_name_tag_suffix,$(file)))))
endef
.PHONY: shareprojects

define __share-projects-rule
$(1) : PRIVATE_TARGETS := $(2)
$(1): $(2) $(COMPLIANCE_LISTSHARE)
	$(hide) rm -f $$@
	mkdir -p $$(dir $$@)
	$$(if $$(strip $$(PRIVATE_TARGETS)),OUT_DIR=$(OUT_DIR) $(COMPLIANCE_LISTSHARE) -o $$@ $$(PRIVATE_TARGETS),touch $$@)
endef

# build list of projects to share in $(1) for meta_lic in $(2)
#
# $(1): the intermediate project sharing file
# $(2): the license metadata to base the sharing on
define _share-projects-rule
$(eval $(call __share-projects-rule,$(1),$(2)))
endef

.PHONY: alllicensetexts

define __license-texts-rule
$(2) : PRIVATE_GOAL := $(1)
$(2) : PRIVATE_TARGETS := $(3)
$(2) : PRIVATE_ROOTS := $(4)
$(2) : PRIVATE_ARGUMENT_FILE := $(call intermediates-dir-for,METAPACKAGING,licensetexts)/$(2)/arguments
$(2): $(3) $(TEXTNOTICE)
	$(hide) rm -f $$@
	mkdir -p $$(dir $$@)
	mkdir -p $$(dir $$(PRIVATE_ARGUMENT_FILE))
	$$(if $$(strip $$(PRIVATE_TARGETS)),$$(call dump-words-to-file,\
            -product="$$(PRIVATE_GOAL)" -title="$$(PRIVATE_GOAL)" \
            $$(addprefix -strip_prefix ,$$(PRIVATE_ROOTS)) \
            -strip_prefix=$(PRODUCT_OUT)/ -strip_prefix=$(HOST_OUT)/\
            $$(PRIVATE_TARGETS),\
            $$(PRIVATE_ARGUMENT_FILE)))
	$$(if $$(strip $$(PRIVATE_TARGETS)),OUT_DIR=$(OUT_DIR) $(TEXTNOTICE) -o $$@ @$$(PRIVATE_ARGUMENT_FILE),touch $$@)
endef

# build list of projects to share in $(2) for meta_lic in $(3) for dist goals $(1)
# Strip `out/dist/` used as proxy for 'DIST_DIR'
#
# $(1): the name of the dist goals
# $(2): the intermediate project sharing file
# $(3): the license metadata to base the sharing on
define _license-texts-rule
$(eval $(call __license-texts-rule,$(1),$(2),$(3),out/dist/))
endef

###########################################################
## License metadata build rule for dist target $(1) with meta_lic $(2) copied from $(3)
###########################################################
define _dist-target-license-metadata-rule
$(strip $(eval _meta :=$(2)))
$(strip $(eval _dep:=))
# 0p is the indicator for a non-copyrightable file where no party owns the copyright.
# i.e. pure data with no copyrightable expression.
# If all of the sources are 0p and only 0p, treat the copied file as 0p. Otherwise, all
# of the sources must either be 0p or originate from a single metadata file to copy.
$(strip $(foreach s,$(strip $(3)),\
  $(eval _dmeta:=$(ALL_TARGETS.$(s).META_LIC))\
  $(if $(strip $(_dmeta)),\
    $(if $(filter-out 0p,$(_dep)),\
      $(if $(filter-out $(_dep) 0p,$(_dmeta)),\
        $(error cannot copy target from multiple modules: $(1) from $(_dep) and $(_dmeta)),\
        $(if $(filter 0p,$(_dep)),$(eval _dep:=$(_dmeta)))),\
      $(eval _dep:=$(_dmeta))\
    ),\
    $(eval TARGETS_MISSING_LICENSE_METADATA += $(s) $(1)))))


ifeq (0p,$(strip $(_dep)))
# Not copyrightable. No emcumbrances, no license text, no license kind etc.
$(_meta): PRIVATE_CONDITIONS := unencumbered
$(_meta): PRIVATE_SOURCES := $(3)
$(_meta): PRIVATE_INSTALLED := $(1)
# use `$(1)` which is the unique and relatively short `out/dist/$(target)`
$(_meta): PRIVATE_ARGUMENT_FILE := $(call intermediates-dir-for,METAPACKAGING,notice)/$(1)/arguments
$(_meta): $(BUILD_LICENSE_METADATA)
$(_meta) :
	rm -f $$@
	mkdir -p $$(dir $$@)
	mkdir -p $$(dir $$(PRIVATE_ARGUMENT_FILE))
	$$(call dump-words-to-file,\
	    $$(addprefix -c ,$$(PRIVATE_CONDITIONS))\
	    $$(addprefix -s ,$$(PRIVATE_SOURCES))\
	    $$(addprefix -t ,$$(PRIVATE_TARGETS))\
	    $$(addprefix -i ,$$(PRIVATE_INSTALLED)),\
	    $$(PRIVATE_ARGUMENT_FILE))
	OUT_DIR=$(OUT_DIR) $(BUILD_LICENSE_METADATA) \
	  @$$(PRIVATE_ARGUMENT_FILE) \
	  -o $$@

else ifneq (,$(strip $(_dep)))
# Not a missing target, copy metadata and `is_container` etc. from license metadata file `$(_dep)`
$(_meta): PRIVATE_DEST_TARGET := $(1)
$(_meta): PRIVATE_SOURCE_TARGETS := $(3)
$(_meta): PRIVATE_SOURCE_METADATA := $(_dep)
# use `$(1)` which is the unique and relatively short `out/dist/$(target)`
$(_meta): PRIVATE_ARGUMENT_FILE := $(call intermediates-dir-for,METAPACKAGING,copynotice)/$(1)/arguments
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
endef

# use `out/dist/` as a proxy for 'DIST_DIR'
define _add_projects_to_share
$(strip $(eval _mdir := $(call intermediates-dir-for,METAPACKAGING,meta)/out/dist)) \
$(strip $(eval _idir := $(call intermediates-dir-for,METAPACKAGING,shareprojects))) \
$(strip $(eval _tdir := $(call intermediates-dir-for,METAPACKAGING,licensetexts))) \
$(strip $(eval _allt := $(sort $(foreach goal,$(_all_dist_goal_output_pairs),$(call word-colon,2,$(goal)))))) \
$(foreach target,$(_allt), \
  $(eval _goals := $(sort $(foreach dg,$(filter %:$(target),$(_all_dist_goal_output_pairs)),$(call word-colon,1,$(dg))))) \
  $(eval _srcs := $(sort $(foreach sdp,$(filter %:$(target),$(_all_dist_src_dst_pairs)),$(call word-colon,1,$(sdp))))) \
  $(eval $(call _dist-target-license-metadata-rule,out/dist/$(target),$(_mdir)/out/dist/$(target).meta_lic,$(_srcs))) \
  $(eval _f := $(_idir)/$(target).shareprojects) \
  $(eval _n := $(_tdir)/$(target).txt) \
  $(eval $(call dist-for-goals,$(_goals),$(_f):shareprojects/$(target).shareprojects)) \
  $(eval $(call dist-for-goals,$(_goals),$(_n):licensetexts/$(target).txt)) \
  $(eval $(call _share-projects-rule,$(_f),$(foreach t, $(filter-out $(TARGETS_MISSING_LICENSE_METADATA),out/dist/$(target)),$(_mdir)/$(t).meta_lic))) \
  $(eval $(call _license-texts-rule,$(_goals),$(_n),$(foreach t,$(filter-out $(TARGETS_MISSING_LICENSE_METADATA),out/dist/$(target)),$(_mdir)/$(t).meta_lic))) \
)
endef

#------------------------------------------------------------------
# To be used at the end of the build to collect all the uses of
# dist-for-goals, and write them into a file for the packaging step to use.

# $(1): The file to write
define dist-write-file
$(strip \
  $(call _add_projects_to_share)\
  $(if $(strip $(ANDROID_REQUIRE_LICENSE_METADATA)),\
    $(foreach target,$(sort $(TARGETS_MISSING_LICENSE_METADATA)),$(warning target $(target) missing license metadata))\
    $(if $(strip $(TARGETS_MISSING_LICENSE_METADATA)),\
      $(if $(filter true error,$(ANDROID_REQUIRE_LICENSE_METADATA)),\
        $(error $(words $(sort $(TARGETS_MISSING_LICENSE_METADATA))) targets need license metadata))))\
  $(foreach t,$(sort $(ALL_NON_MODULES)),$(call record-missing-non-module-dependencies,$(t))) \
  $(eval $(call report-missing-licenses-rule)) \
  $(eval $(call report-all-notice-library-names-rule)) \
  $(KATI_obsolete_var dist-for-goals,Cannot be used after dist-write-file) \
  $(foreach goal,$(sort $(_all_dist_goals)), \
    $(eval $$(goal): _dist_$$(goal))) \
  $(shell mkdir -p $(dir $(1))) \
  $(file >$(1).tmp, \
    DIST_GOAL_OUTPUT_PAIRS := $(sort $(_all_dist_goal_output_pairs)) \
    $(newline)DIST_SRC_DST_PAIRS := $(sort $(_all_dist_src_dst_pairs))) \
  $(shell if ! cmp -s $(1).tmp $(1); then \
            mv $(1).tmp $(1); \
          else \
            rm $(1).tmp; \
          fi))
endef

.KATI_READONLY := dist-for-goals dist-write-file dist-for-goals-with-filenametag
